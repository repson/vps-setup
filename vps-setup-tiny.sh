#!/bin/bash

################################################################################
# VPS Setup Script for Debian Stable
#
# This script configures a fresh Debian VPS with security hardening,
# development tools, and custom configurations.
#
# Usage:
#   1. Upload your SSH public key to the server first
#   2. Run remotely: ssh root@your-vps 'bash -s' < vps-setup.sh
#   3. Or copy and run: scp vps-setup.sh root@your-vps:~ && ssh root@your-vps 'bash ~/vps-setup.sh'
#
################################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
NEW_SSH_PORT=1022
MAIN_USER="${MAIN_USER:-debian}"  # Default to 'debian', override with env var
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"  # Set this before running or provide interactively

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

################################################################################
# Main Setup Functions
################################################################################

setup_user() {
    log_info "Setting up main user: $MAIN_USER"

    # Create user if doesn't exist
    if ! id "$MAIN_USER" &>/dev/null; then
        useradd -m -s /bin/bash -G sudo "$MAIN_USER"
        log_success "User $MAIN_USER created"

        # Set password (will prompt for it)
        passwd "$MAIN_USER"
    else
        log_info "User $MAIN_USER already exists"
    fi

    # Ensure user is in sudo group
    usermod -aG sudo "$MAIN_USER"
}

configure_ssh_keys() {
    log_info "Configuring SSH keys for $MAIN_USER"

    # Get SSH public key if not set
    if [ -z "$SSH_PUBLIC_KEY" ]; then
        log_warning "No SSH public key provided via SSH_PUBLIC_KEY environment variable"
        echo "Please paste your SSH public key (or press Enter to skip):"
        read -r SSH_PUBLIC_KEY
    fi

    if [ -n "$SSH_PUBLIC_KEY" ]; then
        # Setup .ssh directory
        local ssh_dir="/home/$MAIN_USER/.ssh"
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"

        # Add public key
        echo "$SSH_PUBLIC_KEY" >> "$ssh_dir/authorized_keys"
        chmod 600 "$ssh_dir/authorized_keys"
        chown -R "$MAIN_USER:$MAIN_USER" "$ssh_dir"

        log_success "SSH public key configured for $MAIN_USER"
    else
        log_warning "Skipping SSH key configuration - you'll need to add it manually"
    fi
}

configure_bash_prompt() {
    log_info "Configuring custom bash prompts with git support"

    # Install git-prompt if not available
    if [ ! -f /etc/bash_completion.d/git-prompt ]; then
        curl -so /etc/bash_completion.d/git-prompt \
            https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh 2>/dev/null || true
    fi

    # User prompt configuration (green and blue, Gentoo-style)
    cat >> "/home/$MAIN_USER/.bashrc" << 'EOF'

# Custom prompt configuration
if [ -f /etc/bash_completion.d/git-prompt ]; then
    source /etc/bash_completion.d/git-prompt
    GIT_PS1_SHOWDIRTYSTATE=1
    GIT_PS1_SHOWSTASHSTATE=1
    GIT_PS1_SHOWUNTRACKEDFILES=1
    GIT_PS1_SHOWUPSTREAM="auto"
    GIT_PS1_SHOWCOLORHINTS=1
fi

# User prompt: green username, blue path, git branch
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$(__git_ps1 " \[\033[01;33m\](%s)\[\033[00m\]") \$ '
EOF

    # Root prompt configuration (red and blue, Gentoo-style)
    cat >> /root/.bashrc << 'EOF'

# Custom root prompt configuration
if [ -f /etc/bash_completion.d/git-prompt ]; then
    source /etc/bash_completion.d/git-prompt
    GIT_PS1_SHOWDIRTYSTATE=1
    GIT_PS1_SHOWSTASHSTATE=1
    GIT_PS1_SHOWUNTRACKEDFILES=1
    GIT_PS1_SHOWUPSTREAM="auto"
    GIT_PS1_SHOWCOLORHINTS=1
fi

# Root prompt: red username, blue path, git branch
PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$(__git_ps1 " \[\033[01;33m\](%s)\[\033[00m\]") \$ '
EOF

    chown "$MAIN_USER:$MAIN_USER" "/home/$MAIN_USER/.bashrc"
    log_success "Bash prompts configured"
}

update_system() {
    log_info "Updating system packages"

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get upgrade -y
    apt-get dist-upgrade -y
    apt-get autoremove -y
    apt-get autoclean -y

    log_success "System updated"
}

