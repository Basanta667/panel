#!/usr/bin/env bash

# =========================================================
# FAKECLOUD PANEL MANAGER v4.0
# NVM & HVM Panel Installer
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
NC="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"
BG_BLUE="\e[44m"
BG_GREEN="\e[42m"
BG_RED="\e[41m"
BG_YELLOW="\e[43m"
BG_MAGENTA="\e[45m"

# =========================================================
# VARIABLES
# =========================================================

# NVM Panel
NVM_FILE_ID="1Q757Mhk86L2-uWVsXhjHx_XDHIJQk2fN"
NVM_URL="https://drive.usercontent.google.com/download?id=${NVM_FILE_ID}&export=download&confirm=t"
NVM_INSTALL_DIR="/opt/nvm"
NVM_BIN="${NVM_INSTALL_DIR}/nvm.bin"
NVM_SERVICE="nvm"
NVM_PORT="5000"
NVM_LOG="/var/log/nvm.log"

# HVM Panel
HVM_FILE_ID="1IhayXycn0bzu7c8EEO2Xsv8Xwr9OXXiy"
HVM_URL="https://drive.usercontent.google.com/download?id=${HVM_FILE_ID}&export=download&confirm=t"
HVM_INSTALL_DIR="/opt/hvm"
HVM_BIN="${HVM_INSTALL_DIR}/hvmV8.bin"
HVM_SERVICE="hvm"
HVM_PORT="5000"
HVM_LOG="/var/log/hvm.log"

# General
DISCORD_LINK="https://dsc.gg/fakecloud"
BRAND_NAME="FakeCloud"
MANAGER_VERSION="4.0"
INSTALLER_URL="https://raw.githubusercontent.com/Basanta667/panel/main/HvmV8.sh"

# Current selected panel (set by user)
CURRENT_PANEL=""
CURRENT_FILE_ID=""
CURRENT_URL=""
CURRENT_INSTALL_DIR=""
CURRENT_BIN=""
CURRENT_SERVICE=""
CURRENT_PORT=""
CURRENT_LOG=""

HAS_SYSTEMD=false

# =========================================================
# HELPER FUNCTIONS
# =========================================================

info() { echo -e "  ${CYAN}⚡ [INFO]${NC} $1"; }
ok() { echo -e "  ${GREEN}✅ [OK]${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠️  [WARN]${NC} $1"; }
error() { echo -e "  ${RED}❌ [ERROR]${NC} $1"; }
line() { echo -e "${MAGENTA}════════════════════════════════════════════════════════════════════════════${NC}"; }

press_enter() {
    echo
    echo -e "  ${DIM}Press ENTER to continue...${NC}"
    read -r
}

