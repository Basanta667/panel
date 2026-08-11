#!/usr/bin/env bash

# =========================================================
# FAKECLOUD ULTRA PREMIUM INSTALLER v7.0
# HVM Panel Manager (NVM Removed)
# Discord: https://dsc.gg/fakecloud
# =========================================================

set -uo pipefail

# =========================================================
# COLORS
# =========================================================

RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BLUE="\e[1;34m"
CYAN="\e[1;36m"
MAGENTA="\e[1;35m"
WHITE="\e[1;37m"
GRAY="\e[1;90m"
NC="\e[0m"

BOLD="\e[1m"
DIM="\e[2m"
ITALIC="\e[3m"
UNDERLINE="\e[4m"

BG_BLUE="\e[44m"
BG_GREEN="\e[42m"
BG_RED="\e[41m"
BG_YELLOW="\e[43m"
BG_MAGENTA="\e[45m"
BG_CYAN="\e[46m"

# Gradient Colors
G1="\e[38;5;51m"
G2="\e[38;5;45m"
G3="\e[38;5;39m"
G4="\e[38;5;33m"
G5="\e[38;5;27m"
G6="\e[38;5;93m"
G7="\e[38;5;129m"
G8="\e[38;5;198m"

# =========================================================
# VARIABLES
# =========================================================

# HVM Panel Only
HVM_FILE_ID="1IhayXycn0bzu7c8EEO2Xsv8Xwr9OXXiy"
HVM_URL="https://drive.usercontent.google.com/download?id=${HVM_FILE_ID}&export=download&confirm=t"
INSTALL_DIR="/opt/hvm"
BIN_FILE="${INSTALL_DIR}/hvmV8.bin"
SERVICE_NAME="hvm"
PANEL_PORT="5000"
LOG_FILE="/var/log/hvm.log"

# General
DISCORD_LINK="https://dsc.gg/fakecloud"
BRAND_NAME="FakeCloud"
PANEL_NAME="HVM"
PANEL_VERSION="8.0-ULTRA"
MANAGER_VERSION="7.0"
INSTALLER_URL="https://raw.githubusercontent.com/Basanta667/panel/main/installer.sh"

HAS_SYSTEMD=false

# =========================================================
# HELPER FUNCTIONS
# =========================================================

info() { echo -e "  ${G1}❯${NC} ${WHITE}$1${NC}"; }
ok() { echo -e "  ${GREEN}✓${NC} ${WHITE}$1${NC}"; }
warn() { echo -e "  ${YELLOW}⚠${NC} ${WHITE}$1${NC}"; }
error() { echo -e "  ${RED}✗${NC} ${WHITE}$1${NC}"; }
step_msg() { echo -e "\n  ${BG_BLUE}${WHITE}${BOLD} ▶ $1 ${NC}\n"; }

divider() { echo -e "  ${GRAY}────────────────────────────────────────────────────────────────────────${NC}"; }
double_divider() { echo -e "  ${G3}════════════════════════════════════════════════════════════════════════${NC}"; }

fancy_line() {
    echo -e "  ${G1}◆${G2}◆${G3}◆${G4}◆${G5}◆${G6}◆${G7}◆${G8}◆${G1}◆${G2}◆${G3}◆${G4}◆${G5}◆${G6}◆${G7}◆${G8}◆${G1}◆${G2}◆${G3}◆${G4}◆${G5}◆${G6}◆${G7}◆${G8}◆${G1}◆${G2}◆${G3}◆${G4}◆${G5}◆${G6}◆${G7}◆${G8}◆${NC}"
}

press_enter() {
    echo
    echo -e "  ${DIM}${ITALIC}Press ENTER to continue...${NC}"
    read -r
}

check_internet() {
    for url in "https://www.google.com" "https://1.1.1.1"; do
        if curl -s --max-time 5 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null | grep -qE "200|301|302"; then
            return 0
        fi
    done
    ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 && return 0
    return 1
}

detect_environment() {
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        HAS_SYSTEMD=true
    fi
}

get_public_ip() {
    local ip=""
    ip=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || true)
    [[ -z "$ip" ]] && ip=$(curl -4 -s --max-time 5 api.ipify.org 2>/dev/null || true)
    [[ -z "$ip" ]] && ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "YOUR_IP")
    echo "$ip"
}

is_panel_installed() { [[ -f "$BIN_FILE" ]]; }

