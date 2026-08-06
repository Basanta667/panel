#!/usr/bin/env bash

# =========================================================
# HVM PANEL V8 ULTRA INSTALLER (v3.0 - UNIVERSAL)
# Powered by FakeCloud
# Discord: https://dsc.gg/fakecloud
# Works on: Ubuntu, Debian, CentOS, Alibaba, Contabo, 
#           Hostinger, DigitalOcean, AWS, GCP, ANY VPS!
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

# =========================================================
# VARIABLES
# =========================================================

FILE_ID="1IhayXycn0bzu7c8EEO2Xsv8Xwr9OXXiy"
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
# FUNCTIONS
# =========================================================

line() {
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════${NC}"
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
# UNIVERSAL INTERNET CHECK (Works on ANY VPS)
# =========================================================

check_internet() {
    # Method 1: curl to Google
    if curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://www.google.com 2>/dev/null | grep -qE "200|301|302"; then
        return 0
    fi
    
    # Method 2: curl to Cloudflare
    if curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://1.1.1.1 2>/dev/null | grep -qE "200|301|302"; then
        return 0
    fi
    
    # Method 3: curl to GitHub
    if curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://raw.githubusercontent.com 2>/dev/null | grep -qE "200|301|302"; then
        return 0
    fi
    
    # Method 4: wget check
    if wget -q --spider --timeout=5 https://www.google.com 2>/dev/null; then
        return 0
    fi
    
    # Method 5: ping fallback
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        return 0
    fi
    
    # Method 6: DNS check
    if nslookup google.com >/dev/null 2>&1; then
        return 0
    fi
    
    # Method 7: Try to resolve via /etc/hosts or DNS
    if getent hosts google.com >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

detect_environment() {
    # Check systemd
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        HAS_SYSTEMD=true
    fi

    # Check Cloud Shell
    if [[ -n "${CLOUD_SHELL:-}" ]] || [[ -n "${GOOGLE_CLOUD_SHELL:-}" ]] || [[ "$(hostname 2>/dev/null)" == *"cloudshell"* ]]; then
        IS_CLOUD_SHELL=true
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
# SYSTEM INFO
# =========================================================

show_system_info() {
    local cpu_model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown")
    local cpu_cores=$(nproc 2>/dev/null || echo "?")
    local total_ram=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "?")
    local free_ram=$(free -h 2>/dev/null | awk '/^Mem:/{print $7}' || echo "?")
    local disk_total=$(df -h / 2>/dev/null | awk 'NR==2{print $2}' || echo "?")
    local disk_free=$(df -h / 2>/dev/null | awk 'NR==2{print $4}' || echo "?")

    echo -e "  ${CYAN}╭──────────────── System Information ────────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🖥️  CPU     :${NC} ${cpu_model} (${cpu_cores} cores)"
    echo -e "  ${CYAN}│${NC}  ${WHITE}💾 RAM     :${NC} ${free_ram} free / ${total_ram} total"
    echo -e "  ${CYAN}│${NC}  ${WHITE}💿 Disk    :${NC} ${disk_free} free / ${disk_total} total"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🐧 OS      :${NC} ${PRETTY_NAME:-Unknown}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🏗️  Arch    :${NC} $(uname -m)"
    if [[ "${IS_CLOUD_SHELL}" == true ]]; then
        echo -e "  ${CYAN}│${NC}  ${WHITE}🌐 Env     :${NC} ${YELLOW}Google Cloud Shell${NC}"
    fi
    if [[ "${HAS_SYSTEMD}" == true ]]; then
        echo -e "  ${CYAN}│${NC}  ${WHITE}⚙️  Systemd :${NC} ${GREEN}Available${NC}"
    else
        echo -e "  ${CYAN}│${NC}  ${WHITE}⚙️  Systemd :${NC} ${YELLOW}Manual Mode${NC}"
    fi
    echo -e "  ${CYAN}╰────────────────────────────────────────────────────╯${NC}"
    echo
}

# =========================================================
# PRE-CHECKS (Improved)
# =========================================================

pre_checks() {
    step "1/8" "Pre-Installation Checks"

    if [[ "$EUID" -ne 0 ]]; then
        error "Please run this installer as root."
        echo -e "  ${DIM}Run: ${WHITE}sudo bash HvmV8.sh${NC}"
        exit 1
    fi
    ok "Running as root"

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO=$ID
    else
        DISTRO="unknown"
        PRETTY_NAME="Unknown Linux"
    fi

    ARCH=$(uname -m)
    ok "OS: ${PRETTY_NAME:-Unknown} (${ARCH})"

    local total_ram_mb=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "1024")
    if [[ "${total_ram_mb}" -lt 512 ]]; then
        warn "Low RAM (${total_ram_mb}MB). 512MB+ recommended."
    else
        ok "RAM: ${total_ram_mb}MB available"
    fi

    # UNIVERSAL Internet check
    info "Checking internet connectivity (multiple methods)..."
    if check_internet; then
        ok "Internet connection verified"
    else
        warn "Standard internet check failed."
        warn "Trying to continue anyway (some VPS block ping/curl checks)..."
        warn "If download fails, please check your network manually."
        # Don't exit, just warn and continue
        sleep 2
    fi

    if [[ -f "${BIN_FILE}" ]]; then
        warn "HVM Panel already installed."
        read -rp "  Reinstall? (y/n): " reinstall
        if [[ "$reinstall" != "y" && "$reinstall" != "Y" ]]; then
            info "Cancelled."
            exit 0
        fi
        if [[ "${HAS_SYSTEMD}" == true ]]; then
            systemctl stop ${SERVICE_NAME} 2>/dev/null || true
        fi
        pkill -f hvmV8.bin 2>/dev/null || true
    fi

    ok "Pre-checks passed!"
}

# =========================================================
# INSTALL DEPENDENCIES
# =========================================================

install_deps() {
    step "2/8" "Installing Dependencies"

    info "Installing packages (2-3 minutes)..."

    if command -v apt >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt update -y -qq >/dev/null 2>&1 || warn "apt update had issues"
        apt install -y -qq \
            curl wget lsof tar unzip sudo nano \
            python3 python3-pip python3-setuptools \
            ca-certificates htop net-tools iputils-ping \
            dnsutils >/dev/null 2>&1 || warn "Some packages may have failed"

    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y -q \
            curl wget lsof tar unzip sudo nano \
            python3 python3-pip python3-setuptools \
            ca-certificates htop net-tools iputils \
            bind-utils >/dev/null 2>&1 || warn "Some packages may have failed"

    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q epel-release >/dev/null 2>&1 || true
        yum install -y -q \
            curl wget lsof tar unzip sudo nano \
            python3 python3-pip python3-setuptools \
            ca-certificates htop net-tools iputils \
            bind-utils >/dev/null 2>&1 || warn "Some packages may have failed"

    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm --quiet \
            curl wget lsof tar unzip sudo nano \
            python python-pip python-setuptools \
            ca-certificates iputils \
            bind >/dev/null 2>&1 || warn "Some packages may have failed"

    elif command -v apk >/dev/null 2>&1; then
        apk update --quiet >/dev/null 2>&1 || true
        apk add --quiet \
            curl wget lsof tar unzip sudo nano \
            python3 py3-pip py3-setuptools \
            ca-certificates \
            bind-tools >/dev/null 2>&1 || warn "Some packages may have failed"
    else
        warn "Unknown package manager. Assuming curl/wget already installed."
    fi

    # Verify essential tools are available
    for tool in curl wget; do
        if ! command -v $tool >/dev/null 2>&1; then
            error "Essential tool '$tool' is not available!"
            error "Please install manually and retry."
            exit 1
        fi
    done

    ok "All dependencies installed!"
}

# =========================================================
# PORT CHECK
# =========================================================

check_port() {
    step "3/8" "Checking Port ${PANEL_PORT}"

    local port_in_use=false
    
    if command -v lsof >/dev/null 2>&1; then
        if lsof -Pi :${PANEL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
            port_in_use=true
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tulpn 2>/dev/null | grep -q ":${PANEL_PORT} "; then
            port_in_use=true
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tulpn 2>/dev/null | grep -q ":${PANEL_PORT} "; then
            port_in_use=true
        fi
    fi

    if [[ "$port_in_use" == true ]]; then
        warn "Port ${PANEL_PORT} is in use!"
        read -rp "  Kill existing process? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            local pid=""
            if command -v lsof >/dev/null 2>&1; then
                pid=$(lsof -Pi :${PANEL_PORT} -sTCP:LISTEN -t 2>/dev/null)
            fi
            if [[ -n "$pid" ]]; then
                kill -9 $pid 2>/dev/null || true
                ok "Port freed"
            else
                pkill -f hvmV8.bin 2>/dev/null || true
                ok "Killed hvmV8.bin processes"
            fi
        else
            error "Cancelled."
            exit 1
        fi
    else
        ok "Port ${PANEL_PORT} available"
    fi
}

# =========================================================
# SETUP DIRECTORY
# =========================================================

setup_directory() {
    step "4/8" "Setting Up Directory"

    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}/backups"
    mkdir -p "${INSTALL_DIR}/logs"
    cd "${INSTALL_DIR}"

    ok "Directory: ${INSTALL_DIR}"
}

# =========================================================
# DOWNLOAD BINARY (Multi-method)
# =========================================================

download_binary() {
    step "5/8" "Downloading hvmV8.bin"

    info "Source: ${BRAND_NAME} Cloud Servers"
    info "File: hvmV8.bin (HVM Panel V8 Binary)"
    echo

    rm -f hvmV8.bin

    local COOKIES_FILE="/tmp/gdrive_cookies_$$.txt"
    local PAGE_FILE="/tmp/gdrive_page_$$.html"

    info "Downloading from Google Drive..."
    echo

    # Method 1: wget with confirmation
    wget --quiet --save-cookies "${COOKIES_FILE}" --keep-session-cookies \
        --no-check-certificate \
        "https://docs.google.com/uc?export=download&id=${FILE_ID}" \
        -O "${PAGE_FILE}" 2>/dev/null || true

    local CONFIRM=$(grep -oP 'confirm=[0-9A-Za-z_-]+' "${PAGE_FILE}" 2>/dev/null | head -1 | cut -d'=' -f2 || echo "")

    if [[ -n "${CONFIRM}" ]]; then
        wget --load-cookies "${COOKIES_FILE}" \
            --no-check-certificate \
            --progress=bar:force:noscroll \
            "https://docs.google.com/uc?export=download&confirm=${CONFIRM}&id=${FILE_ID}" \
            -O hvmV8.bin 2>&1 | tail -3 || true
    fi

    # Method 2: Direct download if Method 1 failed
    if [[ ! -f hvmV8.bin ]] || [[ ! -s hvmV8.bin ]] || file hvmV8.bin 2>/dev/null | grep -qi "html"; then
        info "Trying alternate download method..."
        rm -f hvmV8.bin
        wget --no-check-certificate \
            --progress=bar:force:noscroll \
            "${HVM_URL}" \
            -O hvmV8.bin 2>&1 | tail -3 || true
    fi

    # Method 3: curl fallback
    if [[ ! -f hvmV8.bin ]] || [[ ! -s hvmV8.bin ]] || file hvmV8.bin 2>/dev/null | grep -qi "html"; then
        info "Trying curl download..."
        rm -f hvmV8.bin
        curl -L --insecure --progress-bar \
            "${HVM_URL}" \
            -o hvmV8.bin || true
    fi

    rm -f "${COOKIES_FILE}" "${PAGE_FILE}"
    echo

    if [[ ! -f hvmV8.bin ]] || [[ ! -s hvmV8.bin ]]; then
        error "Download failed after multiple attempts!"
        echo -e "  ${YELLOW}💬 Discord: ${BLUE}${DISCORD_LINK}${NC}"
        exit 1
    fi

    FILE_SIZE_MB=$(du -m hvmV8.bin | cut -f1)

    if [[ "${FILE_SIZE_MB}" -lt "${MIN_FILE_SIZE_MB}" ]]; then
        error "File too small (${FILE_SIZE_MB}MB). Download may be corrupted."
        rm -f hvmV8.bin
        exit 1
    fi

    if file hvmV8.bin 2>/dev/null | grep -qi "html"; then
        error "Google Drive quota exceeded. Try after 24 hours."
        echo -e "  ${YELLOW}💬 Discord: ${BLUE}${DISCORD_LINK}${NC}"
        rm -f hvmV8.bin
        exit 1
    fi

    chmod +x hvmV8.bin
    ok "hvmV8.bin downloaded! (${FILE_SIZE_MB}MB)"
}

# =========================================================
# FIREWALL
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
        warn "No firewall detected."
    fi
}

