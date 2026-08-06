#!/usr/bin/env bash

# =========================================================
# FAKECLOUD VPS PANEL SETUP INSTALLER
# LXC/LXD Container Environment Setup
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

DISCORD_LINK="https://dsc.gg/fakecloud"
BRAND_NAME="FakeCloud"
SCRIPT_VERSION="1.0"

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

check_installed() {
    local pkg="$1"
    if command -v "$pkg" >/dev/null 2>&1 || dpkg -l 2>/dev/null | grep -q "^ii  $pkg " || rpm -q "$pkg" >/dev/null 2>&1; then
        return 0
    fi
    return 1
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
    ║           VPS PANEL SETUP - CONTAINER ENVIRONMENT                    ║
    ║              LXC/LXD Installation for VPS Creation                   ║
    ║                                                                      ║
    ╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "  ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}${BOLD}  Version: ${CYAN}${SCRIPT_VERSION}${NC}   ${WHITE}│${NC}   ${WHITE}${BOLD}Discord: ${BLUE}${DISCORD_LINK}${NC}"
    echo -e "  ${MAGENTA}────────────────────────────────────────────────────────────────────────────${NC}"
    echo
}

# =========================================================
# ROOT CHECK
# =========================================================

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "Please run as root!"
        echo -e "  ${DIM}Run: ${WHITE}sudo bash installer.sh${NC}"
        exit 1
    fi
}

# =========================================================
# OS DETECTION
# =========================================================

detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        ok "OS Detected: ${PRETTY_NAME}"
    else
        error "Unable to detect OS!"
        exit 1
    fi
}

# =========================================================
# SYSTEM INFO
# =========================================================

show_system_info() {
    local cpu_model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown")
    local cpu_cores=$(nproc 2>/dev/null || echo "?")
    local total_ram=$(free -h | awk '/^Mem:/{print $2}')
    local free_ram=$(free -h | awk '/^Mem:/{print $7}')
    local disk_free=$(df -h / | awk 'NR==2{print $4}')
    
    echo -e "  ${CYAN}╭──────────────── System Information ────────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🖥️  CPU     :${NC} ${cpu_model:0:40} (${cpu_cores} cores)"
    echo -e "  ${CYAN}│${NC}  ${WHITE}💾 RAM     :${NC} ${free_ram} free / ${total_ram} total"
    echo -e "  ${CYAN}│${NC}  ${WHITE}💿 Disk    :${NC} ${disk_free} free"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🐧 OS      :${NC} ${PRETTY_NAME:-Unknown}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}🏗️  Arch    :${NC} $(uname -m)"
    echo -e "  ${CYAN}╰────────────────────────────────────────────────────╯${NC}"
    echo
}

# =========================================================
# UPDATE SYSTEM
# =========================================================

update_system() {
    step "1/8" "Updating System Packages"
    
    info "Updating package lists..."
    if command -v apt >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt update -y 2>&1 | tail -3
        apt upgrade -y 2>&1 | tail -3
    elif command -v dnf >/dev/null 2>&1; then
        dnf update -y 2>&1 | tail -3
    elif command -v yum >/dev/null 2>&1; then
        yum update -y 2>&1 | tail -3
    fi
    ok "System updated"
}

# =========================================================
# INSTALL BASIC TOOLS
# =========================================================

install_basic_tools() {
    step "2/8" "Installing Basic Tools"
    
    local packages=""
    
    if command -v apt >/dev/null 2>&1; then
        packages="curl wget git zip unzip nano htop net-tools ca-certificates gnupg software-properties-common apt-transport-https"
        info "Installing: curl, wget, git, zip, unzip, nano, htop..."
        apt install -y $packages 2>&1 | tail -3
    elif command -v dnf >/dev/null 2>&1; then
        packages="curl wget git zip unzip nano htop net-tools ca-certificates gnupg"
        dnf install -y $packages 2>&1 | tail -3
    elif command -v yum >/dev/null 2>&1; then
        packages="curl wget git zip unzip nano htop net-tools ca-certificates"
        yum install -y $packages 2>&1 | tail -3
    fi
    ok "Basic tools installed"
}

# =========================================================
# INSTALL PYTHON & SQLite
# =========================================================