check_internet() {
    for url in "https://www.google.com" "https://1.1.1.1" "https://raw.githubusercontent.com"; do
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

is_panel_installed() {
    local bin="$1"
    [[ -f "$bin" ]]
}

is_panel_running() {
    local port="$1"
    local bin_name="$2"
    if command -v lsof >/dev/null 2>&1 && lsof -Pi :${port} -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    fi
    if pgrep -f "$bin_name" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Set current panel variables
set_panel() {
    local panel="$1"
    CURRENT_PANEL="$panel"
    
    if [[ "$panel" == "NVM" ]]; then
        CURRENT_FILE_ID="$NVM_FILE_ID"
        CURRENT_URL="$NVM_URL"
        CURRENT_INSTALL_DIR="$NVM_INSTALL_DIR"
        CURRENT_BIN="$NVM_BIN"
        CURRENT_SERVICE="$NVM_SERVICE"
        CURRENT_PORT="$NVM_PORT"
        CURRENT_LOG="$NVM_LOG"
    elif [[ "$panel" == "HVM" ]]; then
        CURRENT_FILE_ID="$HVM_FILE_ID"
        CURRENT_URL="$HVM_URL"
        CURRENT_INSTALL_DIR="$HVM_INSTALL_DIR"
        CURRENT_BIN="$HVM_BIN"
        CURRENT_SERVICE="$HVM_SERVICE"
        CURRENT_PORT="$HVM_PORT"
        CURRENT_LOG="$HVM_LOG"
    fi
}

# =========================================================
# LOGO
# =========================================================

show_logo() {
    clear
    echo
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════════╗
    ║                                                                      ║
    ║   ███████╗ █████╗ ██╗  ██╗███████╗ ██████╗██╗      ██████╗ ██╗   ██╗██████╗ 
    ║   ██╔════╝██╔══██╗██║ ██╔╝██╔════╝██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗
    ║   █████╗  ███████║█████╔╝ █████╗  ██║     ██║     ██║   ██║██║   ██║██║  ██║
    ║   ██╔══╝  ██╔══██║██╔═██╗ ██╔══╝  ██║     ██║     ██║   ██║██║   ██║██║  ██║
    ║   ██║     ██║  ██║██║  ██╗███████╗╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝
    ║   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ 
    ║                                                                      ║
    ║              PANEL MANAGER v4.0 — DUAL EDITION                       ║
    ║                                                                      ║
    ╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# =========================================================
# MAIN MENU
# =========================================================

show_main_menu() {
    show_logo
    
    # System info
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "0")
    local ram_used=$(free | awk '/^Mem:/{printf "%.0f", $3/$2*100}' 2>/dev/null || echo "0")
    local uptime_short=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")
    local pub_ip=$(get_public_ip)
    
    # Panel status
    local nvm_status="${RED}○ Not Installed${NC}"
    local hvm_status="${RED}○ Not Installed${NC}"
    
    if is_panel_installed "$NVM_BIN"; then
        if is_panel_running "$NVM_PORT" "nvm.bin"; then
            nvm_status="${GREEN}● Online${NC}"
        else
            nvm_status="${YELLOW}○ Installed (Stopped)${NC}"
        fi
    fi
    
    if is_panel_installed "$HVM_BIN"; then
        if is_panel_running "$HVM_PORT" "hvmV8.bin"; then
            hvm_status="${GREEN}● Online${NC}"
        else
            hvm_status="${YELLOW}○ Installed (Stopped)${NC}"
        fi
    fi
    
    # Tailscale status
    local ts_status="${RED}○ Not Installed${NC}"
    if command -v tailscale >/dev/null 2>&1; then
        if tailscale status >/dev/null 2>&1; then
            ts_status="${GREEN}● Connected${NC}"
        else
            ts_status="${YELLOW}○ Installed (Not Connected)${NC}"
        fi
    fi
    
    echo -e " ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}${BOLD}📊 SYSTEM STATUS${NC}"
    echo -e "     CPU: ${WHITE}${cpu}%${NC}    RAM: ${WHITE}${ram_used}%${NC}    Uptime: ${WHITE}${uptime_short}${NC}    IP: ${WHITE}${pub_ip}${NC}"
    echo
    echo -e "  ${WHITE}${BOLD}🎛️  PANELS STATUS${NC}"
    echo -e "     🔵 NVM Panel: ${nvm_status}"
    echo -e "     🟣 HVM Panel: ${hvm_status}"
    echo -e "     🔗 Tailscale: ${ts_status}"
    echo -e " ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo
    echo -e "  ${WHITE}${BOLD}📋 MAIN MENU${NC}"
    echo -e "  ${CYAN}┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "  ${CYAN}│${NC}  ${GREEN}[1]${NC} ${WHITE}${BOLD}Panel Installation${NC}          ${DIM}(Install NVM or HVM Panel)${NC}"
    echo -e "  ${CYAN}│${NC}  ${YELLOW}[2]${NC} ${WHITE}${BOLD}Panel Management${NC}            ${DIM}(Start/Stop/Restart/Reinstall)${NC}"
    echo -e "  ${CYAN}│${NC}  ${BLUE}[3]${NC} ${WHITE}${BOLD}System Information${NC}          ${DIM}(CPU, RAM, Disk, Network)${NC}"
    echo -e "  ${CYAN}│${NC}  ${MAGENTA}[4]${NC} ${WHITE}${BOLD}Tailscale${NC}                   ${DIM}(Install + Connect to Tailnet)${NC}"
    echo -e "  ${CYAN}│${NC}  ${CYAN}[5]${NC} ${WHITE}${BOLD}Contact & Support${NC}           ${DIM}(Discord, About)${NC}"
    echo -e "  ${CYAN}│${NC}  ${RED}[0]${NC} ${WHITE}${BOLD}Exit${NC}                        ${DIM}(Close manager)${NC}"
    echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────┘${NC}"
    echo
    echo -e " ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}💬 Discord:${NC} ${BLUE}${DISCORD_LINK}${NC}    ${WHITE}🌐 Brand:${NC} ${CYAN}${BRAND_NAME}${NC}    ${WHITE}v${MANAGER_VERSION}${NC}"
    echo -e " ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo
    echo -en "  ${GREEN}${BOLD}➜ Select Option [0-5]:${NC} "
}

# =========================================================
# OPTION 1: PANEL INSTALLATION MENU
# =========================================================

menu_install() {
    while true; do
        show_logo
        echo -e "  ${BG_GREEN}${WHITE} 📦 PANEL INSTALLATION ${NC}"
        echo
        echo -e "  ${WHITE}${BOLD}Select Panel to Install:${NC}"
        echo
        echo -e "  ${CYAN}┌──────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "  ${CYAN}│${NC}  ${BLUE}[1]${NC} ${WHITE}${BOLD}Install NVM Panel${NC}       ${DIM}(FakeCloud NVM v3)${NC}"
        echo -e "  ${CYAN}│${NC}  ${MAGENTA}[2]${NC} ${WHITE}${BOLD}Install HVM Panel${NC}       ${DIM}(FakeCloud HVM v8)${NC}"
        echo -e "  ${CYAN}│${NC}  ${RED}[0]${NC} ${WHITE}${BOLD}Back to Main Menu${NC}"
        echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────┘${NC}"
        echo
        echo -en "  ${GREEN}${BOLD}➜ Select [0-2]:${NC} "
        read -r choice
        
        case $choice in
            1) set_panel "NVM"; install_panel ;;
            2) set_panel "HVM"; install_panel ;;
            0) return ;;
            *) warn "Invalid option!"; sleep 1 ;;
        esac
    done
}