# =========================================================
# SETUP SERVICE
# =========================================================

setup_service() {
    step "7/8" "Creating System Service"

    if [[ "${HAS_SYSTEMD}" == true ]]; then

        info "Systemd detected. Creating service..."

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

        local wait_time=0
        while [[ ${wait_time} -lt 15 ]]; do
            if systemctl is-active --quiet ${SERVICE_NAME}; then
                break
            fi
            sleep 1
            wait_time=$((wait_time + 1))
            printf "\r  ${CYAN}⏳ Waiting for service... (%ds)${NC}" ${wait_time}
        done
        echo

        if systemctl is-active --quiet ${SERVICE_NAME}; then
            ok "HVM service started successfully!"
        else
            warn "Service failed. Starting manually as fallback..."
            start_manual
        fi

    else
        warn "Systemd not available"
        info "Starting HVM Panel manually..."
        start_manual
    fi
}

start_manual() {
    pkill -f hvmV8.bin 2>/dev/null || true
    sleep 2

    cd "${INSTALL_DIR}"
    nohup ${BIN_FILE} >> ${LOG_FILE} 2>&1 &
    local pid=$!

    sleep 5

    if kill -0 $pid 2>/dev/null; then
        ok "HVM Panel started manually (PID: $pid)"
        echo $pid > "${INSTALL_DIR}/hvm.pid"
    else
        error "Failed to start HVM Panel!"
        echo -e "  ${DIM}Check logs: ${LOG_FILE}${NC}"
        echo -e "  ${YELLOW}💬 Discord: ${BLUE}${DISCORD_LINK}${NC}"
    fi
}

