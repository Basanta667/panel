#!/usr/bin/env bash

# =========================================================
# FAKECLOUD ULTIMATE MANAGER v3.0
# Powered by FakeCloud
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

# =========================================================
# VARIABLES
# =========================================================

FILE_ID="16ayBiW01p-W2NAXabjjO8hKv_SBtEgya"
HVM_URL="https://drive.usercontent.google.com/download?id=${FILE_ID}&export=download&confirm=t"

INSTALL_DIR="/opt/hvm"
SERVICE_NAME="hvm"
PANEL_PORT="5000"
BIN_FILE="${INSTALL_DIR}/hvmV8.bin"
LOG_FILE="/var/log/hvm.log"

MIN_FILE_SIZE_MB=20

DISCORD_LINK="https://dsc.gg/fakecloud"
PANEL_VERSION="8.0-ULTRA"
BRAND_NAME="FakeCloud"
INSTALLER_URL="https://raw.githubusercontent.com/Basanta667/panel/main/HvmV8.sh"

HAS_SYSTEMD=false
IS_CLOUD_SHELL=false

# =========================================================
# HELPER FUNCTIONS
# =========================================================

info() { echo -e "  ${CYAN}⚡ [INFO]${NC} $1"; }
ok() { echo -e "  ${GREEN}✅ [OK]${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠️  [WARNING]${NC} $1"; }
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
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then return 0; fi
    return 1
}

detect_environment() {
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        HAS_SYSTEMD=true
    fi
    if [[ -n "${CLOUD_SHELL:-}" ]] || [[ "$(hostname 2>/dev/null)" == *"cloudshell"* ]]; then
        IS_CLOUD_SHELL=true
    fi
}

get_public_ip() {
    local ip=""
    ip=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || true)
    [[ -z "$ip" ]] && ip=$(curl -4 -s --max-time 5 api.ipify.org 2>/dev/null || true)
    [[ -z "$ip" ]] && ip=$(curl -4 -s --max-time 5 icanhazip.com 2>/dev/null || true)
    [[ -z "$ip" ]] && ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "YOUR_IP")
    echo "$ip"
}

is_panel_installed() {
    [[ -f "${BIN_FILE}" ]]
}