install_packages() {
    log_info "Installing essential packages"

    export DEBIAN_FRONTEND=noninteractive

    # Essential packages
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        wget \
        gnupg \
        lsb-release \
        software-properties-common \
        build-essential \
        git \
        vim \
        nano \
        htop \
        tmux \
        screen \
        mc \
        tree \
        zip \
        unzip \
        net-tools \
        dnsutils \
        iptables \
        iptables-persistent \
        fail2ban \
        ufw \
        rsync \
        ncdu \
        jq \
        ripgrep \
        fd-find \
        bat \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        golang \
        sudo

    log_success "Essential packages installed"
}

install_tailscale() {
    log_info "Installing Tailscale"

    # Add Tailscale repository
    curl -fsSL https://pkgs.tailscale.com/stable/debian/$(lsb_release -cs).noarmor.gpg | \
        tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

    curl -fsSL https://pkgs.tailscale.com/stable/debian/$(lsb_release -cs).tailscale-keyring.list | \
        tee /etc/apt/sources.list.d/tailscale.list

    apt-get update
    apt-get install -y tailscale

    # Enable IP forwarding for exit node capability
    log_info "Enabling IP forwarding for Tailscale exit node"

    # Backup sysctl.conf
    cp /etc/sysctl.conf /etc/sysctl.conf.backup

    # Enable IP forwarding
    cat >> /etc/sysctl.conf << 'EOF'

# Enable IP forwarding for Tailscale exit node
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

    sysctl -p

    systemctl enable tailscaled
    systemctl start tailscaled

    log_success "Tailscale installed and IP forwarding enabled"
    log_info "Run 'tailscale up --advertise-exit-node' to configure as exit node"
}

configure_ssh() {
    log_info "Configuring SSH server (port $NEW_SSH_PORT)"

    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

    # Create new SSH config
    cat > /etc/ssh/sshd_config << EOF
# SSH Server Configuration - Hardened
Port $NEW_SSH_PORT

# Security settings
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*

# Connection settings
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Allow only specific users
AllowUsers $MAIN_USER

# Subsystem
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

    # Test SSH configuration
    sshd -t

    log_success "SSH configured (port $NEW_SSH_PORT, root login disabled, password auth disabled)"
    log_warning "SSH will restart at the end of the script. Make sure you have SSH key access!"
}

configure_firewall() {
    log_info "Configuring UFW firewall"

    # Reset UFW to defaults
    ufw --force reset

    # Default policies
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH on new port
    ufw allow "$NEW_SSH_PORT/tcp" comment 'SSH'

    # Allow Tailscale
    ufw allow 41641/udp comment 'Tailscale'

    # Enable firewall
    ufw --force enable

    log_success "Firewall configured"
}

configure_fail2ban() {
    log_info "Configuring Fail2ban"

    # Create local jail configuration
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = $NEW_SSH_PORT
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban

    log_success "Fail2ban configured"
}

disable_unnecessary_services() {
    log_info "Disabling unnecessary services"

    # List of services to disable (adjust based on your needs)
    local services_to_disable=(
        "bluetooth.service"
        "cups.service"
        "cups-browsed.service"
        "avahi-daemon.service"
        "ModemManager.service"
    )

    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" 2>/dev/null | grep -q enabled; then
            systemctl disable "$service" 2>/dev/null || true
            systemctl stop "$service" 2>/dev/null || true
            log_info "Disabled $service"
        fi
    done

    # Disable IPv6 if not needed
    log_info "Disabling IPv6"
    cat >> /etc/sysctl.conf << 'EOF'

# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    sysctl -p

    log_success "Unnecessary services disabled"
}

