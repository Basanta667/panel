#!/usr/bin/env bash

# =========================================================
# FAKECLOUD ULTIMATE INSTALLER v5.0
# All-in-One: VPS Setup + Panel Manager
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
MANAGER_VERSION="5.0"
INSTALLER_URL="https://raw.githubusercontent.com/Basanta667/panel/main/installer.sh"

# Current panel
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

step() {
    echo
    echo -e "  ${BG_BLUE}${WHITE} STEP $1 ${NC} ${BOLD}$2${NC}"
    echo
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
    [[ -f "$1" ]]
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
    ║           ULTIMATE INSTALLER v5.0 — ALL IN ONE                       ║
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
            nvm_status="${YELLOW}○ Stopped${NC}"
        fi
    fi
    
    if is_panel_installed "$HVM_BIN"; then
        if is_panel_running "$HVM_PORT" "hvmV8.bin"; then
            hvm_status="${GREEN}● Online${NC}"
        else
            hvm_status="${YELLOW}○ Stopped${NC}"
        fi
    fi
    
    # Tailscale
    local ts_status="${RED}○ Not Installed${NC}"
    if command -v tailscale >/dev/null 2>&1; then
        if tailscale status >/dev/null 2>&1; then
            ts_status="${GREEN}● Connected${NC}"
        else
            ts_status="${YELLOW}○ Not Connected${NC}"
        fi
    fi
    
    # LXD/LXC status
    local lxc_status="${RED}○ Not Installed${NC}"
    if command -v lxc >/dev/null 2>&1 || command -v lxd >/dev/null 2>&1 || command -v incus >/dev/null 2>&1; then
        lxc_status="${GREEN}● Installed${NC}"
    fi
    
    echo -e " ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}${BOLD}📊 SYSTEM STATUS${NC}"
    echo -e "     CPU: ${WHITE}${cpu}%${NC}    RAM: ${WHITE}${ram_used}%${NC}    Uptime: ${WHITE}${uptime_short}${NC}    IP: ${WHITE}${pub_ip}${NC}"
    echo
    echo -e "  ${WHITE}${BOLD}🎛️  STATUS${NC}"
    echo -e "     🔵 NVM Panel: ${nvm_status}"
    echo -e "     🟣 HVM Panel: ${hvm_status}"
    echo -e "     📦 LXC/LXD  : ${lxc_status}"
    echo -e "     🔗 Tailscale: ${ts_status}"
    echo -e " ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo
    echo -e "  ${WHITE}${BOLD}📋 MAIN MENU${NC}"
    echo -e "  ${CYAN}┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "  ${CYAN}│${NC}  ${GREEN}[1]${NC} ${WHITE}${BOLD}Panel Installation${NC}       ${DIM}(Install NVM or HVM)${NC}"
    echo -e "  ${CYAN}│${NC}  ${YELLOW}[2]${NC} ${WHITE}${BOLD}Panel Management${NC}         ${DIM}(Start/Stop/Restart/Reinstall)${NC}"
    echo -e "  ${CYAN}│${NC}  ${BLUE}[3]${NC} ${WHITE}${BOLD}System Information${NC}       ${DIM}(CPU, RAM, Disk, Network)${NC}"
    echo -e "  ${CYAN}│${NC}  ${MAGENTA}[4]${NC} ${WHITE}${BOLD}Tailscale${NC}                ${DIM}(Install + Connect)${NC}"
    echo -e "  ${CYAN}│${NC}  ${CYAN}[5]${NC} ${WHITE}${BOLD}Contact & Support${NC}        ${DIM}(Discord, About)${NC}"
    echo -e "  ${CYAN}│${NC}  ${RED}[0]${NC} ${WHITE}${BOLD}Exit${NC}"
    echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────┘${NC}"
    echo
    echo -e " ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}💬 Discord:${NC} ${BLUE}${DISCORD_LINK}${NC}    ${WHITE}🌐 Brand:${NC} ${CYAN}${BRAND_NAME}${NC}    ${WHITE}v${MANAGER_VERSION}${NC}"
    echo -e " ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo
    echo -en "  ${GREEN}${BOLD}➜ Select Option [0-5]:${NC} "
}

