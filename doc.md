# Technical Documentation - Proxmox Backup CLI v2

This document details the internal workings of the backup script.

## 🏗️ Project Architecture

```text
backup-proxmox-v2/
├── backup.sh        # Main script (Logic and loop)
├── lib/
│   ├── colors.sh    # ANSI colors and icons definition
│   └── utils.sh     # UI functions (Spinner, Progress Bar, Summary)
├── logs/            # Generated log files (format backup-date-time.log)
└── .assets/         # Visual resources for the README
```

## 🔄 Workflow

For each container (CTID) processed, the script follows these steps:

1.  **Unlock & Cleanup**: Ensures the CT is not locked and no leftovers from a previous session exist.
2.  **Stop Source**: The source CT is gracefully shut down (`pct shutdown`).
3.  **Cloning**: Creation of a full clone (`pct clone`) with a temporary ID (CTID + 9000).
4.  **Restart Source**: The original CT is restarted immediately to minimize service interruption.
5.  **Convert to Template**: The clone is transformed into a Proxmox template.
6.  **Backup (VZDump)**: Generation of the compressed archive (zstd) from the template.
7.  **Download (SCP)**: Retrieval of the `.tar.zst` file to the local machine.
8.  **Final Cleanup**: Deletion of the template and temporary files on the Proxmox server.

## 🎨 User Interface (UI)

The interface relies on several `tput` mechanisms and ANSI escape codes:

### Progress Bar (Sticky Bottom)
The `draw_bottom_bar` function uses `tput cup` to systematically position itself on the last line of the terminal. It is refreshed at each major step.

### Resize Handling
A trap on the `SIGWINCH` signal calls `handle_resize`, which allows recalculating the progress bar's position if the user changes their window size.

### Final Summary
The final table uses a dynamic width calculation. It attempts to use `python3` to precisely measure the width of Unicode characters (emojis counting as 2 columns), with a standard bash fallback.

## 🔐 Security

The script uses `sshpass` to handle the root password provided at startup. The password is stored only in memory for the duration of the execution and is never written in plain text in the logs.
All SSH commands use the `-o StrictHostKeyChecking=no` option to facilitate use on changing local networks.

---
*Last updated: 05/08/2026*
