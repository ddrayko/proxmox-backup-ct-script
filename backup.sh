#!/bin/bash
set -e

# Load libraries
LIB_DIR="$(dirname "$0")/lib"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/utils.sh"

# Default values
PROXMOX_USER="root"
REMOTE_DUMP_DIR="/var/lib/vz/dump"
LOG_DIR="$(dirname "$0")/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/backup-$(date +%Y%m%d-%H%M%S).log"

# Logging setup
exec > >(tee -a "$LOG_FILE") 2>&1

# Trap for cleanup and signals
cleanup_on_exit() {
    local exit_code=$?
    local line_no=$1
    if [ $exit_code -ne 0 ] && [ $exit_code -ne 130 ]; then
        echo -e "\n${ERROR} Une erreur est survenue à la ligne $line_no (Code: $exit_code). Arrêt." > /dev/tty
    elif [ $exit_code -eq 130 ]; then
        echo -e "\n${WARNING} Interruption par l'utilisateur. Nettoyage..." > /dev/tty
    fi
    tput cnorm > /dev/tty # Restore cursor
    exit $exit_code
}
trap 'cleanup_on_exit $LINENO' ERR SIGINT SIGTERM
trap 'handle_resize || true' SIGWINCH

# Argument parsing
TARGET_CTS=""
LOCAL_BACKUP_DIR=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--ct)
            TARGET_CTS=$2
            shift 2
            ;;
        -d|--dest)
            LOCAL_BACKUP_DIR=$2
            shift 2
            ;;
        *)
            echo -e "${ERROR} Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Banner
clear
echo -e "${CYAN}╔═══════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║                                               ║${RESET}"
echo -e "${CYAN}║${RESET}            ${BOLD}PROXMOX BACKUP AUTOMATION${RESET}          ${CYAN}║${RESET}"
echo -e "${CYAN}║                                               ║${RESET}"
echo -e "${CYAN}║${RESET}                 ${PURPLE}By Drayko${RESET}                     ${CYAN}║${RESET}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${RESET}"
echo -e "${INFO} Début : $(date '+%d/%m/%Y %H:%M:%S')"
echo ""

# Interactive prompts
if [[ -z "$PROXMOX_HOST" ]]; then
    read -p "$(echo -e "${IP} IP du serveur Proxmox : ")" PROXMOX_HOST
fi

read -p "$(echo -e "${PORT} Port SSH [22] : ")" PROXMOX_PORT
PROXMOX_PORT=${PROXMOX_PORT:-22}

if [[ -z "$LOCAL_BACKUP_DIR" ]]; then
    read -p "$(echo -e "${FOLDER} Dossier destination [ici] : ")" LOCAL_BACKUP_DIR
    LOCAL_BACKUP_DIR=${LOCAL_BACKUP_DIR:-$(pwd)}
fi
mkdir -p "$LOCAL_BACKUP_DIR"