is_panel_running() {
    if command -v lsof >/dev/null 2>&1 && lsof -Pi :${PANEL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    fi
    if command -v ss >/dev/null 2>&1 && ss -tulpn 2>/dev/null | grep -q ":${PANEL_PORT} "; then
        return 0
    fi
    if pgrep -f hvmV8.bin >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

get_panel_uptime() {
    local pid=$(pgrep -f hvmV8.bin | head -1)
    if [[ -n "$pid" ]]; then
        ps -o etime= -p "$pid" 2>/dev/null | xargs || echo "N/A"
    else
        echo "Not Running"
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
    ║              ULTIMATE MANAGER v3.0 — NEXT GEN                        ║
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
    
    # Status Bar
    local status_color="${RED}"
    local status_text="OFFLINE"
    local status_icon="●"
    
    if is_panel_installed; then
        if is_panel_running; then
            status_color="${GREEN}"
            status_text="ONLINE"
            status_icon="●"
        else
            status_color="${YELLOW}"
            status_text="INSTALLED (Stopped)"
            status_icon="○"
        fi
    else
        status_color="${DIM}"
        status_text="NOT INSTALLED"
        status_icon="○"
    fi
    
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
    local ram_used=$(free | awk '/^Mem:/{printf "%.0f", $3/$2*100}')
    local disk_used=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
    local uptime_short=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")
    
    echo -e " ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}${BOLD}📊 SYSTEM STATUS${NC}"
    echo -e "     CPU Usage: ${WHITE}${cpu:-0}%${NC}    RAM Usage: ${WHITE}${ram_used:-0}%${NC}    Disk: ${WHITE}${disk_used:-0}%${NC}    Uptime: ${WHITE}${uptime_short}${NC}"
    echo
    echo -e "  ${WHITE}${BOLD}🎛️  PANEL STATUS${NC}"
    echo -e "     Status: ${status_color}${status_icon} ${status_text}${NC}    Version: ${WHITE}${PANEL_VERSION}${NC}"
    if is_panel_running; then
        echo -e "     URL: ${CYAN}http://$(get_public_ip):${PANEL_PORT}${NC}    Uptime: ${WHITE}$(get_panel_uptime)${NC}"
    fi
    echo -e " ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo
    echo -e "  ${WHITE}${BOLD}📦 INSTALLATION & MANAGEMENT${NC}"
    echo -e "  ${CYAN}┌──────────────────────────────┬──────────────────────────────┐${NC}"
    echo -e "  ${CYAN}│${NC} ${GREEN}[1]${NC}  Install Panel          ${CYAN}│${NC} ${YELLOW}[5]${NC}  Restart Panel          ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC} ${BLUE}[2]${NC}  Reinstall Panel        ${CYAN}│${NC} ${MAGENTA}[6]${NC}  Update Panel           ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC} ${RED}[3]${NC}  Uninstall Panel        ${CYAN}│${NC} ${CYAN}[7]${NC}  View Logs              ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC} ${GREEN}[4]${NC}  Start / Stop Panel     ${CYAN}│${NC} ${WHITE}[8]${NC}  Panel Info             ${CYAN}│${NC}"
    echo -e "  ${CYAN}└──────────────────────────────┴──────────────────────────────┘${NC}"
    echo
    echo -e "  ${WHITE}${BOLD}🔧 SYSTEM & TOOLS${NC}"
    echo -e "  ${CYAN}┌──────────────────────────────┬──────────────────────────────┐${NC}"
    echo -e "  ${CYAN}│${NC} ${YELLOW}[9]${NC}  System Information     ${CYAN}│${NC} ${GREEN}[12]${NC} Change Port            ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC} ${BLUE}[10]${NC} Configure Firewall     ${CYAN}│${NC} ${MAGENTA}[13]${NC} Backup & Restore       ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC} ${CYAN}[11]${NC} Reset Admin Password   ${CYAN}│${NC} ${RED}[14]${NC} Fix Common Issues      ${CYAN}│${NC}"
    echo -e "  ${CYAN}└──────────────────────────────┴──────────────────────────────┘${NC}"
    echo
    echo -e "  ${WHITE}${BOLD}📚 EXTRAS & SUPPORT${NC}"
    echo -e "  ${CYAN}┌──────────────────────────────┬──────────────────────────────┐${NC}"
    echo -e "  ${CYAN}│${NC} ${BLUE}[15]${NC} Join Discord Support   ${CYAN}│${NC} ${GREEN}[17]${NC} Buy License            ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC} ${MAGENTA}[16]${NC} About FakeCloud        ${CYAN}│${NC} ${RED}[0]${NC}  Exit                   ${CYAN}│${NC}"
    echo -e "  ${CYAN}└──────────────────────────────┴──────────────────────────────┘${NC}"
    echo
    echo -e " ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}${BOLD}💬 Discord:${NC} ${BLUE}${DISCORD_LINK}${NC}    ${WHITE}${BOLD}🌐 Brand:${NC} ${CYAN}${BRAND_NAME}${NC}"
    echo -e " ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo
    echo -en "  ${GREEN}${BOLD}➜ Select Option [0-17]:${NC} "
}

# =========================================================
# OPTION 1: INSTALL PANEL
# =========================================================

action_install() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE} 📦 INSTALL PANEL ${NC}"
    echo
    
    if is_panel_installed; then
        warn "Panel is already installed!"
        echo -e "  ${DIM}Use option [2] to reinstall.${NC}"
        press_enter
        return
    fi
    
    line
    info "Starting installation..."
    line
    
    # Pre-checks
    if [[ "$EUID" -ne 0 ]]; then
        error "Must run as root!"
        press_enter
        return
    fi
    
    # Internet check
    info "Checking internet..."
    if check_internet; then
        ok "Internet OK"
    else
        warn "Internet check failed, but continuing..."
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
    
    # Port check
    if is_panel_running; then
        warn "Port ${PANEL_PORT} is in use, killing..."
        pkill -f hvmV8.bin 2>/dev/null || true
        sleep 2
    fi
    
    # Create dir
    mkdir -p "${INSTALL_DIR}/backups" "${INSTALL_DIR}/logs"
    cd "${INSTALL_DIR}"
    ok "Directory created"
    
    # Download
    info "Downloading hvmV8.bin (may take 5-10 min)..."
    echo
    
    local COOKIES_FILE="/tmp/gdrive_cookies_$$.txt"
    local PAGE_FILE="/tmp/gdrive_page_$$.html"
    
    wget --quiet --save-cookies "${COOKIES_FILE}" --keep-session-cookies \
        --no-check-certificate \
        "https://docs.google.com/uc?export=download&id=${FILE_ID}" \
        -O "${PAGE_FILE}" 2>/dev/null || true
    
    local CONFIRM=$(grep -oP 'confirm=[0-9A-Za-z_-]+' "${PAGE_FILE}" 2>/dev/null | head -1 | cut -d'=' -f2 || echo "")
    
    if [[ -n "${CONFIRM}" ]]; then
        wget --load-cookies "${COOKIES_FILE}" --no-check-certificate --progress=bar:force:noscroll \
            "https://docs.google.com/uc?export=download&confirm=${CONFIRM}&id=${FILE_ID}" \
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
    if [[ "${size}" -lt "${MIN_FILE_SIZE_MB}" ]]; then
        error "File corrupted (${size}MB)"
        rm -f hvmV8.bin
        press_enter
        return
    fi
    
    chmod +x hvmV8.bin
    ok "Downloaded (${size}MB)"
    
    # Firewall
    info "Configuring firewall..."
    command -v ufw >/dev/null 2>&1 && ufw allow ${PANEL_PORT}/tcp >/dev/null 2>&1 || true
    command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --permanent --add-port=${PANEL_PORT}/tcp >/dev/null 2>&1 && firewall-cmd --reload >/dev/null 2>&1 || true
    command -v iptables >/dev/null 2>&1 && iptables -I INPUT -p tcp --dport ${PANEL_PORT} -j ACCEPT 2>/dev/null || true
    ok "Firewall configured"
    
    # Create service or start manually
    if [[ "${HAS_SYSTEMD}" == true ]]; then
        info "Creating systemd service..."
        cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=HVM Panel V8 - Powered by ${BRAND_NAME}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${BIN_FILE}
Restart=always
RestartSec=5
LimitNOFILE=1048576
User=root
StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable ${SERVICE_NAME} >/dev/null 2>&1
        systemctl restart ${SERVICE_NAME}
        ok "Service created and started"
    else
        info "Starting manually..."
        nohup ${BIN_FILE} >> ${LOG_FILE} 2>&1 &
        sleep 3
        ok "Panel started"
    fi
    
    sleep 5
    
    line
    echo
    echo -e "  ${BG_GREEN}${WHITE} ✅ INSTALLATION COMPLETE! ${NC}"
    echo
    echo -e "  🌐 Panel URL: ${CYAN}${BOLD}http://$(get_public_ip):${PANEL_PORT}${NC}"
    echo -e "  👤 Username : ${GREEN}admin${NC}"
    echo -e "  🔑 Password : ${GREEN}admin${NC}"
    echo
    echo -e "  💬 Discord: ${BLUE}${DISCORD_LINK}${NC}"
    line
    press_enter
}

