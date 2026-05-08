# Proxmox Backup CLI v2 🚀

Un outil en ligne de commande moderne et élégant pour automatiser la sauvegarde de vos containers Proxmox (LXC).

![Banner](.assets/Capture%20d’écran%20du%202026-05-08%2020-18-53.png)

## ✨ Caractéristiques

*   **Interface Premium** : Barre de progression "sticky" en bas de terminal, spinners fluides et résumé final sous forme de tableau.
*   **Workflow Sécurisé** : Travaille sur un clone temporaire pour minimiser le temps d'arrêt du container source.
*   **Filtrage Intelligent** : Sauvegardez tous vos containers ou ciblez-en certains par ID.
*   **Logs Complets** : Chaque exécution est enregistrée dans le dossier `logs/`.
*   **Résilient** : Gestion du redimensionnement du terminal et nettoyage automatique en cas d'interruption (Ctrl+C).

## 🛠️ Prérequis

*   `sshpass` (pour l'authentification non-interactive)
*   Accès SSH root sur votre serveur Proxmox.
*   `python3` (optionnel, utilisé pour un calcul précis de la largeur du tableau final).

## 🚀 Installation

```bash
git clone https://github.com/votre-repo/backup-proxmox-v2.git
cd backup-proxmox-v2
chmod +x backup.sh
```

## 📖 Utilisation

Lancez simplement le script pour le mode interactif :
```bash
./backup.sh
```

Ou utilisez les arguments pour automatiser :
```bash
# Sauvegarder les CT 101 et 102 dans un dossier spécifique
./backup.sh --ct 101,102 --dest /votre/chemin/sauvegarde
```

### Options
- `-h, --help` : Affiche l'aide.
- `-c, --ct ID1,ID2` : Liste des IDs de containers séparés par des virgules.
- `-d, --dest PATH` : Chemin local pour stocker les sauvegardes.

## 📸 Screenshots

### En cours de traitement
![Process](.assets/Capture%20d’écran%20du%202026-05-08%2020-20-15.png)

---
*Développé avec ❤️ par Drayko*