is_panel_running() {
    if command -v lsof >/dev/null 2>&1 && lsof -Pi :${PANEL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    fi
    if pgrep -f "hvmV8.bin" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# =========================================================
# PREMIUM LOGO
# =========================================================

show_logo() {
    clear
    echo
    echo -e "${G1}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                                                                           ║
EOF
    echo -e "${G2}"
    cat << "EOF"
    ║        ███████╗ █████╗ ██╗  ██╗███████╗                                 ║
    ║        ██╔════╝██╔══██╗██║ ██╔╝██╔════╝                                 ║
EOF
    echo -e "${G3}"
    cat << "EOF"
    ║        █████╗  ███████║█████╔╝ █████╗                                   ║
    ║        ██╔══╝  ██╔══██║██╔═██╗ ██╔══╝                                   ║
EOF
    echo -e "${G4}"
    cat << "EOF"
    ║        ██║     ██║  ██║██║  ██╗███████╗                                 ║
    ║        ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝                                 ║
EOF
    echo -e "${G5}"
    cat << "EOF"
    ║         ██████╗██╗      ██████╗ ██╗   ██╗██████╗                        ║
    ║        ██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗                       ║
EOF
    echo -e "${G6}"
    cat << "EOF"
    ║        ██║     ██║     ██║   ██║██║   ██║██║  ██║                       ║
    ║        ██║     ██║     ██║   ██║██║   ██║██║  ██║                       ║
EOF
    echo -e "${G7}"
    cat << "EOF"
    ║        ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝                       ║
    ║         ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝                        ║
EOF
    echo -e "${G8}"
    cat << "EOF"
    ║                                                                           ║
    ║           ⚡ HVM PANEL MANAGER v7.0 ⚡                                  ║
    ║                                                                           ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# =========================================================
# MAIN MENU
# =========================================================

show_main_menu() {
    show_logo
    
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "0")
    local ram_used=$(free | awk '/^Mem:/{printf "%.0f", $3/$2*100}' 2>/dev/null || echo "0")
    local disk_used=$(df -h / | awk 'NR==2{print $5}' | tr -d '%' 2>/dev/null || echo "0")
    local uptime_short=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")
    local pub_ip=$(get_public_ip)
    local hostname=$(hostname)
    
    local hvm_status="${RED}●${NC} ${GRAY}Not Installed${NC}"
    
    if is_panel_installed; then
        if is_panel_running; then
            hvm_status="${GREEN}●${NC} ${GREEN}${BOLD}ONLINE${NC}"
        else
            hvm_status="${YELLOW}●${NC} ${YELLOW}Stopped${NC}"
        fi
    fi
    
    local ts_status="${RED}●${NC} ${GRAY}Not Installed${NC}"
    if command -v tailscale >/dev/null 2>&1; then
        if tailscale status >/dev/null 2>&1; then
            ts_status="${GREEN}●${NC} ${GREEN}Connected${NC}"
        else
            ts_status="${YELLOW}●${NC} ${YELLOW}Not Connected${NC}"
        fi
    fi
    
    local lxc_status="${RED}●${NC} ${GRAY}Not Installed${NC}"
    if command -v lxc >/dev/null 2>&1 || command -v lxd >/dev/null 2>&1; then
        lxc_status="${GREEN}●${NC} ${GREEN}Installed${NC}"
    fi
    
    # Header Box
    fancy_line
    echo -e "  ${WHITE}${BOLD}🌐 Hostname:${NC} ${CYAN}${hostname}${NC}     ${WHITE}${BOLD}🔗 IP:${NC} ${CYAN}${pub_ip}${NC}     ${WHITE}${BOLD}⏰ Uptime:${NC} ${CYAN}${uptime_short}${NC}"
    fancy_line
    echo
    
    # Stats Box
    echo -e "  ${G1}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${G1}║${NC}  ${WHITE}${BOLD}⚡ LIVE SYSTEM STATS ⚡${NC}                                          ${G1}║${NC}"
    echo -e "  ${G1}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${G1}║${NC}  ${WHITE}💻 CPU:${NC}  ${CYAN}${BOLD}${cpu}%${NC}    ${WHITE}💾 RAM:${NC} ${CYAN}${BOLD}${ram_used}%${NC}    ${WHITE}💿 Disk:${NC} ${CYAN}${BOLD}${disk_used}%${NC}              ${G1}║${NC}"
    echo -e "  ${G1}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Status Box
    echo -e "  ${G6}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${G6}║${NC}  ${WHITE}${BOLD}🎛️  SERVICES STATUS${NC}                                                ${G6}║${NC}"
    echo -e "  ${G6}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${G6}║${NC}  ${MAGENTA}🔶 HVM Panel${NC}     : ${hvm_status}                              ${G6}║${NC}"
    echo -e "  ${G6}║${NC}  ${GREEN}📦 LXC/LXD${NC}       : ${lxc_status}                            ${G6}║${NC}"
    echo -e "  ${G6}║${NC}  ${CYAN}🔗 Tailscale${NC}     : ${ts_status}                            ${G6}║${NC}"
    echo -e "  ${G6}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Main Menu Box
    echo -e "  ${G3}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${G3}║${NC}  ${WHITE}${BOLD}📋 MAIN MENU${NC}                                                       ${G3}║${NC}"
    echo -e "  ${G3}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${G3}║${NC}                                                                      ${G3}║${NC}"
    echo -e "  ${G3}║${NC}   ${GREEN}${BOLD}[1]${NC}  🚀  ${WHITE}${BOLD}Install HVM Panel${NC}     ${DIM}Install FakeCloud HVM v8${NC}     ${G3}║${NC}"
    echo -e "  ${G3}║${NC}   ${YELLOW}${BOLD}[2]${NC}  ⚙️   ${WHITE}${BOLD}Panel Management${NC}      ${DIM}Start/Stop/Restart/Reinstall${NC}  ${G3}║${NC}"
    echo -e "  ${G3}║${NC}   ${BLUE}${BOLD}[3]${NC}  💻  ${WHITE}${BOLD}System Information${NC}    ${DIM}CPU, RAM, Disk, Network Info${NC}  ${G3}║${NC}"
    echo -e "  ${G3}║${NC}   ${MAGENTA}${BOLD}[4]${NC}  🔗  ${WHITE}${BOLD}Tailscale Manager${NC}     ${DIM}Install + Connect Tailnet${NC}     ${G3}║${NC}"
    echo -e "  ${G3}║${NC}   ${CYAN}${BOLD}[5]${NC}  🌐  ${WHITE}${BOLD}Network Tools${NC}         ${DIM}Speed Test, IP, Ports${NC}         ${G3}║${NC}"
    echo -e "  ${G3}║${NC}   ${G7}${BOLD}[6]${NC}  🔥  ${WHITE}${BOLD}Firewall Manager${NC}      ${DIM}UFW/iptables Configuration${NC}    ${G3}║${NC}"
    echo -e "  ${G3}║${NC}   ${G8}${BOLD}[7]${NC}  💾  ${WHITE}${BOLD}Backup & Restore${NC}      ${DIM}Backup Panel Data${NC}             ${G3}║${NC}"
    echo -e "  ${G3}║${NC}   ${GREEN}${BOLD}[8]${NC}  🖥️   ${WHITE}${BOLD}VPS Environment${NC}       ${DIM}LXC/LXD Setup${NC}                 ${G3}║${NC}"
    echo -e "  ${G3}║${NC}   ${YELLOW}${BOLD}[9]${NC}  💬  ${WHITE}${BOLD}Contact & Support${NC}     ${DIM}Discord, About Us${NC}             ${G3}║${NC}"
    echo -e "  ${G3}║${NC}   ${RED}${BOLD}[0]${NC}  🚪  ${WHITE}${BOLD}Exit Installer${NC}        ${DIM}Close Manager${NC}                 ${G3}║${NC}"
    echo -e "  ${G3}║${NC}                                                                      ${G3}║${NC}"
    echo -e "  ${G3}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    fancy_line
    echo -e "  ${WHITE}💬 Discord:${NC} ${BLUE}${DISCORD_LINK}${NC}    ${WHITE}🌐 Brand:${NC} ${CYAN}${BRAND_NAME}${NC}    ${WHITE}📌 v${MANAGER_VERSION}${NC}"
    fancy_line
    echo
    echo -en "  ${GREEN}${BOLD}➜ Select Option ${WHITE}[${GREEN}0-9${WHITE}]${NC}${GREEN}${BOLD}:${NC} "
}

# =========================================================
# OPTION 1: INSTALL HVM PANEL
# =========================================================

action_install() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE}${BOLD}  🚀 INSTALL HVM PANEL  ${NC}"
    echo
    
    if is_panel_installed; then
        warn "HVM Panel already installed!"
        echo -e "  ${DIM}Use option [2] Panel Management to reinstall.${NC}"
        press_enter
        return
    fi
    
    double_divider
    
    if [[ "$EUID" -ne 0 ]]; then
        error "Must run as root!"
        press_enter
        return
    fi
    ok "Running as root"
    
    info "Checking internet connection..."
    check_internet && ok "Internet OK" || warn "Continuing anyway..."
    
    info "Installing dependencies..."
    if command -v apt >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt update -y -qq >/dev/null 2>&1 || true
        apt install -y -qq curl wget lsof tar unzip sudo nano python3 python3-pip ca-certificates net-tools >/dev/null 2>&1 || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y -q curl wget lsof tar unzip sudo nano python3 python3-pip ca-certificates net-tools >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q curl wget lsof tar unzip sudo nano python3 python3-pip ca-certificates net-tools >/dev/null 2>&1 || true
    fi
    ok "Dependencies installed"
    
    if is_panel_running; then
        warn "Port ${PANEL_PORT} busy, freeing..."
        pkill -f "hvmV8.bin" 2>/dev/null || true
        sleep 2
    fi
    
    mkdir -p "${INSTALL_DIR}"
    cd "${INSTALL_DIR}"
    ok "Directory: ${INSTALL_DIR}"
    
    info "Downloading HVM Panel binary..."
    echo
    
    local COOKIES_FILE="/tmp/gdrive_cookies_$$.txt"
    local PAGE_FILE="/tmp/gdrive_page_$$.html"
    
    rm -f hvmV8.bin
    
    wget --quiet --save-cookies "${COOKIES_FILE}" --keep-session-cookies \
        --no-check-certificate \
        "https://docs.google.com/uc?export=download&id=${HVM_FILE_ID}" \
        -O "${PAGE_FILE}" 2>/dev/null || true
    
    local CONFIRM=$(grep -oP 'confirm=[0-9A-Za-z_-]+' "${PAGE_FILE}" 2>/dev/null | head -1 | cut -d'=' -f2 || echo "")
    
    if [[ -n "${CONFIRM}" ]]; then
        wget --load-cookies "${COOKIES_FILE}" --no-check-certificate --progress=bar:force:noscroll \
            "https://docs.google.com/uc?export=download&confirm=${CONFIRM}&id=${HVM_FILE_ID}" \
            -O hvmV8.bin 2>&1 | tail -3 || true
    fi
    
    if [[ ! -f hvmV8.bin ]] || [[ ! -s hvmV8.bin ]] || file hvmV8.bin 2>/dev/null | grep -qi "html"; then
        rm -f hvmV8.bin
        wget --no-check-certificate --progress=bar:force:noscroll "${HVM_URL}" -O hvmV8.bin 2>&1 | tail -3 || true
    fi
    
    rm -f "${COOKIES_FILE}" "${PAGE_FILE}"
    
    if [[ ! -f hvmV8.bin ]] || [[ ! -s hvmV8.bin ]]; then
        error "Download failed!"
        press_enter
        return
    fi
    
    local size=$(du -m hvmV8.bin | cut -f1)
    if [[ "$size" -lt 20 ]]; then
        error "File corrupted (${size}MB)!"
        rm -f hvmV8.bin
        press_enter
        return
    fi
    
    chmod +x hvmV8.bin
    ok "Downloaded (${size}MB)"
    
    info "Configuring firewall..."
    command -v ufw >/dev/null 2>&1 && ufw allow ${PANEL_PORT}/tcp >/dev/null 2>&1 || true
    command -v iptables >/dev/null 2>&1 && iptables -I INPUT -p tcp --dport ${PANEL_PORT} -j ACCEPT 2>/dev/null || true
    ok "Firewall configured"
    
    if [[ "${HAS_SYSTEMD}" == true ]]; then
        info "Creating systemd service..."
        cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=HVM Panel - Powered by ${BRAND_NAME}
After=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${BIN_FILE}
Restart=always
RestartSec=5
User=root
StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable ${SERVICE_NAME} >/dev/null 2>&1
        systemctl restart ${SERVICE_NAME}
        ok "Service started"
    else
        info "Starting manually..."
        nohup ${BIN_FILE} >> ${LOG_FILE} 2>&1 &
        sleep 3
        ok "Panel started"
    fi
    
    sleep 5
    
    double_divider
    echo
    echo -e "  ${GREEN}${BOLD}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════╗
    ║          ✅ INSTALLATION SUCCESSFUL! ✅              ║
    ╚══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "  ${G3}╭──────────────── Panel Details ───────────────────╮${NC}"
    echo -e "  ${G3}│${NC}  ${WHITE}🌐 Panel URL${NC}  : ${CYAN}${BOLD}http://$(get_public_ip):${PANEL_PORT}${NC}"
    echo -e "  ${G3}│${NC}  ${WHITE}👤 Username${NC}   : ${GREEN}admin${NC}"
    echo -e "  ${G3}│${NC}  ${WHITE}🔑 Password${NC}   : ${GREEN}admin${NC}"
    echo -e "  ${G3}│${NC}  ${WHITE}📁 Directory${NC}  : ${DIM}${INSTALL_DIR}${NC}"
    echo -e "  ${G3}│${NC}  ${WHITE}💬 Discord${NC}    : ${BLUE}${DISCORD_LINK}${NC}"
    echo -e "  ${G3}╰──────────────────────────────────────────────────╯${NC}"
    echo
    press_enter
}