# =========================================================
# OPTION 2: REINSTALL
# =========================================================

action_reinstall() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 🔄 REINSTALL PANEL ${NC}"
    echo
    warn "This will UNINSTALL and INSTALL fresh copy!"
    echo
    read -rp "  Are you sure? (y/n): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled"
        press_enter
        return
    fi
    
    info "Uninstalling..."
    pkill -f hvmV8.bin 2>/dev/null || true
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl disable ${SERVICE_NAME} 2>/dev/null || true
    rm -f /etc/systemd/system/${SERVICE_NAME}.service
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl daemon-reload 2>/dev/null || true
    rm -rf "${INSTALL_DIR}"
    rm -f "${LOG_FILE}"
    ok "Old installation removed"
    
    action_install
}

# =========================================================
# OPTION 3: UNINSTALL
# =========================================================

action_uninstall() {
    show_logo
    echo -e "  ${BG_RED}${WHITE} 🗑️  UNINSTALL PANEL ${NC}"
    echo
    
    if ! is_panel_installed; then
        warn "Panel is not installed!"
        press_enter
        return
    fi
    
    warn "This will PERMANENTLY DELETE:"
    echo -e "    ${DIM}• Panel binary${NC}"
    echo -e "    ${DIM}• Configuration files${NC}"
    echo -e "    ${DIM}• Log files${NC}"
    echo -e "    ${DIM}• Database (VPS/User data)${NC}"
    echo
    read -rp "  Type 'YES' to confirm: " confirm
    
    if [[ "$confirm" != "YES" ]]; then
        info "Cancelled"
        press_enter
        return
    fi
    
    info "Uninstalling..."
    pkill -f hvmV8.bin 2>/dev/null || true
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl disable ${SERVICE_NAME} 2>/dev/null || true
    rm -f /etc/systemd/system/${SERVICE_NAME}.service
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl daemon-reload 2>/dev/null || true
    rm -rf "${INSTALL_DIR}"
    rm -f "${LOG_FILE}"
    ok "Panel uninstalled successfully!"
    press_enter
}