install_panel() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE} 📦 INSTALLING ${CURRENT_PANEL} PANEL ${NC}"
    echo
    
    if is_panel_installed "$CURRENT_BIN"; then
        warn "${CURRENT_PANEL} Panel already installed!"
        echo -e "  ${DIM}Use Panel Management to reinstall.${NC}"
        press_enter
        return
    fi
    
    line
    info "Installing ${CURRENT_PANEL} Panel..."
    line
    
    # Root check
    if [[ "$EUID" -ne 0 ]]; then
        error "Must run as root!"
        press_enter
        return
    fi
    ok "Running as root"
    
    # Internet
    info "Checking internet..."
    if check_internet; then
        ok "Internet OK"
    else
        warn "Internet check failed, continuing..."
    fi
    
    # Install deps
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
    
    # Kill port
    if is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
        warn "Port ${CURRENT_PORT} busy, killing..."
        pkill -f "$(basename $CURRENT_BIN)" 2>/dev/null || true
        sleep 2
    fi
    
    # Create dir
    mkdir -p "${CURRENT_INSTALL_DIR}"
    cd "${CURRENT_INSTALL_DIR}"
    ok "Directory: ${CURRENT_INSTALL_DIR}"
    
    # Download
    info "Downloading ${CURRENT_PANEL} binary (5-10 min)..."
    echo
    
    local COOKIES_FILE="/tmp/gdrive_cookies_$$.txt"
    local PAGE_FILE="/tmp/gdrive_page_$$.html"
    local BIN_NAME=$(basename "$CURRENT_BIN")
    
    rm -f "$BIN_NAME"
    
    wget --quiet --save-cookies "${COOKIES_FILE}" --keep-session-cookies \
        --no-check-certificate \
        "https://docs.google.com/uc?export=download&id=${CURRENT_FILE_ID}" \
        -O "${PAGE_FILE}" 2>/dev/null || true
    
    local CONFIRM=$(grep -oP 'confirm=[0-9A-Za-z_-]+' "${PAGE_FILE}" 2>/dev/null | head -1 | cut -d'=' -f2 || echo "")
    
    if [[ -n "${CONFIRM}" ]]; then
        wget --load-cookies "${COOKIES_FILE}" --no-check-certificate --progress=bar:force:noscroll \
            "https://docs.google.com/uc?export=download&confirm=${CONFIRM}&id=${CURRENT_FILE_ID}" \
            -O "$BIN_NAME" 2>&1 | tail -3 || true
    fi
    
    if [[ ! -f "$BIN_NAME" ]] || [[ ! -s "$BIN_NAME" ]] || file "$BIN_NAME" 2>/dev/null | grep -qi "html"; then
        rm -f "$BIN_NAME"
        wget --no-check-certificate --progress=bar:force:noscroll "${CURRENT_URL}" -O "$BIN_NAME" 2>&1 | tail -3 || true
    fi
    
    rm -f "${COOKIES_FILE}" "${PAGE_FILE}"
    
    if [[ ! -f "$BIN_NAME" ]] || [[ ! -s "$BIN_NAME" ]]; then
        error "Download failed!"
        press_enter
        return
    fi
    
    local size=$(du -m "$BIN_NAME" | cut -f1)
    if [[ "$size" -lt 20 ]]; then
        error "File too small (${size}MB), corrupted!"
        rm -f "$BIN_NAME"
        press_enter
        return
    fi
    
    chmod +x "$BIN_NAME"
    ok "Downloaded ${BIN_NAME} (${size}MB)"
    
    # Firewall
    info "Configuring firewall..."
    command -v ufw >/dev/null 2>&1 && ufw allow ${CURRENT_PORT}/tcp >/dev/null 2>&1 || true
    command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --permanent --add-port=${CURRENT_PORT}/tcp >/dev/null 2>&1 && firewall-cmd --reload >/dev/null 2>&1 || true
    command -v iptables >/dev/null 2>&1 && iptables -I INPUT -p tcp --dport ${CURRENT_PORT} -j ACCEPT 2>/dev/null || true
    ok "Firewall configured"
    
    # Service or manual
    if [[ "${HAS_SYSTEMD}" == true ]]; then
        info "Creating systemd service..."
        cat > /etc/systemd/system/${CURRENT_SERVICE}.service << EOF