# =========================================================
# OPTION 2: PANEL MANAGEMENT
# =========================================================

action_manage() {
    while true; do
        show_logo
        echo -e "  ${BG_YELLOW}${WHITE}${BOLD}  ⚙️  HVM PANEL MANAGER  ${NC}"
        echo
        
        local status_color="${RED}"
        local status_text="Not Installed"
        if is_panel_installed; then
            if is_panel_running; then
                status_color="${GREEN}"
                status_text="● RUNNING"
            else
                status_color="${YELLOW}"
                status_text="○ STOPPED"
            fi
        fi
        
        echo -e "  ${WHITE}Status:${NC} ${status_color}${BOLD}${status_text}${NC}"
        if is_panel_running; then
            echo -e "  ${WHITE}URL:${NC} ${CYAN}http://$(get_public_ip):${PANEL_PORT}${NC}"
        fi
        echo
        
        echo -e "  ${G3}╭──────────────────────────────────────────────────────────────────────╮${NC}"
        echo -e "  ${G3}│${NC}   ${GREEN}${BOLD}[1]${NC}  ▶️   ${WHITE}${BOLD}Start${NC}          Start the panel                    ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${RED}${BOLD}[2]${NC}  ⏸️   ${WHITE}${BOLD}Stop${NC}           Stop the panel                     ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${YELLOW}${BOLD}[3]${NC}  🔄  ${WHITE}${BOLD}Restart${NC}        Restart the panel                  ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${BLUE}${BOLD}[4]${NC}  🔧  ${WHITE}${BOLD}Reinstall${NC}      Fresh install                      ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${MAGENTA}${BOLD}[5]${NC}  🗑️   ${WHITE}${BOLD}Uninstall${NC}      Remove completely                  ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${CYAN}${BOLD}[6]${NC}  📋  ${WHITE}${BOLD}View Logs${NC}      Show panel logs                    ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${WHITE}${BOLD}[7]${NC}  ℹ️   ${WHITE}${BOLD}Panel Info${NC}     Detailed information               ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${RED}${BOLD}[0]${NC}  ⬅️   ${WHITE}${BOLD}Back${NC}                                            ${G3}│${NC}"
        echo -e "  ${G3}╰──────────────────────────────────────────────────────────────────────╯${NC}"
        echo
        echo -en "  ${GREEN}${BOLD}➜ Select [0-7]:${NC} "
        read -r choice
        
        case $choice in
            1) panel_start ;;
            2) panel_stop ;;
            3) panel_restart ;;
            4) panel_reinstall ;;
            5) panel_uninstall ;;
            6) panel_logs ;;
            7) panel_info ;;
            0) return ;;
            *) warn "Invalid!"; sleep 1 ;;
        esac
    done
}

panel_start() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE}${BOLD}  ▶️  START HVM PANEL  ${NC}"
    echo
    
    if ! is_panel_installed; then
        error "Not installed!"
        press_enter
        return
    fi
    
    if is_panel_running; then
        warn "Already running!"
        press_enter
        return
    fi
    
    info "Starting HVM Panel..."
    if [[ "${HAS_SYSTEMD}" == true ]] && [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
        systemctl start ${SERVICE_NAME}
    else
        cd "${INSTALL_DIR}"
        nohup ${BIN_FILE} >> ${LOG_FILE} 2>&1 &
    fi
    
    sleep 5
    
    if is_panel_running; then
        ok "Started successfully!"
        echo -e "  🌐 URL: ${CYAN}http://$(get_public_ip):${PANEL_PORT}${NC}"
    else
        error "Failed to start!"
    fi
    press_enter
}