# =========================================================
# OPTION 4: START/STOP
# =========================================================

action_toggle() {
    show_logo
    echo -e "  ${BG_YELLOW}${WHITE} ⚡ START / STOP PANEL ${NC}"
    echo
    
    if ! is_panel_installed; then
        error "Panel not installed!"
        press_enter
        return
    fi
    
    if is_panel_running; then
        info "Panel is currently RUNNING. Stopping..."
        [[ "${HAS_SYSTEMD}" == true ]] && systemctl stop ${SERVICE_NAME} 2>/dev/null || true
        pkill -f hvmV8.bin 2>/dev/null || true
        sleep 2
        ok "Panel stopped!"
    else
        info "Panel is currently STOPPED. Starting..."
        if [[ "${HAS_SYSTEMD}" == true ]]; then
            systemctl start ${SERVICE_NAME}
        else
            cd "${INSTALL_DIR}"
            nohup ${BIN_FILE} >> ${LOG_FILE} 2>&1 &
        fi
        sleep 5
        if is_panel_running; then
            ok "Panel started!"
            echo -e "  🌐 URL: ${CYAN}http://$(get_public_ip):${PANEL_PORT}${NC}"
        else
            error "Failed to start!"
        fi
    fi
    press_enter
}

# =========================================================
# OPTION 5: RESTART
# =========================================================

action_restart() {
    show_logo
    echo -e "  ${BG_YELLOW}${WHITE} 🔄 RESTART PANEL ${NC}"
    echo
    
    if ! is_panel_installed; then
        error "Panel not installed!"
        press_enter
        return
    fi
    
    info "Restarting panel..."
    if [[ "${HAS_SYSTEMD}" == true ]]; then
        systemctl restart ${SERVICE_NAME}
    else
        pkill -f hvmV8.bin 2>/dev/null || true
        sleep 2
        cd "${INSTALL_DIR}"
        nohup ${BIN_FILE} >> ${LOG_FILE} 2>&1 &
    fi
    sleep 5
    
    if is_panel_running; then
        ok "Panel restarted successfully!"
        echo -e "  🌐 URL: ${CYAN}http://$(get_public_ip):${PANEL_PORT}${NC}"
    else
        error "Restart failed!"
    fi
    press_enter
}

# =========================================================
# OPTION 6: UPDATE
# =========================================================