# =========================================================
# FINAL SETUP
# =========================================================

final_setup() {
    step "8/8" "Finalizing Installation"

    cat > "${INSTALL_DIR}/uninstall.sh" << 'UNINSTALL_EOF'
#!/bin/bash
echo "🗑️  Uninstalling HVM Panel..."
systemctl stop hvm 2>/dev/null || true
systemctl disable hvm 2>/dev/null || true
pkill -f hvmV8.bin 2>/dev/null || true
rm -f /etc/systemd/system/hvm.service
systemctl daemon-reload 2>/dev/null || true
rm -rf /opt/hvm
rm -f /var/log/hvm.log
echo "✅ HVM Panel uninstalled!"
UNINSTALL_EOF
    chmod +x "${INSTALL_DIR}/uninstall.sh"

    cat > "${INSTALL_DIR}/restart.sh" << RESTART_EOF
#!/bin/bash
if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    systemctl restart ${SERVICE_NAME}
else
    pkill -f hvmV8.bin 2>/dev/null || true
    sleep 2
    nohup ${BIN_FILE} >> ${LOG_FILE} 2>&1 &
    echo \$! > ${INSTALL_DIR}/hvm.pid
fi
echo "✅ HVM Panel restarted!"
RESTART_EOF
    chmod +x "${INSTALL_DIR}/restart.sh"

    cat > "${INSTALL_DIR}/update.sh" << UPDATESCRIPT
#!/bin/bash
echo "🔄 Updating HVM Panel V8..."
systemctl stop ${SERVICE_NAME} 2>/dev/null || true
pkill -f hvmV8.bin 2>/dev/null || true
bash <(curl -fsSL ${INSTALLER_URL})
UPDATESCRIPT
    chmod +x "${INSTALL_DIR}/update.sh"

    ok "Scripts created!"
}