[Unit]
Description=${CURRENT_PANEL} Panel - Powered by ${BRAND_NAME}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${CURRENT_INSTALL_DIR}
ExecStart=${CURRENT_BIN}
Restart=always
RestartSec=5
LimitNOFILE=1048576
User=root
StandardOutput=append:${CURRENT_LOG}
StandardError=append:${CURRENT_LOG}

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable ${CURRENT_SERVICE} >/dev/null 2>&1
        systemctl restart ${CURRENT_SERVICE}
        ok "Service created and started"
    else
        info "Starting manually..."
        nohup ${CURRENT_BIN} >> ${CURRENT_LOG} 2>&1 &
        sleep 3
        ok "Panel started"
    fi
    
    sleep 5
    
    line
    echo
    echo -e "  ${BG_GREEN}${WHITE} ✅ ${CURRENT_PANEL} PANEL INSTALLED! ${NC}"
    echo
    echo -e "  🌐 Panel URL: ${CYAN}${BOLD}http://$(get_public_ip):${CURRENT_PORT}${NC}"
    echo -e "  👤 Username : ${GREEN}admin${NC}"
    echo -e "  🔑 Password : ${GREEN}admin${NC}"
    echo -e "  📁 Directory: ${DIM}${CURRENT_INSTALL_DIR}${NC}"
    echo
    echo -e "  💬 Discord: ${BLUE}${DISCORD_LINK}${NC}"
    line
    press_enter
}

# =========================================================
# OPTION 2: PANEL MANAGEMENT MENU
# =========================================================

menu_manage() {
    while true; do
        show_logo
        echo -e "  ${BG_YELLOW}${WHITE} ⚙️  PANEL MANAGEMENT ${NC}"
        echo
        echo -e "  ${WHITE}${BOLD}Select Panel to Manage:${NC}"
        echo
        
        # Show panel status
        local nvm_status="${RED}○ Not Installed${NC}"
        local hvm_status="${RED}○ Not Installed${NC}"
        
        if is_panel_installed "$NVM_BIN"; then
            if is_panel_running "$NVM_PORT" "nvm.bin"; then
                nvm_status="${GREEN}● Running${NC}"
            else
                nvm_status="${YELLOW}○ Stopped${NC}"
            fi
        fi
        
        if is_panel_installed "$HVM_BIN"; then
            if is_panel_running "$HVM_PORT" "hvmV8.bin"; then
                hvm_status="${GREEN}● Running${NC}"
            else
                hvm_status="${YELLOW}○ Stopped${NC}"
            fi
        fi
        
        echo -e "  ${CYAN}┌──────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "  ${CYAN}│${NC}  ${BLUE}[1]${NC} ${WHITE}${BOLD}Manage NVM Panel${NC}         Status: ${nvm_status}"
        echo -e "  ${CYAN}│${NC}  ${MAGENTA}[2]${NC} ${WHITE}${BOLD}Manage HVM Panel${NC}         Status: ${hvm_status}"
        echo -e "  ${CYAN}│${NC}  ${RED}[0]${NC} ${WHITE}${BOLD}Back to Main Menu${NC}"
        echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────┘${NC}"
        echo
        echo -en "  ${GREEN}${BOLD}➜ Select [0-2]:${NC} "
        read -r choice
        
        case $choice in
            1) set_panel "NVM"; manage_panel ;;
            2) set_panel "HVM"; manage_panel ;;
            0) return ;;
            *) warn "Invalid option!"; sleep 1 ;;
        esac
    done
}