action_update() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} ⬆️  UPDATE PANEL ${NC}"
    echo
    
    warn "This will download latest binary and replace current one."
    echo -e "  ${DIM}Your data (VPS, users) will NOT be deleted.${NC}"
    echo
    read -rp "  Continue? (y/n): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled"
        press_enter
        return
    fi
    
    info "Stopping panel..."
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    pkill -f hvmV8.bin 2>/dev/null || true
    sleep 2
    
    info "Backing up old binary..."
    [[ -f "${BIN_FILE}" ]] && cp "${BIN_FILE}" "${BIN_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
    ok "Backup created"
    
    info "Downloading latest version..."
    cd "${INSTALL_DIR}"
    rm -f hvmV8.bin
    
    wget --no-check-certificate --progress=bar:force:noscroll "${HVM_URL}" -O hvmV8.bin 2>&1 | tail -3 || true
    
    if [[ -f hvmV8.bin ]] && [[ -s hvmV8.bin ]]; then
        chmod +x hvmV8.bin
        ok "Updated to latest version!"
        
        info "Starting panel..."
        if [[ "${HAS_SYSTEMD}" == true ]]; then
            systemctl start ${SERVICE_NAME}
        else
            nohup ${BIN_FILE} >> ${LOG_FILE} 2>&1 &
        fi
        sleep 5
        ok "Panel started!"
    else
        error "Update failed! Restoring backup..."
        local latest_bak=$(ls -t "${BIN_FILE}".bak.* 2>/dev/null | head -1)
        [[ -n "$latest_bak" ]] && cp "$latest_bak" "${BIN_FILE}"
    fi
    press_enter
}

# =========================================================
# OPTION 7: VIEW LOGS
# =========================================================

action_logs() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 📋 VIEW LOGS ${NC}"
    echo
    echo -e "  ${WHITE}[1]${NC} Last 50 lines"
    echo -e "  ${WHITE}[2]${NC} Last 200 lines"
    echo -e "  ${WHITE}[3]${NC} Live tail (Ctrl+C to exit)"
    echo -e "  ${WHITE}[4]${NC} Systemd logs (journalctl)"
    echo -e "  ${WHITE}[0]${NC} Back to menu"
    echo
    echo -en "  ${GREEN}Choice:${NC} "
    read -r choice
    
    case $choice in
        1) 
            clear
            echo -e "${CYAN}══════ Last 50 lines ══════${NC}"
            [[ -f "${LOG_FILE}" ]] && tail -50 "${LOG_FILE}" || warn "No log file found"
            ;;
        2)
            clear
            echo -e "${CYAN}══════ Last 200 lines ══════${NC}"
            [[ -f "${LOG_FILE}" ]] && tail -200 "${LOG_FILE}" || warn "No log file found"
            ;;
        3)
            clear
            echo -e "${CYAN}══════ Live Logs (Ctrl+C to exit) ══════${NC}"
            [[ -f "${LOG_FILE}" ]] && tail -f "${LOG_FILE}" || warn "No log file found"
            ;;
        4)
            clear
            echo -e "${CYAN}══════ Systemd Logs ══════${NC}"
            [[ "${HAS_SYSTEMD}" == true ]] && journalctl -u ${SERVICE_NAME} -n 100 --no-pager || warn "Systemd not available"
            ;;
        0) return ;;
        *) warn "Invalid choice" ;;
    esac
    press_enter
}

# =========================================================
# OPTION 8: PANEL INFO
# =========================================================

