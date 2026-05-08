#!/bin/bash

# Global variables for progress tracking
GLOBAL_CURRENT=0
GLOBAL_TOTAL=0

# Spinner / Wrapper with duration
run_with_spinner() {
    local msg="$1"
    shift
    local pid
    
    # Run the command in background
    ( "$@" ) >> "${LOG_FILE:-/dev/null}" 2>&1 &
    pid=$!
    
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local start_time=$(date +%s)
    
    while kill -0 $pid 2>/dev/null; do
        for f in "${frames[@]}"; do
            kill -0 $pid 2>/dev/null || break
            printf "\r${PURPLE}[%s]${RESET} %s" "$f" "$msg" > /dev/tty 2>/dev/null || true
            sleep 0.1
        done
    done
    
    wait $pid
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        printf "\r${SUCCESS} %s ${GREEN}Done${RESET} (${duration}s)\n" "$msg" > /dev/tty 2>/dev/null || true
    else
        printf "\r${ERROR} %s ${RED}Failed${RESET} (${duration}s)\n" "$msg" > /dev/tty 2>/dev/null || true
    fi
    
    return $exit_code
}

# Sticky Bottom Progress Bar
draw_bottom_bar() {
    set +e
    local current=${1:-$GLOBAL_CURRENT}
    local total=${2:-$GLOBAL_TOTAL}
    
    if [ $total -eq 0 ]; then set -e; return; fi
    
    local cols=$(tput cols 2>/dev/null || echo 80)
    local lines=$(tput lines 2>/dev/null || echo 24)
    
    if [ "$cols" -lt 20 ]; then set -e; return; fi

    local overhead=32
    local bar_width=$((cols - overhead))
    if [ $bar_width -lt 5 ]; then bar_width=0; fi
    
    local filled=0
    local empty=0
    if [ $bar_width -gt 0 ]; then
        filled=$((current * bar_width / total))
        [[ $filled -gt $bar_width ]] && filled=$bar_width
        empty=$((bar_width - filled))
        [[ $empty -lt 0 ]] && empty=0
    fi
    local percent=$((current * 100 / total))
    
    tput sc > /dev/tty 2>/dev/null
    tput cup $((lines - 1)) 0 > /dev/tty 2>/dev/null
    tput el > /dev/tty 2>/dev/null
    
    echo -ne "${BOLD}${CYAN}Progress: ${RESET}" > /dev/tty 2>/dev/null
    if [ $bar_width -gt 0 ]; then
        echo -ne "[" > /dev/tty 2>/dev/null
        if [ $filled -gt 0 ]; then
            printf "${GREEN}█%.0s${RESET}" $(seq 1 $filled) > /dev/tty 2>/dev/null
        fi
        if [ $empty -gt 0 ]; then
            printf "░%.0s" $(seq 1 $empty) > /dev/tty 2>/dev/null
        fi
        echo -ne "] " > /dev/tty 2>/dev/null
    fi
    echo -ne "${BOLD}${percent}% (CT $current/$total)${RESET}" > /dev/tty 2>/dev/null
    tput rc > /dev/tty 2>/dev/null
    set -e
}

# Handle terminal resize
IS_RESIZING=0
handle_resize() {
    if [ $IS_RESIZING -eq 0 ]; then
        IS_RESIZING=1
        # Clear the potential "ghost" bars at the bottom
        local lines=$(tput lines)
        tput sc > /dev/tty 2>/dev/null
        for ((i=1; i<=2; i++)); do
            tput cup $((lines - i)) 0 > /dev/tty 2>/dev/null
            tput el > /dev/tty 2>/dev/null
        done
        draw_bottom_bar
        tput rc > /dev/tty 2>/dev/null
        sleep 0.1
        IS_RESIZING=0
    fi
}

# Summary Table — simple fixed-width, no cursor positioning
show_summary() {
    set +e
    local success=$1
    local failed=$2
    local total_time=$3
    local dest=$4

    local minutes=$((total_time / 60))
    local seconds=$((total_time % 60))
    local time_str="${seconds}s"
    [[ $minutes -gt 0 ]] && time_str="${minutes}m ${seconds}s"

    # Truncate dest if needed
    if [[ ${#dest} -gt 30 ]]; then
        dest="${dest:0:29}…"
    fi

    # Pad ASCII text to width
    _pad() { printf "%-${2}s" "$1"; }

    local bar
    bar=$(printf '═%.0s' $(seq 1 48))

    {
        echo "" > /dev/tty
        echo -e "${BOLD}${CYAN}╔${bar}╗${RESET}" > /dev/tty
        echo -e "${BOLD}${CYAN}║${RESET}           ${BOLD}${CYAN}PROXMOX BACKUP SUMMARY${RESET}             ${BOLD}${CYAN}║${RESET}" > /dev/tty
        echo -e "${BOLD}${CYAN}╠${bar}╣${RESET}" > /dev/tty
        echo -e "${BOLD}${CYAN}║${RESET}  ${SUCCESS} Success : ${GREEN}$(_pad "$success" 32)${RESET}${BOLD}${CYAN}║${RESET}" > /dev/tty
        echo -e "${BOLD}${CYAN}║${RESET}  ${ERROR} Failed  : ${RED}$(_pad "$failed" 32)${RESET}${BOLD}${CYAN}║${RESET}" > /dev/tty
        echo -e "${BOLD}${CYAN}║${RESET}  ${TIME} Time    : ${YELLOW}$(_pad "$time_str" 32)${RESET}${BOLD}${CYAN}║${RESET}" > /dev/tty
        echo -e "${BOLD}${CYAN}║${RESET}  ${FOLDER} Dest    : ${CYAN}$(_pad "$dest" 32)${RESET}${BOLD}${CYAN}║${RESET}" > /dev/tty
        echo -e "${BOLD}${CYAN}╚${bar}╝${RESET}" > /dev/tty
        echo "" > /dev/tty
    } > /dev/tty
    set -e
}

# Help Menu
show_help() {
    echo -e "${BOLD}${CYAN}Proxmox Backup CLI v2${RESET}"
    echo -e "Usage: $0 [options]"
    echo ""
    echo -e "${BOLD}Options:${RESET}"
    echo -e "  -h, --help            Display this help menu"
    echo -e "  -c, --ct ID1,ID2      Target specific CTs (ex: --ct 101,105)"
    echo -e "  -d, --dest PATH       Specify destination folder"
    echo ""
    echo -e "${BOLD}Example:${RESET}"
    echo -e "  $0 --ct 101,102 --dest /mnt/backups"
}
