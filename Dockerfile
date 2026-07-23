# 🛡️ DATASPACE — image « GPU Station » pré-cuite (3D + vidéo).
#
# Problème résolu : sur une machine louée (Vast/RunPod), le disque est JETABLE. Sans image
# pré-cuite, chaque nouvelle instance réinstalle PyTorch, TripoSR et LTX-Video et retélécharge
# ~14 Go de poids — 10 à 15 minutes avant de pouvoir calculer. Ici tout est déjà dedans :
# la station est opérationnelle en ~2 min (le temps du pull, que Vast met ensuite en cache).
#
# Principe : on APPELLE LES INSTALLEURS OFFICIELS (une seule source de vérité, pas de copie
# de logique) en mode DS_PREFETCH=1 — dépendances + poids, sans le test de fumée qui exige un
# GPU absent au moment de la construction. Le test réel a lieu au PREMIER DÉMARRAGE sur la
# vraie carte : la capacité n'est donc jamais déclarée sans preuve.
#
# Construction :  podman build -t dataspace/gpu-station:1 .
# Utilisation   :  passée en `image` à createInstance (app/lib/vast-api.js)

FROM docker.io/pytorch/pytorch:2.4.0-cuda12.4-cudnn9-devel

LABEL org.opencontainers.image.title="DATASPACE GPU Station" \
      org.opencontainers.image.description="Station de calcul DATASPACE : image→3D (TripoSR) et image→vidéo (LTX-Video), modèles inclus" \
      org.opencontainers.image.licenses="MIT"

ARG DS_BASE=https://data-space.world
ENV DEBIAN_FRONTEND=noninteractive \
    HF_HOME=/opt/ds/hf \
    PYTHONUNBUFFERED=1

# Outils requis par les installeurs et par l'agent (ffmpeg sert à l'audio/vidéo).
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl ca-certificates ffmpeg build-essential python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Les poids partagent un cache unique (HF_HOME) → une seule copie dans l'image.
RUN mkdir -p /opt/ds/hf /var/lib/dataspace

# Cache-bust : les installeurs sont servis dynamiquement par DATASPACE et évoluent, mais
# l'instruction RUN ne change pas — Docker réutiliserait alors une couche périmée. On bump ce
# marqueur à chaque correctif d'installeur pour forcer la reconstruction des couches ci-dessous.
# v2 (2026-07-23) : mesh3d fige numpy<2 (tsr/torchmcubes/ptp), video ajoute tiktoken.
ARG INSTALLERS_REV=v2-2026-07-23

# ── Capacité 3D : TripoSR + poids (~1,7 Go) ────────────────────────────────────
RUN echo "rev ${INSTALLERS_REV}" && DS_PREFETCH=1 bash -c "curl -fsSL ${DS_BASE}/api/spot/mesh3d-install | bash"

# ── Capacité VIDÉO : LTX-Video + poids (~12 Go) ────────────────────────────────
# Couche séparée : si le modèle vidéo change, la couche 3D reste en cache.
RUN echo "rev ${INSTALLERS_REV}" && DS_PREFETCH=1 bash -c "curl -fsSL ${DS_BASE}/api/spot/video-install | bash"

# Au démarrage, la station se rattache au réseau : l'instance passe le jeton d'installation
# dans DS_INSTALL_URL (fabriqué par l'admin DATASPACE). Les tests de fumée s'exécutent alors
# sur la vraie carte et valident les capacités.
COPY entrypoint.sh /usr/local/bin/ds-entrypoint.sh
RUN chmod +x /usr/local/bin/ds-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/ds-entrypoint.sh"]