action_info() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} ℹ️  PANEL INFORMATION ${NC}"
    echo
    
    if ! is_panel_installed; then
        error "Panel not installed!"
        press_enter
        return
    fi
    
    local status_color="${RED}"
    local status_text="OFFLINE"
    is_panel_running && status_color="${GREEN}" && status_text="ONLINE"
    
    local file_size="N/A"
    [[ -f "${BIN_FILE}" ]] && file_size=$(du -h "${BIN_FILE}" | cut -f1)
    
    local install_date="N/A"
    [[ -f "${BIN_FILE}" ]] && install_date=$(stat -c %y "${BIN_FILE}" 2>/dev/null | cut -d. -f1)
    
    echo -e "  ${CYAN}╭─────────────── Panel Details ───────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Status${NC}       : ${status_color}${status_text}${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Version${NC}      : ${GREEN}${PANEL_VERSION}${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}URL${NC}          : ${CYAN}http://$(get_public_ip):${PANEL_PORT}${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Username${NC}     : admin"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Password${NC}     : admin"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Install Dir${NC}  : ${INSTALL_DIR}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Binary Size${NC}  : ${file_size}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Installed${NC}    : ${install_date}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Log File${NC}     : ${LOG_FILE}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Uptime${NC}       : $(get_panel_uptime)"
    echo -e "  ${CYAN}╰─────────────────────────────────────────────╯${NC}"
    press_enter
}

# =========================================================
# OPTION 9: SYSTEM INFO
# =========================================================

action_sysinfo() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 💻 SYSTEM INFORMATION ${NC}"
    echo
    
    local cpu_model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown")
    local cpu_cores=$(nproc 2>/dev/null || echo "?")
    local total_ram=$(free -h | awk '/^Mem:/{print $2}')
    local used_ram=$(free -h | awk '/^Mem:/{print $3}')
    local free_ram=$(free -h | awk '/^Mem:/{print $7}')
    local disk_info=$(df -h / | awk 'NR==2{print $3" / "$2" ("$5")"}')
    local kernel=$(uname -r)
    local uptime=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")
    local pub_ip=$(get_public_ip)
    local priv_ip=$(hostname -I | awk '{print $1}')
    
    echo -e "  ${CYAN}╭─────────────── System Info ───────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}OS${NC}           : ${PRETTY_NAME:-Unknown}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Kernel${NC}       : ${kernel}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Architecture${NC} : $(uname -m)"
    echo -e "  ${CYAN}│${NC}  ${WHITE}CPU${NC}          : ${cpu_model}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}CPU Cores${NC}    : ${cpu_cores}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}RAM Total${NC}    : ${total_ram}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}RAM Used${NC}     : ${used_ram}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}RAM Free${NC}     : ${free_ram}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Disk${NC}         : ${disk_info}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Public IP${NC}    : ${pub_ip}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Private IP${NC}   : ${priv_ip}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Uptime${NC}       : ${uptime}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}Systemd${NC}      : $([[ "${HAS_SYSTEMD}" == true ]] && echo "Available" || echo "Not Available")"
    echo -e "  ${CYAN}╰────────────────────────────────────────────╯${NC}"
    press_enter
}

# =========================================================
# OPTION 10: FIREWALL
# =========================================================

action_firewall() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 🔥 FIREWALL CONFIGURATION ${NC}"
    echo
    info "Configuring firewall for port ${PANEL_PORT}..."
    
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${PANEL_PORT}/tcp >/dev/null 2>&1 && ok "UFW: Port ${PANEL_PORT} opened"
        ufw allow 22/tcp >/dev/null 2>&1 && ok "UFW: SSH (22) allowed"
    fi
    
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=${PANEL_PORT}/tcp >/dev/null 2>&1 && ok "Firewalld: Port opened"
        firewall-cmd --reload >/dev/null 2>&1
    fi
    
    if command -v iptables >/dev/null 2>&1; then
        iptables -I INPUT -p tcp --dport ${PANEL_PORT} -j ACCEPT 2>/dev/null && ok "Iptables: Port allowed"
    fi
    
    press_enter
}

# =========================================================
# OPTION 11: RESET PASSWORD
# =========================================================

action_reset_password() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 🔑 RESET ADMIN PASSWORD ${NC}"
    echo
    warn "Default credentials will be restored:"
    echo -e "  ${DIM}Username: admin${NC}"
    echo -e "  ${DIM}Password: admin${NC}"
    echo
    warn "Note: For advanced password reset, contact support on Discord"
    echo -e "  ${BLUE}${DISCORD_LINK}${NC}"
    press_enter
}

