# Documentation Technique - Proxmox Backup CLI v2

Ce document détaille le fonctionnement interne du script de sauvegarde.

## 🏗️ Architecture du Projet

```text
backup-proxmox-v2/
├── backup.sh        # Script principal (Logique et boucle)
├── lib/
│   ├── colors.sh    # Définition des couleurs ANSI et icônes
│   └── utils.sh     # Fonctions UI (Spinner, Progress Bar, Summary)
├── logs/            # Fichiers logs générés (format backup-date-heure.log)
└── .assets/         # Ressources visuelles pour le README
```

## 🔄 Flux de Travail (Workflow)

Pour chaque container (CTID) traité, le script suit ces étapes :

1.  **Dévérouillage & Nettoyage** : S'assure que le CT n'est pas vérouillé et qu'aucun résidu d'une session précédente n'existe.
2.  **Arrêt de la Source** : Le CT source est arrêté proprement (`pct shutdown`).
3.  **Clonage** : Création d'un clone complet (`pct clone`) avec un ID temporaire (CTID + 9000).
4.  **Redémarrage Source** : Le CT original est relancé immédiatement pour minimiser l'interruption de service.
5.  **Conversion en Template** : Le clone est transformé en template Proxmox.
6.  **Sauvegarde (VZDump)** : Génération de l'archive compressée (zstd) à partir du template.
7.  **Téléchargement (SCP)** : Récupération du fichier `.tar.zst` sur la machine locale.
8.  **Nettoyage final** : Suppression du template et des fichiers temporaires sur le serveur Proxmox.

## 🎨 Interface Utilisateur (UI)

L'interface repose sur plusieurs mécanismes `tput` et codes d'échappement ANSI :

### Barre de progression (Sticky Bottom)
La fonction `draw_bottom_bar` utilise `tput cup` pour se positionner systématiquement sur la dernière ligne du terminal. Elle est rafraîchie à chaque étape majeure.

### Gestion du redimensionnement
Un trap sur le signal `SIGWINCH` appelle `handle_resize`, ce qui permet de recalculer la position de la barre de progression si l'utilisateur change la taille de sa fenêtre.

### Résumé Final
Le tableau final utilise un calcul de largeur dynamique. Il tente d'utiliser `python3` pour mesurer précisément la largeur des caractères Unicode (les emojis comptant pour 2 colonnes), avec un repli (fallback) sur une mesure bash standard.

## 🔐 Sécurité

Le script utilise `sshpass` pour gérer le mot de passe root fourni au démarrage. Le mot de passe est stocké uniquement en mémoire pendant la durée de l'exécution et n'est jamais écrit en clair dans les logs.
Toutes les commandes SSH utilisent l'option `-o StrictHostKeyChecking=no` pour faciliter l'usage sur des réseaux locaux changeants.

---
*Dernière mise à jour : 08/05/2026*
