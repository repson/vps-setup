# VPS Setup Script - Documentation

Automated configuration system for VPS servers with Debian Stable. Modular and highly configurable script that implements security best practices, development tools, and monitoring.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Configuration Sections](#configuration-sections)
- [Maintenance Scripts](#maintenance-scripts)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

## Features

### Security
- SSH hardening (custom port, key-based auth only, no root)
- 2FA with Google Authenticator (optional)
- UFW firewall configured
- Fail2ban against brute force attacks
- AppArmor for MAC (Mandatory Access Control)
- Auditd for system auditing
- Rkhunter (rootkit detection)
- ClamAV antivirus (optional)
- AIDE (intrusion detection)
- Kernel hardening
- Automatic security updates
- Logwatch for daily reports

### Development
- Python 3 + pip + venv
- Go
- Node.js (configurable version: lts, current, or specific)
- Rust toolchain
- Docker + Docker Compose
- Podman (Docker alternative)
- Git with sensible configuration
- direnv for per-project environment variables
- Build essentials and compilation tools

### Monitoring
- Netdata (real-time web dashboard)
- Prometheus Node Exporter
- Monit (service auto-recovery)
- Sysstat (sar, iostat, mpstat)

### Network
- Tailscale with exit node support
- WireGuard
- DNS-over-HTTPS with cloudflared
- Diagnostic tools (mtr, iperf3, nmap)

### Web
- Nginx
- Caddy (with auto-SSL)
- Certbot for Let's Encrypt

### Databases
- PostgreSQL (configurable version)
- MariaDB
- Redis

### Shell and CLI
- Bash with custom prompts (Gentoo-style)
- Git branch support in prompt
- Zsh + oh-my-zsh (optional)
- Starship prompt (optional)
- fzf (fuzzy finder)
- Modern tools: ripgrep, fd, bat, jq
- Pre-configured useful aliases

### Backup
- Restic
- Borg Backup
- Schedulable backup scripts

### System
- Configurable swap
- Performance optimizations
- Systemd journal size control
- Etckeeper (version control for /etc)
- IPv6 disable (configurable)
- TCP BBR for better network performance

## Requirements

- **OS**: Debian Stable (Debian 11 "Bullseye" or Debian 12 "Bookworm")
- **Access**: Root or sudo
- **Connection**: Internet for package downloads
- **SSH**: SSH public key (recommended)

## Installation

### Option 1: Local Execution

```bash
# Clone or download the repository
git clone <repository-url> vps-setup
cd vps-setup

# Edit configuration
vim vps-setup.conf

# Execute (requires root)
sudo ./vps-setup.sh
```

### Option 2: Remote Execution

```bash
# Copy files to server
scp vps-setup.{sh,conf} root@your-vps:~

# Connect and execute
ssh root@your-vps
cd ~
bash vps-setup.sh vps-setup.conf
```

### Option 3: One-Line Remote Execution

```bash
# With local files
cat vps-setup.conf vps-setup.sh | ssh root@your-vps 'cat > /tmp/setup.sh && bash /tmp/setup.sh'

# Or downloading from URL
ssh root@your-vps 'curl -O https://example.com/vps-setup.sh && curl -O https://example.com/vps-setup.conf && bash vps-setup.sh'
```

### Option 4: Dry-Run Mode (Recommended for First Time)

```bash
# Edit vps-setup.conf
DRY_RUN=true

# Execute to see what it would do without applying changes
sudo ./vps-setup.sh
```

## Configuration

The `vps-setup.conf` file controls all script behavior. It's organized into thematic sections.

### File Format

```ini
# Comments start with #
[SECTION_NAME]
OPTION_NAME=value

# Boolean values
ENABLE=true        # true/yes/1/on
DISABLE=false      # false/no/0/off

# Empty values use defaults
OPTION=            # Will use default value
```

### Recommended Minimum Configuration

```ini
[GENERAL]
MAIN_USER=admin
SSH_PUBLIC_KEY=ssh-rsa AAAAB3NzaC1yc2E... your-key-here
TIMEZONE=Europe/Madrid

[SSH]
ENABLE=true
PORT=1022

[SECURITY]
ENABLE_FIREWALL=true
ENABLE_FAIL2BAN=true
ENABLE_AUTO_UPDATES=true
```

## Usage

### Basic Execution

```bash
# With default configuration (vps-setup.conf in same directory)
sudo ./vps-setup.sh

# With specific configuration file
sudo ./vps-setup.sh /path/to/custom-config.conf
```

### Operation Modes

#### 1. Interactive Mode (default)
```ini
[ADVANCED]
SKIP_PROMPTS=false
```
- Asks for confirmation before applying changes
- Requests passwords when necessary
- Recommended mode for manual use

#### 2. Automatic Mode
```ini
[ADVANCED]
SKIP_PROMPTS=true
```
- No confirmation prompts
- Useful for automation
- Use with caution

#### 3. Dry-Run Mode
```ini
[ADVANCED]
DRY_RUN=true
```
- Shows what would be executed without making changes
- Perfect for testing
- Generates logs of what it would do

#### 4. Verbose Mode
```ini
[ADVANCED]
VERBOSE=true
```
- Shows detailed output of each command
- Useful for debugging
- More complete logs

### Post-Installation Verification

```bash
# Review configuration summary
cat ~/SETUP_SUMMARY.txt

# View setup logs
sudo tail -f /var/log/vps-setup.log

# Verify services
systemctl status sshd
systemctl status fail2ban
sudo ufw status
sudo fail2ban-client status
```

## Configuration Sections

### [GENERAL]

Basic system configuration.

```ini
[GENERAL]
MAIN_USER=debian              # Main user to create
SSH_PUBLIC_KEY=               # SSH public key (optional)
TIMEZONE=Europe/Madrid        # Timezone
LOCALES=es_ES.UTF-8 en_US.UTF-8  # Locales to generate
DEFAULT_LOCALE=en_US.UTF-8    # Default locale
HOSTNAME=                     # Hostname (empty = don't change)
```

**Important options:**
- `MAIN_USER`: Will be created with sudo access
- `SSH_PUBLIC_KEY`: If not provided, will be requested during execution
- `TIMEZONE`: Available list with `timedatectl list-timezones`

### [SSH]

SSH server configuration.

```ini
[SSH]
ENABLE=true                    # Enable SSH configuration
PORT=1022                      # SSH port
DISABLE_ROOT_LOGIN=true        # Disable root login
DISABLE_PASSWORD_AUTH=true     # Key authentication only
ENABLE_PUBKEY_AUTH=true        # Enable public key auth
MAX_AUTH_TRIES=3               # Maximum authentication attempts
CLIENT_ALIVE_INTERVAL=300      # Seconds for keep-alive
CLIENT_ALIVE_COUNT_MAX=2       # Keep-alive messages before disconnect
VERBOSE_LOGGING=true           # Detailed logging
ENABLE_2FA=false               # 2FA with Google Authenticator
```

**IMPORTANT:**
- Ensure you have your SSH key configured before disabling password auth
- Note the configured SSH port
- If enabling 2FA, each user must run `google-authenticator`

### [SECURITY]

System security configuration.

```ini
[SECURITY]
ENABLE_FIREWALL=true           # UFW firewall
ENABLE_FAIL2BAN=true           # Brute force protection
FAIL2BAN_BANTIME=7200          # Ban time (seconds)
FAIL2BAN_MAXRETRY=3            # Attempts before ban
ENABLE_AUTO_UPDATES=true       # Automatic updates
ENABLE_APPARMOR=true           # AppArmor MAC
ENABLE_AUDITD=true             # System auditing
ENABLE_RKHUNTER=true           # Rootkit detection
ENABLE_CLAMAV=false            # Antivirus (resource intensive)
ENABLE_AIDE=false              # IDS (slow first run)
ENABLE_LOGWATCH=true           # Daily log reports
ALERT_EMAIL=                   # Email for alerts
DISABLE_IPV6=true              # Disable IPv6
ENABLE_KERNEL_HARDENING=true   # Kernel hardening
SECURE_TMP=true                # /tmp with noexec
DISABLE_CORE_DUMPS=true        # Disable core dumps
```

**Recommendations:**
- `ENABLE_CLAMAV`: Only if you need antivirus scanning (consumes RAM)
- `ENABLE_AIDE`: Only if you need complete IDS (slow first run)
- `ALERT_EMAIL`: Configure to receive security alerts

### [SYSTEM]

Operating system configuration.

```ini
[SYSTEM]
UPDATE_SYSTEM=true             # Update during setup
INSTALL_ESSENTIALS=true        # Essential packages
DISABLE_UNNECESSARY_SERVICES=true  # Disable unnecessary services
APPLY_OPTIMIZATIONS=true       # Performance optimizations
SWAP_SIZE=2048                 # Swap size in MB (0=disabled)
JOURNAL_SIZE_LIMIT=500         # Systemd log limit in MB
ENABLE_ETCKEEPER=true          # Version control for /etc with Git
```

**Recommended swap:**
- VPS with 1GB RAM: 2048 MB
- VPS with 2GB RAM: 2048 MB
- VPS with 4GB+ RAM: 1024 MB or 0

### [SHELL]

Shell and prompt configuration.

```ini
[SHELL]
CONFIGURE_PROMPTS=true         # Custom prompts (Gentoo-style)
INSTALL_ZSH=false              # Install zsh
INSTALL_OH_MY_ZSH=false        # oh-my-zsh (requires zsh)
INSTALL_STARSHIP=false         # Modern Starship prompt
INSTALL_FZF=true               # Fuzzy finder
INSTALL_ALIASES=true           # Useful aliases
```

**Available prompts:**
1. **Custom Bash** (default): Green/blue with Git branch
2. **Zsh + oh-my-zsh**: Highly customizable, more plugins
3. **Starship**: Modern, fast, multi-shell

### [MONITORING]

Monitoring tools.

```ini
[MONITORING]
ENABLE_NETDATA=false           # Real-time web dashboard
ENABLE_NODE_EXPORTER=false     # Prometheus metrics
ENABLE_MONIT=false             # Service auto-recovery
ENABLE_SYSSTAT=true            # Historical statistics (sar)
MONIT_INTERVAL=120             # Monit check interval (seconds)
```

**Ports:**
- Netdata: 19999
- Node Exporter: 9100
- Monit: 2812

**Recommendation:**
- Netdata: Best for complete visual monitoring
- Node Exporter: If using Prometheus/Grafana
- Sysstat: Always useful for historical analysis

### [BACKUP]

Backup configuration.

```ini
[BACKUP]
ENABLE_BACKUP=true             # Enable backups
INSTALL_RESTIC=true            # Restic (modern, efficient)
INSTALL_BORG=false             # Borg (deduplication)
BACKUP_DESTINATION=/var/backups  # Backup destination
BACKUP_SCHEDULE=0 2 * * *      # Cron schedule (2 AM daily)
BACKUP_RETENTION=30            # Retention days
```

**Restic supported destinations:**
- Local: `/var/backups`
- S3: `s3:s3.amazonaws.com/bucket-name`
- SFTP: `sftp:user@host:/path`
- Backblaze: `b2:bucket-name`

### [NETWORK]

Network tools and VPN.

```ini
[NETWORK]
INSTALL_TAILSCALE=true         # Tailscale VPN
TAILSCALE_EXIT_NODE=true       # Enable as exit node
INSTALL_WIREGUARD=false        # WireGuard VPN
INSTALL_CLOUDFLARED=false      # DNS-over-HTTPS
INSTALL_NET_TOOLS=true         # mtr, iperf3, nmap, etc.
```

**Post-installation configuration:**

```bash
# Tailscale
sudo tailscale up --advertise-exit-node

# WireGuard (requires manual configuration)
sudo wg-quick up wg0
```

### [DEVELOPMENT]

Development tools.

```ini
[DEVELOPMENT]
INSTALL_PYTHON=true            # Python 3 + pip + venv
INSTALL_GO=true                # Go
INSTALL_NODEJS=true            # Node.js
NODEJS_VERSION=lts             # lts, current, or version (e.g., 20)
INSTALL_RUST=false             # Rust toolchain
INSTALL_DOCKER=false           # Docker
INSTALL_DOCKER_COMPOSE=false   # Docker Compose
DOCKER_USER_ACCESS=true        # Add user to docker group
INSTALL_PODMAN=false           # Podman (Docker alternative)
INSTALL_DIRENV=true            # direnv for env vars
```

**Node.js versions:**
- `lts`: Latest LTS version
- `current`: Latest stable version
- `20`: Specific version

### [WEBSERVER]

Web servers.

```ini
[WEBSERVER]
INSTALL_NGINX=false            # Nginx
INSTALL_CADDY=false            # Caddy (auto-SSL)
INSTALL_CERTBOT=false          # Let's Encrypt
AUTO_SSL=false                 # Auto-configure SSL
```

**Recommendations:**
- **Nginx**: More traditional, highly configurable
- **Caddy**: Simpler, automatic SSL
- Don't install both at once

### [DATABASE]

Databases.

```ini
[DATABASE]
INSTALL_POSTGRESQL=false       # PostgreSQL
POSTGRESQL_VERSION=            # Empty = default version
INSTALL_MARIADB=false          # MariaDB
INSTALL_REDIS=false            # Redis
REDIS_CACHE_ONLY=true          # No persistence (cache only)
```

**Post-installation:**

```bash
# MariaDB - Run manually
sudo mysql_secure_installation

# PostgreSQL - Access
sudo -u postgres psql

# Redis - Test
redis-cli ping
```

### [MAIL]

Mail configuration for alerts.

```ini
[MAIL]
ENABLE_MAIL=false              # Enable mail sending
MAIL_AGENT=msmtp               # postfix or msmtp
SMTP_SERVER=                   # smtp.gmail.com
SMTP_PORT=587                  # 587 (TLS) or 465 (SSL)
SMTP_USER=                     # user@gmail.com
SMTP_PASSWORD=                 # password or app password
MAIL_FROM=                     # from address
```

**Gmail example:**
```ini
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
MAIL_FROM=your-email@gmail.com
```

### [TOOLS]

CLI tools.

```ini
[TOOLS]
INSTALL_MC=true                # Midnight Commander
INSTALL_VIM=true               # Vim
INSTALL_TMUX=true              # tmux
INSTALL_SCREEN=true            # screen
INSTALL_HTOP=true              # htop
INSTALL_MODERN_TOOLS=true      # ripgrep, fd, bat, jq
INSTALL_GIT=true               # Git
```

**Modern tools includes:**
- `ripgrep` (rg): Fast search
- `fd`: File finding
- `bat`: cat with syntax highlighting
- `jq`: JSON processor

### [MAINTENANCE]

Maintenance scripts.

```ini
[MAINTENANCE]
CREATE_SCRIPTS=true            # Create scripts
CREATE_UPDATE_SCRIPT=true      # sysupdate
CREATE_DISKUSAGE_SCRIPT=true   # diskusage
CREATE_SYSINFO_SCRIPT=true     # sysinfo
CREATE_BACKUP_SCRIPT=true      # backup-home
CREATE_HEALTHCHECK_SCRIPT=true # healthcheck
CREATE_LOGANALYZER_SCRIPT=false # loganalyzer
CREATE_BENCHMARK_SCRIPT=true   # benchmark
```

### [ADVANCED]

Advanced options.

```ini
[ADVANCED]
VERBOSE=true                   # Detailed output
CREATE_LOG=true                # Create log file
LOG_FILE=/var/log/vps-setup.log  # Log path
DRY_RUN=false                  # Don't execute, just show
SKIP_PROMPTS=false             # No confirmations
ENABLE_EXPERIMENTAL=false      # Experimental features
```

## Maintenance Scripts

After installation, these scripts will be available in `/usr/local/bin/`:

### sysupdate
Complete system update.

```bash
sudo sysupdate
```

Executes:
- `apt update`
- `apt upgrade -y`
- `apt dist-upgrade -y`
- `apt autoremove -y`
- `apt autoclean -y`

### sysinfo
System information.

```bash
sysinfo
```

Shows:
- Hostname, kernel, OS, uptime
- Memory usage
- CPU information
- Network interfaces
- Active connections

### diskusage
Disk usage report.

```bash
diskusage
```

Shows:
- General disk usage (`df -h`)
- Largest directories in `/home`
- Largest directories in `/var`

### healthcheck
System health check.

```bash
healthcheck
```

Verifies:
- Disk usage
- Memory usage
- Load average
- Failed services
- SSH status
- Firewall status

### benchmark
System benchmarks.

```bash
sudo benchmark
```

Runs:
- CPU benchmark (prime calculation)
- Disk write benchmark
- Disk read benchmark
- Network benchmark (if iperf3 is installed)

### backup-home
Home directory backup.

```bash
sudo backup-home [username]
```

Features:
- Compressed backup to `/var/backups/home/`
- Excludes: `.cache`, `node_modules`, `.venv`, `__pycache__`
- Keeps only the last 5 backups
- Timestamp naming

## Security

### SSH Connection

After setup, SSH will be securely configured:

```bash
# Connect with new port
ssh -p 1022 user@server-ip

# First time, verify fingerprint
# Then, add to ~/.ssh/config

Host my-vps
    HostName server-ip
    Port 1022
    User user
    IdentityFile ~/.ssh/id_rsa
```

### 2FA (If enabled)

Configuration for each user:

```bash
# Run as the user
google-authenticator

# Answer the questions:
# - Do you want authentication tokens to be time-based? Yes
# - Scan QR code with Google Authenticator app
# - Save emergency scratch codes
# - Update .google_authenticator file? Yes
# - Disallow multiple uses? Yes
# - Increase window? No
# - Enable rate-limiting? Yes
```

### Firewall

Verify rules:

```bash
sudo ufw status verbose
```

Open additional ports:

```bash
# HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Custom port
sudo ufw allow 8080/tcp comment 'My App'

# Port range
sudo ufw allow 8000:8100/tcp
```

### Fail2ban

View status:

```bash
# General status
sudo fail2ban-client status

# SSH jail status
sudo fail2ban-client status sshd

# View banned IPs
sudo fail2ban-client get sshd banip

# Unban an IP
sudo fail2ban-client set sshd unbanip IP_ADDRESS
```

### Auditd

View audit logs:

```bash
# Search for specific events
sudo ausearch -k passwd_changes
sudo ausearch -k sshd_config_changes

# View reports
sudo aureport

# Authentication reports
sudo aureport -au
```

### Rkhunter

Run rootkit scan:

```bash
# Full scan
sudo rkhunter --check

# Only show warnings
sudo rkhunter --check --report-warnings-only

# Update
sudo rkhunter --update
```

## Troubleshooting

### SSH doesn't connect after setup

**Problem:** Cannot connect via SSH

**Solution:**
```bash
# Verify SSH is running
systemctl status sshd

# Verify correct port
sudo ss -tlnp | grep sshd

# Verify firewall
sudo ufw status

# SSH logs
sudo tail -f /var/log/auth.log

# If locked out, access via VPS web console
# and revert changes:
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Fail2ban banned my IP

**Solution:**
```bash
# Check if you're banned
sudo fail2ban-client status sshd

# Unban
sudo fail2ban-client set sshd unbanip YOUR_IP

# Temporarily disable
sudo systemctl stop fail2ban
```

### Services don't start

**Problem:** A service won't start

**Solution:**
```bash
# View detailed status
sudo systemctl status service-name

# View logs
sudo journalctl -u service-name -n 50

# View all failed services
sudo systemctl --failed

# Restart service
sudo systemctl restart service-name
```

### Disk full

**Solution:**
```bash
# Use disk usage script
diskusage

# Clean old logs
sudo journalctl --vacuum-time=7d

# Clean apt cache
sudo apt clean
sudo apt autoclean

# Find large files
sudo find / -type f -size +100M -exec ls -lh {} \;

# Clean old backups
sudo find /var/backups -type f -mtime +30 -delete
```

### Netdata not accessible

**Problem:** Cannot access Netdata on port 19999

**Solution:**
```bash
# Verify it's running
systemctl status netdata

# Open port in firewall
sudo ufw allow 19999/tcp

# Or create SSH tunnel
ssh -L 19999:localhost:19999 -p 1022 user@server-ip
# Then access http://localhost:19999
```

### Docker doesn't work

**Problem:** Docker gives permission denied

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Logout and login to apply
exit
# Reconnect

# Verify
docker ps

# If still failing, restart docker
sudo systemctl restart docker
```

## FAQ

### Can I run the script multiple times?

Yes, the script is idempotent for most configurations. It detects if something is already installed and skips it. However:
- The first execution is the most important
- SSH changes may require manual reconfiguration
- Use `DRY_RUN=true` to verify before running

### Does it work on Ubuntu?

The script is designed for Debian Stable, but should work on Ubuntu with minor adjustments. Ubuntu LTS versions are more compatible.

### Can I customize the maintenance scripts?

Yes, after installation you can edit the scripts in `/usr/local/bin/`. For example:

```bash
sudo vim /usr/local/bin/sysupdate
```

### How do I update the script?

```bash
cd vps-setup
git pull  # If using git

# Review changes in vps-setup.conf.example
# Update your vps-setup.conf if necessary

# Run with DRY_RUN first
sudo ./vps-setup.sh
```

### How long does full execution take?

Depends on what you enable:
- **Minimum** (only SSH + basics): 5-10 minutes
- **Standard** (security + dev tools): 15-25 minutes
- **Complete** (everything enabled): 30-45 minutes

AIDE and ClamAV can add significant time on first run.

### What to do if I get locked out of SSH?

1. Access via **web console** from your VPS provider
2. Restore SSH config:
   ```bash
   sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
   sudo systemctl restart sshd
   ```
3. Or temporarily enable password auth:
   ```bash
   sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
   sudo systemctl restart sshd
   ```

### How do I uninstall components?

The script doesn't include automatic uninstallation. To remove:

```bash
# Example: Remove Docker
sudo apt remove docker-ce docker-ce-cli containerd.io
sudo apt autoremove

# Example: Disable service
sudo systemctl stop netdata
sudo systemctl disable netdata
```

### Is it safe for production?

Yes, the script implements security best practices. However:
- Review configuration before applying
- Test first with `DRY_RUN=true`
- Backup before running on existing server
- Keep a copy of your SSH key
- Document any customizations

### Can I use this on an existing server?

Yes, but with caution:
- Make a complete backup first
- Review for conflicts with existing configuration
- Use `DRY_RUN=true` to see what would change
- Consider running only specific sections

### How do I contribute to the project?

1. Fork the repository
2. Create a branch for your feature
3. Commit your changes
4. Push to your fork
5. Create a Pull Request

### Where do I report bugs?

Create an issue in the repository with:
- Debian version
- Configuration file (sanitized)
- Relevant logs (`/var/log/vps-setup.log`)
- Problem description

## Configuration Examples

### Basic Web Server

```ini
[GENERAL]
MAIN_USER=webadmin
TIMEZONE=Europe/Madrid

[SSH]
ENABLE=true
PORT=2222

[SECURITY]
ENABLE_FIREWALL=true
ENABLE_FAIL2BAN=true
ENABLE_AUTO_UPDATES=true

[WEBSERVER]
INSTALL_NGINX=true
INSTALL_CERTBOT=true

[DATABASE]
INSTALL_MARIADB=true

[DEVELOPMENT]
INSTALL_PYTHON=true
INSTALL_NODEJS=true
```

### Development Server

```ini
[DEVELOPMENT]
INSTALL_PYTHON=true
INSTALL_GO=true
INSTALL_NODEJS=true
NODEJS_VERSION=lts
INSTALL_RUST=true
INSTALL_DOCKER=true
INSTALL_DOCKER_COMPOSE=true

[TOOLS]
INSTALL_MODERN_TOOLS=true
INSTALL_FZF=true

[SHELL]
INSTALL_STARSHIP=true
```

### Minimal Ultra-Secure Server

```ini
[SECURITY]
ENABLE_FIREWALL=true
ENABLE_FAIL2BAN=true
FAIL2BAN_MAXRETRY=2
FAIL2BAN_BANTIME=86400
ENABLE_2FA=true
ENABLE_APPARMOR=true
ENABLE_AUDITD=true
ENABLE_RKHUNTER=true
ENABLE_KERNEL_HARDENING=true
SECURE_TMP=true

[SSH]
PORT=9876
MAX_AUTH_TRIES=2
VERBOSE_LOGGING=true

[SYSTEM]
DISABLE_UNNECESSARY_SERVICES=true
```

### Monitoring Server

```ini
[MONITORING]
ENABLE_NETDATA=true
ENABLE_NODE_EXPORTER=true
ENABLE_MONIT=true
ENABLE_SYSSTAT=true

[SECURITY]
ENABLE_FIREWALL=true

# Open ports for monitoring
# (configure manually afterwards)
```

## License

[Specify project license]

## Credits

Script developed to automate VPS server configuration with Debian Stable.

## Support

For support, additional documentation or questions:
- Review the [Troubleshooting](#troubleshooting) section first
- Consult the [FAQ](#faq)
- Open an issue in the repository

---

**Last updated:** 2024
**Script version:** 2.0.0
**Compatible with:** Debian 11 (Bullseye), Debian 12 (Bookworm)