panel_stop() {
    show_logo
    echo -e "  ${BG_RED}${WHITE}${BOLD}  ⏸️  STOP HVM PANEL  ${NC}"
    echo
    
    if ! is_panel_running; then
        warn "Not running!"
        press_enter
        return
    fi
    
    info "Stopping..."
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    pkill -f "hvmV8.bin" 2>/dev/null || true
    sleep 2
    
    is_panel_running && error "Failed!" || ok "Stopped!"
    press_enter
}

panel_restart() {
    show_logo
    echo -e "  ${BG_YELLOW}${WHITE}${BOLD}  🔄 RESTART HVM PANEL  ${NC}"
    echo
    
    if ! is_panel_installed; then
        error "Not installed!"
        press_enter
        return
    fi
    
    info "Restarting..."
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl restart ${SERVICE_NAME} 2>/dev/null || {
        pkill -f "hvmV8.bin" 2>/dev/null || true
        sleep 2
        cd "${INSTALL_DIR}"
        nohup ${BIN_FILE} >> ${LOG_FILE} 2>&1 &
    }
    
    sleep 5
    
    if is_panel_running; then
        ok "Restarted!"
        echo -e "  🌐 URL: ${CYAN}http://$(get_public_ip):${PANEL_PORT}${NC}"
    else
        error "Failed!"
    fi
    press_enter
}

panel_reinstall() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE}${BOLD}  🔧 REINSTALL HVM PANEL  ${NC}"
    echo
    warn "Will delete and reinstall!"
    read -rp "  Continue? (y/n): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled"
        press_enter
        return
    fi
    
    info "Removing old installation..."
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl disable ${SERVICE_NAME} 2>/dev/null || true
    pkill -f "hvmV8.bin" 2>/dev/null || true
    rm -f /etc/systemd/system/${SERVICE_NAME}.service
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl daemon-reload 2>/dev/null || true
    rm -rf "${INSTALL_DIR}"
    rm -f "${LOG_FILE}"
    ok "Removed"
    
    action_install
}

panel_uninstall() {
    show_logo
    echo -e "  ${BG_RED}${WHITE}${BOLD}  🗑️  UNINSTALL HVM PANEL  ${NC}"
    echo
    
    if ! is_panel_installed; then
        warn "Not installed!"
        press_enter
        return
    fi
    
    warn "This deletes EVERYTHING (binary, config, database, logs)!"
    read -rp "  Type 'YES' to confirm: " confirm
    
    if [[ "$confirm" != "YES" ]]; then
        info "Cancelled"
        press_enter
        return
    fi
    
    info "Uninstalling..."
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl disable ${SERVICE_NAME} 2>/dev/null || true
    pkill -f "hvmV8.bin" 2>/dev/null || true
    rm -f /etc/systemd/system/${SERVICE_NAME}.service
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl daemon-reload 2>/dev/null || true
    rm -rf "${INSTALL_DIR}"
    rm -f "${LOG_FILE}"
    ok "HVM Panel uninstalled!"
    press_enter
}

panel_logs() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE}${BOLD}  📋 HVM PANEL LOGS  ${NC}"
    echo
    
    if [[ ! -f "${LOG_FILE}" ]]; then
        error "Log file not found!"
        press_enter
        return
    fi
    
    echo -e "  ${WHITE}[1]${NC} Last 50 lines"
    echo -e "  ${WHITE}[2]${NC} Last 200 lines"
    echo -e "  ${WHITE}[3]${NC} Live tail (Ctrl+C to exit)"
    echo -e "  ${WHITE}[0]${NC} Back"
    echo
    echo -en "  ${GREEN}Choice:${NC} "
    read -r c
    
    case $c in
        1) clear; tail -50 "${LOG_FILE}" ;;
        2) clear; tail -200 "${LOG_FILE}" ;;
        3) clear; tail -f "${LOG_FILE}" ;;
    esac
    press_enter
}

panel_info() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE}${BOLD}  ℹ️  HVM PANEL INFO  ${NC}"
    echo
    
    if ! is_panel_installed; then
        error "Not installed!"
        press_enter
        return
    fi
    
    local status="${RED}Offline${NC}"
    is_panel_running && status="${GREEN}Online${NC}"
    
    local size=$(du -h "$BIN_FILE" 2>/dev/null | cut -f1)
    local install_date=$(stat -c %y "$BIN_FILE" 2>/dev/null | cut -d. -f1)
    
    echo -e "  ${G3}╭────────── Panel Details ──────────╮${NC}"
    echo -e "  ${G3}│${NC}  ${WHITE}Name${NC}      : HVM Panel"
    echo -e "  ${G3}│${NC}  ${WHITE}Version${NC}   : ${PANEL_VERSION}"
    echo -e "  ${G3}│${NC}  ${WHITE}Status${NC}    : ${status}"
    echo -e "  ${G3}│${NC}  ${WHITE}URL${NC}       : ${CYAN}http://$(get_public_ip):${PANEL_PORT}${NC}"
    echo -e "  ${G3}│${NC}  ${WHITE}Directory${NC} : ${INSTALL_DIR}"
    echo -e "  ${G3}│${NC}  ${WHITE}Binary${NC}    : hvmV8.bin"
    echo -e "  ${G3}│${NC}  ${WHITE}Size${NC}      : ${size}"
    echo -e "  ${G3}│${NC}  ${WHITE}Installed${NC} : ${install_date}"
    echo -e "  ${G3}│${NC}  ${WHITE}Log${NC}       : ${LOG_FILE}"
    echo -e "  ${G3}╰───────────────────────────────────╯${NC}"
    press_enter
}

# =========================================================
# OPTION 3: SYSTEM INFO
# =========================================================

