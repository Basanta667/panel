#!/usr/bin/env bash

# =========================================================
# HVM PANEL V8 ULTRA INSTALLER
# Powered by FakeCloud
# Discord: https://dsc.gg/fakecloud
# =========================================================

set -euo pipefail

# =========================================================
# COLORS & STYLES
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
BLINK="\e[5m"
BG_BLUE="\e[44m"
BG_GREEN="\e[42m"
BG_RED="\e[41m"

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
CONFIG_FILE="${INSTALL_DIR}/config.json"

MIN_FILE_SIZE_MB=30

DISCORD_LINK="https://dsc.gg/fakecloud"
PANEL_VERSION="8.0-ULTRA"
BRAND_NAME="FakeCloud"

INSTALLER_URL="https://raw.githubusercontent.com/Basanta667/panel/main/HvmV8.sh"

# =========================================================
# FUNCTIONS
# =========================================================

line() {
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"
}

double_line() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
}

info() {
    echo -e "  ${CYAN}⚡ [INFO]${NC} $1"
}

ok() {
    echo -e "  ${GREEN}✅ [OK]${NC} $1"
}

warn() {
    echo -e "  ${YELLOW}⚠️  [WARNING]${NC} $1"
}

error() {
    echo -e "  ${RED}❌ [ERROR]${NC} $1"
}

step() {
    echo -e "\n  ${BG_BLUE}${WHITE} STEP $1 ${NC} ${BOLD}$2${NC}\n"
}

spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='⣾⣽⣻⢿⡿⣟⣯⣷'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "  ${CYAN}%c${NC} %s" "$spinstr" "$1"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    printf "  ${GREEN}✅${NC} %s\n" "$2"
}

progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r  ${CYAN}[${NC}"
    printf "%0.s█" $(seq 1 $filled 2>/dev/null) || true
    printf "%0.s░" $(seq 1 $empty 2>/dev/null) || true
    printf "${CYAN}]${NC} ${WHITE}%3d%%${NC}" $percentage
}

countdown() {
    local seconds=$1
    local msg=$2
    for ((i=seconds; i>0; i--)); do
        printf "\r  ${YELLOW}⏳ ${msg} in ${i}s...${NC}  "
        sleep 1
    done
    printf "\r  ${GREEN}✅ ${msg} starting...${NC}          \n"
}

# =========================================================
# ANIMATED LOGO
# =========================================================