install_python() {
    step "3/8" "Installing Python 3 & SQLite3"
    
    if command -v apt >/dev/null 2>&1; then
        info "Installing Python 3, pip, SQLite3..."
        apt install -y python3 python3-pip python3-venv python3-dev sqlite3 libsqlite3-dev 2>&1 | tail -3
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y python3 python3-pip python3-devel sqlite sqlite-devel 2>&1 | tail -3
    elif command -v yum >/dev/null 2>&1; then
        yum install -y python3 python3-pip python3-devel sqlite sqlite-devel 2>&1 | tail -3
    fi
    
    # Verify
    if command -v python3 >/dev/null 2>&1; then
        ok "Python: $(python3 --version)"
    fi
    if command -v sqlite3 >/dev/null 2>&1; then
        ok "SQLite: $(sqlite3 --version | cut -d' ' -f1)"
    fi
}

# =========================================================
# INSTALL SSH SERVER
# =========================================================

install_ssh() {
    step "4/8" "Installing OpenSSH Server"
    
    if command -v apt >/dev/null 2>&1; then
        info "Installing openssh-server..."
        apt install -y openssh-server 2>&1 | tail -3
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y openssh-server 2>&1 | tail -3
    elif command -v yum >/dev/null 2>&1; then
        yum install -y openssh-server 2>&1 | tail -3
    fi
    
    # Enable & start
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null
        systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null
    fi
    
    ok "SSH Server installed and running"
}

# =========================================================
# INSTALL NETWORK TOOLS
# =========================================================

install_network_tools() {
    step "5/8" "Installing Network Tools"
    
    if command -v apt >/dev/null 2>&1; then
        info "Installing iproute2, bridge-utils, iptables..."
        apt install -y iproute2 bridge-utils iptables iptables-persistent dnsmasq-base uidmap 2>&1 | tail -3
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y iproute bridge-utils iptables iptables-services dnsmasq shadow-utils 2>&1 | tail -3
    elif command -v yum >/dev/null 2>&1; then
        yum install -y iproute bridge-utils iptables iptables-services dnsmasq shadow-utils 2>&1 | tail -3
    fi
    
    ok "Network tools installed"
    ok "  - iproute2 (ip command)"
    ok "  - bridge-utils (network bridges)"
    ok "  - iptables (firewall)"
    ok "  - dnsmasq-base (DHCP/DNS)"
    ok "  - uidmap (user namespaces)"
}

# =========================================================
# INSTALL QEMU UTILS
# =========================================================

install_qemu() {
    step "6/8" "Installing QEMU Utils"
    
    if command -v apt >/dev/null 2>&1; then
        info "Installing qemu-utils, qemu-system, kvm..."
        apt install -y qemu-utils qemu-system qemu-kvm libvirt-daemon-system libvirt-clients virtinst 2>&1 | tail -3
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y qemu-img qemu-kvm libvirt virt-install 2>&1 | tail -3
    elif command -v yum >/dev/null 2>&1; then
        yum install -y qemu-img qemu-kvm libvirt virt-install 2>&1 | tail -3
    fi
    
    ok "QEMU utils installed"
    
    # Check KVM support
    if [[ -e /dev/kvm ]]; then
        ok "KVM support: ${GREEN}Enabled${NC}"
    else
        warn "KVM not available (may not be supported on this system)"
    fi
}

# =========================================================
# INSTALL LXC/LXD (Snap Method)
# =========================================================

install_lxc_lxd() {
    step "7/8" "Installing LXC & LXD"
    
    # Method 1: Try LXD via snap (Ubuntu recommended)
    if command -v apt >/dev/null 2>&1; then
        info "Installing LXC..."
        apt install -y lxc lxc-utils lxcfs 2>&1 | tail -3
        ok "LXC installed"
        
        # Install snapd if not present
        if ! command -v snap >/dev/null 2>&1; then
            info "Installing snapd..."
            apt install -y snapd 2>&1 | tail -3
            sleep 3
        fi
        
        # Install LXD via snap
        if command -v snap >/dev/null 2>&1; then
            info "Installing LXD (via snap)..."
            snap install lxd 2>&1 | tail -3
            
            # Wait for snap to be ready
            sleep 5
            
            # Add current user to lxd group
            if id "$SUDO_USER" &>/dev/null; then
                usermod -aG lxd "$SUDO_USER" 2>/dev/null || true
                ok "User ${SUDO_USER} added to lxd group"
            fi
            
            ok "LXD installed via snap"
        else
            # Fallback: Install Incus (LXD alternative)
            warn "Snap not available, installing Incus (LXD alternative)..."
            install_incus
        fi
    
    elif command -v dnf >/dev/null 2>&1; then
        info "Installing LXC on RHEL/Fedora..."
        dnf install -y lxc lxc-templates lxc-libs 2>&1 | tail -3
        ok "LXC installed"
        
        # Install Incus for RHEL-based systems
        install_incus
    
    elif command -v yum >/dev/null 2>&1; then
        info "Installing LXC on CentOS..."
        yum install -y epel-release
        yum install -y lxc lxc-templates lxc-libs 2>&1 | tail -3
        ok "LXC installed"
        
        install_incus
    fi
}