# =========================================================
# OPTION 1: PANEL INSTALLATION
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
        echo -e "  ${CYAN}│${NC}  ${GREEN}[3]${NC} ${WHITE}${BOLD}Setup VPS Environment${NC}   ${DIM}(LXC/LXD + Dependencies)${NC}"
        echo -e "  ${CYAN}│${NC}  ${RED}[0]${NC} ${WHITE}${BOLD}Back${NC}"
        echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────┘${NC}"
        echo
        echo -en "  ${GREEN}${BOLD}➜ Select [0-3]:${NC} "
        read -r choice
        
        case $choice in
            1) set_panel "NVM"; install_panel ;;
            2) set_panel "HVM"; install_panel ;;
            3) install_vps_environment ;;
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
        press_enter
        return
    fi
    
    line
    
    if [[ "$EUID" -ne 0 ]]; then
        error "Must run as root!"
        press_enter
        return
    fi
    ok "Running as root"
    
    info "Checking internet..."
    check_internet && ok "Internet OK" || warn "Internet check failed, continuing..."
    
    info "Installing dependencies..."
    if command -v apt >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt update -y -qq >/dev/null 2>&1 || true
        apt install -y -qq curl wget lsof tar unzip sudo nano python3 python3-pip ca-certificates net-tools >/dev/null 2>&1 || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y -q curl wget lsof tar unzip sudo nano python3 python3-pip ca-certificates net-tools >/dev/null 2>&1 || true
    fi
    ok "Dependencies installed"
    
    if is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
        warn "Port ${CURRENT_PORT} busy, killing..."
        pkill -f "$(basename $CURRENT_BIN)" 2>/dev/null || true
        sleep 2
    fi
    
    mkdir -p "${CURRENT_INSTALL_DIR}"
    cd "${CURRENT_INSTALL_DIR}"
    ok "Directory: ${CURRENT_INSTALL_DIR}"
    
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
    
    info "Configuring firewall..."
    command -v ufw >/dev/null 2>&1 && ufw allow ${CURRENT_PORT}/tcp >/dev/null 2>&1 || true
    command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --permanent --add-port=${CURRENT_PORT}/tcp >/dev/null 2>&1 && firewall-cmd --reload >/dev/null 2>&1 || true
    command -v iptables >/dev/null 2>&1 && iptables -I INPUT -p tcp --dport ${CURRENT_PORT} -j ACCEPT 2>/dev/null || true
    ok "Firewall configured"
    
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
# INSTALL VPS ENVIRONMENT (LXC/LXD)
# =========================================================