create_maintenance_scripts() {
    log_info "Creating maintenance scripts"

    # System update script
    cat > /usr/local/bin/sysupdate << 'EOF'
#!/bin/bash
# System update script

echo "Updating package lists..."
apt-get update

echo "Upgrading packages..."
apt-get upgrade -y

echo "Performing distribution upgrade..."
apt-get dist-upgrade -y

echo "Removing unnecessary packages..."
apt-get autoremove -y

echo "Cleaning package cache..."
apt-get autoclean -y

echo "System update completed!"
EOF

    chmod +x /usr/local/bin/sysupdate

    # Disk usage report script
    cat > /usr/local/bin/diskusage << 'EOF'
#!/bin/bash
# Disk usage report

echo "=== Disk Usage Report ==="
echo ""
df -h
echo ""
echo "=== Largest directories in /home ==="
du -h --max-depth=1 /home 2>/dev/null | sort -hr | head -10
echo ""
echo "=== Largest directories in /var ==="
du -h --max-depth=1 /var 2>/dev/null | sort -hr | head -10
EOF

    chmod +x /usr/local/bin/diskusage

    # System info script
    cat > /usr/local/bin/sysinfo << 'EOF'
#!/bin/bash
# System information script

echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Uptime: $(uptime -p)"
echo ""
echo "=== Memory Usage ==="
free -h
echo ""
echo "=== CPU Info ==="
lscpu | grep -E "^Model name|^CPU\(s\)|^Thread|^Core"
echo ""
echo "=== Network Interfaces ==="
ip -brief addr
echo ""
echo "=== Active Connections ==="
ss -tuln | grep LISTEN
EOF

    chmod +x /usr/local/bin/sysinfo

    # Backup script template
    cat > /usr/local/bin/backup-home << 'EOF'
#!/bin/bash
# Home directory backup script

BACKUP_DIR="/var/backups/home"
DATE=$(date +%Y%m%d_%H%M%S)
USER="${1:-debian}"

mkdir -p "$BACKUP_DIR"

echo "Backing up /home/$USER to $BACKUP_DIR/home_${USER}_${DATE}.tar.gz"
tar -czf "$BACKUP_DIR/home_${USER}_${DATE}.tar.gz" \
    --exclude='.cache' \
    --exclude='node_modules' \
    --exclude='.venv' \
    --exclude='__pycache__' \
    "/home/$USER" 2>/dev/null

echo "Backup completed!"
echo "Keeping only the last 5 backups..."
ls -t "$BACKUP_DIR"/home_${USER}_*.tar.gz | tail -n +6 | xargs -r rm

ls -lh "$BACKUP_DIR"
EOF

    chmod +x /usr/local/bin/backup-home

    log_success "Maintenance scripts created in /usr/local/bin/"
    log_info "Available commands: sysupdate, diskusage, sysinfo, backup-home"
}

configure_vim() {
    log_info "Configuring vim with sensible defaults"

    # User vim config
    cat > "/home/$MAIN_USER/.vimrc" << 'EOF'
" Sensible vim configuration
syntax on
set number
set relativenumber
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set autoindent
set smartindent
set hlsearch
set incsearch
set ignorecase
set smartcase
set showmatch
set ruler
set showcmd
set wildmenu
set wildmode=longest:full,full
set backspace=indent,eol,start
set clipboard=unnamedplus
set mouse=a
set encoding=utf-8
set fileencoding=utf-8
set termguicolors
set background=dark
colorscheme desert

" Line wrapping
set wrap
set linebreak

" File type detection
filetype plugin indent on

" Persistent undo
set undofile
set undodir=~/.vim/undodir
EOF

    mkdir -p "/home/$MAIN_USER/.vim/undodir"
    chown -R "$MAIN_USER:$MAIN_USER" "/home/$MAIN_USER/.vim" "/home/$MAIN_USER/.vimrc"

    # Root vim config
    cp "/home/$MAIN_USER/.vimrc" /root/.vimrc
    mkdir -p /root/.vim/undodir

    log_success "Vim configured"
}

configure_git() {
    log_info "Configuring git global settings"

    # User git config
    sudo -u "$MAIN_USER" git config --global init.defaultBranch main
    sudo -u "$MAIN_USER" git config --global core.editor vim
    sudo -u "$MAIN_USER" git config --global pull.rebase false
    sudo -u "$MAIN_USER" git config --global color.ui auto

    log_success "Git configured"
}

setup_automatic_security_updates() {
    log_info "Setting up automatic security updates"

    apt-get install -y unattended-upgrades apt-listchanges

    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    log_success "Automatic security updates configured"
}