manage_panel() {
    while true; do
        show_logo
        echo -e "  ${BG_YELLOW}${WHITE} ⚙️  MANAGING ${CURRENT_PANEL} PANEL ${NC}"
        echo
        
        # Status
        local status_color="${RED}"
        local status_text="Not Installed"
        if is_panel_installed "$CURRENT_BIN"; then
            if is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
                status_color="${GREEN}"
                status_text="Running"
            else
                status_color="${YELLOW}"
                status_text="Stopped"
            fi
        fi
        
        echo -e "  ${WHITE}Current Status:${NC} ${status_color}${status_text}${NC}"
        if is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
            echo -e "  ${WHITE}Panel URL:${NC} ${CYAN}http://$(get_public_ip):${CURRENT_PORT}${NC}"
        fi
        echo
        
        echo -e "  ${CYAN}┌──────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "  ${CYAN}│${NC}  ${GREEN}[1]${NC} ▶ ${WHITE}${BOLD}Start Panel${NC}"
        echo -e "  ${CYAN}│${NC}  ${RED}[2]${NC} ■ ${WHITE}${BOLD}Stop Panel${NC}"
        echo -e "  ${CYAN}│${NC}  ${YELLOW}[3]${NC} ↻ ${WHITE}${BOLD}Restart Panel${NC}"
        echo -e "  ${CYAN}│${NC}  ${BLUE}[4]${NC} 🔄 ${WHITE}${BOLD}Reinstall Panel${NC}"
        echo -e "  ${CYAN}│${NC}  ${MAGENTA}[5]${NC} 🗑️  ${WHITE}${BOLD}Uninstall Panel${NC}"
        echo -e "  ${CYAN}│${NC}  ${CYAN}[6]${NC} 📋 ${WHITE}${BOLD}View Logs${NC}"
        echo -e "  ${CYAN}│${NC}  ${WHITE}[7]${NC} ℹ️  ${WHITE}${BOLD}Panel Info${NC}"
        echo -e "  ${CYAN}│${NC}  ${RED}[0]${NC} ← ${WHITE}${BOLD}Back${NC}"
        echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────┘${NC}"
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
            *) warn "Invalid option!"; sleep 1 ;;
        esac
    done
}

panel_start() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE} ▶ START ${CURRENT_PANEL} PANEL ${NC}"
    echo
    
    if ! is_panel_installed "$CURRENT_BIN"; then
        error "${CURRENT_PANEL} Panel not installed!"
        press_enter
        return
    fi
    
    if is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
        warn "Panel already running!"
        press_enter
        return
    fi
    
    info "Starting ${CURRENT_PANEL} panel..."
    if [[ "${HAS_SYSTEMD}" == true ]] && [[ -f "/etc/systemd/system/${CURRENT_SERVICE}.service" ]]; then
        systemctl start ${CURRENT_SERVICE}
    else
        cd "${CURRENT_INSTALL_DIR}"
        nohup ${CURRENT_BIN} >> ${CURRENT_LOG} 2>&1 &
    fi
    
    sleep 5
    
    if is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
        ok "Panel started successfully!"
        echo -e "  🌐 URL: ${CYAN}http://$(get_public_ip):${CURRENT_PORT}${NC}"
    else
        error "Failed to start!"
    fi
    press_enter
}

panel_stop() {
    show_logo
    echo -e "  ${BG_RED}${WHITE} ■ STOP ${CURRENT_PANEL} PANEL ${NC}"
    echo
    
    if ! is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
        warn "Panel not running!"
        press_enter
        return
    fi
    
    info "Stopping ${CURRENT_PANEL} panel..."
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl stop ${CURRENT_SERVICE} 2>/dev/null || true
    pkill -f "$(basename $CURRENT_BIN)" 2>/dev/null || true
    sleep 2
    
    if ! is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
        ok "Panel stopped!"
    else
        error "Failed to stop!"
    fi
    press_enter
}

panel_restart() {
    show_logo
    echo -e "  ${BG_YELLOW}${WHITE} ↻ RESTART ${CURRENT_PANEL} PANEL ${NC}"
    echo
    
    if ! is_panel_installed "$CURRENT_BIN"; then
        error "Panel not installed!"
        press_enter
        return
    fi
    
    info "Restarting ${CURRENT_PANEL}..."
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl restart ${CURRENT_SERVICE} 2>/dev/null || {
        pkill -f "$(basename $CURRENT_BIN)" 2>/dev/null || true
        sleep 2
        cd "${CURRENT_INSTALL_DIR}"
        nohup ${CURRENT_BIN} >> ${CURRENT_LOG} 2>&1 &
    }
    
    sleep 5
    
    if is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
        ok "Panel restarted!"
        echo -e "  🌐 URL: ${CYAN}http://$(get_public_ip):${CURRENT_PORT}${NC}"
    else
        error "Restart failed!"
    fi
    press_enter
}