install_vps_environment() {
    show_logo
    echo -e "  ${BG_GREEN}${WHITE} 🖥️  VPS ENVIRONMENT SETUP ${NC}"
    echo
    
    if [[ "$EUID" -ne 0 ]]; then
        error "Must run as root!"
        press_enter
        return
    fi
    
    echo -e "  ${WHITE}${BOLD}This will install:${NC}"
    echo -e "  ${GREEN}✅${NC} Python 3 & SQLite3"
    echo -e "  ${GREEN}✅${NC} OpenSSH Server"
    echo -e "  ${GREEN}✅${NC} Git, Curl, Wget, Zip, Unzip"
    echo -e "  ${GREEN}✅${NC} LXC & LXD (or Incus)"
    echo -e "  ${GREEN}✅${NC} Network Tools (iproute2, bridge-utils, iptables)"
    echo -e "  ${GREEN}✅${NC} dnsmasq-base, UIDMap"
    echo -e "  ${GREEN}✅${NC} QEMU Utils + KVM"
    echo
    warn "This may take 10-15 minutes."
    echo
    read -rp "  Continue? (y/n): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled"
        press_enter
        return
    fi
    
    line
    
    # Update system
    step "1/8" "Updating System"
    if command -v apt >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt update -y 2>&1 | tail -3
    fi
    ok "System updated"
    
    # Basic tools
    step "2/8" "Installing Basic Tools"
    if command -v apt >/dev/null 2>&1; then
        apt install -y curl wget git zip unzip nano htop net-tools ca-certificates gnupg software-properties-common 2>&1 | tail -3
    fi
    ok "Basic tools installed"
    
    # Python
    step "3/8" "Installing Python 3 & SQLite3"
    if command -v apt >/dev/null 2>&1; then
        apt install -y python3 python3-pip python3-venv python3-dev sqlite3 libsqlite3-dev 2>&1 | tail -3
    fi
    ok "Python: $(python3 --version 2>/dev/null || echo 'installed')"
    ok "SQLite: $(sqlite3 --version 2>/dev/null | cut -d' ' -f1 || echo 'installed')"
    
    # SSH
    step "4/8" "Installing OpenSSH Server"
    if command -v apt >/dev/null 2>&1; then
        apt install -y openssh-server 2>&1 | tail -3
    fi
    systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
    systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null || true
    ok "SSH Server installed and running"
    
    # Network tools
    step "5/8" "Installing Network Tools"
    if command -v apt >/dev/null 2>&1; then
        apt install -y iproute2 bridge-utils iptables iptables-persistent dnsmasq-base uidmap 2>&1 | tail -3
    fi
    ok "Network tools installed"
    
    # QEMU
    step "6/8" "Installing QEMU Utils"
    if command -v apt >/dev/null 2>&1; then
        apt install -y qemu-utils qemu-system qemu-kvm libvirt-daemon-system libvirt-clients virtinst 2>&1 | tail -3
    fi
    ok "QEMU installed"
    [[ -e /dev/kvm ]] && ok "KVM support: Enabled" || warn "KVM not available"
    
    # LXC/LXD
    step "7/8" "Installing LXC & LXD"
    if command -v apt >/dev/null 2>&1; then
        apt install -y lxc lxc-utils lxcfs 2>&1 | tail -3
        ok "LXC installed"
        
        if ! command -v snap >/dev/null 2>&1; then
            info "Installing snapd..."
            apt install -y snapd 2>&1 | tail -3
            sleep 3
        fi
        
        if command -v snap >/dev/null 2>&1; then
            info "Installing LXD via snap..."
            snap install lxd 2>&1 | tail -3
            sleep 5
            
            if id "$SUDO_USER" &>/dev/null; then
                usermod -aG lxd "$SUDO_USER" 2>/dev/null || true
                ok "User added to lxd group"
            fi
            ok "LXD installed"
        fi
    fi
    
    # Final setup
    step "8/8" "Final Setup"
    info "Enabling IP forwarding..."
    echo "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf >/dev/null 2>&1
    echo "net.ipv6.conf.all.forwarding=1" | tee -a /etc/sysctl.conf >/dev/null 2>&1
    sysctl -p >/dev/null 2>&1
    ok "IP forwarding enabled"
    
    modprobe br_netfilter 2>/dev/null || true
    modprobe overlay 2>/dev/null || true
    ok "Kernel modules loaded"
    
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable lxc 2>/dev/null || true
        systemctl start lxc 2>/dev/null || true
    fi
    ok "Services enabled"
    
    line
    echo
    echo -e "  ${BG_GREEN}${WHITE} ✅ VPS ENVIRONMENT SETUP COMPLETE! ${NC}"
    echo
    echo -e "  ${WHITE}${BOLD}Next Steps:${NC}"
    echo -e "  ${GREEN}1.${NC} Reboot system: ${CYAN}sudo reboot${NC}"
    echo -e "  ${GREEN}2.${NC} Initialize LXD: ${CYAN}sudo lxd init${NC}"
    echo -e "  ${GREEN}3.${NC} Install Panel (NVM/HVM from menu)"
    echo -e "  ${GREEN}4.${NC} Access panel: ${CYAN}http://$(get_public_ip):5000${NC}"
    echo
    line
    press_enter
}

# =========================================================
# OPTION 2: PANEL MANAGEMENT
# =========================================================