# =========================================================
# OPTION 12: CHANGE PORT
# =========================================================

action_change_port() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 🌐 CHANGE PANEL PORT ${NC}"
    echo
    echo -e "  Current port: ${CYAN}${PANEL_PORT}${NC}"
    echo
    read -rp "  Enter new port (1024-65535): " new_port
    
    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [[ "$new_port" -lt 1024 ]] || [[ "$new_port" -gt 65535 ]]; then
        error "Invalid port!"
        press_enter
        return
    fi
    
    warn "Port change requires panel restart and config update."
    info "Feature coming in next update. Contact Discord for help."
    echo -e "  ${BLUE}${DISCORD_LINK}${NC}"
    press_enter
}

# =========================================================
# OPTION 13: BACKUP & RESTORE
# =========================================================

action_backup() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 💾 BACKUP & RESTORE ${NC}"
    echo
    echo -e "  ${WHITE}[1]${NC} Create Backup"
    echo -e "  ${WHITE}[2]${NC} List Backups"
    echo -e "  ${WHITE}[3]${NC} Restore Backup"
    echo -e "  ${WHITE}[0]${NC} Back"
    echo
    echo -en "  ${GREEN}Choice:${NC} "
    read -r choice
    
    case $choice in
        1)
            local backup_name="hvm_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
            info "Creating backup: ${backup_name}"
            tar -czf "/tmp/${backup_name}" -C /opt hvm 2>/dev/null && ok "Backup created: /tmp/${backup_name}"
            ;;
        2)
            echo -e "  ${CYAN}Available Backups:${NC}"
            ls -lh /tmp/hvm_backup_*.tar.gz 2>/dev/null || warn "No backups found"
            ;;
        3)
            echo -e "  ${CYAN}Available Backups:${NC}"
            ls /tmp/hvm_backup_*.tar.gz 2>/dev/null
            echo
            read -rp "  Enter backup filename: " backup_file
            if [[ -f "/tmp/${backup_file}" ]]; then
                pkill -f hvmV8.bin 2>/dev/null || true
                rm -rf /opt/hvm
                tar -xzf "/tmp/${backup_file}" -C /opt && ok "Restored!"
            else
                error "Backup not found!"
            fi
            ;;
    esac
    press_enter
}

# =========================================================
# OPTION 14: FIX ISSUES
# =========================================================

action_fix() {
    show_logo
    echo -e "  ${BG_RED}${WHITE} 🔧 FIX COMMON ISSUES ${NC}"
    echo
    info "Running diagnostic checks..."
    echo
    
    # Check 1: Binary exists
    if [[ -f "${BIN_FILE}" ]]; then
        ok "Binary file exists"
    else
        error "Binary missing! Reinstall required."
    fi
    
    # Check 2: Executable
    if [[ -x "${BIN_FILE}" ]]; then
        ok "Binary is executable"
    else
        warn "Fixing permissions..."
        chmod +x "${BIN_FILE}" 2>/dev/null && ok "Permissions fixed"
    fi
    
    # Check 3: Port
    if is_panel_running; then
        ok "Panel running on port ${PANEL_PORT}"
    else
        warn "Panel not running. Trying to start..."
        cd "${INSTALL_DIR}" 2>/dev/null && nohup ${BIN_FILE} >> ${LOG_FILE} 2>&1 &
        sleep 3
        is_panel_running && ok "Panel started" || error "Failed to start"
    fi
    
    # Check 4: Firewall
    action_firewall_silent
    
    # Check 5: Log file
    if [[ -f "${LOG_FILE}" ]]; then
        ok "Log file exists"
    else
        touch "${LOG_FILE}" && ok "Log file created"
    fi
    
    ok "Diagnostic complete!"
    press_enter
}