panel_reinstall() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 🔄 REINSTALL ${CURRENT_PANEL} PANEL ${NC}"
    echo
    warn "This will DELETE current installation and install fresh!"
    echo
    read -rp "  Continue? (y/n): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled"
        press_enter
        return
    fi
    
    info "Uninstalling..."
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl stop ${CURRENT_SERVICE} 2>/dev/null || true
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl disable ${CURRENT_SERVICE} 2>/dev/null || true
    pkill -f "$(basename $CURRENT_BIN)" 2>/dev/null || true
    rm -f /etc/systemd/system/${CURRENT_SERVICE}.service
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl daemon-reload 2>/dev/null || true
    rm -rf "${CURRENT_INSTALL_DIR}"
    rm -f "${CURRENT_LOG}"
    ok "Old installation removed"
    
    install_panel
}

panel_uninstall() {
    show_logo
    echo -e "  ${BG_RED}${WHITE} 🗑️  UNINSTALL ${CURRENT_PANEL} PANEL ${NC}"
    echo
    
    if ! is_panel_installed "$CURRENT_BIN"; then
        warn "Panel not installed!"
        press_enter
        return
    fi
    
    warn "This will DELETE:"
    echo -e "    ${DIM}• Binary${NC}"
    echo -e "    ${DIM}• Config${NC}"
    echo -e "    ${DIM}• Database${NC}"
    echo -e "    ${DIM}• Logs${NC}"
    echo
    read -rp "  Type 'YES' to confirm: " confirm
    
    if [[ "$confirm" != "YES" ]]; then
        info "Cancelled"
        press_enter
        return
    fi
    
    info "Uninstalling..."
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl stop ${CURRENT_SERVICE} 2>/dev/null || true
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl disable ${CURRENT_SERVICE} 2>/dev/null || true
    pkill -f "$(basename $CURRENT_BIN)" 2>/dev/null || true
    rm -f /etc/systemd/system/${CURRENT_SERVICE}.service
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl daemon-reload 2>/dev/null || true
    rm -rf "${CURRENT_INSTALL_DIR}"
    rm -f "${CURRENT_LOG}"
    ok "${CURRENT_PANEL} Panel uninstalled!"
    press_enter
}

panel_logs() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 📋 ${CURRENT_PANEL} PANEL LOGS ${NC}"
    echo
    
    if [[ ! -f "${CURRENT_LOG}" ]]; then
        error "Log file not found: ${CURRENT_LOG}"
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
        1) clear; echo -e "${CYAN}══ Last 50 ══${NC}"; tail -50 "${CURRENT_LOG}" ;;
        2) clear; echo -e "${CYAN}══ Last 200 ══${NC}"; tail -200 "${CURRENT_LOG}" ;;
        3) clear; echo -e "${CYAN}══ Live Logs ══${NC}"; tail -f "${CURRENT_LOG}" ;;
        0) return ;;
    esac
    press_enter
}

panel_info() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} ℹ️  ${CURRENT_PANEL} PANEL INFO ${NC}"
    echo
    
    if ! is_panel_installed "$CURRENT_BIN"; then
        error "Panel not installed!"
        press_enter
        return
    fi
    
    local status="${RED}Offline${NC}"
    is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)" && status="${GREEN}Online${NC}"
    
    local size=$(du -h "$CURRENT_BIN" 2>/dev/null | cut -f1)
    local install_date=$(stat -c %y "$CURRENT_BIN" 2>/dev/null | cut -d. -f1)
    
    echo -e "  ${CYAN}╭─── Panel Details ───╮${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Name${NC}       : ${CURRENT_PANEL}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Status${NC}     : ${status}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}URL${NC}        : ${CYAN}http://$(get_public_ip):${CURRENT_PORT}${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Directory${NC}  : ${CURRENT_INSTALL_DIR}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Binary${NC}     : ${CURRENT_BIN}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Size${NC}       : ${size}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Installed${NC}  : ${install_date}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Log File${NC}   : ${CURRENT_LOG}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Service${NC}    : ${CURRENT_SERVICE}"
    echo -e "  ${CYAN}╰─────────────────────╯${NC}"
    press_enter
}

# =========================================================
# OPTION 3: SYSTEM INFORMATION
# =========================================================