create_motd() {
    log_info "Creating custom MOTD"

    # Disable default MOTD scripts
    chmod -x /etc/update-motd.d/* 2>/dev/null || true

    cat > /etc/motd << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                    VPS Custom Configuration                    ║
╚════════════════════════════════════════════════════════════════╝

Available maintenance commands:
  • sysupdate      - Update system packages
  • sysinfo        - Display system information
  • diskusage      - Show disk usage report
  • backup-home    - Backup home directory

Security notes:
  - SSH is running on port 1022
  - Password authentication is disabled
  - Root login is disabled
  - Fail2ban is active
  - UFW firewall is enabled

EOF

    log_success "Custom MOTD created"
}

configure_timezone_and_locale() {
    log_info "Configuring timezone and locale"

    # Set timezone (change to your preferred timezone)
    timedatectl set-timezone Europe/Madrid || timedatectl set-timezone UTC

    # Configure locale
    locale-gen es_ES.UTF-8 en_US.UTF-8
    update-locale LANG=en_US.UTF-8

    log_success "Timezone and locale configured"
}

optimize_system() {
    log_info "Applying system optimizations"

    # Add some performance tuning to sysctl
    cat >> /etc/sysctl.conf << 'EOF'

# Performance tuning
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Network optimizations
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr

# Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.tcp_syncookies = 1
EOF

    sysctl -p

    log_success "System optimizations applied"
}

final_steps() {
    log_info "Performing final steps"

    # Create a summary file
    cat > "/home/$MAIN_USER/SETUP_SUMMARY.txt" << EOF
VPS Setup Completed: $(date)

Configuration Summary:
======================

SSH Configuration:
  - Port: $NEW_SSH_PORT
  - Root login: Disabled
  - Password authentication: Disabled
  - Public key authentication: Enabled

User Account:
  - Username: $MAIN_USER
  - Sudo access: Enabled
  - Custom prompt: Configured (green/blue with git support)

Security:
  - UFW firewall: Enabled
  - Fail2ban: Active
  - Automatic security updates: Enabled

Installed Software:
  - Git, Vim, MC (Midnight Commander)
  - Python3 with pip and venv
  - Golang
  - Screen, Tmux
  - Tailscale (configured for exit node capability)
  - Network tools, htop, tree, jq, ripgrep, fd, bat
  - Build essentials

Maintenance Scripts:
  - sysupdate: Update system packages
  - sysinfo: Display system information
  - diskusage: Disk usage report
  - backup-home: Backup home directory

Next Steps:
===========
1. Configure Tailscale: tailscale up --advertise-exit-node
2. Set your git user: git config --global user.name "Your Name"
3. Set your git email: git config --global user.email "your@email.com"
4. Review firewall rules: ufw status
5. Check fail2ban: fail2ban-client status

Important:
==========
SSH is now on port $NEW_SSH_PORT
Connect with: ssh -p $NEW_SSH_PORT $MAIN_USER@your-server-ip

EOF

    chown "$MAIN_USER:$MAIN_USER" "/home/$MAIN_USER/SETUP_SUMMARY.txt"

    log_success "Setup summary created at /home/$MAIN_USER/SETUP_SUMMARY.txt"
}

restart_services() {
    log_info "Restarting services"

    systemctl restart sshd

    log_success "Services restarted"
    log_warning "SSH is now listening on port $NEW_SSH_PORT"
}

################################################################################
# Main Execution
################################################################################

main() {
    log_info "Starting VPS setup script"
    echo "========================================"

    check_root

    # Prompt for user if not set
    if [ -z "$MAIN_USER" ] || [ "$MAIN_USER" = "debian" ]; then
        read -p "Enter the main username [debian]: " input_user
        MAIN_USER="${input_user:-debian}"
    fi

    echo ""
    log_warning "This script will configure your VPS with the following:"
    log_warning "  - Create/configure user: $MAIN_USER"
    log_warning "  - SSH port: $NEW_SSH_PORT"
    log_warning "  - Disable root SSH login"
    log_warning "  - Disable password authentication"
    log_warning "  - Install and configure firewall"
    log_warning "  - Install development tools"
    echo ""
    read -p "Continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_error "Setup cancelled"
        exit 1
    fi

    echo ""
    log_info "Starting setup process..."
    echo "========================================"

    # Execute setup steps
    setup_user
    configure_ssh_keys
    update_system
    install_packages
    install_tailscale
    configure_bash_prompt
    configure_vim
    configure_git
    configure_timezone_and_locale
    create_maintenance_scripts
    configure_ssh
    configure_firewall
    configure_fail2ban
    disable_unnecessary_services
    optimize_system
    setup_automatic_security_updates
    create_motd
    final_steps

    echo ""
    log_success "========================================"
    log_success "VPS Setup Completed Successfully!"
    log_success "========================================"
    echo ""
    cat "/home/$MAIN_USER/SETUP_SUMMARY.txt"
    echo ""
    log_warning "IMPORTANT: SSH will be restarted now on port $NEW_SSH_PORT"
    log_warning "Make sure you can connect with SSH keys before closing this session!"
    echo ""
    read -p "Press Enter to restart SSH service..."

    restart_services

    log_success "All done! Please reconnect using: ssh -p $NEW_SSH_PORT $MAIN_USER@your-server-ip"
}

# Run main function
main "$@"