menu_manage() {
    while true; do
        show_logo
        echo -e "  ${BG_YELLOW}${WHITE} ⚙️  PANEL MANAGEMENT ${NC}"
        echo
        
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
        echo -e "  ${CYAN}│${NC}  ${BLUE}[1]${NC} ${WHITE}${BOLD}Manage NVM Panel${NC}     Status: ${nvm_status}"
        echo -e "  ${CYAN}│${NC}  ${MAGENTA}[2]${NC} ${WHITE}${BOLD}Manage HVM Panel${NC}     Status: ${hvm_status}"
        echo -e "  ${CYAN}│${NC}  ${RED}[0]${NC} ${WHITE}${BOLD}Back${NC}"
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
        error "${CURRENT_PANEL} not installed!"
        press_enter
        return
    fi
    
    if is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
        warn "Already running!"
        press_enter
        return
    fi
    
    info "Starting ${CURRENT_PANEL}..."
    if [[ "${HAS_SYSTEMD}" == true ]] && [[ -f "/etc/systemd/system/${CURRENT_SERVICE}.service" ]]; then
        systemctl start ${CURRENT_SERVICE}
    else
        cd "${CURRENT_INSTALL_DIR}"
        nohup ${CURRENT_BIN} >> ${CURRENT_LOG} 2>&1 &
    fi
    
    sleep 5
    
    if is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
        ok "Started!"
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
        warn "Not running!"
        press_enter
        return
    fi
    
    info "Stopping..."
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl stop ${CURRENT_SERVICE} 2>/dev/null || true
    pkill -f "$(basename $CURRENT_BIN)" 2>/dev/null || true
    sleep 2
    
    if ! is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
        ok "Stopped!"
    else
        error "Failed!"
    fi
    press_enter
}

panel_restart() {
    show_logo
    echo -e "  ${BG_YELLOW}${WHITE} ↻ RESTART ${CURRENT_PANEL} PANEL ${NC}"
    echo
    
    if ! is_panel_installed "$CURRENT_BIN"; then
        error "Not installed!"
        press_enter
        return
    fi
    
    info "Restarting..."
    [[ "${HAS_SYSTEMD}" == true ]] && systemctl restart ${CURRENT_SERVICE} 2>/dev/null || {
        pkill -f "$(basename $CURRENT_BIN)" 2>/dev/null || true
        sleep 2
        cd "${CURRENT_INSTALL_DIR}"
        nohup ${CURRENT_BIN} >> ${CURRENT_LOG} 2>&1 &
    }
    
    sleep 5
    
    if is_panel_running "$CURRENT_PORT" "$(basename $CURRENT_BIN)"; then
        ok "Restarted!"
        echo -e "  🌐 URL: ${CYAN}http://$(get_public_ip):${CURRENT_PORT}${NC}"
    else
        error "Failed!"
    fi
    press_enter
}

panel_reinstall() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 🔄 REINSTALL ${CURRENT_PANEL} PANEL ${NC}"
    echo
    warn "This will DELETE and reinstall!"
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
    ok "Removed"
    
    install_panel
}

panel_uninstall() {
    show_logo
    echo -e "  ${BG_RED}${WHITE} 🗑️  UNINSTALL ${CURRENT_PANEL} PANEL ${NC}"
    echo
    
    if ! is_panel_installed "$CURRENT_BIN"; then
        warn "Not installed!"
        press_enter
        return
    fi
    
    warn "This will DELETE everything!"
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
    ok "Uninstalled!"
    press_enter
}

panel_logs() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 📋 ${CURRENT_PANEL} LOGS ${NC}"
    echo
    
    if [[ ! -f "${CURRENT_LOG}" ]]; then
        error "Log not found: ${CURRENT_LOG}"
        press_enter
        return
    fi
    
    echo -e "  ${WHITE}[1]${NC} Last 50 lines"
    echo -e "  ${WHITE}[2]${NC} Last 200 lines"
    echo -e "  ${WHITE}[3]${NC} Live tail (Ctrl+C exit)"
    echo -e "  ${WHITE}[0]${NC} Back"
    echo
    echo -en "  ${GREEN}Choice:${NC} "
    read -r c
    
    case $c in
        1) clear; tail -50 "${CURRENT_LOG}" ;;
        2) clear; tail -200 "${CURRENT_LOG}" ;;
        3) clear; tail -f "${CURRENT_LOG}" ;;
    esac
    press_enter
}