# =========================================================
# COMPLETION
# =========================================================

show_complete() {
    local PANEL_STATUS
    if command -v lsof >/dev/null 2>&1 && lsof -Pi :${PANEL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
        PANEL_STATUS="${GREEN}● ONLINE${NC}"
    elif command -v ss >/dev/null 2>&1 && ss -tulpn 2>/dev/null | grep -q ":${PANEL_PORT} "; then
        PANEL_STATUS="${GREEN}● ONLINE${NC}"
    else
        PANEL_STATUS="${YELLOW}○ STARTING...${NC}"
    fi

    local PUBLIC_IP
    PUBLIC_IP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null || true)
    if [[ -z "${PUBLIC_IP}" ]]; then
        PUBLIC_IP=$(curl -4 -s --max-time 10 api.ipify.org 2>/dev/null || true)
    fi
    if [[ -z "${PUBLIC_IP}" ]]; then
        PUBLIC_IP=$(curl -4 -s --max-time 10 icanhazip.com 2>/dev/null || true)
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

    if [[ "${IS_CLOUD_SHELL}" == true ]]; then
        echo
        echo -e "  ${YELLOW}╭──────────── ⚠️  Cloud Shell Notice ────────────────╮${NC}"
        echo -e "  ${YELLOW}│${NC}  ${WHITE}To access panel:${NC}"
        echo -e "  ${YELLOW}│${NC}  ${CYAN}Click 'Web Preview' icon → Change port to 5000${NC}"
        echo -e "  ${YELLOW}╰────────────────────────────────────────────────────╯${NC}"
    fi

    echo
    echo -e "  ${BLUE}╭──────────────── Service Commands ──────────────────╮${NC}"
    if [[ "${HAS_SYSTEMD}" == true ]]; then
        echo -e "  ${BLUE}│${NC}  ${GREEN}▶ Start${NC}    :  systemctl start ${SERVICE_NAME}"
        echo -e "  ${BLUE}│${NC}  ${RED}■ Stop${NC}     :  systemctl stop ${SERVICE_NAME}"
        echo -e "  ${BLUE}│${NC}  ${YELLOW}↻ Restart${NC}  :  systemctl restart ${SERVICE_NAME}"
        echo -e "  ${BLUE}│${NC}  ${CYAN}ℹ Status${NC}   :  systemctl status ${SERVICE_NAME}"
        echo -e "  ${BLUE}│${NC}  ${MAGENTA}📋 Logs${NC}    :  journalctl -u ${SERVICE_NAME} -f"
    else
        echo -e "  ${BLUE}│${NC}  ${GREEN}▶ Start${NC}    :  bash ${INSTALL_DIR}/restart.sh"
        echo -e "  ${BLUE}│${NC}  ${RED}■ Stop${NC}     :  pkill -f hvmV8.bin"
        echo -e "  ${BLUE}│${NC}  ${YELLOW}↻ Restart${NC}  :  bash ${INSTALL_DIR}/restart.sh"
        echo -e "  ${BLUE}│${NC}  ${MAGENTA}📋 Logs${NC}    :  tail -f ${LOG_FILE}"
    fi
    echo -e "  ${BLUE}╰────────────────────────────────────────────────────╯${NC}"

    echo
    echo -e "  ${RED}╭──────────────── 🔐 LICENSE NOTICE ─────────────────╮${NC}"
    echo -e "  ${RED}│${NC}  ${WHITE}${BOLD}⚠️  A valid license is required.${NC}"
    echo -e "  ${RED}│${NC}"
    echo -e "  ${RED}│${NC}  ${CYAN}Buy License: ${BLUE}${BOLD}${DISCORD_LINK}${NC}"
    echo -e "  ${RED}│${NC}"
    echo -e "  ${RED}│${NC}  ${YELLOW}Benefits: Full access, Updates, Support${NC}"
    echo -e "  ${RED}╰────────────────────────────────────────────────────╯${NC}"

    echo
    echo -e "  ${MAGENTA}╭──────────────── 💬 Support ──────────────────────────╮${NC}"
    echo -e "  ${MAGENTA}│${NC}  ${WHITE}Discord${NC}: ${BLUE}${BOLD}${DISCORD_LINK}${NC}"
    echo -e "  ${MAGENTA}│${NC}  ${WHITE}Brand${NC}  : ${CYAN}${BRAND_NAME}${NC}"
    echo -e "  ${MAGENTA}│${NC}  ${WHITE}Version${NC}: ${GREEN}${PANEL_VERSION}${NC}"
    echo -e "  ${MAGENTA}╰──────────────────────────────────────────────────────╯${NC}"

    echo
    echo -e "  ${GREEN}${BOLD}Thank you for choosing HVM Panel V8!${NC}"
    echo -e "  ${MAGENTA}Powered by ${BRAND_NAME} ☁️  | ${BLUE}${DISCORD_LINK}${NC}"
    echo
    line
    echo
}

# =========================================================
# MAIN
# =========================================================

main() {
    detect_environment
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

main "$@"
