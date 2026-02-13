#!/bin/bash

################################################################################
# VPS Setup Script for Debian Stable - Advanced Edition
#
# This script configures a fresh Debian VPS with extensive customization
# options controlled by a configuration file.
#
# Usage:
#   1. Edit vps-setup.conf to customize your setup
#   2. Run: ./vps-setup.sh [config-file]
#   3. Or remotely: cat vps-setup.conf vps-setup.sh | ssh root@vps 'cat > /tmp/setup.sh && bash /tmp/setup.sh /tmp/vps-setup.conf'
#
################################################################################

set -e  # Exit on any error
set -o pipefail

# Script version
VERSION="2.0.0"

# Default paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${1:-${SCRIPT_DIR}/vps-setup.conf}"
LOG_FILE="${LOG_FILE:-/var/log/vps-setup.log}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables for configuration
declare -A CONFIG

################################################################################
# Helper Functions
################################################################################

log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo -e "${message}" >&2

    if [[ "${CONFIG[CREATE_LOG]}" == "true" ]]; then
        echo "[${timestamp}] [${level}] ${message}" | sed 's/\x1b\[[0-9;]*m//g' >> "${LOG_FILE}"
    fi
}

log_info() {
    log "INFO" "${BLUE}[INFO]${NC} $@"
}

log_success() {
    log "SUCCESS" "${GREEN}[SUCCESS]${NC} $@"
}

log_warning() {
    log "WARNING" "${YELLOW}[WARNING]${NC} $@"
}

log_error() {
    log "ERROR" "${RED}[ERROR]${NC} $@"
}

