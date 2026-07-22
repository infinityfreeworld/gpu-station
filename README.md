# DATASPACE — image « GPU Station »

Image conteneur pour les machines GPU louées à la demande par le réseau
[DATASPACE](https://data-space.world). Elle embarque déjà les modèles, ce qui évite de
réinstaller ~14 Go de poids à chaque location.

| Capacité | Modèle | Poids inclus |
|---|---|---|
| image → 3D | [TripoSR](https://github.com/VAST-AI-Research/TripoSR) | ~1,7 Go |
| image → vidéo | [LTX-Video](https://huggingface.co/Lightricks/LTX-Video) | ~14 Go |

Sans elle, une machine fraîchement louée passe 10 à 15 minutes à installer PyTorch, cloner
les dépôts et télécharger les poids avant de pouvoir calculer quoi que ce soit. Avec elle,
la station est opérationnelle en ~2 minutes — le temps du téléchargement de l'image, que
les hébergeurs mettent ensuite en cache.

## Utilisation

```
ghcr.io/infinityfreeworld/gpu-station:1
```

Prévoir **au moins 60 Go de disque** : l'image en occupe ~35 Go.

Au démarrage, la station valide chaque capacité sur la carte réellement présente (les tests
ne peuvent pas s'exécuter pendant la construction, faute de GPU), puis rejoint le réseau si
la variable `DS_INSTALL_URL` lui fournit un jeton d'installation à usage unique. Une capacité
qui n'a pas passé son test n'est jamais déclarée : le réseau ne promet que ce qu'il sait faire.

## Construction

Les installeurs officiels de DATASPACE sont appelés pendant la construction plutôt que
recopiés ici : une seule source de vérité, donc aucune dérive possible entre ce que la
station installe et ce que le réseau attend d'elle.

La construction tourne sur GitHub Actions (`.github/workflows/build.yml`), sur disque
jetable — l'image de 35 Go ne peut pas être assemblée sur un serveur de production sans
risquer d'en saturer le disque.

## Licences

Le code de ce dépôt est sous licence MIT. Les modèles embarqués relèvent de leurs licences
respectives, à consulter chez leurs auteurs.