show_logo() {
    clear
    echo
    echo -e "${CYAN}${BOLD}"

    cat << "EOF"
    ╔══════════════════════════════════════════════════════╗
    ║                                                      ║
    ║   ███████╗ █████╗ ██╗  ██╗███████╗                  ║
    ║   ██╔════╝██╔══██╗██║ ██╔╝██╔════╝                  ║
    ║   █████╗  ███████║█████╔╝ █████╗                    ║
    ║   ██╔══╝  ██╔══██║██╔═██╗ ██╔══╝                    ║
    ║   ██║     ██║  ██║██║  ██╗███████╗                  ║
    ║   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝                  ║
    ║                                                      ║
    ║    ██████╗██╗      ██████╗ ██╗   ██╗██████╗          ║
    ║   ██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗        ║
    ║   ██║     ██║     ██║   ██║██║   ██║██║  ██║        ║
    ║   ██║     ██║     ██║   ██║██║   ██║██║  ██║        ║
    ║   ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝        ║
    ║    ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝        ║
    ║                                                      ║
    ║          HVM PANEL V8 ULTRA INSTALLER                ║
    ║            Powered by FakeCloud                      ║
    ║                                                      ║
    ╚══════════════════════════════════════════════════════╝
EOF

    echo -e "${NC}"
    echo
    echo -e "  ${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}${BOLD}  Version: ${CYAN}${PANEL_VERSION}${NC}   ${WHITE}│${NC}   ${WHITE}${BOLD}Discord: ${BLUE}${DISCORD_LINK}${NC}"
    echo -e "  ${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# =========================================================
# SYSTEM INFO DISPLAY
# =========================================================

show_system_info() {
    local cpu_model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown")
    local cpu_cores=$(nproc 2>/dev/null || echo "?")
    local total_ram=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "?")
    local free_ram=$(free -h 2>/dev/null | awk '/^Mem:/{print $7}' || echo "?")
    local disk_total=$(df -h / 2>/dev/null | awk 'NR==2{print $2}' || echo "?")
    local disk_free=$(df -h / 2>/dev/null | awk 'NR==2{print $4}' || echo "?")
    local uptime_info=$(uptime -p 2>/dev/null | sed 's/up //' || echo "?")

    echo -e "  ${CYAN}╭──────────────── System Information ────────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🖥️  CPU     :${NC} ${cpu_model} (${cpu_cores} cores)"
    echo -e "  ${CYAN}│${NC}  ${WHITE}💾 RAM     :${NC} ${free_ram} free / ${total_ram} total"
    echo -e "  ${CYAN}│${NC}  ${WHITE}💿 Disk    :${NC} ${disk_free} free / ${disk_total} total"
    echo -e "  ${CYAN}│${NC}  ${WHITE}⏰ Uptime  :${NC} ${uptime_info}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🐧 OS      :${NC} ${PRETTY_NAME:-Unknown}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🏗️  Arch    :${NC} $(uname -m)"
    echo -e "  ${CYAN}│${NC}  ${WHITE}📅 Date    :${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo -e "  ${CYAN}╰────────────────────────────────────────────────────╯${NC}"
    echo
}

# =========================================================
# PRE-INSTALLATION CHECKS
# =========================================================

pre_checks() {

    step "1/8" "Pre-Installation Checks"

    # Root check
    if [[ "$EUID" -ne 0 ]]; then
        error "Please run this installer as root."
        echo -e "  ${DIM}Run: ${WHITE}sudo bash HvmV8.sh${NC}"
        exit 1
    fi
    ok "Running as root"

    # OS Detection
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        error "Unable to detect operating system."
        exit 1
    fi

    ARCH=$(uname -m)
    ok "OS: ${PRETTY_NAME} (${ARCH})"

    # Check RAM
    local total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    if [[ "${total_ram_mb}" -lt 512 ]]; then
        warn "Low RAM detected (${total_ram_mb}MB). Minimum 512MB recommended."
    else
        ok "RAM: ${total_ram_mb}MB available"
    fi

    # Check disk space
    local disk_free_mb=$(df -m / | awk 'NR==2{print $4}')
    if [[ "${disk_free_mb}" -lt 1000 ]]; then
        warn "Low disk space (${disk_free_mb}MB free). Minimum 1GB recommended."
    else
        ok "Disk: ${disk_free_mb}MB free"
    fi

    # Check internet
    if ping -c 1 -W 3 google.com >/dev/null 2>&1; then
        ok "Internet connection verified"
    else
        if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
            ok "Internet connection verified (DNS may be slow)"
        else
            error "No internet connection detected."
            exit 1
        fi
    fi

    # Check if already installed
    if [[ -f "${BIN_FILE}" ]]; then
        warn "HVM Panel is already installed at ${INSTALL_DIR}"
        echo
        read -rp "  Do you want to reinstall? (y/n): " reinstall
        if [[ "$reinstall" != "y" && "$reinstall" != "Y" ]]; then
            info "Installation cancelled."
            exit 0
        fi
        info "Stopping existing service..."
        systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    fi

    ok "All pre-checks passed!"
}

# =========================================================
# INSTALL DEPENDENCIES
# =========================================================