log_debug() {
    if [[ "${CONFIG[VERBOSE]}" == "true" ]]; then
        log "DEBUG" "${CYAN}[DEBUG]${NC} $@"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

is_enabled() {
    local value="$1"
    [[ "$value" =~ ^(true|yes|1|on)$ ]]
}

is_disabled() {
    local value="$1"
    [[ "$value" =~ ^(false|no|0|off)$ ]] || [[ -z "$value" ]]
}

################################################################################
# Configuration Parser
################################################################################

load_config() {
    log_info "Loading configuration from: $CONFIG_FILE"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    local section=""
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # Detect section headers
        if [[ "$key" =~ ^\[(.+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi

        # Trim whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        # Store in associative array
        if [[ -n "$section" && -n "$key" ]]; then
            CONFIG["${key}"]="$value"
        fi
    done < "$CONFIG_FILE"

    log_success "Configuration loaded (${#CONFIG[@]} options)"

    # Set defaults for empty values
    set_defaults
}

set_defaults() {
    # Set default values for critical options if not specified
    : "${CONFIG[MAIN_USER]:=debian}"
    : "${CONFIG[SSH_PORT]:=1022}"
    : "${CONFIG[TIMEZONE]:=UTC}"
    : "${CONFIG[VERBOSE]:=true}"
    : "${CONFIG[CREATE_LOG]:=true}"
    : "${CONFIG[DRY_RUN]:=false}"
}

show_config_summary() {
    log_info "Configuration Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "User: ${CONFIG[MAIN_USER]}"
    echo "SSH Port: ${CONFIG[SSH_PORT]}"
    echo "Timezone: ${CONFIG[TIMEZONE]}"
    echo ""
    echo "Security:"
    echo "  - Firewall: $(is_enabled "${CONFIG[ENABLE_FIREWALL]}" && echo "✓" || echo "✗")"
    echo "  - Fail2ban: $(is_enabled "${CONFIG[ENABLE_FAIL2BAN]}" && echo "✓" || echo "✗")"
    echo "  - Auto Updates: $(is_enabled "${CONFIG[ENABLE_AUTO_UPDATES]}" && echo "✓" || echo "✗")"
    echo "  - Auditd: $(is_enabled "${CONFIG[ENABLE_AUDITD]}" && echo "✓" || echo "✗")"
    echo "  - Rkhunter: $(is_enabled "${CONFIG[ENABLE_RKHUNTER]}" && echo "✓" || echo "✗")"
    echo ""
    echo "Network:"
    echo "  - Tailscale: $(is_enabled "${CONFIG[INSTALL_TAILSCALE]}" && echo "✓" || echo "✗")"
    echo "  - WireGuard: $(is_enabled "${CONFIG[INSTALL_WIREGUARD]}" && echo "✓" || echo "✗")"
    echo ""
    echo "Development:"
    echo "  - Python: $(is_enabled "${CONFIG[INSTALL_PYTHON]}" && echo "✓" || echo "✗")"
    echo "  - Go: $(is_enabled "${CONFIG[INSTALL_GO]}" && echo "✓" || echo "✗")"
    echo "  - Node.js: $(is_enabled "${CONFIG[INSTALL_NODEJS]}" && echo "✓" || echo "✗")"
    echo "  - Docker: $(is_enabled "${CONFIG[INSTALL_DOCKER]}" && echo "✓" || echo "✗")"
    echo ""
    echo "Monitoring:"
    echo "  - Netdata: $(is_enabled "${CONFIG[ENABLE_NETDATA]}" && echo "✓" || echo "✗")"
    echo "  - Node Exporter: $(is_enabled "${CONFIG[ENABLE_NODE_EXPORTER]}" && echo "✓" || echo "✗")"
    echo "  - Sysstat: $(is_enabled "${CONFIG[ENABLE_SYSSTAT]}" && echo "✓" || echo "✗")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

run_command() {
    local description="$1"
    shift
    local command="$@"

    log_debug "Running: $command"

    if is_enabled "${CONFIG[DRY_RUN]}"; then
        log_info "[DRY RUN] Would execute: $command"
        return 0
    fi

    if [[ "${CONFIG[VERBOSE]}" == "true" ]]; then
        eval "$command"
    else
        eval "$command" >/dev/null 2>&1
    fi
}

################################################################################
# Main Setup Functions
################################################################################

setup_user() {
    local user="${CONFIG[MAIN_USER]}"
    log_info "Setting up main user: $user"

    if ! id "$user" &>/dev/null; then
        run_command "Create user" "useradd -m -s /bin/bash -G sudo '$user'"
        log_success "User $user created"

        if ! is_enabled "${CONFIG[SKIP_PROMPTS]}"; then
            passwd "$user"
        else
            log_warning "Skipping password setup (SKIP_PROMPTS=true)"
        fi
    else
        log_info "User $user already exists"
    fi

    run_command "Add to sudo group" "usermod -aG sudo '$user'"
}

configure_hostname() {
    local new_hostname="${CONFIG[HOSTNAME]}"

    if [[ -n "$new_hostname" ]]; then
        log_info "Setting hostname to: $new_hostname"
        run_command "Set hostname" "hostnamectl set-hostname '$new_hostname'"

        # Update /etc/hosts
        if ! is_enabled "${CONFIG[DRY_RUN]}"; then
            sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
        fi

        log_success "Hostname configured"
    fi
}

configure_ssh_keys() {
    local user="${CONFIG[MAIN_USER]}"
    local ssh_key="${CONFIG[SSH_PUBLIC_KEY]}"

    log_info "Configuring SSH keys for $user"

    if [[ -z "$ssh_key" ]] && ! is_enabled "${CONFIG[SKIP_PROMPTS]}"; then
        log_warning "No SSH public key provided"
        echo "Please paste your SSH public key (or press Enter to skip):"
        read -r ssh_key
    fi

    if [[ -n "$ssh_key" ]]; then
        local ssh_dir="/home/$user/.ssh"
        run_command "Create .ssh directory" "mkdir -p '$ssh_dir'"
        run_command "Set .ssh permissions" "chmod 700 '$ssh_dir'"

        if ! is_enabled "${CONFIG[DRY_RUN]}"; then
            echo "$ssh_key" >> "$ssh_dir/authorized_keys"
            chmod 600 "$ssh_dir/authorized_keys"
            chown -R "$user:$user" "$ssh_dir"
        fi

        log_success "SSH public key configured"
    else
        log_warning "Skipping SSH key configuration"
    fi
}

configure_bash_prompt() {
    if ! is_enabled "${CONFIG[CONFIGURE_PROMPTS]}"; then
        return 0
    fi

    local user="${CONFIG[MAIN_USER]}"
    log_info "Configuring custom bash prompts with git support"

    # Download git-prompt
    if [[ ! -f /etc/bash_completion.d/git-prompt ]]; then
        run_command "Download git-prompt" \
            "curl -fsSL -o /etc/bash_completion.d/git-prompt https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh"
    fi

    # User prompt
    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat >> "/home/$user/.bashrc" << 'EOF'

# Custom prompt configuration
if [ -f /etc/bash_completion.d/git-prompt ]; then
    source /etc/bash_completion.d/git-prompt
    GIT_PS1_SHOWDIRTYSTATE=1
    GIT_PS1_SHOWSTASHSTATE=1
    GIT_PS1_SHOWUNTRACKEDFILES=1
    GIT_PS1_SHOWUPSTREAM="auto"
    GIT_PS1_SHOWCOLORHINTS=1
fi

PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$(__git_ps1 " \[\033[01;33m\](%s)\[\033[00m\]") \$ '
EOF

        # Root prompt
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

PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$(__git_ps1 " \[\033[01;33m\](%s)\[\033[00m\]") \$ '
EOF

        chown "$user:$user" "/home/$user/.bashrc"
    fi

    log_success "Bash prompts configured"
}

install_shell_aliases() {
    if ! is_enabled "${CONFIG[INSTALL_ALIASES]}"; then
        return 0
    fi

    local user="${CONFIG[MAIN_USER]}"
    log_info "Installing useful shell aliases"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat >> "/home/$user/.bashrc" << 'EOF'

# Useful aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ports='netstat -tulanp'
alias update='sudo apt update && sudo apt upgrade -y'
alias myip='curl -s https://ipinfo.io/ip'
alias speedtest='curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'

# Safety
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
EOF

        chown "$user:$user" "/home/$user/.bashrc"
    fi

    log_success "Shell aliases installed"
}

update_system() {
    if ! is_enabled "${CONFIG[UPDATE_SYSTEM]}"; then
        return 0
    fi

    log_info "Updating system packages"

    export DEBIAN_FRONTEND=noninteractive
    run_command "apt update" "apt-get update"
    run_command "apt upgrade" "apt-get upgrade -y"
    run_command "apt dist-upgrade" "apt-get dist-upgrade -y"
    run_command "apt autoremove" "apt-get autoremove -y"
    run_command "apt autoclean" "apt-get autoclean -y"

    log_success "System updated"
}

install_essential_packages() {
    if ! is_enabled "${CONFIG[INSTALL_ESSENTIALS]}"; then
        return 0
    fi

    log_info "Installing essential packages"

    export DEBIAN_FRONTEND=noninteractive

    local packages=(
        apt-transport-https
        ca-certificates
        curl
        wget
        gnupg
        lsb-release
        software-properties-common
        build-essential
        sudo
    )

    is_enabled "${CONFIG[INSTALL_GIT]}" && packages+=(git)
    is_enabled "${CONFIG[INSTALL_VIM]}" && packages+=(vim)
    packages+=(nano)
    is_enabled "${CONFIG[INSTALL_HTOP]}" && packages+=(htop)
    is_enabled "${CONFIG[INSTALL_TMUX]}" && packages+=(tmux)
    is_enabled "${CONFIG[INSTALL_SCREEN]}" && packages+=(screen)
    is_enabled "${CONFIG[INSTALL_MC]}" && packages+=(mc)

    if is_enabled "${CONFIG[INSTALL_MODERN_TOOLS]}"; then
        packages+=(tree zip unzip ncdu jq ripgrep fd-find bat)
    fi

    if is_enabled "${CONFIG[INSTALL_NET_TOOLS]}"; then
        packages+=(net-tools dnsutils iptables iptables-persistent rsync mtr-tiny iperf3 nmap traceroute)
    fi

    run_command "Install packages" "apt-get install -y ${packages[*]}"

    log_success "Essential packages installed"
}

install_python() {
    if ! is_enabled "${CONFIG[INSTALL_PYTHON]}"; then
        return 0
    fi

    log_info "Installing Python development tools"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Python" "apt-get install -y python3 python3-pip python3-venv python3-dev"

    log_success "Python installed"
}

install_go() {
    if ! is_enabled "${CONFIG[INSTALL_GO]}"; then
        return 0
    fi

    log_info "Installing Go"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Go" "apt-get install -y golang"

    log_success "Go installed"
}

install_nodejs() {
    if ! is_enabled "${CONFIG[INSTALL_NODEJS]}"; then
        return 0
    fi

    log_info "Installing Node.js (${CONFIG[NODEJS_VERSION]:-lts})"

    local version="${CONFIG[NODEJS_VERSION]:-lts}"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        curl -fsSL https://deb.nodesource.com/setup_${version}.x | bash -
        apt-get install -y nodejs
    fi

    log_success "Node.js installed"
}

install_rust() {
    if ! is_enabled "${CONFIG[INSTALL_RUST]}"; then
        return 0
    fi

    local user="${CONFIG[MAIN_USER]}"
    log_info "Installing Rust"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        sudo -u "$user" bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
    fi

    log_success "Rust installed"
}

install_docker() {
    if ! is_enabled "${CONFIG[INSTALL_DOCKER]}"; then
        return 0
    fi

    log_info "Installing Docker"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        # Add Docker's official GPG key
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        # Add repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

        if is_enabled "${CONFIG[DOCKER_USER_ACCESS]}"; then
            usermod -aG docker "${CONFIG[MAIN_USER]}"
        fi

        if is_enabled "${CONFIG[INSTALL_DOCKER_COMPOSE]}"; then
            apt-get install -y docker-compose-plugin
        fi

        systemctl enable docker
        systemctl start docker
    fi

    log_success "Docker installed"
}

install_podman() {
    if ! is_enabled "${CONFIG[INSTALL_PODMAN]}"; then
        return 0
    fi

    log_info "Installing Podman"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Podman" "apt-get install -y podman"

    log_success "Podman installed"
}

install_tailscale() {
    if ! is_enabled "${CONFIG[INSTALL_TAILSCALE]}"; then
        return 0
    fi

    log_info "Installing Tailscale"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        curl -fsSL https://pkgs.tailscale.com/stable/debian/$(lsb_release -cs).noarmor.gpg | \
            tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

        curl -fsSL https://pkgs.tailscale.com/stable/debian/$(lsb_release -cs).tailscale-keyring.list | \
            tee /etc/apt/sources.list.d/tailscale.list

        apt-get update
        apt-get install -y tailscale

        systemctl enable tailscaled
        systemctl start tailscaled
    fi

    log_success "Tailscale installed"

    if is_enabled "${CONFIG[TAILSCALE_EXIT_NODE]}"; then
        log_info "Run 'tailscale up --advertise-exit-node' to enable exit node"
    fi
}

install_wireguard() {
    if ! is_enabled "${CONFIG[INSTALL_WIREGUARD]}"; then
        return 0
    fi

    log_info "Installing WireGuard"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install WireGuard" "apt-get install -y wireguard wireguard-tools"

    log_success "WireGuard installed"
}

install_cloudflared() {
    if ! is_enabled "${CONFIG[INSTALL_CLOUDFLARED]}"; then
        return 0
    fi

    log_info "Installing cloudflared (DNS-over-HTTPS)"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        wget -O /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
        chmod +x /usr/local/bin/cloudflared

        # Create systemd service
        cat > /etc/systemd/system/cloudflared.service << 'EOF'
[Unit]
Description=cloudflared DNS over HTTPS proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared proxy-dns --port 5053 --upstream https://1.1.1.1/dns-query --upstream https://1.0.0.1/dns-query
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable cloudflared
        systemctl start cloudflared
    fi

    log_success "Cloudflared installed"
}

configure_ssh() {
    if ! is_enabled "${CONFIG[ENABLE]}"; then
        return 0
    fi

    local port="${CONFIG[SSH_PORT]}"
    local user="${CONFIG[MAIN_USER]}"

    log_info "Configuring SSH server (port $port)"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

        cat > /etc/ssh/sshd_config << EOF
# SSH Server Configuration - Hardened
Port $port

# Security settings
PermitRootLogin $(is_enabled "${CONFIG[DISABLE_ROOT_LOGIN]}" && echo "no" || echo "yes")
PasswordAuthentication $(is_enabled "${CONFIG[DISABLE_PASSWORD_AUTH]}" && echo "no" || echo "yes")
PubkeyAuthentication $(is_enabled "${CONFIG[ENABLE_PUBKEY_AUTH]}" && echo "yes" || echo "no")
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*

# Connection settings
ClientAliveInterval ${CONFIG[CLIENT_ALIVE_INTERVAL]:-300}
ClientAliveCountMax ${CONFIG[CLIENT_ALIVE_COUNT_MAX]:-2}
MaxAuthTries ${CONFIG[MAX_AUTH_TRIES]:-3}
MaxSessions 10

# Logging
SyslogFacility AUTH
LogLevel $(is_enabled "${CONFIG[VERBOSE_LOGGING]}" && echo "VERBOSE" || echo "INFO")

# Allow only specific users
AllowUsers $user

# Subsystem
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

        sshd -t
    fi

    log_success "SSH configured"
}

configure_ssh_2fa() {
    if ! is_enabled "${CONFIG[ENABLE_2FA]}"; then
        return 0
    fi

    log_info "Configuring SSH 2FA with Google Authenticator"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install libpam-google-authenticator" "apt-get install -y libpam-google-authenticator"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        # Configure PAM
        if ! grep -q "pam_google_authenticator.so" /etc/pam.d/sshd; then
            echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
        fi

        # Update SSH config
        sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config

        if ! grep -q "AuthenticationMethods" /etc/ssh/sshd_config; then
            echo "AuthenticationMethods publickey,keyboard-interactive" >> /etc/ssh/sshd_config
        fi
    fi

    log_success "2FA configured (users need to run: google-authenticator)"
}

configure_firewall() {
    if ! is_enabled "${CONFIG[ENABLE_FIREWALL]}"; then
        return 0
    fi

    log_info "Configuring UFW firewall"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install UFW" "apt-get install -y ufw"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing

        ufw allow "${CONFIG[SSH_PORT]}/tcp" comment 'SSH'

        is_enabled "${CONFIG[INSTALL_TAILSCALE]}" && ufw allow 41641/udp comment 'Tailscale'
        is_enabled "${CONFIG[INSTALL_NGINX]}" && ufw allow 80/tcp comment 'HTTP' && ufw allow 443/tcp comment 'HTTPS'

        ufw --force enable
    fi

    log_success "Firewall configured"
}

configure_fail2ban() {
    if ! is_enabled "${CONFIG[ENABLE_FAIL2BAN]}"; then
        return 0
    fi

    log_info "Configuring Fail2ban"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Fail2ban" "apt-get install -y fail2ban"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = ${CONFIG[FAIL2BAN_BANTIME]:-7200}
findtime = 600
maxretry = ${CONFIG[FAIL2BAN_MAXRETRY]:-3}
destemail = ${CONFIG[ALERT_EMAIL]:-root@localhost}
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = ${CONFIG[SSH_PORT]}
logpath = /var/log/auth.log
maxretry = ${CONFIG[FAIL2BAN_MAXRETRY]:-3}
bantime = ${CONFIG[FAIL2BAN_BANTIME]:-7200}
EOF

        systemctl enable fail2ban
        systemctl restart fail2ban
    fi

    log_success "Fail2ban configured"
}

enable_apparmor() {
    if ! is_enabled "${CONFIG[ENABLE_APPARMOR]}"; then
        return 0
    fi

    log_info "Enabling AppArmor"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install AppArmor" "apt-get install -y apparmor apparmor-utils"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        systemctl enable apparmor
        systemctl start apparmor
    fi

    log_success "AppArmor enabled"
}

enable_auditd() {
    if ! is_enabled "${CONFIG[ENABLE_AUDITD]}"; then
        return 0
    fi

    log_info "Installing and configuring Auditd"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Auditd" "apt-get install -y auditd audispd-plugins"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        systemctl enable auditd
        systemctl start auditd

        # Add some basic audit rules
        cat >> /etc/audit/rules.d/audit.rules << 'EOF'
# Monitor changes to system files
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/sudoers -p wa -k sudoers_changes

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes

# Monitor authentication
-w /var/log/auth.log -p wa -k auth_log_changes
EOF

        augenrules --load
    fi

    log_success "Auditd configured"
}

install_rkhunter() {
    if ! is_enabled "${CONFIG[ENABLE_RKHUNTER]}"; then
        return 0
    fi

    log_info "Installing rkhunter (rootkit detection)"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install rkhunter" "apt-get install -y rkhunter"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        rkhunter --update
        rkhunter --propupd
    fi

    log_success "Rkhunter installed"
}

install_clamav() {
    if ! is_enabled "${CONFIG[ENABLE_CLAMAV]}"; then
        return 0
    fi

    log_info "Installing ClamAV antivirus"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install ClamAV" "apt-get install -y clamav clamav-daemon"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        systemctl stop clamav-freshclam
        freshclam
        systemctl start clamav-freshclam
        systemctl enable clamav-daemon
        systemctl start clamav-daemon
    fi

    log_success "ClamAV installed"
}

install_aide() {
    if ! is_enabled "${CONFIG[ENABLE_AIDE]}"; then
        return 0
    fi

    log_info "Installing AIDE (intrusion detection)"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install AIDE" "apt-get install -y aide aide-common"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        aideinit
        mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    fi

    log_success "AIDE installed"
}

install_logwatch() {
    if ! is_enabled "${CONFIG[ENABLE_LOGWATCH]}"; then
        return 0
    fi

    log_info "Installing Logwatch"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Logwatch" "apt-get install -y logwatch"

    if ! is_enabled "${CONFIG[DRY_RUN]}" && [[ -n "${CONFIG[ALERT_EMAIL]}" ]]; then
        sed -i "s/MailTo = .*/MailTo = ${CONFIG[ALERT_EMAIL]}/" /etc/logwatch/conf/logwatch.conf
    fi

    log_success "Logwatch installed"
}

configure_automatic_updates() {
    if ! is_enabled "${CONFIG[ENABLE_AUTO_UPDATES]}"; then
        return 0
    fi

    log_info "Configuring automatic security updates"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install unattended-upgrades" "apt-get install -y unattended-upgrades apt-listchanges"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
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
    fi

    log_success "Automatic updates configured"
}

disable_unnecessary_services() {
    if ! is_enabled "${CONFIG[DISABLE_UNNECESSARY_SERVICES]}"; then
        return 0
    fi

    log_info "Disabling unnecessary services"

    local services_to_disable=(
        "bluetooth.service"
        "cups.service"
        "cups-browsed.service"
        "avahi-daemon.service"
        "ModemManager.service"
    )

    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" 2>/dev/null | grep -q enabled; then
            run_command "Disable $service" "systemctl disable '$service' && systemctl stop '$service'"
            log_info "Disabled $service"
        fi
    done

    log_success "Unnecessary services disabled"
}

configure_kernel_hardening() {
    if ! is_enabled "${CONFIG[ENABLE_KERNEL_HARDENING]}"; then
        return 0
    fi

    log_info "Applying kernel hardening"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat >> /etc/sysctl.conf << 'EOF'

# Kernel Hardening
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
kernel.kexec_load_disabled = 1

# Network hardening
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF

        sysctl -p
    fi

    log_success "Kernel hardening applied"
}

disable_ipv6() {
    if ! is_enabled "${CONFIG[DISABLE_IPV6]}"; then
        return 0
    fi

    log_info "Disabling IPv6"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat >> /etc/sysctl.conf << 'EOF'

# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

        sysctl -p
    fi

    log_success "IPv6 disabled"
}

secure_tmp() {
    if ! is_enabled "${CONFIG[SECURE_TMP]}"; then
        return 0
    fi

    log_info "Securing /tmp with noexec"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        if ! grep -q "tmpfs /tmp tmpfs" /etc/fstab; then
            echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
        fi
    fi

    log_success "/tmp secured"
}

disable_core_dumps() {
    if ! is_enabled "${CONFIG[DISABLE_CORE_DUMPS]}"; then
        return 0
    fi

    log_info "Disabling core dumps"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        echo "* hard core 0" >> /etc/security/limits.conf
        echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
        sysctl -p
    fi

    log_success "Core dumps disabled"
}

configure_swap() {
    local swap_size="${CONFIG[SWAP_SIZE]:-0}"

    if [[ "$swap_size" -eq 0 ]]; then
        return 0
    fi

    log_info "Configuring swap (${swap_size}MB)"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        if ! swapon --show | grep -q /swapfile; then
            fallocate -l "${swap_size}M" /swapfile
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo "/swapfile none swap sw 0 0" >> /etc/fstab
        fi
    fi

    log_success "Swap configured"
}

configure_journal() {
    local size="${CONFIG[JOURNAL_SIZE_LIMIT]:-0}"

    if [[ "$size" -eq 0 ]]; then
        return 0
    fi

    log_info "Configuring systemd journal size limit (${size}MB)"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        mkdir -p /etc/systemd/journald.conf.d
        cat > /etc/systemd/journald.conf.d/size-limit.conf << EOF
[Journal]
SystemMaxUse=${size}M
EOF

        systemctl restart systemd-journald
    fi

    log_success "Journal size limit configured"
}

install_etckeeper() {
    if ! is_enabled "${CONFIG[ENABLE_ETCKEEPER]}"; then
        return 0
    fi

    log_info "Installing etckeeper (version control for /etc)"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install etckeeper" "apt-get install -y etckeeper"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        etckeeper init
        etckeeper commit "Initial commit by vps-setup script"
    fi

    log_success "Etckeeper installed"
}

apply_system_optimizations() {
    if ! is_enabled "${CONFIG[APPLY_OPTIMIZATIONS]}"; then
        return 0
    fi

    log_info "Applying system optimizations"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
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
net.core.default_qdisc = fq
EOF

        sysctl -p
    fi

    log_success "System optimizations applied"
}

enable_ip_forwarding() {
    if ! is_enabled "${CONFIG[TAILSCALE_EXIT_NODE]}" && ! is_enabled "${CONFIG[INSTALL_WIREGUARD]}"; then
        return 0
    fi

    log_info "Enabling IP forwarding"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat >> /etc/sysctl.conf << 'EOF'

# Enable IP forwarding
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

        sysctl -p
    fi

    log_success "IP forwarding enabled"
}

configure_timezone() {
    local tz="${CONFIG[TIMEZONE]}"

    log_info "Setting timezone to: $tz"

    run_command "Set timezone" "timedatectl set-timezone '$tz'"

    log_success "Timezone configured"
}

configure_locale() {
    local locales="${CONFIG[LOCALES]}"
    local default_locale="${CONFIG[DEFAULT_LOCALE]}"

    log_info "Configuring locales: $locales"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        for locale in $locales; do
            locale-gen "$locale"
        done

        update-locale "LANG=$default_locale"
    fi

    log_success "Locales configured"
}

install_zsh() {
    if ! is_enabled "${CONFIG[INSTALL_ZSH]}"; then
        return 0
    fi

    local user="${CONFIG[MAIN_USER]}"
    log_info "Installing zsh"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install zsh" "apt-get install -y zsh"

    if is_enabled "${CONFIG[INSTALL_OH_MY_ZSH]}" && ! is_enabled "${CONFIG[DRY_RUN]}"; then
        sudo -u "$user" bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        chsh -s /bin/zsh "$user"
    fi

    log_success "Zsh installed"
}

install_starship() {
    if ! is_enabled "${CONFIG[INSTALL_STARSHIP]}"; then
        return 0
    fi

    log_info "Installing Starship prompt"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        curl -sS https://starship.rs/install.sh | sh -s -- -y

        # Add to bashrc
        local user="${CONFIG[MAIN_USER]}"
        echo 'eval "$(starship init bash)"' >> "/home/$user/.bashrc"
        chown "$user:$user" "/home/$user/.bashrc"
    fi

    log_success "Starship installed"
}

install_fzf() {
    if ! is_enabled "${CONFIG[INSTALL_FZF]}"; then
        return 0
    fi

    local user="${CONFIG[MAIN_USER]}"
    log_info "Installing fzf (fuzzy finder)"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        sudo -u "$user" bash -c "git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all"
    fi

    log_success "fzf installed"
}

install_direnv() {
    if ! is_enabled "${CONFIG[INSTALL_DIRENV]}"; then
        return 0
    fi

    log_info "Installing direnv"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install direnv" "apt-get install -y direnv"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        local user="${CONFIG[MAIN_USER]}"
        echo 'eval "$(direnv hook bash)"' >> "/home/$user/.bashrc"
        chown "$user:$user" "/home/$user/.bashrc"
    fi

    log_success "direnv installed"
}

install_nginx() {
    if ! is_enabled "${CONFIG[INSTALL_NGINX]}"; then
        return 0
    fi

    log_info "Installing Nginx"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Nginx" "apt-get install -y nginx"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        systemctl enable nginx
        systemctl start nginx
    fi

    log_success "Nginx installed"
}

install_caddy() {
    if ! is_enabled "${CONFIG[INSTALL_CADDY]}"; then
        return 0
    fi

    log_info "Installing Caddy"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
        apt-get update
        apt-get install -y caddy

        systemctl enable caddy
        systemctl start caddy
    fi

    log_success "Caddy installed"
}

install_certbot() {
    if ! is_enabled "${CONFIG[INSTALL_CERTBOT]}"; then
        return 0
    fi

    log_info "Installing Certbot"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Certbot" "apt-get install -y certbot"

    if is_enabled "${CONFIG[INSTALL_NGINX]}"; then
        run_command "Install Certbot Nginx plugin" "apt-get install -y python3-certbot-nginx"
    fi

    log_success "Certbot installed"
}

install_postgresql() {
    if ! is_enabled "${CONFIG[INSTALL_POSTGRESQL]}"; then
        return 0
    fi

    log_info "Installing PostgreSQL"

    export DEBIAN_FRONTEND=noninteractive

    if [[ -n "${CONFIG[POSTGRESQL_VERSION]}" ]]; then
        run_command "Install PostgreSQL ${CONFIG[POSTGRESQL_VERSION]}" "apt-get install -y postgresql-${CONFIG[POSTGRESQL_VERSION]}"
    else
        run_command "Install PostgreSQL" "apt-get install -y postgresql postgresql-contrib"
    fi

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        systemctl enable postgresql
        systemctl start postgresql
    fi

    log_success "PostgreSQL installed"
}

install_mariadb() {
    if ! is_enabled "${CONFIG[INSTALL_MARIADB]}"; then
        return 0
    fi

    log_info "Installing MariaDB"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install MariaDB" "apt-get install -y mariadb-server mariadb-client"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        systemctl enable mariadb
        systemctl start mariadb
    fi

    log_success "MariaDB installed (run mysql_secure_installation manually)"
}

install_redis() {
    if ! is_enabled "${CONFIG[INSTALL_REDIS]}"; then
        return 0
    fi

    log_info "Installing Redis"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Redis" "apt-get install -y redis-server"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        if is_enabled "${CONFIG[REDIS_CACHE_ONLY]}"; then
            sed -i 's/^save/#save/g' /etc/redis/redis.conf
            echo "maxmemory-policy allkeys-lru" >> /etc/redis/redis.conf
        fi

        systemctl enable redis-server
        systemctl start redis-server
    fi

    log_success "Redis installed"
}

install_netdata() {
    if ! is_enabled "${CONFIG[ENABLE_NETDATA]}"; then
        return 0
    fi

    log_info "Installing Netdata"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait --stable-channel
    fi

    log_success "Netdata installed (accessible at http://server-ip:19999)"
}

install_node_exporter() {
    if ! is_enabled "${CONFIG[ENABLE_NODE_EXPORTER]}"; then
        return 0
    fi

    log_info "Installing Prometheus Node Exporter"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Node Exporter" "apt-get install -y prometheus-node-exporter"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        systemctl enable prometheus-node-exporter
        systemctl start prometheus-node-exporter
    fi

    log_success "Node Exporter installed (port 9100)"
}

install_monit() {
    if ! is_enabled "${CONFIG[ENABLE_MONIT]}"; then
        return 0
    fi

    log_info "Installing Monit"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Monit" "apt-get install -y monit"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat > /etc/monit/conf.d/system << EOF
check system \$HOST
    if loadavg (1min) per core > 2 for 5 cycles then alert
    if loadavg (5min) per core > 1.5 for 10 cycles then alert
    if cpu usage > 95% for 10 cycles then alert
    if memory usage > 90% then alert

check filesystem rootfs with path /
    if space usage > 80% then alert
EOF

        systemctl enable monit
        systemctl start monit
    fi

    log_success "Monit installed"
}

install_sysstat() {
    if ! is_enabled "${CONFIG[ENABLE_SYSSTAT]}"; then
        return 0
    fi

    log_info "Installing sysstat"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install sysstat" "apt-get install -y sysstat"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
        systemctl enable sysstat
        systemctl start sysstat
    fi

    log_success "Sysstat installed"
}

install_restic() {
    if ! is_enabled "${CONFIG[INSTALL_RESTIC]}"; then
        return 0
    fi

    log_info "Installing Restic"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Restic" "apt-get install -y restic"

    log_success "Restic installed"
}

install_borg() {
    if ! is_enabled "${CONFIG[INSTALL_BORG]}"; then
        return 0
    fi

    log_info "Installing Borg Backup"

    export DEBIAN_FRONTEND=noninteractive
    run_command "Install Borg" "apt-get install -y borgbackup"

    log_success "Borg installed"
}

configure_mail() {
    if ! is_enabled "${CONFIG[ENABLE_MAIL]}"; then
        return 0
    fi

    local agent="${CONFIG[MAIL_AGENT]}"

    log_info "Configuring mail ($agent)"

    if [[ "$agent" == "msmtp" ]]; then
        export DEBIAN_FRONTEND=noninteractive
        run_command "Install msmtp" "apt-get install -y msmtp msmtp-mta mailutils"

        if ! is_enabled "${CONFIG[DRY_RUN]}" && [[ -n "${CONFIG[SMTP_SERVER]}" ]]; then
            cat > /etc/msmtprc << EOF
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /var/log/msmtp.log

account default
host ${CONFIG[SMTP_SERVER]}
port ${CONFIG[SMTP_PORT]:-587}
from ${CONFIG[MAIL_FROM]}
user ${CONFIG[SMTP_USER]}
password ${CONFIG[SMTP_PASSWORD]}
EOF

            chmod 600 /etc/msmtprc
        fi
    elif [[ "$agent" == "postfix" ]]; then
        export DEBIAN_FRONTEND=noninteractive
        run_command "Install Postfix" "apt-get install -y postfix mailutils"
    fi

    log_success "Mail configured"
}

configure_vim() {
    if ! is_enabled "${CONFIG[INSTALL_VIM]}"; then
        return 0
    fi

    local user="${CONFIG[MAIN_USER]}"
    log_info "Configuring vim"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat > "/home/$user/.vimrc" << 'EOF'
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
set mouse=a
set encoding=utf-8
set fileencoding=utf-8
colorscheme desert

filetype plugin indent on

set undofile
set undodir=~/.vim/undodir
EOF

        mkdir -p "/home/$user/.vim/undodir"
        chown -R "$user:$user" "/home/$user/.vim" "/home/$user/.vimrc"

        cp "/home/$user/.vimrc" /root/.vimrc
        mkdir -p /root/.vim/undodir
    fi

    log_success "Vim configured"
}

configure_git() {
    if ! is_enabled "${CONFIG[INSTALL_GIT]}"; then
        return 0
    fi

    local user="${CONFIG[MAIN_USER]}"
    log_info "Configuring git"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        sudo -u "$user" git config --global init.defaultBranch main
        sudo -u "$user" git config --global core.editor vim
        sudo -u "$user" git config --global pull.rebase false
        sudo -u "$user" git config --global color.ui auto
    fi

    log_success "Git configured"
}

create_maintenance_scripts() {
    if ! is_enabled "${CONFIG[CREATE_SCRIPTS]}"; then
        return 0
    fi

    log_info "Creating maintenance scripts"

    if is_enabled "${CONFIG[CREATE_UPDATE_SCRIPT]}" && ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat > /usr/local/bin/sysupdate << 'EOF'
#!/bin/bash
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
    fi

    if is_enabled "${CONFIG[CREATE_DISKUSAGE_SCRIPT]}" && ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat > /usr/local/bin/diskusage << 'EOF'
#!/bin/bash
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
    fi

    if is_enabled "${CONFIG[CREATE_SYSINFO_SCRIPT]}" && ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat > /usr/local/bin/sysinfo << 'EOF'
#!/bin/bash
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
    fi

    if is_enabled "${CONFIG[CREATE_BACKUP_SCRIPT]}" && ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat > /usr/local/bin/backup-home << 'EOF'
#!/bin/bash
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
    fi

    if is_enabled "${CONFIG[CREATE_HEALTHCHECK_SCRIPT]}" && ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat > /usr/local/bin/healthcheck << 'EOF'
#!/bin/bash
echo "=== System Health Check ==="
echo ""

# Check disk space
echo "Disk Usage:"
df -h / | tail -1 | awk '{print "  Root: " $5 " used"}'

# Check memory
echo ""
echo "Memory Usage:"
free -h | grep Mem | awk '{print "  " $3 " / " $2 " (" int($3/$2 * 100) "%)"}'

# Check load average
echo ""
echo "Load Average:"
uptime | awk -F'load average:' '{print "  " $2}'

# Check failed systemd services
echo ""
echo "Failed Services:"
systemctl --failed --no-pager --no-legend | wc -l | awk '{if ($1 > 0) print "  " $1 " failed"; else print "  All services OK"}'

# Check SSH
echo ""
echo "SSH Status:"
systemctl is-active sshd | awk '{if ($1 == "active") print "  ✓ Running"; else print "  ✗ Not running"}'

# Check firewall
echo ""
echo "Firewall Status:"
ufw status | grep -q "Status: active" && echo "  ✓ Active" || echo "  ✗ Inactive"

echo ""
echo "=== End of Health Check ==="
EOF
        chmod +x /usr/local/bin/healthcheck
    fi

    if is_enabled "${CONFIG[CREATE_BENCHMARK_SCRIPT]}" && ! is_enabled "${CONFIG[DRY_RUN]}"; then
        cat > /usr/local/bin/benchmark << 'EOF'
#!/bin/bash
echo "=== System Benchmark ==="
echo ""

# CPU benchmark
echo "CPU Benchmark (calculating primes)..."
echo "Time to calculate primes up to 10000:"
time for i in {1..5}; do
    factor {1..10000} > /dev/null
done 2>&1 | grep real

# Disk write benchmark
echo ""
echo "Disk Write Benchmark:"
dd if=/dev/zero of=/tmp/benchmark bs=1M count=1024 conv=fdatasync 2>&1 | grep copied

# Disk read benchmark
echo ""
echo "Disk Read Benchmark:"
dd if=/tmp/benchmark of=/dev/null bs=1M 2>&1 | grep copied

rm -f /tmp/benchmark

# Network benchmark (if iperf3 is installed)
if command -v iperf3 &> /dev/null; then
    echo ""
    echo "iperf3 is installed. Run 'iperf3 -c <server>' for network benchmarks"
fi

echo ""
echo "=== Benchmark Complete ==="
EOF
        chmod +x /usr/local/bin/benchmark
    fi

    log_success "Maintenance scripts created"
}

create_motd() {
    log_info "Creating custom MOTD"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        chmod -x /etc/update-motd.d/* 2>/dev/null || true

        cat > /etc/motd << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                    VPS Custom Configuration                    ║
╚════════════════════════════════════════════════════════════════╝

Maintenance commands:
  • sysupdate      - Update system packages
  • sysinfo        - Display system information
  • diskusage      - Show disk usage report
  • healthcheck    - Check system health
  • benchmark      - Run system benchmarks
  • backup-home    - Backup home directory

Security:
  - SSH on custom port with key-only authentication
  - Firewall enabled with UFW
  - Fail2ban active
  - Automatic security updates enabled

EOF
    fi

    log_success "MOTD created"
}

create_summary() {
    local user="${CONFIG[MAIN_USER]}"
    local summary_file="/home/$user/SETUP_SUMMARY.txt"

    log_info "Creating setup summary"

    if is_enabled "${CONFIG[DRY_RUN]}"; then
        return 0
    fi

    cat > "$summary_file" << EOF
VPS Setup Completed: $(date)
Script Version: $VERSION

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONFIGURATION SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

System:
  - Hostname: $(hostname)
  - Timezone: ${CONFIG[TIMEZONE]}
  - Locale: ${CONFIG[DEFAULT_LOCALE]}

User Account:
  - Username: $user
  - Sudo access: ✓
  - Custom prompt: $(is_enabled "${CONFIG[CONFIGURE_PROMPTS]}" && echo "✓" || echo "✗")

SSH Configuration:
  - Port: ${CONFIG[SSH_PORT]}
  - Root login: $(is_enabled "${CONFIG[DISABLE_ROOT_LOGIN]}" && echo "Disabled" || echo "Enabled")
  - Password auth: $(is_enabled "${CONFIG[DISABLE_PASSWORD_AUTH]}" && echo "Disabled" || echo "Enabled")
  - Key auth: $(is_enabled "${CONFIG[ENABLE_PUBKEY_AUTH]}" && echo "✓" || echo "✗")
  - 2FA: $(is_enabled "${CONFIG[ENABLE_2FA]}" && echo "✓" || echo "✗")

Security:
  - UFW Firewall: $(is_enabled "${CONFIG[ENABLE_FIREWALL]}" && echo "✓" || echo "✗")
  - Fail2ban: $(is_enabled "${CONFIG[ENABLE_FAIL2BAN]}" && echo "✓" || echo "✗")
  - AppArmor: $(is_enabled "${CONFIG[ENABLE_APPARMOR]}" && echo "✓" || echo "✗")
  - Auditd: $(is_enabled "${CONFIG[ENABLE_AUDITD]}" && echo "✓" || echo "✗")
  - Rkhunter: $(is_enabled "${CONFIG[ENABLE_RKHUNTER]}" && echo "✓" || echo "✗")
  - Auto updates: $(is_enabled "${CONFIG[ENABLE_AUTO_UPDATES]}" && echo "✓" || echo "✗")

Development Tools:
  - Python: $(is_enabled "${CONFIG[INSTALL_PYTHON]}" && echo "✓" || echo "✗")
  - Go: $(is_enabled "${CONFIG[INSTALL_GO]}" && echo "✓" || echo "✗")
  - Node.js: $(is_enabled "${CONFIG[INSTALL_NODEJS]}" && echo "✓" || echo "✗")
  - Rust: $(is_enabled "${CONFIG[INSTALL_RUST]}" && echo "✓" || echo "✗")
  - Docker: $(is_enabled "${CONFIG[INSTALL_DOCKER]}" && echo "✓" || echo "✗")
  - Git: $(is_enabled "${CONFIG[INSTALL_GIT]}" && echo "✓" || echo "✗")

Network:
  - Tailscale: $(is_enabled "${CONFIG[INSTALL_TAILSCALE]}" && echo "✓" || echo "✗")
  - WireGuard: $(is_enabled "${CONFIG[INSTALL_WIREGUARD]}" && echo "✓" || echo "✗")
  - Cloudflared: $(is_enabled "${CONFIG[INSTALL_CLOUDFLARED]}" && echo "✓" || echo "✗")

Web Server:
  - Nginx: $(is_enabled "${CONFIG[INSTALL_NGINX]}" && echo "✓" || echo "✗")
  - Caddy: $(is_enabled "${CONFIG[INSTALL_CADDY]}" && echo "✓" || echo "✗")
  - Certbot: $(is_enabled "${CONFIG[INSTALL_CERTBOT]}" && echo "✓" || echo "✗")

Database:
  - PostgreSQL: $(is_enabled "${CONFIG[INSTALL_POSTGRESQL]}" && echo "✓" || echo "✗")
  - MariaDB: $(is_enabled "${CONFIG[INSTALL_MARIADB]}" && echo "✓" || echo "✗")
  - Redis: $(is_enabled "${CONFIG[INSTALL_REDIS]}" && echo "✓" || echo "✗")

Monitoring:
  - Netdata: $(is_enabled "${CONFIG[ENABLE_NETDATA]}" && echo "✓ (port 19999)" || echo "✗")
  - Node Exporter: $(is_enabled "${CONFIG[ENABLE_NODE_EXPORTER]}" && echo "✓ (port 9100)" || echo "✗")
  - Monit: $(is_enabled "${CONFIG[ENABLE_MONIT]}" && echo "✓" || echo "✗")
  - Sysstat: $(is_enabled "${CONFIG[ENABLE_SYSSTAT]}" && echo "✓" || echo "✗")

Backup:
  - Restic: $(is_enabled "${CONFIG[INSTALL_RESTIC]}" && echo "✓" || echo "✗")
  - Borg: $(is_enabled "${CONFIG[INSTALL_BORG]}" && echo "✓" || echo "✗")

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

NEXT STEPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. SSH Connection:
   ssh -p ${CONFIG[SSH_PORT]} $user@your-server-ip

2. Configure Git (if installed):
   git config --global user.name "Your Name"
   git config --global user.email "your@email.com"

3. Tailscale (if installed):
   tailscale up $(is_enabled "${CONFIG[TAILSCALE_EXIT_NODE]}" && echo "--advertise-exit-node" || echo "")

4. Security:
   - Check firewall: sudo ufw status
   - Check fail2ban: sudo fail2ban-client status
   - Run security scan: sudo rkhunter --check

5. Monitoring:
$(is_enabled "${CONFIG[ENABLE_NETDATA]}" && echo "   - Netdata: http://server-ip:19999" || echo "")
$(is_enabled "${CONFIG[ENABLE_NODE_EXPORTER]}" && echo "   - Node Exporter: http://server-ip:9100/metrics" || echo "")

6. Database (if installed):
$(is_enabled "${CONFIG[INSTALL_MARIADB]}" && echo "   - Secure MariaDB: sudo mysql_secure_installation" || echo "")
$(is_enabled "${CONFIG[INSTALL_POSTGRESQL]}" && echo "   - PostgreSQL: sudo -u postgres psql" || echo "")

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

For logs, see: ${LOG_FILE}

EOF

    chown "$user:$user" "$summary_file"
    log_success "Setup summary created: $summary_file"
}

restart_services() {
    log_info "Restarting services"

    if ! is_enabled "${CONFIG[DRY_RUN]}"; then
        systemctl daemon-reload

        if is_enabled "${CONFIG[ENABLE]}"; then
            systemctl restart sshd
            log_warning "SSH restarted on port ${CONFIG[SSH_PORT]}"
        fi
    fi

    log_success "Services restarted"
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    log_info "╔═══════════════════════════════════════════════════════════╗"
    log_info "║        VPS Setup Script v${VERSION}                           ║"
    log_info "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    check_root
    load_config

    echo ""
    show_config_summary
    echo ""

    if ! is_enabled "${CONFIG[SKIP_PROMPTS]}"; then
        read -p "Continue with this configuration? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_error "Setup cancelled by user"
            exit 1
        fi
    fi

    if is_enabled "${CONFIG[DRY_RUN]}"; then
        log_warning "DRY RUN MODE - No changes will be made"
    fi

    echo ""
    log_info "Starting VPS setup..."
    log_info "═══════════════════════════════════════════════════════════"
    echo ""

    # Execute setup in order
    setup_user
    configure_hostname
    configure_ssh_keys
    configure_timezone
    configure_locale

    update_system
    install_essential_packages

    # Development tools
    install_python
    install_go
    install_nodejs
    install_rust
    install_docker
    install_podman
    install_direnv

    # Network tools
    install_tailscale
    install_wireguard
    install_cloudflared
    enable_ip_forwarding

    # Web servers
    install_nginx
    install_caddy
    install_certbot

    # Databases
    install_postgresql
    install_mariadb
    install_redis

    # Shell configuration
    configure_bash_prompt
    install_shell_aliases
    install_zsh
    install_starship
    install_fzf
    configure_vim
    configure_git

    # Security
    configure_ssh
    configure_ssh_2fa
    configure_firewall
    configure_fail2ban
    enable_apparmor
    enable_auditd
    install_rkhunter
    install_clamav
    install_aide
    install_logwatch
    configure_automatic_updates
    configure_kernel_hardening
    disable_ipv6
    secure_tmp
    disable_core_dumps

    # Monitoring
    install_netdata
    install_node_exporter
    install_monit
    install_sysstat

    # Backup
    install_restic
    install_borg

    # Mail
    configure_mail

    # System optimization
    disable_unnecessary_services
    apply_system_optimizations
    configure_swap
    configure_journal
    install_etckeeper

    # Maintenance scripts and finalization
    create_maintenance_scripts
    create_motd
    create_summary

    echo ""
    log_success "═══════════════════════════════════════════════════════════"
    log_success "VPS Setup Completed Successfully!"
    log_success "═══════════════════════════════════════════════════════════"
    echo ""

    cat "/home/${CONFIG[MAIN_USER]}/SETUP_SUMMARY.txt"

    echo ""
    if is_enabled "${CONFIG[ENABLE]}" && ! is_enabled "${CONFIG[DRY_RUN]}"; then
        log_warning "IMPORTANT: SSH will be restarted on port ${CONFIG[SSH_PORT]}"
        log_warning "Make sure you can connect with SSH keys!"
        echo ""

        if ! is_enabled "${CONFIG[SKIP_PROMPTS]}"; then
            read -p "Press Enter to restart SSH and complete setup..."
        fi

        restart_services
    fi

    echo ""
    log_success "Setup complete! Connect with:"
    log_success "  ssh -p ${CONFIG[SSH_PORT]} ${CONFIG[MAIN_USER]}@your-server-ip"
    echo ""
}

# Run main function
main "$@"
