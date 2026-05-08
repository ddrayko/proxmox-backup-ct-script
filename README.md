# Proxmox Backup CLI v2 🚀

A modern and elegant command-line tool to automate the backup of your Proxmox containers (LXC).

![Banner](.assets/Capture%20d’écran%20du%202026-05-08%2020-18-53.png)

## ✨ Features

*   **Premium Interface**: Sticky bottom progress bar, smooth spinners, and a final summary table.
*   **Secure Workflow**: Operates on a temporary clone to minimize downtime of the source container.
*   **Smart Filtering**: Backup all your containers or target specific ones by ID.
*   **Full Logging**: Every execution is recorded in the `logs/` folder.
*   **Resilient**: Handles terminal resizing and automatic cleanup upon interruption (Ctrl+C).

## 🛠️ Prerequisites

*   `sshpass` (for non-interactive authentication)
*   Root SSH access to your Proxmox server.
*   `python3` (optional, used for precise final table width calculation).

## 🚀 Installation

```bash
git clone https://github.com/ddrayko/proxmox-backup-ct-script.git
cd proxmox-backup-ct-script
chmod +x backup.sh
```

## 📖 Usage

Simply run the script for interactive mode:
```bash
./backup.sh
```

Or use arguments to automate:
```bash
# Backup CT 101 and 102 to a specific folder
./backup.sh --ct 101,102 --dest /your/backup/path
```

### Options
- `-h, --help`: Displays help.
- `-c, --ct ID1,ID2`: List of container IDs separated by commas.
- `-d, --dest PATH`: Local path to store backups.

## 🔐 Security

*   **Password Handling**: The root password is only stored in memory during execution and is never written to disk or logs.
*   **SSH Verification**: The script uses `-o StrictHostKeyChecking=accept-new` for a balance of security and automation. It automatically trusts new hosts but alerts you if a known host's key changes. For more details, see the [technical documentation](doc.md).

## 📸 Screenshots

### Processing in progress
![Process](.assets/Capture%20d’écran%20du%202026-05-08%2020-20-15.png)

---
*Developed with ❤️ by Drayko*