action_sysinfo() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE}${BOLD}  💻 SYSTEM INFORMATION  ${NC}"
    echo
    
    local cpu_model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown")
    local cpu_cores=$(nproc 2>/dev/null || echo "?")
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    local total_ram=$(free -h | awk '/^Mem:/{print $2}')
    local used_ram=$(free -h | awk '/^Mem:/{print $3}')
    local free_ram=$(free -h | awk '/^Mem:/{print $7}')
    local ram_percent=$(free | awk '/^Mem:/{printf "%.1f", $3/$2*100}')
    local disk_info=$(df -h / | awk 'NR==2{print $3" / "$2" ("$5")"}')
    local disk_free=$(df -h / | awk 'NR==2{print $4}')
    local kernel=$(uname -r)
    local uptime=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")
    local pub_ip=$(get_public_ip)
    local priv_ip=$(hostname -I | awk '{print $1}')
    local hostname=$(hostname)
    
    local os_name="Unknown"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        os_name="$PRETTY_NAME"
    fi
    
    echo -e "  ${G1}╔═════════════════════════════════════════════════╗${NC}"
    echo -e "  ${G1}║${NC}  ${WHITE}${BOLD}🖥️  SYSTEM${NC}                                    ${G1}║${NC}"
    echo -e "  ${G1}╠═════════════════════════════════════════════════╣${NC}"
    echo -e "  ${G1}║${NC}  ${WHITE}Hostname${NC}   : ${CYAN}${hostname}${NC}"
    echo -e "  ${G1}║${NC}  ${WHITE}OS${NC}         : ${CYAN}${os_name}${NC}"
    echo -e "  ${G1}║${NC}  ${WHITE}Kernel${NC}     : ${CYAN}${kernel}${NC}"
    echo -e "  ${G1}║${NC}  ${WHITE}Arch${NC}       : ${CYAN}$(uname -m)${NC}"
    echo -e "  ${G1}║${NC}  ${WHITE}Uptime${NC}     : ${CYAN}${uptime}${NC}"
    echo -e "  ${G1}╚═════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "  ${G3}╔═════════════════════════════════════════════════╗${NC}"
    echo -e "  ${G3}║${NC}  ${WHITE}${BOLD}💻 CPU${NC}                                       ${G3}║${NC}"
    echo -e "  ${G3}╠═════════════════════════════════════════════════╣${NC}"
    echo -e "  ${G3}║${NC}  ${WHITE}Model${NC}      : ${CYAN}${cpu_model:0:35}${NC}"
    echo -e "  ${G3}║${NC}  ${WHITE}Cores${NC}      : ${CYAN}${cpu_cores}${NC}"
    echo -e "  ${G3}║${NC}  ${WHITE}Usage${NC}      : ${CYAN}${cpu_usage}%${NC}"
    echo -e "  ${G3}╚═════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "  ${G6}╔═════════════════════════════════════════════════╗${NC}"
    echo -e "  ${G6}║${NC}  ${WHITE}${BOLD}💾 MEMORY${NC}                                    ${G6}║${NC}"
    echo -e "  ${G6}╠═════════════════════════════════════════════════╣${NC}"
    echo -e "  ${G6}║${NC}  ${WHITE}Total${NC}      : ${CYAN}${total_ram}${NC}"
    echo -e "  ${G6}║${NC}  ${WHITE}Used${NC}       : ${CYAN}${used_ram} (${ram_percent}%)${NC}"
    echo -e "  ${G6}║${NC}  ${WHITE}Free${NC}       : ${CYAN}${free_ram}${NC}"
    echo -e "  ${G6}╚═════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "  ${G7}╔═════════════════════════════════════════════════╗${NC}"
    echo -e "  ${G7}║${NC}  ${WHITE}${BOLD}💿 STORAGE & NETWORK${NC}                         ${G7}║${NC}"
    echo -e "  ${G7}╠═════════════════════════════════════════════════╣${NC}"
    echo -e "  ${G7}║${NC}  ${WHITE}Disk${NC}       : ${CYAN}${disk_info}${NC}"
    echo -e "  ${G7}║${NC}  ${WHITE}Free${NC}       : ${CYAN}${disk_free}${NC}"
    echo -e "  ${G7}║${NC}  ${WHITE}Public IP${NC}  : ${CYAN}${pub_ip}${NC}"
    echo -e "  ${G7}║${NC}  ${WHITE}Private IP${NC} : ${CYAN}${priv_ip}${NC}"
    echo -e "  ${G7}╚═════════════════════════════════════════════════╝${NC}"
    press_enter
}

# =========================================================
# OPTION 4: TAILSCALE
# =========================================================

action_tailscale() {
    while true; do
        show_logo
        echo -e "  ${BG_MAGENTA}${WHITE}${BOLD}  🔗 TAILSCALE MANAGER  ${NC}"
        echo
        
        local ts_status="${RED}Not Installed${NC}"
        local ts_ip="N/A"
        
        if command -v tailscale >/dev/null 2>&1; then
            if tailscale status >/dev/null 2>&1; then
                ts_status="${GREEN}● Connected${NC}"
                ts_ip=$(tailscale ip -4 2>/dev/null | head -1 || echo "N/A")
            else
                ts_status="${YELLOW}○ Not Connected${NC}"
            fi
        fi
        
        echo -e "  ${WHITE}Status:${NC} ${ts_status}"
        echo -e "  ${WHITE}IP:${NC} ${CYAN}${ts_ip}${NC}"
        echo
        
        echo -e "  ${G3}╭──────────────────────────────────────────────────────────────────────╮${NC}"
        echo -e "  ${G3}│${NC}   ${GREEN}${BOLD}[1]${NC}  📥  ${WHITE}${BOLD}Install${NC}      Install Tailscale                    ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${BLUE}${BOLD}[2]${NC}  🔗  ${WHITE}${BOLD}Connect${NC}      Connect to Tailnet                   ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${YELLOW}${BOLD}[3]${NC}  ⬇️   ${WHITE}${BOLD}Disconnect${NC}   Disconnect                          ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${CYAN}${BOLD}[4]${NC}  ℹ️   ${WHITE}${BOLD}Status${NC}       Show detailed status                ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${RED}${BOLD}[5]${NC}  🗑️   ${WHITE}${BOLD}Uninstall${NC}    Remove Tailscale                    ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${RED}${BOLD}[0]${NC}  ⬅️   ${WHITE}${BOLD}Back${NC}                                             ${G3}│${NC}"
        echo -e "  ${G3}╰──────────────────────────────────────────────────────────────────────╯${NC}"
        echo
        echo -en "  ${GREEN}${BOLD}➜ Select [0-5]:${NC} "
        read -r choice
        
        case $choice in
            1) tailscale_install ;;
            2) tailscale_up ;;
            3) tailscale_down ;;
            4) tailscale_status ;;
            5) tailscale_uninstall ;;
            0) return ;;
            *) warn "Invalid!"; sleep 1 ;;
        esac
    done
}

tailscale_install() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE}${BOLD}  📥 INSTALL TAILSCALE  ${NC}"
    echo
    
    if command -v tailscale >/dev/null 2>&1; then
        warn "Already installed!"
        tailscale version 2>/dev/null | head -3
        press_enter
        return
    fi
    
    info "Downloading & installing..."
    curl -fsSL https://tailscale.com/install.sh | sh
    
    if command -v tailscale >/dev/null 2>&1; then
        ok "Tailscale installed!"
    else
        error "Failed!"
    fi
    press_enter
}

tailscale_up() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE}${BOLD}  🔗 CONNECT TAILSCALE  ${NC}"
    echo
    
    if ! command -v tailscale >/dev/null 2>&1; then
        error "Not installed!"
        press_enter
        return
    fi
    
    warn "Open the URL in browser to authenticate!"
    echo
    tailscale up
    
    sleep 2
    if tailscale status >/dev/null 2>&1; then
        ok "Connected!"
        echo -e "  ${WHITE}IP:${NC} ${CYAN}$(tailscale ip -4 | head -1)${NC}"
    fi
    press_enter
}

tailscale_down() {
    show_logo
    echo -e "  ${BG_YELLOW}${WHITE}${BOLD}  ⬇️  DISCONNECT  ${NC}"
    echo
    
    if ! command -v tailscale >/dev/null 2>&1; then
        error "Not installed!"
        press_enter
        return
    fi
    
    tailscale down
    ok "Disconnected!"
    press_enter
}

tailscale_status() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE}${BOLD}  ℹ️  TAILSCALE STATUS  ${NC}"
    echo
    
    if ! command -v tailscale >/dev/null 2>&1; then
        error "Not installed!"
        press_enter
        return
    fi
    
    tailscale status 2>/dev/null || warn "Not connected"
    echo
    tailscale version 2>/dev/null | head -3
    press_enter
}