install_incus() {
    info "Installing Incus (modern LXD fork)..."
    
    if command -v apt >/dev/null 2>&1; then
        # Add Zabbly repository for Incus
        curl -fsSL https://pkgs.zabbly.com/key.asc | gpg --dearmor -o /etc/apt/keyrings/zabbly.gpg 2>/dev/null || true
        
        sh -c 'cat <<EOF > /etc/apt/sources.list.d/zabbly-incus-stable.sources
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: $(. /etc/os-release && echo ${VERSION_CODENAME})
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.gpg
EOF'
        
        apt update -y 2>&1 | tail -2
        apt install -y incus 2>&1 | tail -3
        ok "Incus installed"
    fi
}

# =========================================================
# FINAL SETUP & VERIFICATION
# =========================================================

final_setup() {
    step "8/8" "Final Setup & Verification"
    
    info "Enabling IP forwarding..."
    echo "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf >/dev/null
    echo "net.ipv6.conf.all.forwarding=1" | tee -a /etc/sysctl.conf >/dev/null
    sysctl -p >/dev/null 2>&1
    ok "IP forwarding enabled"
    
    info "Loading kernel modules..."
    modprobe br_netfilter 2>/dev/null || true
    modprobe overlay 2>/dev/null || true
    ok "Kernel modules loaded"
    
    # Enable & start services
    info "Enabling services..."
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable lxc 2>/dev/null || true
        systemctl start lxc 2>/dev/null || true
        systemctl enable lxc-net 2>/dev/null || true
        systemctl start lxc-net 2>/dev/null || true
        
        # LXD
        if command -v lxd >/dev/null 2>&1; then
            systemctl enable snap.lxd.daemon 2>/dev/null || true
            systemctl start snap.lxd.daemon 2>/dev/null || true
        fi
        
        # Incus
        if command -v incus >/dev/null 2>&1; then
            systemctl enable incus 2>/dev/null || true
            systemctl start incus 2>/dev/null || true
        fi
    fi
    ok "Services enabled"
    
    ok "All setup complete!"
}

# =========================================================
# VERIFICATION
# =========================================================

verify_installation() {
    show_logo
    echo -e "  ${BG_BLUE}${WHITE} 🔍 VERIFYING INSTALLATION ${NC}"
    echo
    
    local checks=(
        "python3:Python 3"
        "sqlite3:SQLite3"
        "ssh:OpenSSH Server"
        "git:Git"
        "curl:Curl"
        "wget:Wget"
        "zip:Zip"
        "unzip:Unzip"
        "ip:iproute2"
        "brctl:Bridge Utils"
        "iptables:Iptables"
        "dnsmasq:dnsmasq-base"
        "newuidmap:UIDMap"
        "qemu-img:QEMU Utils"
        "lxc-ls:LXC"
    )
    
    echo -e "  ${CYAN}╭──────────────── Installation Status ────────────────╮${NC}"
    for check in "${checks[@]}"; do
        IFS=':' read -r cmd name <<< "$check"
        if command -v "$cmd" >/dev/null 2>&1; then
            printf "  ${CYAN}│${NC}  ${GREEN}✅${NC} %-25s ${GREEN}Installed${NC}\n" "$name"
        else
            printf "  ${CYAN}│${NC}  ${YELLOW}⚠️${NC}  %-25s ${YELLOW}Not Found${NC}\n" "$name"
        fi
    done
    
    # Check LXD or Incus
    if command -v lxd >/dev/null 2>&1; then
        printf "  ${CYAN}│${NC}  ${GREEN}✅${NC} %-25s ${GREEN}Installed${NC}\n" "LXD"
    elif command -v incus >/dev/null 2>&1; then
        printf "  ${CYAN}│${NC}  ${GREEN}✅${NC} %-25s ${GREEN}Installed${NC}\n" "Incus (LXD alt)"
    else
        printf "  ${CYAN}│${NC}  ${YELLOW}⚠️${NC}  %-25s ${YELLOW}Not Found${NC}\n" "LXD/Incus"
    fi
    
    echo -e "  ${CYAN}╰─────────────────────────────────────────────────────╯${NC}"
}

# =========================================================
# COMPLETION SCREEN
# =========================================================