install_deps() {

    step "2/8" "Installing Dependencies"

    if command -v apt >/dev/null 2>&1; then

        export DEBIAN_FRONTEND=noninteractive

        info "Updating package lists..."
        apt update -y -qq >/dev/null 2>&1 &
        spinner "Updating..." "Package lists updated"

        info "Installing required packages..."
        apt install -y -qq \
        curl wget lsof tar unzip sudo nano \
        python3 python3-pip ca-certificates \
        htop net-tools >/dev/null 2>&1 &
        spinner "Installing packages..." "All packages installed"

    elif command -v dnf >/dev/null 2>&1; then

        dnf install -y -q \
        curl wget lsof tar unzip sudo nano \
        python3 python3-pip ca-certificates \
        htop net-tools >/dev/null 2>&1 &
        spinner "Installing packages..." "All packages installed"

    elif command -v yum >/dev/null 2>&1; then

        yum install -y -q epel-release >/dev/null 2>&1 || true

        yum install -y -q \
        curl wget lsof tar unzip sudo nano \
        python3 python3-pip ca-certificates \
        htop net-tools >/dev/null 2>&1 &
        spinner "Installing packages..." "All packages installed"

    elif command -v pacman >/dev/null 2>&1; then

        pacman -Sy --noconfirm --quiet \
        curl wget lsof tar unzip sudo nano \
        python python-pip ca-certificates >/dev/null 2>&1 &
        spinner "Installing packages..." "All packages installed"

    elif command -v apk >/dev/null 2>&1; then

        apk update --quiet >/dev/null 2>&1
        apk add --quiet \
        curl wget lsof tar unzip sudo nano \
        python3 py3-pip ca-certificates >/dev/null 2>&1 &
        spinner "Installing packages..." "All packages installed"

    elif command -v zypper >/dev/null 2>&1; then

        zypper refresh --quiet >/dev/null 2>&1
        zypper install -y --quiet \
        curl wget lsof tar unzip sudo nano \
        python3 python3-pip ca-certificates >/dev/null 2>&1 &
        spinner "Installing packages..." "All packages installed"

    else
        error "Unsupported Linux distribution: ${DISTRO}"
        error "Supported: Ubuntu, Debian, CentOS, RHEL, Fedora, Arch, Alpine, openSUSE"
        exit 1
    fi

    ok "All dependencies installed successfully!"
}

# =========================================================
# PORT CHECK
# =========================================================

check_port() {

    step "3/8" "Checking Port ${PANEL_PORT}"

    if lsof -Pi :${PANEL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then

        warn "Port ${PANEL_PORT} is already in use!"
        echo
        echo -e "  ${DIM}Process using port ${PANEL_PORT}:${NC}"
        lsof -i:${PANEL_PORT} 2>/dev/null | head -5 | while read line; do
            echo -e "  ${DIM}  ${line}${NC}"
        done
        echo

        read -rp "  Kill existing process and continue? (y/n): " confirm

        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            local pid=$(lsof -Pi :${PANEL_PORT} -sTCP:LISTEN -t 2>/dev/null)
            if [[ -n "$pid" ]]; then
                kill -9 $pid 2>/dev/null || true
                ok "Process killed. Port ${PANEL_PORT} is now free."
            fi
        else
            error "Installation cancelled."
            exit 1
        fi
    else
        ok "Port ${PANEL_PORT} is available"
    fi
}

# =========================================================
# CREATE DIRECTORY
# =========================================================

setup_directory() {

    step "4/8" "Setting Up Installation Directory"

    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}/backups"
    mkdir -p "${INSTALL_DIR}/logs"

    cd "${INSTALL_DIR}"

    ok "Directory created: ${INSTALL_DIR}"
}

# =========================================================
# DOWNLOAD BINARY FROM GOOGLE DRIVE
# =========================================================