tailscale_uninstall() {
    show_logo
    echo -e "  ${BG_RED}${WHITE}${BOLD}  🗑️  UNINSTALL TAILSCALE  ${NC}"
    echo
    
    if ! command -v tailscale >/dev/null 2>&1; then
        warn "Not installed!"
        press_enter
        return
    fi
    
    read -rp "  Continue? (y/n): " c
    [[ "$c" != "y" && "$c" != "Y" ]] && return
    
    tailscale down 2>/dev/null || true
    command -v apt >/dev/null 2>&1 && apt remove --purge -y tailscale 2>&1 | tail -3
    ok "Uninstalled!"
    press_enter
}

# =========================================================
# OPTION 5: NETWORK TOOLS
# =========================================================

action_network_tools() {
    while true; do
        show_logo
        echo -e "  ${BG_CYAN}${WHITE}${BOLD}  🌐 NETWORK TOOLS  ${NC}"
        echo
        
        echo -e "  ${G3}╭──────────────────────────────────────────────────────────────────────╮${NC}"
        echo -e "  ${G3}│${NC}   ${GREEN}${BOLD}[1]${NC}  🚀  ${WHITE}${BOLD}Speed Test${NC}          Check network speed              ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${BLUE}${BOLD}[2]${NC}  🌍  ${WHITE}${BOLD}Show IP Info${NC}        Public & Private IP             ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${YELLOW}${BOLD}[3]${NC}  🔍  ${WHITE}${BOLD}Check Open Ports${NC}    Scan open ports                 ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${MAGENTA}${BOLD}[4]${NC}  📡  ${WHITE}${BOLD}Ping Test${NC}           Test connectivity               ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${CYAN}${BOLD}[5]${NC}  🔗  ${WHITE}${BOLD}DNS Lookup${NC}          Check DNS resolution            ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${RED}${BOLD}[0]${NC}  ⬅️   ${WHITE}${BOLD}Back${NC}                                          ${G3}│${NC}"
        echo -e "  ${G3}╰──────────────────────────────────────────────────────────────────────╯${NC}"
        echo
        echo -en "  ${GREEN}${BOLD}➜ Select [0-5]:${NC} "
        read -r choice
        
        case $choice in
            1) net_speed_test ;;
            2) net_ip_info ;;
            3) net_port_scan ;;
            4) net_ping_test ;;
            5) net_dns_lookup ;;
            0) return ;;
            *) warn "Invalid!"; sleep 1 ;;
        esac
    done
}

net_speed_test() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE}${BOLD}  🚀 SPEED TEST  ${NC}"
    echo
    
    if ! command -v speedtest-cli >/dev/null 2>&1; then
        info "Installing speedtest-cli..."
        pip3 install speedtest-cli 2>&1 | tail -2 || apt install -y speedtest-cli 2>&1 | tail -2 || {
            error "Cannot install"
            press_enter
            return
        }
    fi
    
    info "Running test (30-60 sec)..."
    speedtest-cli --simple 2>/dev/null || speedtest --simple 2>/dev/null || error "Failed"
    press_enter
}

net_ip_info() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE}${BOLD}  🌍 IP INFORMATION  ${NC}"
    echo
    
    local pub_ip=$(get_public_ip)
    local priv_ip=$(hostname -I | awk '{print $1}')
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    
    echo -e "  ${G3}╭─────────────── IP Details ───────────────╮${NC}"
    echo -e "  ${G3}│${NC}  ${WHITE}Public IP${NC}   : ${CYAN}${pub_ip}${NC}"
    echo -e "  ${G3}│${NC}  ${WHITE}Private IP${NC}  : ${CYAN}${priv_ip}${NC}"
    echo -e "  ${G3}│${NC}  ${WHITE}Gateway${NC}     : ${CYAN}${gateway:-N/A}${NC}"
    echo -e "  ${G3}╰──────────────────────────────────────────╯${NC}"
    echo
    info "Location info..."
    curl -s ipinfo.io 2>/dev/null | head -20
    press_enter
}

net_port_scan() {
    show_logo
    echo -e "  ${BG_YELLOW}${WHITE}${BOLD}  🔍 OPEN PORTS  ${NC}"
    echo
    info "Listening ports:"
    ss -tulpn 2>/dev/null | head -20 || netstat -tulpn 2>/dev/null | head -20
    press_enter
}

net_ping_test() {
    show_logo
    echo -e "  ${BG_MAGENTA}${WHITE}${BOLD}  📡 PING TEST  ${NC}"
    echo
    read -rp "  Enter host (default: google.com): " host
    host=${host:-google.com}
    ping -c 5 "$host" 2>&1 || error "Failed"
    press_enter
}

net_dns_lookup() {
    show_logo
    echo -e "  ${BG_CYAN}${WHITE}${BOLD}  🔗 DNS LOOKUP  ${NC}"
    echo
    read -rp "  Enter domain (default: google.com): " domain
    domain=${domain:-google.com}
    nslookup "$domain" 2>/dev/null || dig "$domain" 2>/dev/null || host "$domain" 2>/dev/null || error "Failed"
    press_enter
}

# =========================================================
# OPTION 6: FIREWALL
# =========================================================

action_firewall() {
    while true; do
        show_logo
        echo -e "  ${BG_RED}${WHITE}${BOLD}  🔥 FIREWALL MANAGER  ${NC}"
        echo
        
        local ufw_status="${RED}Inactive${NC}"
        if command -v ufw >/dev/null 2>&1; then
            ufw status | grep -q "active" && ufw_status="${GREEN}Active${NC}"
        fi
        echo -e "  ${WHITE}UFW Status:${NC} ${ufw_status}"
        echo
        
        echo -e "  ${G3}╭──────────────────────────────────────────────────────────────────────╮${NC}"
        echo -e "  ${G3}│${NC}   ${GREEN}${BOLD}[1]${NC}  🔓  ${WHITE}${BOLD}Enable UFW${NC}         Enable firewall                 ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${RED}${BOLD}[2]${NC}  🔒  ${WHITE}${BOLD}Disable UFW${NC}        Disable firewall                ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${BLUE}${BOLD}[3]${NC}  ➕  ${WHITE}${BOLD}Allow Port${NC}         Open a port                     ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${YELLOW}${BOLD}[4]${NC}  ➖  ${WHITE}${BOLD}Deny Port${NC}          Block a port                    ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${CYAN}${BOLD}[5]${NC}  📋  ${WHITE}${BOLD}Show Rules${NC}         List all rules                  ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${MAGENTA}${BOLD}[6]${NC}  🔧  ${WHITE}${BOLD}Reset Firewall${NC}     Reset all rules                 ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${RED}${BOLD}[0]${NC}  ⬅️   ${WHITE}${BOLD}Back${NC}                                          ${G3}│${NC}"
        echo -e "  ${G3}╰──────────────────────────────────────────────────────────────────────╯${NC}"
        echo
        echo -en "  ${GREEN}${BOLD}➜ Select [0-6]:${NC} "
        read -r choice
        
        case $choice in
            1) fw_enable ;;
            2) fw_disable ;;
            3) fw_allow ;;
            4) fw_deny ;;
            5) fw_list ;;
            6) fw_reset ;;
            0) return ;;
            *) warn "Invalid!"; sleep 1 ;;
        esac
    done
}