action_sysinfo() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 💻 SYSTEM INFORMATION ${NC}"
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
    
    # OS info
    local os_name="Unknown"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        os_name="$PRETTY_NAME"
    fi
    
    echo -e "  ${CYAN}╭─────────────── System Info ────────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🖥️  Hostname${NC}   : ${hostname}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🐧 OS${NC}         : ${os_name}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🔧 Kernel${NC}     : ${kernel}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🏗️  Arch${NC}       : $(uname -m)"
    echo -e "  ${CYAN}├────────────────────────────────────────────┤${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}💻 CPU Model${NC}  : ${cpu_model}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🔢 CPU Cores${NC}  : ${cpu_cores}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}📊 CPU Usage${NC}  : ${cpu_usage}%"
    echo -e "  ${CYAN}├────────────────────────────────────────────┤${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}💾 RAM Total${NC}  : ${total_ram}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}📈 RAM Used${NC}   : ${used_ram} (${ram_percent}%)"
    echo -e "  ${CYAN}│${NC}  ${WHITE}📉 RAM Free${NC}   : ${free_ram}"
    echo -e "  ${CYAN}├────────────────────────────────────────────┤${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}💿 Disk${NC}       : ${disk_info}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}📂 Disk Free${NC}  : ${disk_free}"
    echo -e "  ${CYAN}├────────────────────────────────────────────┤${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🌐 Public IP${NC}  : ${pub_ip}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🏠 Private IP${NC} : ${priv_ip}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}⏰ Uptime${NC}     : ${uptime}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}⚙️  Systemd${NC}    : $([[ "${HAS_SYSTEMD}" == true ]] && echo "${GREEN}Yes${NC}" || echo "${YELLOW}No${NC}")"
    echo -e "  ${CYAN}╰────────────────────────────────────────────╯${NC}"
    press_enter
}

# =========================================================
# OPTION 4: TAILSCALE
# =========================================================

action_tailscale() {
    while true; do
        show_logo
        echo -e "  ${BG_MAGENTA}${WHITE} 🔗 TAILSCALE MANAGER ${NC}"
        echo
        
        local ts_status="${RED}Not Installed${NC}"
        local ts_ip="N/A"
        
        if command -v tailscale >/dev/null 2>&1; then
            if tailscale status >/dev/null 2>&1; then
                ts_status="${GREEN}Connected${NC}"
                ts_ip=$(tailscale ip -4 2>/dev/null | head -1 || echo "N/A")
            else
                ts_status="${YELLOW}Installed (Not Connected)${NC}"
            fi
        fi
        
        echo -e "  ${WHITE}Status:${NC} ${ts_status}"
        echo -e "  ${WHITE}Tailscale IP:${NC} ${CYAN}${ts_ip}${NC}"
        echo
        echo -e "  ${CYAN}┌──────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "  ${CYAN}│${NC}  ${GREEN}[1]${NC} 📥 Install Tailscale"
        echo -e "  ${CYAN}│${NC}  ${BLUE}[2]${NC} 🔗 Connect (tailscale up)"
        echo -e "  ${CYAN}│${NC}  ${YELLOW}[3]${NC} ⬇️  Disconnect (tailscale down)"
        echo -e "  ${CYAN}│${NC}  ${MAGENTA}[4]${NC} ℹ️  Show Status"
        echo -e "  ${CYAN}│${NC}  ${RED}[5]${NC} 🗑️  Uninstall Tailscale"
        echo -e "  ${CYAN}│${NC}  ${RED}[0]${NC} ← Back to Main Menu"
        echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────┘${NC}"
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
            *) warn "Invalid option!"; sleep 1 ;;
        esac
    done
}

tailscale_install() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE} 📥 INSTALLING TAILSCALE ${NC}"
    echo
    
    if command -v tailscale >/dev/null 2>&1; then
        warn "Tailscale already installed!"
        !tailscale version 2>/dev/null
        press_enter
        return
    fi
    
    info "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    
    if command -v tailscale >/dev/null 2>&1; then
        ok "Tailscale installed successfully!"
        echo
        info "Now run 'tailscale up' to connect."
    else
        error "Installation failed!"
    fi
    press_enter
}

tailscale_up() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE} 🔗 CONNECT TO TAILSCALE ${NC}"
    echo
    
    if ! command -v tailscale >/dev/null 2>&1; then
        error "Tailscale not installed! Install it first."
        press_enter
        return
    fi
    
    info "Starting Tailscale..."
    echo
    warn "You will get a URL - open it in browser to authenticate."
    echo
    tailscale up
    
    sleep 2
    if tailscale status >/dev/null 2>&1; then
        ok "Connected!"
        echo -e "  ${WHITE}Tailscale IP:${NC} ${CYAN}$(tailscale ip -4 | head -1)${NC}"
    else
        warn "Not connected yet. Complete browser authentication."
    fi
    press_enter
}