download_binary() {

    step "5/8" "Downloading hvmV8.bin"

    info "Source: ${BRAND_NAME} Cloud Servers"
    info "File: hvmV8.bin (HVM Panel V8 Binary)"
    echo

    rm -f hvmV8.bin

    # Google Drive Large File Download Method
    local COOKIES_FILE="/tmp/gdrive_cookies_$$.txt"
    local PAGE_FILE="/tmp/gdrive_page_$$.html"

    info "Connecting to download server..."

    # Step 1: Get confirmation token
    wget --quiet --save-cookies "${COOKIES_FILE}" --keep-session-cookies \
        --no-check-certificate \
        "https://docs.google.com/uc?export=download&id=${FILE_ID}" \
        -O "${PAGE_FILE}" 2>/dev/null || true

    local CONFIRM=$(grep -oP 'confirm=[0-9A-Za-z_-]+' "${PAGE_FILE}" 2>/dev/null | head -1 | cut -d'=' -f2 || echo "")

    # Step 2: Download the file
    info "Downloading hvmV8.bin... (this may take 5-15 minutes)"
    echo

    if [[ -n "${CONFIRM}" ]]; then
        wget --load-cookies "${COOKIES_FILE}" \
            --no-check-certificate \
            --progress=bar:force:noscroll \
            "https://docs.google.com/uc?export=download&confirm=${CONFIRM}&id=${FILE_ID}" \
            -O hvmV8.bin 2>&1 | tail -1 || true
    else
        wget --no-check-certificate \
            --progress=bar:force:noscroll \
            "${HVM_URL}" \
            -O hvmV8.bin 2>&1 | tail -1 || true
    fi

    # Cleanup temp files
    rm -f "${COOKIES_FILE}" "${PAGE_FILE}"

    echo

    # =====================================================
    # VERIFY FILE
    # =====================================================

    if [[ ! -f hvmV8.bin ]]; then
        error "Download failed!"
        error "Please check your internet connection."
        echo -e "  ${YELLOW}💬 Need help? Join our Discord: ${BLUE}${DISCORD_LINK}${NC}"
        exit 1
    fi

    if [[ ! -s hvmV8.bin ]]; then
        error "Downloaded file is empty!"
        echo -e "  ${YELLOW}💬 Need help? Join our Discord: ${BLUE}${DISCORD_LINK}${NC}"
        exit 1
    fi

    FILE_SIZE_MB=$(du -m hvmV8.bin | cut -f1)

    if [[ "${FILE_SIZE_MB}" -lt "${MIN_FILE_SIZE_MB}" ]]; then
        error "File too small (${FILE_SIZE_MB}MB). Download may be corrupted."
        echo -e "  ${YELLOW}💬 Need help? Join our Discord: ${BLUE}${DISCORD_LINK}${NC}"
        file hvmV8.bin || true
        rm -f hvmV8.bin
        exit 1
    fi

    if file hvmV8.bin | grep -qi "html"; then
        error "Downloaded HTML page instead of binary."
        error "Google Drive daily download quota may be exceeded."
        echo -e "  ${YELLOW}⏰ Try again after 24 hours, or contact support.${NC}"
        echo -e "  ${YELLOW}💬 Discord: ${BLUE}${DISCORD_LINK}${NC}"
        rm -f hvmV8.bin
        exit 1
    fi

    chmod +x hvmV8.bin

    ok "hvmV8.bin downloaded successfully! (${FILE_SIZE_MB}MB)"
}

# =========================================================
# FIREWALL CONFIG
# =========================================================

configure_firewall() {

    step "6/8" "Configuring Firewall"

    local firewall_configured=false

    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${PANEL_PORT}/tcp >/dev/null 2>&1 || true
        ufw allow 22/tcp >/dev/null 2>&1 || true
        firewall_configured=true
        ok "UFW: Port ${PANEL_PORT} allowed"
    fi

    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=${PANEL_PORT}/tcp >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
        firewall_configured=true
        ok "Firewalld: Port ${PANEL_PORT} allowed"
    fi

    if command -v iptables >/dev/null 2>&1; then
        iptables -C INPUT -p tcp --dport ${PANEL_PORT} -j ACCEPT >/dev/null 2>&1 || \
        iptables -I INPUT -p tcp --dport ${PANEL_PORT} -j ACCEPT >/dev/null 2>&1 || true
        firewall_configured=true
        ok "Iptables: Port ${PANEL_PORT} allowed"
    fi

    if [[ "${firewall_configured}" == false ]]; then
        warn "No firewall detected. Make sure port ${PANEL_PORT} is open."
    fi
}