fw_enable() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE}${BOLD}  🔓 ENABLE FIREWALL  ${NC}"
    echo
    
    if ! command -v ufw >/dev/null 2>&1; then
        info "Installing ufw..."
        apt install -y ufw 2>&1 | tail -2
    fi
    
    info "Allowing SSH first..."
    ufw allow 22/tcp
    ufw allow ${PANEL_PORT}/tcp
    info "Enabling..."
    echo "y" | ufw enable
    ok "Firewall enabled!"
    press_enter
}

fw_disable() {
    show_logo
    echo -e "  ${BG_RED}${WHITE}${BOLD}  🔒 DISABLE FIREWALL  ${NC}"
    echo
    ufw disable
    ok "Disabled!"
    press_enter
}

fw_allow() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE}${BOLD}  ➕ ALLOW PORT  ${NC}"
    echo
    read -rp "  Enter port: " port
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        error "Invalid!"
        press_enter
        return
    fi
    ufw allow ${port}/tcp
    ok "Port ${port} allowed!"
    press_enter
}

fw_deny() {
    show_logo
    echo -e "  ${BG_YELLOW}${WHITE}${BOLD}  ➖ DENY PORT  ${NC}"
    echo
    read -rp "  Enter port: " port
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        error "Invalid!"
        press_enter
        return
    fi
    ufw deny ${port}/tcp
    ok "Port ${port} blocked!"
    press_enter
}

fw_list() {
    show_logo
    echo -e "  ${BG_CYAN}${WHITE}${BOLD}  📋 FIREWALL RULES  ${NC}"
    echo
    ufw status verbose 2>/dev/null || iptables -L -n 2>/dev/null
    press_enter
}

fw_reset() {
    show_logo
    echo -e "  ${BG_MAGENTA}${WHITE}${BOLD}  🔧 RESET FIREWALL  ${NC}"
    echo
    warn "This deletes ALL rules!"
    read -rp "  Continue? (y/n): " c
    [[ "$c" != "y" && "$c" != "Y" ]] && return
    echo "y" | ufw reset
    ok "Reset done!"
    press_enter
}

# =========================================================
# OPTION 7: BACKUP & RESTORE
# =========================================================

action_backup() {
    while true; do
        show_logo
        echo -e "  ${BG_MAGENTA}${WHITE}${BOLD}  💾 BACKUP & RESTORE  ${NC}"
        echo
        
        echo -e "  ${G3}╭──────────────────────────────────────────────────────────────────────╮${NC}"
        echo -e "  ${G3}│${NC}   ${GREEN}${BOLD}[1]${NC}  💾  ${WHITE}${BOLD}Create Backup${NC}       Backup HVM panel data             ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${CYAN}${BOLD}[2]${NC}  📋  ${WHITE}${BOLD}List Backups${NC}        Show all backups                  ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${YELLOW}${BOLD}[3]${NC}  🔄  ${WHITE}${BOLD}Restore Backup${NC}      Restore from backup               ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${RED}${BOLD}[4]${NC}  🗑️   ${WHITE}${BOLD}Delete Backup${NC}       Remove old backups                ${G3}│${NC}"
        echo -e "  ${G3}│${NC}   ${RED}${BOLD}[0]${NC}  ⬅️   ${WHITE}${BOLD}Back${NC}                                            ${G3}│${NC}"
        echo -e "  ${G3}╰──────────────────────────────────────────────────────────────────────╯${NC}"
        echo
        echo -en "  ${GREEN}${BOLD}➜ Select [0-4]:${NC} "
        read -r choice
        
        case $choice in
            1) backup_create ;;
            2) backup_list ;;
            3) backup_restore ;;
            4) backup_delete ;;
            0) return ;;
            *) warn "Invalid!"; sleep 1 ;;
        esac
    done
}

backup_create() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE}${BOLD}  💾 CREATE BACKUP  ${NC}"
    echo
    
    if ! is_panel_installed; then
        error "Panel not installed!"
        press_enter
        return
    fi
    
    mkdir -p /opt/hvm_backups
    local backup_name="hvm_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    info "Creating backup: ${backup_name}"
    tar -czf "/opt/hvm_backups/${backup_name}" -C /opt hvm 2>/dev/null
    
    if [[ -f "/opt/hvm_backups/${backup_name}" ]]; then
        local size=$(du -h "/opt/hvm_backups/${backup_name}" | cut -f1)
        ok "Backup created: ${size}"
        echo -e "  ${WHITE}Location:${NC} ${CYAN}/opt/hvm_backups/${backup_name}${NC}"
    else
        error "Failed!"
    fi
    press_enter
}

backup_list() {
    show_logo
    echo -e "  ${BG_CYAN}${WHITE}${BOLD}  📋 ALL BACKUPS  ${NC}"
    echo
    
    if [[ ! -d /opt/hvm_backups ]] || [[ -z "$(ls /opt/hvm_backups 2>/dev/null)" ]]; then
        warn "No backups found!"
        press_enter
        return
    fi
    
    echo -e "  ${WHITE}${BOLD}Available Backups:${NC}"
    echo
    ls -lh /opt/hvm_backups/ | tail -n +2 | awk '{print "  💾 " $9 "  (" $5 ")  " $6 " " $7}'
    press_enter
}

backup_restore() {
    show_logo
    echo -e "  ${BG_YELLOW}${WHITE}${BOLD}  🔄 RESTORE BACKUP  ${NC}"
    echo
    
    if [[ ! -d /opt/hvm_backups ]] || [[ -z "$(ls /opt/hvm_backups 2>/dev/null)" ]]; then
        warn "No backups!"
        press_enter
        return
    fi
    
    echo -e "  ${WHITE}Available:${NC}"
    ls /opt/hvm_backups/
    echo
    read -rp "  Enter filename: " backup_file
    
    if [[ ! -f "/opt/hvm_backups/${backup_file}" ]]; then
        error "Not found!"
        press_enter
        return
    fi
    
    warn "Will overwrite current installation!"
    read -rp "  Continue? (y/n): " c
    [[ "$c" != "y" && "$c" != "Y" ]] && return
    
    info "Stopping panel..."
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    pkill -f "hvmV8.bin" 2>/dev/null || true
    
    info "Restoring..."
    tar -xzf "/opt/hvm_backups/${backup_file}" -C /opt
    ok "Restored!"
    press_enter
}

