#!/usr/bin/env bash
# Démarrage d'une station GPU pré-cuite : les modèles sont déjà dans l'image, il ne reste
# qu'à PROUVER qu'ils tournent sur cette carte, puis à rejoindre le réseau.
set -u

BASE="${DS_BASE:-https://data-space.world}"
echo "● DATASPACE GPU Station (image pré-cuite)"

# 1) Carte détectée ? (sans GPU, la station ne sert à rien pour la 3D/vidéo)
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | sed 's/^/   GPU : /'
else
  echo "   ⚠ aucun GPU NVIDIA détecté — la station ne pourra pas calculer 3D/vidéo."
fi

# 2) Tests de fumée RÉELS (rapides : tout est déjà installé). Ils créent run.sh, seul
#    marqueur que l'agent lit pour déclarer une capacité — pas de test, pas de capacité.
smoke() {
  local dir="$1" kind="$2"
  [ -d "$dir" ] || return 1
  [ -x "$dir/run.sh" ] && return 0        # déjà validé (redémarrage de l'instance)
  echo "   → validation $kind sur cette carte…"
  # L'installeur normal est RAPIDE ici : dépendances déjà satisfaites, poids déjà en cache.
  # Il ne fait donc en pratique que le test de fumée, qui crée run.sh.
  bash -c "curl -fsSL \"$BASE/api/spot/${kind}-install\" | bash" >"/var/log/ds-${kind}-smoke.log" 2>&1 \
    && echo "   ✓ $kind prête" \
    || echo "   ⚠ $kind non validée (voir /var/log/ds-${kind}-smoke.log)"
}
smoke /var/lib/dataspace/mesh3d mesh3d &
smoke /var/lib/dataspace/video video &
wait

# 3) Rattachement au réseau : l'admin DATASPACE fournit une URL d'installation à usage
#    unique (jeton). Sans elle, la station reste locale — on le dit clairement.
if [ -n "${DS_INSTALL_URL:-}" ]; then
  echo "   → rattachement au réseau DATASPACE…"
  curl -fsSL "$DS_INSTALL_URL" | bash || echo "   ⚠ rattachement échoué (jeton expiré ? usage unique)"
else
  echo "   ⚠ DS_INSTALL_URL absente : station NON rattachée au réseau."
  echo "     Lance depuis l'admin DATASPACE une location (le jeton est injecté automatiquement)."
fi

# 4) On garde le conteneur vivant : l'agent tourne en arrière-plan, ce processus veille.
echo "● Station prête. Journal de l'agent : tail -f /var/log/ds-agent.log"
while true; do sleep 3600; done