show_complete() {
    verify_installation
    
    echo
    echo -e "${GREEN}${BOLD}"
    cat << "EOF"

    ╔══════════════════════════════════════════════════════╗
    ║                                                      ║
    ║      ✅  VPS ENVIRONMENT SETUP COMPLETE!  ✅        ║
    ║                                                      ║
    ║              Powered by FakeCloud                    ║
    ║                                                      ║
    ╚══════════════════════════════════════════════════════╝

EOF
    echo -e "${NC}"
    
    echo -e "  ${CYAN}╭──────────────── Next Steps ─────────────────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}${BOLD}1. Initialize LXD:${NC}"
    echo -e "  ${CYAN}│${NC}     ${GREEN}sudo lxd init${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}${BOLD}2. Or Initialize Incus:${NC}"
    echo -e "  ${CYAN}│${NC}     ${GREEN}sudo incus admin init${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}${BOLD}3. Create your first container:${NC}"
    echo -e "  ${CYAN}│${NC}     ${GREEN}lxc launch ubuntu:22.04 test-vps${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}${BOLD}4. List containers:${NC}"
    echo -e "  ${CYAN}│${NC}     ${GREEN}lxc list${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}│${NC}  ${WHITE}${BOLD}5. Access container:${NC}"
    echo -e "  ${CYAN}│${NC}     ${GREEN}lxc exec test-vps -- bash${NC}"
    echo -e "  ${CYAN}│${NC}"
    echo -e "  ${CYAN}╰─────────────────────────────────────────────────────╯${NC}"
    
    echo
    echo -e "  ${YELLOW}╭──────────────── Important Notes ───────────────────╮${NC}"
    echo -e "  ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${WHITE}⚠️  Please REBOOT your system for full effect${NC}"
    echo -e "  ${YELLOW}│${NC}  ${WHITE}⚠️  Run: ${GREEN}sudo reboot${NC}"
    echo -e "  ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}│${NC}  ${WHITE}💡 After reboot, initialize LXD/Incus${NC}"
    echo -e "  ${YELLOW}│${NC}  ${WHITE}💡 Then install the panel (NVM or HVM)${NC}"
    echo -e "  ${YELLOW}│${NC}"
    echo -e "  ${YELLOW}╰────────────────────────────────────────────────────╯${NC}"
    
    echo
    echo -e "  ${MAGENTA}╭──────────────── Install Panel ────────────────────╮${NC}"
    echo -e "  ${MAGENTA}│${NC}"
    echo -e "  ${MAGENTA}│${NC}  ${WHITE}${BOLD}Install FakeCloud Panel:${NC}"
    echo -e "  ${MAGENTA}│${NC}  ${CYAN}bash <(curl -fsSL https://raw.githubusercontent.com/Basanta667/panel/main/HvmV8.sh)${NC}"
    echo -e "  ${MAGENTA}│${NC}"
    echo -e "  ${MAGENTA}╰────────────────────────────────────────────────────╯${NC}"
    
    echo
    echo -e "  ${BLUE}╭──────────────── Support ──────────────────────────╮${NC}"
    echo -e "  ${BLUE}│${NC}  ${WHITE}💬 Discord:${NC} ${BLUE}${DISCORD_LINK}${NC}"
    echo -e "  ${BLUE}│${NC}  ${WHITE}🌐 Brand:${NC} ${CYAN}${BRAND_NAME}${NC}"
    echo -e "  ${BLUE}╰────────────────────────────────────────────────────╯${NC}"
    
    echo
    line
    echo
    echo -e "  ${GREEN}${BOLD}Thank you for choosing FakeCloud!${NC}"
    echo
}

# =========================================================
# MAIN FUNCTION
# =========================================================

main() {
    show_logo
    check_root
    detect_os
    show_system_info
    
    line
    echo
    echo -e "  ${WHITE}${BOLD}This installer will setup:${NC}"
    echo
    echo -e "  ${GREEN}✅${NC} Python 3 & SQLite3"
    echo -e "  ${GREEN}✅${NC} OpenSSH Server"
    echo -e "  ${GREEN}✅${NC} Git, Curl, Wget, Zip, Unzip"
    echo -e "  ${GREEN}✅${NC} LXC & LXD (or Incus)"
    echo -e "  ${GREEN}✅${NC} Network Tools (iproute2, bridge-utils, iptables)"
    echo -e "  ${GREEN}✅${NC} dnsmasq-base, UIDMap"
    echo -e "  ${GREEN}✅${NC} QEMU Utils"
    echo
    warn "This may take 10-15 minutes."
    echo
    read -rp "  Continue? (y/n): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled"
        exit 0
    fi
    
    line
    
    update_system
    line
    install_basic_tools
    line
    install_python
    line
    install_ssh
    line
    install_network_tools
    line
    install_qemu
    line
    install_lxc_lxd
    line
    final_setup
    line
    show_complete
}

main "$@"