backup_delete() {
    show_logo
    echo -e "  ${BG_RED}${WHITE}${BOLD}  🗑️  DELETE BACKUP  ${NC}"
    echo
    
    ls /opt/hvm_backups/ 2>/dev/null
    echo
    read -rp "  Enter filename (or 'all'): " target
    
    if [[ "$target" == "all" ]]; then
        rm -f /opt/hvm_backups/*
        ok "All deleted!"
    elif [[ -f "/opt/hvm_backups/${target}" ]]; then
        rm -f "/opt/hvm_backups/${target}"
        ok "Deleted!"
    else
        error "Not found!"
    fi
    press_enter
}

# =========================================================
# OPTION 8: VPS ENVIRONMENT SETUP
# =========================================================

action_vps_env() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE}${BOLD}  🖥️  VPS ENVIRONMENT SETUP  ${NC}"
    echo
    
    if [[ "$EUID" -ne 0 ]]; then
        error "Must run as root!"
        press_enter
        return
    fi
    
    echo -e "  ${WHITE}${BOLD}This will install:${NC}"
    echo -e "  ${GREEN}✓${NC} Python 3, SQLite3, OpenSSH"
    echo -e "  ${GREEN}✓${NC} Git, Curl, Wget, Zip, Unzip"
    echo -e "  ${GREEN}✓${NC} LXC, LXD (or Incus)"
    echo -e "  ${GREEN}✓${NC} Network Tools + QEMU"
    echo
    warn "This may take 10-15 minutes."
    read -rp "  Continue? (y/n): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled"
        press_enter
        return
    fi
    
    double_divider
    
    step_msg "1/8 Updating System"
    if command -v apt >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt update -y 2>&1 | tail -2
    fi
    ok "Updated"
    
    step_msg "2/8 Basic Tools"
    if command -v apt >/dev/null 2>&1; then
        apt install -y curl wget git zip unzip nano htop net-tools ca-certificates gnupg software-properties-common 2>&1 | tail -2
    fi
    ok "Installed"
    
    step_msg "3/8 Python & SQLite"
    if command -v apt >/dev/null 2>&1; then
        apt install -y python3 python3-pip python3-venv python3-dev sqlite3 libsqlite3-dev 2>&1 | tail -2
    fi
    ok "Installed"
    
    step_msg "4/8 SSH Server"
    if command -v apt >/dev/null 2>&1; then
        apt install -y openssh-server 2>&1 | tail -2
    fi
    systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
    systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null || true
    ok "SSH ready"
    
    step_msg "5/8 Network Tools"
    if command -v apt >/dev/null 2>&1; then
        apt install -y iproute2 bridge-utils iptables iptables-persistent dnsmasq-base uidmap 2>&1 | tail -2
    fi
    ok "Ready"
    
    step_msg "6/8 QEMU"
    if command -v apt >/dev/null 2>&1; then
        apt install -y qemu-utils qemu-system qemu-kvm libvirt-daemon-system libvirt-clients 2>&1 | tail -2
    fi
    ok "Installed"
    
    step_msg "7/8 LXC & LXD"
    if command -v apt >/dev/null 2>&1; then
        apt install -y lxc lxc-utils lxcfs 2>&1 | tail -2
        
        if ! command -v snap >/dev/null 2>&1; then
            apt install -y snapd 2>&1 | tail -2
            sleep 3
        fi
        
        if command -v snap >/dev/null 2>&1; then
            snap install lxd 2>&1 | tail -2
            sleep 5
            ok "LXD installed"
        fi
    fi
    
    step_msg "8/8 Final Setup"
    echo "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf >/dev/null 2>&1
    sysctl -p >/dev/null 2>&1
    modprobe br_netfilter 2>/dev/null || true
    ok "Complete"
    
    double_divider
    echo
    echo -e "  ${GREEN}${BOLD}✅ VPS ENVIRONMENT READY!${NC}"
    echo
    echo -e "  ${WHITE}Next Steps:${NC}"
    echo -e "  ${GREEN}1.${NC} ${CYAN}sudo reboot${NC}"
    echo -e "  ${GREEN}2.${NC} ${CYAN}sudo lxd init${NC}"
    echo -e "  ${GREEN}3.${NC} Install HVM Panel"
    press_enter
}

# =========================================================
# OPTION 9: CONTACT
# =========================================================

action_contact() {
    show_logo
    echo -e "  ${BG_MAGENTA}${WHITE}${BOLD}  💬 CONTACT & SUPPORT  ${NC}"
    echo
    
    echo -e "  ${G1}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${G1}║${NC}                                                                      ${G1}║${NC}"
    echo -e "  ${G2}║${NC}         ${WHITE}${BOLD}🌐 FakeCloud Community${NC}                                    ${G2}║${NC}"
    echo -e "  ${G3}║${NC}                                                                      ${G3}║${NC}"
    echo -e "  ${G3}║${NC}         ${WHITE}Join our Discord for:${NC}                                        ${G3}║${NC}"
    echo -e "  ${G4}║${NC}                                                                      ${G4}║${NC}"
    echo -e "  ${G4}║${NC}         ${GREEN}✓${NC} 24/7 Support                                             ${G4}║${NC}"
    echo -e "  ${G5}║${NC}         ${GREEN}✓${NC} Latest Panel Updates                                     ${G5}║${NC}"
    echo -e "  ${G5}║${NC}         ${GREEN}✓${NC} License Purchase                                         ${G5}║${NC}"
    echo -e "  ${G6}║${NC}         ${GREEN}✓${NC} Bug Reports                                              ${G6}║${NC}"
    echo -e "  ${G6}║${NC}         ${GREEN}✓${NC} Feature Requests                                         ${G6}║${NC}"
    echo -e "  ${G7}║${NC}         ${GREEN}✓${NC} Tutorials & Guides                                       ${G7}║${NC}"
    echo -e "  ${G7}║${NC}                                                                      ${G7}║${NC}"
    echo -e "  ${G8}║${NC}         ${WHITE}${BOLD}💬 Discord:${NC}                                                ${G8}║${NC}"
    echo -e "  ${G8}║${NC}         ${BLUE}${BOLD}${UNDERLINE}${DISCORD_LINK}${NC}                              ${G8}║${NC}"
    echo -e "  ${G1}║${NC}                                                                      ${G1}║${NC}"
    echo -e "  ${G2}║${NC}         ${WHITE}Brand:${NC} ${CYAN}${BRAND_NAME}${NC}                                              ${G2}║${NC}"
    echo -e "  ${G3}║${NC}         ${WHITE}Panel:${NC} ${MAGENTA}HVM v${PANEL_VERSION}${NC}                                    ${G3}║${NC}"
    echo -e "  ${G4}║${NC}         ${WHITE}Manager:${NC} ${GREEN}v${MANAGER_VERSION}${NC}                                            ${G4}║${NC}"
    echo -e "  ${G5}║${NC}                                                                      ${G5}║${NC}"
    echo -e "  ${G1}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    press_enter
}

# =========================================================
# MAIN
# =========================================================

main() {
    detect_environment
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
    fi
    
    if [[ "$EUID" -ne 0 ]]; then
        show_logo
        error "Please run as root!"
        echo -e "  Run: ${WHITE}sudo bash installer.sh${NC}"
        echo -e "  Or: ${WHITE}sudo bash <(curl -s ${INSTALLER_URL})${NC}"
        exit 1
    fi
    
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1) action_install ;;
            2) action_manage ;;
            3) action_sysinfo ;;
            4) action_tailscale ;;
            5) action_network_tools ;;
            6) action_firewall ;;
            7) action_backup ;;
            8) action_vps_env ;;
            9) action_contact ;;
            0) 
                show_logo
                echo -e "  ${GREEN}${BOLD}Thank you for using FakeCloud HVM Manager!${NC}"
                echo -e "  ${BLUE}${DISCORD_LINK}${NC}"
                echo
                exit 0
                ;;
            *)
                warn "Invalid option! Choose 0-9"
                sleep 2
                ;;
        esac
    done
}

main "$@"