action_firewall_silent() {
    command -v ufw >/dev/null 2>&1 && ufw allow ${PANEL_PORT}/tcp >/dev/null 2>&1 || true
    command -v iptables >/dev/null 2>&1 && iptables -I INPUT -p tcp --dport ${PANEL_PORT} -j ACCEPT 2>/dev/null || true
    ok "Firewall verified"
}

# =========================================================
# OPTION 15: DISCORD
# =========================================================

action_discord() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 💬 JOIN DISCORD SUPPORT ${NC}"
    echo
    echo -e "  ${CYAN}╭──────────────────────────────────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   Join our Discord community for:"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} 24/7 Support"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} Latest Updates"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} Buy License"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} Feature Requests"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} Bug Reports"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   🔗 ${BLUE}${BOLD}${DISCORD_LINK}${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}╰──────────────────────────────────────────╯${NC}"
    press_enter
}

# =========================================================
# OPTION 16: ABOUT
# =========================================================

action_about() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} ℹ️  ABOUT FAKECLOUD ${NC}"
    echo
    echo -e "  ${CYAN}╭──────────────────────────────────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${WHITE}${BOLD}FakeCloud HVM Panel${NC}"
    echo -e "  ${CYAN}│${NC}   Version: ${GREEN}${PANEL_VERSION}${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   A powerful VPS management panel"
    echo -e "  ${CYAN}│${NC}   for creating and managing LXC"
    echo -e "  ${CYAN}│${NC}   containers with ease."
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${YELLOW}Features:${NC}"
    echo -e "  ${CYAN}│${NC}   • Multi-node support"
    echo -e "  ${CYAN}│${NC}   • Web-based SSH console"
    echo -e "  ${CYAN}│${NC}   • Real-time stats"
    echo -e "  ${CYAN}│${NC}   • User management"
    echo -e "  ${CYAN}│${NC}   • Backup system"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   💬 ${BLUE}${DISCORD_LINK}${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}╰──────────────────────────────────────────╯${NC}"
    press_enter
}

# =========================================================
# OPTION 17: BUY LICENSE
# =========================================================

action_buy_license() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE} 💰 BUY LICENSE ${NC}"
    echo
    echo -e "  ${CYAN}╭──────────────────────────────────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${WHITE}${BOLD}Get Full Access!${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${GREEN}💎 What You Get:${NC}"
    echo -e "  ${CYAN}│${NC}   • Full Panel Access"
    echo -e "  ${CYAN}│${NC}   • Unlimited VPS Creation"
    echo -e "  ${CYAN}│${NC}   • Free Updates for 1 Year"
    echo -e "  ${CYAN}│${NC}   • Priority Support"
    echo -e "  ${CYAN}│${NC}   • Multi-Node Support"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${YELLOW}🎯 How to Buy:${NC}"
    echo -e "  ${CYAN}│${NC}   1. Join Discord"
    echo -e "  ${CYAN}│${NC}   2. Open ticket"
    echo -e "  ${CYAN}│${NC}   3. Complete payment"
    echo -e "  ${CYAN}│${NC}   4. Get license key"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   💬 ${BLUE}${BOLD}${DISCORD_LINK}${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}╰──────────────────────────────────────────╯${NC}"
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
            1) action_install ;;
            2) action_reinstall ;;
            3) action_uninstall ;;
            4) action_toggle ;;
            5) action_restart ;;
            6) action_update ;;
            7) action_logs ;;
            8) action_info ;;
            9) action_sysinfo ;;
            10) action_firewall; press_enter ;;
            11) action_reset_password ;;
            12) action_change_port ;;
            13) action_backup ;;
            14) action_fix ;;
            15) action_discord ;;
            16) action_about ;;
            17) action_buy_license ;;
            0) 
                show_logo
                echo -e "  ${GREEN}${BOLD}Thank you for using FakeCloud Manager!${NC}"
                echo -e "  ${BLUE}${DISCORD_LINK}${NC}"
                echo
                exit 0
                ;;
            *)
                warn "Invalid option! Please choose 0-17"
                sleep 2
                ;;
        esac
    done
}

main "$@"