# =========================================================
# CREATE SYSTEMD SERVICE
# =========================================================

setup_service() {

    step "7/8" "Creating System Service"

    if command -v systemctl >/dev/null 2>&1; then

cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=HVM Panel V8 - Powered by ${BRAND_NAME}
Documentation=${DISCORD_LINK}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${BIN_FILE}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
LimitNOFILE=1048576
LimitNPROC=infinity
User=root
StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}

# Security
NoNewPrivileges=false
ProtectSystem=false

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable ${SERVICE_NAME} >/dev/null 2>&1

        info "Starting HVM Panel service..."

        systemctl restart ${SERVICE_NAME}

        # Wait for service to start
        local wait_time=0
        local max_wait=15

        while [[ ${wait_time} -lt ${max_wait} ]]; do
            if systemctl is-active --quiet ${SERVICE_NAME}; then
                break
            fi
            sleep 1
            wait_time=$((wait_time + 1))
            printf "\r  ${CYAN}⏳ Waiting for service to start... (%ds)${NC}" ${wait_time}
        done
        echo

        if systemctl is-active --quiet ${SERVICE_NAME}; then
            ok "HVM service started successfully!"
        else
            error "HVM service failed to start."
            echo
            echo -e "  ${DIM}Service log:${NC}"
            journalctl -u ${SERVICE_NAME} --no-pager -n 10 2>/dev/null | while read line; do
                echo -e "  ${DIM}  ${line}${NC}"
            done
            echo
            echo -e "  ${YELLOW}💬 Need help? Join Discord: ${BLUE}${DISCORD_LINK}${NC}"
            echo
            warn "Continuing installation... You may need to troubleshoot the service."
        fi

    else

        warn "systemd not detected."
        info "Starting HVM Panel manually..."

        nohup ${BIN_FILE} >> ${LOG_FILE} 2>&1 &

        sleep 3
        ok "HVM Panel started in background."

    fi
}

# =========================================================
# FINAL SETUP
# =========================================================

final_setup() {

    step "8/8" "Finalizing Installation"

    # Create uninstaller script
    cat > "${INSTALL_DIR}/uninstall.sh" << 'UNINSTALL_EOF'
#!/bin/bash
echo "Uninstalling HVM Panel..."
systemctl stop hvm 2>/dev/null || true
systemctl disable hvm 2>/dev/null || true
rm -f /etc/systemd/system/hvm.service
systemctl daemon-reload 2>/dev/null || true
rm -rf /opt/hvm
rm -f /var/log/hvm.log
echo "HVM Panel uninstalled successfully!"
UNINSTALL_EOF
    chmod +x "${INSTALL_DIR}/uninstall.sh"
    ok "Uninstaller created: ${INSTALL_DIR}/uninstall.sh"

    # Create update script
    cat > "${INSTALL_DIR}/update.sh" << UPDATESCRIPT
#!/bin/bash
echo "Updating HVM Panel V8..."
systemctl stop ${SERVICE_NAME} 2>/dev/null || true
cd ${INSTALL_DIR}
cp hvmV8.bin hvmV8.bin.bak 2>/dev/null || true
bash <(curl -fsSL ${INSTALLER_URL})
UPDATESCRIPT
    chmod +x "${INSTALL_DIR}/update.sh"
    ok "Updater created: ${INSTALL_DIR}/update.sh"

    # Create log rotate config
    if [[ -d /etc/logrotate.d ]]; then
        cat > /etc/logrotate.d/hvm << LOGROTATE
${LOG_FILE} {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0644 root root
    postrotate
        systemctl reload ${SERVICE_NAME} 2>/dev/null || true
    endscript
}
LOGROTATE
        ok "Log rotation configured"
    fi

    ok "Installation finalized!"
}