tailscale_down() {
    show_logo
    echo -e "  ${BG_YELLOW}${WHITE} ⬇️  DISCONNECT TAILSCALE ${NC}"
    echo
    
    if ! command -v tailscale >/dev/null 2>&1; then
        error "Tailscale not installed!"
        press_enter
        return
    fi
    
    info "Disconnecting..."
    tailscale down
    ok "Disconnected!"
    press_enter
}

tailscale_status() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} ℹ️  TAILSCALE STATUS ${NC}"
    echo
    
    if ! command -v tailscale >/dev/null 2>&1; then
        error "Tailscale not installed!"
        press_enter
        return
    fi
    
    tailscale status 2>/dev/null || warn "Not connected"
    echo
    echo -e "  ${WHITE}Version:${NC}"
    tailscale version 2>/dev/null | head -3
    echo
    echo -e "  ${WHITE}IP Address:${NC} $(tailscale ip -4 2>/dev/null | head -1 || echo 'N/A')"
    press_enter
}

tailscale_uninstall() {
    show_logo
    echo -e "  ${BG_RED}${WHITE} 🗑️  UNINSTALL TAILSCALE ${NC}"
    echo
    
    if ! command -v tailscale >/dev/null 2>&1; then
        warn "Tailscale not installed!"
        press_enter
        return
    fi
    
    read -rp "  Are you sure? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled"
        press_enter
        return
    fi
    
    info "Uninstalling Tailscale..."
    tailscale down 2>/dev/null || true
    
    if command -v apt >/dev/null 2>&1; then
        apt remove --purge -y tailscale 2>&1 | tail -3
    elif command -v dnf >/dev/null 2>&1; then
        dnf remove -y tailscale 2>&1 | tail -3
    elif command -v yum >/dev/null 2>&1; then
        yum remove -y tailscale 2>&1 | tail -3
    fi
    
    ok "Tailscale uninstalled!"
    press_enter
}

# =========================================================
# OPTION 5: CONTACT & SUPPORT
# =========================================================

action_contact() {
    show_logo
    echo -e "  ${BG_MAGENTA}${WHITE} 💬 CONTACT & SUPPORT ${NC}"
    echo
    echo -e "  ${CYAN}╭──────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${WHITE}${BOLD}🌐 FakeCloud Community${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   Join our Discord community for:"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} 24/7 Support"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} Latest Panel Updates"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} License Purchase"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} Bug Reports"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} Feature Requests"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} Tutorial & Guides"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${WHITE}${BOLD}💬 Discord:${NC}"
    echo -e "  ${CYAN}│${NC}   ${BLUE}${BOLD}${DISCORD_LINK}${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${WHITE}${BOLD}🌐 Brand:${NC} ${CYAN}${BRAND_NAME}${NC}"
    echo -e "  ${CYAN}│${NC}   ${WHITE}${BOLD}📌 Manager:${NC} v${MANAGER_VERSION}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${WHITE}${BOLD}📦 Available Panels:${NC}"
    echo -e "  ${CYAN}│${NC}   • ${BLUE}NVM Panel v3${NC} - Fast Container Manager"
    echo -e "  ${CYAN}│${NC}   • ${MAGENTA}HVM Panel v8${NC} - Full VPS Management"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}╰──────────────────────────────────────────────────────────────────────╯${NC}"
    press_enter
}

# =========================================================
# MAIN LOOP
# =========================================================

main() {
    detect_environment
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
    fi
    
    if [[ "$EUID" -ne 0 ]]; then
        show_logo
        error "Please run as root!"
        echo -e "  Run: ${WHITE}sudo bash HvmV8.sh${NC}"
        exit 1
    fi
    
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1) menu_install ;;
            2) menu_manage ;;
            3) action_sysinfo ;;
            4) action_tailscale ;;
            5) action_contact ;;
            0) 
                show_logo
                echo -e "  ${GREEN}${BOLD}Thank you for using FakeCloud Panel Manager!${NC}"
                echo -e "  ${BLUE}${DISCORD_LINK}${NC}"
                echo
                exit 0
                ;;
            *)
                warn "Invalid option! Please choose 0-5"
                sleep 2
                ;;
        esac
    done
}

main "$@"
