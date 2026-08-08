# 🛡️ DATASPACE — image « GPU Station » pré-cuite.
#
# Problème résolu : sur une machine louée (Vast/RunPod), le disque est JETABLE. Sans image
# pré-cuite, chaque nouvelle instance réinstalle PyTorch, TripoSR et LTX-Video et retélécharge
# les poids — 10 à 15 minutes avant de pouvoir calculer. Ici tout est déjà dedans.
#
# Principe : on APPELLE LES INSTALLEURS OFFICIELS (une seule source de vérité, pas de copie
# de logique) en mode DS_PREFETCH=1 — dépendances + poids, sans le test de fumée qui exige un
# GPU absent au moment de la construction. Le test réel a lieu au PREMIER DÉMARRAGE sur la
# vraie carte : la capacité n'est donc jamais déclarée sans preuve.
#
# ── DEUX IMAGES DEPUIS UN SEUL FICHIER (2026-08-08) ────────────────────────────
# MESURÉ sur le manifeste publié de l'image unique (36,24 Go compressés) :
#     base PyTorch/CUDA  7,9 Go · paquets  0,2 Go · 3D  7,9 Go · VIDÉO  20,2 Go
# La vidéo pesait donc **56 % de l'image** — et une station louée pour un job 3D la
# téléchargeait INTÉGRALEMENT pour rien. Mesuré en conditions réelles le même jour :
# 24 minutes bloquées en « loading » sur le seul téléchargement, contre ~3 minutes
# pour l'installation ET le calcul réunis. Le goulot d'étranglement était là, pas
# dans la compilation CUDA que j'avais optimisée juste avant.
#
#   cible « trois-d »  → base + 3D            (~16 Go)  tag :3d
#   cible « complet »  → trois-d + vidéo      (~36 Go)  tag :1 et :latest
#
# L'autoscale choisit l'image selon les capacités RÉELLEMENT demandées par la file
# (cf. activeImage() dans app/lib/vast-api.js). Une station 3D démarre donc sur
# ~16 Go au lieu de 36.
#
# Construction :  docker build --target trois-d -t …:3d .
#                 docker build --target complet -t …:1  .

FROM docker.io/pytorch/pytorch:2.4.0-cuda12.4-cudnn9-devel AS base

LABEL org.opencontainers.image.title="DATASPACE GPU Station" \
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
# v4 (2026-08-08) : mesh3d exige la PREUVE de CUDA (mcubes_cuda) avant de sauter la compilation.
ARG INSTALLERS_REV=v5-2026-08-08

# ══ CIBLE « trois-d » — base + capacité 3D (TripoSR). Image légère. ═══════════
FROM base AS trois-d
LABEL org.opencontainers.image.description="Station DATASPACE — image→3D (TripoSR), modèles inclus"
ARG DS_BASE
ARG INSTALLERS_REV
RUN echo "rev ${INSTALLERS_REV}" && DS_PREFETCH=1 bash -c "curl -fsSL ${DS_BASE}/api/spot/mesh3d-install | bash"

# L'entrée est posée ICI pour que les DEUX cibles en héritent : « complet » part de
# « trois-d ». La placer après la vidéo la rendrait absente de l'image légère.
COPY entrypoint.sh /usr/local/bin/ds-entrypoint.sh
RUN chmod +x /usr/local/bin/ds-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/ds-entrypoint.sh"]

# ══ CIBLE « complet » — ajoute la vidéo (LTX-Video, ~20 Go). ══════════════════
# Couche séparée : si le modèle vidéo change, la couche 3D reste en cache.
FROM trois-d AS complet
LABEL org.opencontainers.image.description="Station DATASPACE — image→3D (TripoSR) et image→vidéo (LTX-Video), modèles inclus"
ARG DS_BASE
ARG INSTALLERS_REV
RUN echo "rev ${INSTALLERS_REV}" && DS_PREFETCH=1 bash -c "curl -fsSL ${DS_BASE}/api/spot/video-install | bash"