echo -n -e "${KEY} Mot de passe Root : "
PROXMOX_PASSWORD=""
while IFS= read -r -s -n 1 char; do
    if [[ -z "$char" ]]; then break; fi
    if [[ "$char" == $'\177' ]]; then
        if [ ${#PROXMOX_PASSWORD} -gt 0 ]; then
            PROXMOX_PASSWORD="${PROXMOX_PASSWORD%?}"
            echo -ne "\b \b"
        fi
    else
        PROXMOX_PASSWORD+="$char"
        echo -ne "*"
    fi
done
echo -e "\n"

# Commands
SSH_CMD="sshpass -p $PROXMOX_PASSWORD ssh -p $PROXMOX_PORT -o StrictHostKeyChecking=no -o ConnectTimeout=10 -q"
SCP_CMD="sshpass -p $PROXMOX_PASSWORD scp -P $PROXMOX_PORT -o StrictHostKeyChecking=no -q"

# Helpers for spinner
proxmox_ssh() { $SSH_CMD "$PROXMOX_USER@$PROXMOX_HOST" "$1"; }
proxmox_scp() { $SCP_CMD "$PROXMOX_USER@$PROXMOX_HOST:$1" "$2"; }

# Connection check
run_with_spinner "Test connexion Proxmox" proxmox_ssh "echo OK" || {
    echo -e "${ERROR} Détail: IP ou mot de passe incorrect."
    exit 1
}

# List CTs
echo -n -e "${WAIT} Récupération de la liste des containers... "
RAW_CT_LIST=$($SSH_CMD "$PROXMOX_USER@$PROXMOX_HOST" "pct list | awk 'NR>1 && \$1 < 9000 {print \$1}'")
echo -e "\r${SUCCESS} Récupération de la liste des containers... ${GREEN}Fait${RESET}"

# Filtering by arguments
if [[ -n "$TARGET_CTS" ]]; then
    FILTER=$(echo "$TARGET_CTS" | tr ',' ' ')
    CT_LIST=""
    for ID in $RAW_CT_LIST; do
        for T in $FILTER; do
            if [[ "$ID" == "$T" ]]; then
                CT_LIST="$CT_LIST $ID"
            fi
        done
    done
else
    CT_LIST=$RAW_CT_LIST
fi

if [[ -z "$CT_LIST" ]]; then
    echo -e "${ERROR} Aucun CT correspondant trouvé."
    exit 1
fi

# Main Loop
SUCCESS_COUNT=0
FAIL_COUNT=0
GLOBAL_TOTAL=$(echo $CT_LIST | wc -w)
GLOBAL_CURRENT=0
START_TIME=$(date +%s)

# Hide cursor for cleaner UI
tput civis > /dev/tty

for CTID in $CT_LIST; do
    ((GLOBAL_CURRENT += 1))
    draw_bottom_bar
    echo -e "\n${BOLD}${BLUE}--------------------------------------${RESET}"
    echo -e "${BACKUP} ${BOLD}Traitement CT $CTID${RESET}"
    
    CLONE_ID=$((CTID + 9000))
    TEMPLATE_NAME="template-$CTID"

    # Pre-cleanup & Unlock
    run_with_spinner "Deverrouillage" proxmox_ssh "pct unlock $CTID 2>/dev/null || true; pct unlock $CLONE_ID 2>/dev/null || true"
    run_with_spinner "Nettoyage initial" proxmox_ssh "pct destroy $CLONE_ID --force 2>/dev/null || true; rm -f $REMOTE_DUMP_DIR/vzdump-lxc-$CLONE_ID-*.tar.zst"

    # Stop Source
    run_with_spinner "Arrêt source" proxmox_ssh "pct shutdown $CTID --timeout 30 2>/dev/null || pct stop $CTID 2>/dev/null || true"

    # Clone
    run_with_spinner "Clonage" proxmox_ssh "pct clone $CTID $CLONE_ID --hostname $TEMPLATE_NAME --full 1"

    # Start Source
    run_with_spinner "Redémarrage source" proxmox_ssh "pct start $CTID 2>/dev/null || true"

    # Convert to Template
    run_with_spinner "Conversion template" proxmox_ssh "pct stop $CLONE_ID 2>/dev/null || true; pct template $CLONE_ID"

    # Backup
    if ! run_with_spinner "Sauvegarde (vzdump)" proxmox_ssh "vzdump $CLONE_ID --dumpdir $REMOTE_DUMP_DIR --compress zstd --mode stop"; then
        ((FAIL_COUNT += 1))
        continue
    fi

    # Download
    if ! run_with_spinner "Téléchargement" proxmox_scp "$REMOTE_DUMP_DIR/vzdump-lxc-$CLONE_ID-*.tar.zst" "$LOCAL_BACKUP_DIR/"; then
        ((FAIL_COUNT += 1))
        continue
    fi

    # Post-cleanup
    run_with_spinner "Nettoyage final" proxmox_ssh "rm -f $REMOTE_DUMP_DIR/vzdump-lxc-$CLONE_ID-*.tar.zst; pct destroy $CLONE_ID --force"

    echo -e "${DONE} ${BOLD}CT $CTID terminé avec succès${RESET}"
    ((SUCCESS_COUNT += 1))
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Final Summary
tput cnorm > /dev/tty # Restore cursor
# Clear the bottom bar line before showing summary
tput sc > /dev/tty
tput cup $(($(tput lines) - 1)) 0 > /dev/tty
tput el > /dev/tty
tput rc > /dev/tty

show_summary "$SUCCESS_COUNT" "$FAIL_COUNT" "$DURATION" "$LOCAL_BACKUP_DIR"