# =========================================================
# SHOW COMPLETION SCREEN
# =========================================================

show_complete() {

    # Get panel status
    local PANEL_STATUS
    if lsof -Pi :${PANEL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
        PANEL_STATUS="${GREEN}● ONLINE${NC}"
    else
        PANEL_STATUS="${YELLOW}○ STARTING...${NC}"
    fi

    # Get public IP
    local PUBLIC_IP
    PUBLIC_IP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null || true)
    if [[ -z "${PUBLIC_IP}" ]]; then
        PUBLIC_IP=$(curl -4 -s --max-time 10 api.ipify.org 2>/dev/null || true)
    fi
    if [[ -z "${PUBLIC_IP}" ]]; then
        PUBLIC_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "YOUR_SERVER_IP")
    fi

    clear

    echo -e "${GREEN}${BOLD}"

    cat << "EOF"

    ╔══════════════════════════════════════════════════════╗
    ║                                                      ║
    ║     ✅  INSTALLATION COMPLETED SUCCESSFULLY!  ✅     ║
    ║                                                      ║
    ║              Powered by FakeCloud                    ║
    ║                                                      ║
    ╚══════════════════════════════════════════════════════╝

EOF

    echo -e "${NC}"

    echo -e "  ${CYAN}╭──────────────── Panel Information ─────────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}📊 Status${NC}      : ${PANEL_STATUS}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🌐 Panel URL${NC}   : ${CYAN}${BOLD}http://${PUBLIC_IP}:${PANEL_PORT}${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}👤 Username${NC}    : ${GREEN}admin${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🔑 Password${NC}    : ${GREEN}admin${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}╰────────────────────────────────────────────────────╯${NC}"

    echo
    echo -e "  ${MAGENTA}╭──────────────── File Locations ─────────────────────╮${NC}"
    echo -e "  ${MAGENTA}│${NC}"
    echo -e "  ${MAGENTA}│${NC}  ${WHITE}📁 Install Dir${NC} : ${DIM}${INSTALL_DIR}${NC}"
    echo -e "  ${MAGENTA}│${NC}  ${WHITE}📦 Binary${NC}      : ${DIM}${BIN_FILE}${NC}"
    echo -e "  ${MAGENTA}│${NC}  ${WHITE}📝 Log File${NC}    : ${DIM}${LOG_FILE}${NC}"
    echo -e "  ${MAGENTA}│${NC}  ${WHITE}🔧 Service${NC}     : ${DIM}${SERVICE_NAME}${NC}"
    echo -e "  ${MAGENTA}│${NC}"
    echo -e "  ${MAGENTA}╰────────────────────────────────────────────────────╯${NC}"

    echo
    echo -e "  ${BLUE}╭──────────────── Service Commands ──────────────────╮${NC}"
    echo -e "  ${BLUE}│${NC}"
    echo -e "  ${BLUE}│${NC}  ${GREEN}▶ Start${NC}    :  systemctl start ${SERVICE_NAME}"
    echo -e "  ${BLUE}│${NC}  ${RED}■ Stop${NC}     :  systemctl stop ${SERVICE_NAME}"
    echo -e "  ${BLUE}│${NC}  ${YELLOW}↻ Restart${NC}  :  systemctl restart ${SERVICE_NAME}"
    echo -e "  ${BLUE}│${NC}  ${CYAN}ℹ Status${NC}   :  systemctl status ${SERVICE_NAME}"
    echo -e "  ${BLUE}│${NC}  ${MAGENTA}📋 Logs${NC}    :  journalctl -u ${SERVICE_NAME} -f"
    echo -e "  ${BLUE}│${NC}"
    echo -e "  ${BLUE}╰────────────────────────────────────────────────────╯${NC}"

    echo
    echo -e "  ${YELLOW}╭──────────────── Quick Actions ─────────────────────╮${NC}"
    echo -e "  ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${WHITE}🔄 Update${NC}    :  bash ${INSTALL_DIR}/update.sh"
    echo -e "  ${YELLOW}│${NC}  ${WHITE}🗑️  Uninstall${NC} :  bash ${INSTALL_DIR}/uninstall.sh"
    echo -e "  ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}╰────────────────────────────────────────────────────╯${NC}"

    echo
    echo -e "  ${RED}╭──────────────── 🔐 LICENSE NOTICE ─────────────────╮${NC}"
    echo -e "  ${RED}│${NC}"
    echo -e "  ${RED}│${NC}  ${WHITE}${BOLD}⚠️  A valid license key is required to use this panel.${NC}"
    echo -e "  ${RED}│${NC}"
    echo -e "  ${RED}│${NC}  ${WHITE}📌 To purchase a license:${NC}"
    echo -e "  ${RED}│${NC}  ${CYAN}   1. Open the panel: ${BOLD}http://${PUBLIC_IP}:${PANEL_PORT}${NC}"
    echo -e "  ${RED}│${NC}  ${CYAN}   2. Go to License page${NC}"
    echo -e "  ${RED}│${NC}  ${CYAN}   3. Join our Discord to buy a key:${NC}"
    echo -e "  ${RED}│${NC}  ${BLUE}${BOLD}      ${DISCORD_LINK}${NC}"
    echo -e "  ${RED}│${NC}"
    echo -e "  ${RED}│${NC}  ${YELLOW}💰 License gives you: Full panel access, updates,${NC}"
    echo -e "  ${RED}│${NC}  ${YELLOW}   unlimited VPS creation, and priority support!${NC}"
    echo -e "  ${RED}│${NC}"
    echo -e "  ${RED}╰────────────────────────────────────────────────────╯${NC}"

    echo
    echo -e "  ${CYAN}╭──────────────── 🚀 One Line Installer ───────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}bash <(curl -fsSL ${INSTALLER_URL})${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}╰──────────────────────────────────────────────────────╯${NC}"

    echo
    echo -e "  ${MAGENTA}╭──────────────── 💬 Support & Community ──────────────╮${NC}"
    echo -e "  ${MAGENTA}│${NC}"
    echo -e "  ${MAGENTA}│${NC}  ${WHITE}Discord${NC}  :  ${BLUE}${BOLD}${DISCORD_LINK}${NC}"
    echo -e "  ${MAGENTA}│${NC}  ${WHITE}Brand${NC}    :  ${CYAN}${BRAND_NAME}${NC}"
    echo -e "  ${MAGENTA}│${NC}  ${WHITE}Version${NC}  :  ${GREEN}${PANEL_VERSION}${NC}"
    echo -e "  ${MAGENTA}│${NC}"
    echo -e "  ${MAGENTA}╰──────────────────────────────────────────────────────╯${NC}"

    echo
    echo -e "  ${GREEN}${BOLD}Thank you for choosing HVM Panel V8!${NC}"
    echo -e "  ${MAGENTA}Powered by ${BRAND_NAME} ☁️  | ${BLUE}${DISCORD_LINK}${NC}"
    echo
    line
    echo
}

# =========================================================
# MAIN EXECUTION
# =========================================================

main() {

    show_logo

    sleep 1

    show_system_info

    sleep 1

    echo -e "  ${YELLOW}${BOLD}Starting installation in 3 seconds...${NC}"
    countdown 3 "Installation"

    line

    pre_checks

    line

    install_deps

    line

    check_port

    line

    setup_directory

    line

    download_binary

    line

    configure_firewall

    line

    setup_service

    line

    final_setup

    line

    show_complete
}

# Run
main "$@"