panel_info() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} ℹ️  ${CURRENT_PANEL} PANEL INFO ${NC}"
    echo
    
    if ! is_panel_installed "$CURRENT_BIN"; then
        error "Not installed!"
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
    echo -e "  ${CYAN}│${NC}  ${WHITE}💻 CPU Model${NC}  : ${cpu_model:0:40}"
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
        echo -e "  ${CYAN}│${NC}  ${RED}[0]${NC} ← Back"
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
        tailscale version 2>/dev/null | head -3
        press_enter
        return
    fi
    
    info "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    
    if command -v tailscale >/dev/null 2>&1; then
        ok "Tailscale installed!"
        info "Run 'tailscale up' to connect."
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
        error "Not installed! Install first."
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
    fi
    press_enter
}

tailscale_down() {
    show_logo
    echo -e "  ${BG_YELLOW}${WHITE} ⬇️  DISCONNECT ${NC}"
    echo
    
    if ! command -v tailscale >/dev/null 2>&1; then
        error "Not installed!"
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
        error "Not installed!"
        press_enter
        return
    fi
    
    tailscale status 2>/dev/null || warn "Not connected"
    echo
    tailscale version 2>/dev/null | head -3
    echo
    echo -e "  ${WHITE}IP:${NC} $(tailscale ip -4 2>/dev/null | head -1 || echo 'N/A')"
    press_enter
}

tailscale_uninstall() {
    show_logo
    echo -e "  ${BG_RED}${WHITE} 🗑️  UNINSTALL TAILSCALE ${NC}"
    echo
    
    if ! command -v tailscale >/dev/null 2>&1; then
        warn "Not installed!"
        press_enter
        return
    fi
    
    read -rp "  Continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled"
        press_enter
        return
    fi
    
    info "Uninstalling..."
    tailscale down 2>/dev/null || true
    
    if command -v apt >/dev/null 2>&1; then
        apt remove --purge -y tailscale 2>&1 | tail -3
    fi
    
    ok "Uninstalled!"
    press_enter
}

# =========================================================
# OPTION 5: CONTACT
# =========================================================

action_contact() {
    show_logo
    echo -e "  ${BG_MAGENTA}${WHITE} 💬 CONTACT & SUPPORT ${NC}"
    echo
    echo -e "  ${CYAN}╭──────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${WHITE}${BOLD}🌐 FakeCloud Community${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   Join our Discord for:"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} 24/7 Support"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} Latest Updates"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} License Purchase"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} Bug Reports"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} Feature Requests"
    echo -e "  ${CYAN}│${NC}   ${GREEN}✅${NC} Tutorials & Guides"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${WHITE}${BOLD}💬 Discord:${NC}"
    echo -e "  ${CYAN}│${NC}   ${BLUE}${BOLD}${DISCORD_LINK}${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${WHITE}${BOLD}🌐 Brand:${NC} ${CYAN}${BRAND_NAME}${NC}"
    echo -e "  ${CYAN}│${NC}   ${WHITE}${BOLD}📌 Version:${NC} ${GREEN}v${MANAGER_VERSION}${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}   ${WHITE}${BOLD}📦 Available Panels:${NC}"
    echo -e "  ${CYAN}│${NC}   • ${BLUE}NVM Panel v3${NC} - Fast Container Manager"
    echo -e "  ${CYAN}│${NC}   • ${MAGENTA}HVM Panel v8${NC} - Full VPS Management"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}╰──────────────────────────────────────────────────────────────────────╯${NC}"
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
        echo
        echo -e "  Or: ${WHITE}sudo bash <(curl -s ${INSTALLER_URL})${NC}"
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
                echo -e "  ${GREEN}${BOLD}Thank you for using FakeCloud Installer!${NC}"
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
