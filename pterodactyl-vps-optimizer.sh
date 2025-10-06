#!/bin/bash

#==============================================================================
# Pterodactyl VPS Optimizer for Ubuntu 22.04
# Comprehensive system optimization script for Pterodactyl Panel and Wings
# Author: VPS Optimization Script
# Version: 1.0
# Compatible: Ubuntu 22.04 LTS
#==============================================================================

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="Pterodactyl VPS Optimizer"
readonly SCRIPT_VERSION="1.0"
readonly BACKUP_DIR="/opt/vps-optimizer-backups/$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="/var/log/vps-optimizer.log"
readonly SUPPORTED_OS="Ubuntu 22.04"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global variables
DRY_RUN=false
INTERACTIVE=false
FORCE_MODE=false
ROLLBACK_MODE=false

#==============================================================================
# Utility Functions
#==============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

info() {
    log "INFO" "${BLUE}$*${NC}"
}

success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

warning() {
    log "WARNING" "${YELLOW}$*${NC}"
}

error() {
    log "ERROR" "${RED}$*${NC}"
}

debug() {
    log "DEBUG" "${PURPLE}$*${NC}"
}

# Print banner
print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    Pterodactyl VPS Optimizer v1.0                           ║
║                     Ubuntu 22.04 Performance Tuning                         ║
║                                                                              ║
║  Optimizes system performance for Pterodactyl Panel and Wings               ║
║  Includes kernel tuning, network optimization, and service configuration    ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo privileges"
        exit 1
    fi
}

# Check OS compatibility
check_os_compatibility() {
    info "Checking OS compatibility..."
    
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine OS version"
        exit 1
    fi
    
    source /etc/os-release
    
    if [[ "$NAME" != "Ubuntu" ]] || [[ "$VERSION_ID" != "22.04" ]]; then
        error "This script is designed for Ubuntu 22.04 LTS only"
        error "Detected: $NAME $VERSION_ID"
        exit 1
    fi
    
    success "OS compatibility check passed: $NAME $VERSION_ID"
}

# Create backup directory
create_backup_dir() {
    info "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
}

# Backup file with timestamp
backup_file() {
    local file="$1"
    local backup_name="$2"
    
    if [[ -f "$file" ]]; then
        info "Backing up $file"
        cp "$file" "$BACKUP_DIR/${backup_name}_$(date +%Y%m%d_%H%M%S).bak"
    fi
}

# Check if service exists and is active
check_service() {
    local service="$1"
    if systemctl list-unit-files | grep -q "^${service}\.service"; then
        return 0
    else
        return 1
    fi
}

# Get system information
get_system_info() {
    info "Gathering system information..."
    
    echo "=== System Information ===" >> "$LOG_FILE"
    {
        echo "Hostname: $(hostname)"
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo "CPU Cores: $(nproc)"
        echo "Total Memory: $(free -h | awk '/^Mem:/ {print $2}')"
        echo "Disk Space: $(df -h / | awk 'NR==2 {print $2}')"
        echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
        echo "Network Interfaces: $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | tr '\n' ' ')"
    } >> "$LOG_FILE"
}

# Detect storage type (SSD vs HDD)
detect_storage_type() {
    local device="$1"
    local rotational=$(cat "/sys/block/${device}/queue/rotational" 2>/dev/null || echo "1")
    
    if [[ "$rotational" == "0" ]]; then
        echo "ssd"
    else
        echo "hdd"
    fi
}

# Get primary network interface
get_primary_interface() {
    ip route | grep default | awk '{print $5}' | head -n1
}

#==============================================================================
# System Resource Monitoring
#==============================================================================

collect_before_metrics() {
    info "Collecting baseline system metrics..."
    
    local metrics_file="$BACKUP_DIR/metrics_before.txt"
    
    {
        echo "=== BASELINE SYSTEM METRICS ==="
        echo "Timestamp: $(date)"
        echo ""
        echo "=== CPU Information ==="
        lscpu
        echo ""
        echo "=== Memory Usage ==="
        free -h
        echo ""
        echo "=== Disk Usage ==="
        df -h
        echo ""
        echo "=== Network Statistics ==="
        cat /proc/net/dev
        echo ""
        echo "=== Load Average ==="
        uptime
        echo ""
        echo "=== Active Connections ==="
        ss -tuln | wc -l
        echo ""
        echo "=== Kernel Parameters ==="
        sysctl -a 2>/dev/null | head -50
    } > "$metrics_file"
    
    success "Baseline metrics saved to $metrics_file"
}

collect_after_metrics() {
    info "Collecting post-optimization system metrics..."
    
    local metrics_file="$BACKUP_DIR/metrics_after.txt"
    
    {
        echo "=== POST-OPTIMIZATION SYSTEM METRICS ==="
        echo "Timestamp: $(date)"
        echo ""
        echo "=== CPU Information ==="
        lscpu
        echo ""
        echo "=== Memory Usage ==="
        free -h
        echo ""
        echo "=== Disk Usage ==="
        df -h
        echo ""
        echo "=== Network Statistics ==="
        cat /proc/net/dev
        echo ""
        echo "=== Load Average ==="
        uptime
        echo ""
        echo "=== Active Connections ==="
        ss -tuln | wc -l
        echo ""
        echo "=== Kernel Parameters ==="
        sysctl -a 2>/dev/null | head -50
    } > "$metrics_file"
    
    success "Post-optimization metrics saved to $metrics_file"
}

#==============================================================================
# Kernel Parameter Optimization
#==============================================================================

optimize_kernel_parameters() {
    info "Optimizing kernel parameters..."
    
    backup_file "/etc/sysctl.conf" "sysctl.conf"
    
    local sysctl_config="/etc/sysctl.d/99-pterodactyl-optimization.conf"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would create kernel parameter optimizations in $sysctl_config"
        return 0
    fi
    
    cat > "$sysctl_config" << 'EOF'
# Pterodactyl VPS Optimization - Kernel Parameters
# Generated by Pterodactyl VPS Optimizer

# Network Performance Optimization
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000
net.core.netdev_budget = 600
net.core.somaxconn = 65535
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 7
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.ip_local_port_range = 1024 65535

# Connection Tracking
net.netfilter.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120

# Memory Management
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
vm.min_free_kbytes = 65536
vm.overcommit_memory = 1
vm.overcommit_ratio = 50

# File System
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 256

# Kernel
kernel.pid_max = 4194304
kernel.threads-max = 4194304
kernel.sched_migration_cost_ns = 5000000
kernel.sched_autogroup_enabled = 0
EOF
    
    # Apply the settings
    sysctl -p "$sysctl_config"
    
    success "Kernel parameters optimized and applied"
}

#==============================================================================
# CPU and Load Balancing Optimization
#==============================================================================

optimize_cpu_performance() {
    info "Optimizing CPU performance and load balancing..."

    # Set CPU governor to performance
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would set CPU governor to performance mode"
    else
        if command -v cpupower >/dev/null 2>&1; then
            cpupower frequency-set -g performance 2>/dev/null || true
            success "CPU governor set to performance mode"
        else
            warning "cpupower not available, installing..."
            apt-get update && apt-get install -y linux-tools-common linux-tools-generic
            cpupower frequency-set -g performance 2>/dev/null || true
        fi
    fi

    # Configure IRQ balance
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would configure IRQ balance optimization"
    else
        if ! command -v irqbalance >/dev/null 2>&1; then
            apt-get install -y irqbalance
        fi

        backup_file "/etc/default/irqbalance" "irqbalance"

        cat > /etc/default/irqbalance << 'EOF'
# IRQ Balance configuration for Pterodactyl optimization
ENABLED="1"
ONESHOT="0"
OPTIONS="--policyscript=/usr/local/bin/irqbalance-policy.sh"
EOF

        # Create IRQ balance policy script
        cat > /usr/local/bin/irqbalance-policy.sh << 'EOF'
#!/bin/bash
# IRQ Balance policy for Pterodactyl optimization
# Prioritize network and disk interrupts

case "$1" in
    "network")
        echo "exact"
        ;;
    "storage")
        echo "exact"
        ;;
    *)
        echo "ignore"
        ;;
esac
EOF
        chmod +x /usr/local/bin/irqbalance-policy.sh

        systemctl enable irqbalance
        systemctl restart irqbalance
        success "IRQ balance configured and started"
    fi
}

#==============================================================================
# Memory Management Optimization
#==============================================================================

optimize_memory_management() {
    info "Optimizing memory management..."

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would configure Transparent Huge Pages and memory settings"
        return 0
    fi

    # Configure Transparent Huge Pages
    echo 'madvise' > /sys/kernel/mm/transparent_hugepage/enabled
    echo 'madvise' > /sys/kernel/mm/transparent_hugepage/defrag

    # Make THP settings persistent
    cat > /etc/systemd/system/thp-settings.service << 'EOF'
[Unit]
Description=Configure Transparent Huge Pages
After=sysinit.target local-fs.target
Before=pterodactyl.service wings.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo madvise > /sys/kernel/mm/transparent_hugepage/enabled'
ExecStart=/bin/bash -c 'echo madvise > /sys/kernel/mm/transparent_hugepage/defrag'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable thp-settings.service
    systemctl start thp-settings.service

    success "Memory management optimized"
}

#==============================================================================
# Swap Configuration Optimization
#==============================================================================

optimize_swap_configuration() {
    info "Optimizing swap configuration..."

    local total_mem=$(free -m | awk '/^Mem:/ {print $2}')
    local current_swap=$(free -m | awk '/^Swap:/ {print $2}')

    info "Total memory: ${total_mem}MB, Current swap: ${current_swap}MB"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would optimize swap configuration based on available memory"
        return 0
    fi

    # Determine optimal swap size (1GB for systems with >4GB RAM, 2GB for <=4GB)
    local optimal_swap
    if [[ $total_mem -gt 4096 ]]; then
        optimal_swap=1024
    else
        optimal_swap=2048
    fi

    # Only modify swap if current configuration is suboptimal
    if [[ $current_swap -eq 0 ]] || [[ $current_swap -lt 512 ]] || [[ $current_swap -gt 4096 ]]; then
        warning "Suboptimal swap configuration detected. Configuring ${optimal_swap}MB swap..."

        # Disable existing swap
        swapoff -a

        # Remove old swap entries from fstab
        backup_file "/etc/fstab" "fstab"
        sed -i '/swap/d' /etc/fstab

        # Create new swap file
        local swap_file="/swapfile"
        dd if=/dev/zero of="$swap_file" bs=1M count="$optimal_swap" status=progress
        chmod 600 "$swap_file"
        mkswap "$swap_file"
        swapon "$swap_file"

        # Add to fstab
        echo "$swap_file none swap sw 0 0" >> /etc/fstab

        success "Swap configured: ${optimal_swap}MB"
    else
        success "Swap configuration is already optimal: ${current_swap}MB"
    fi
}

#==============================================================================
# Disk I/O Scheduler Optimization
#==============================================================================

optimize_disk_scheduler() {
    info "Optimizing disk I/O scheduler..."

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would optimize disk I/O schedulers based on storage type"
        return 0
    fi

    # Get all block devices
    for device in $(lsblk -nd -o NAME | grep -E '^(sd|nvme|vd)'); do
        local storage_type=$(detect_storage_type "$device")
        local scheduler

        if [[ "$storage_type" == "ssd" ]]; then
            scheduler="mq-deadline"
        else
            scheduler="bfq"
        fi

        info "Setting scheduler for $device ($storage_type): $scheduler"
        echo "$scheduler" > "/sys/block/$device/queue/scheduler"

        # Make persistent
        cat > "/etc/udev/rules.d/60-${device}-scheduler.rules" << EOF
# Set I/O scheduler for $device ($storage_type)
ACTION=="add|change", KERNEL=="$device", ATTR{queue/scheduler}="$scheduler"
EOF
    done

    success "Disk I/O schedulers optimized"
}

#==============================================================================
# Network Interface Optimization
#==============================================================================

optimize_network_interface() {
    info "Optimizing network interface settings..."

    local primary_interface=$(get_primary_interface)

    if [[ -z "$primary_interface" ]]; then
        warning "Could not determine primary network interface"
        return 1
    fi

    info "Primary network interface: $primary_interface"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would optimize network interface: $primary_interface"
        return 0
    fi

    # Optimize ring buffers
    if command -v ethtool >/dev/null 2>&1; then
        ethtool -G "$primary_interface" rx 4096 tx 4096 2>/dev/null || true

        # Enable offloading features
        ethtool -K "$primary_interface" gso on tso on ufo on 2>/dev/null || true
        ethtool -K "$primary_interface" rx-checksumming on tx-checksumming on 2>/dev/null || true

        success "Network interface $primary_interface optimized"
    else
        warning "ethtool not available, installing..."
        apt-get install -y ethtool
        optimize_network_interface
    fi
}

#==============================================================================
# Ulimit and File Descriptor Optimization
#==============================================================================

optimize_ulimits() {
    info "Optimizing ulimits and file descriptors..."

    backup_file "/etc/security/limits.conf" "limits.conf"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would configure ulimits for high concurrent connections"
        return 0
    fi

    # Configure limits for all users and specific services
    cat >> /etc/security/limits.conf << 'EOF'

# Pterodactyl VPS Optimization - File Descriptor Limits
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
root soft nofile 1048576
root hard nofile 1048576
www-data soft nofile 1048576
www-data hard nofile 1048576
mysql soft nofile 1048576
mysql hard nofile 1048576
redis soft nofile 1048576
redis hard nofile 1048576
EOF

    # Configure systemd limits
    mkdir -p /etc/systemd/system.conf.d
    cat > /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=1048576
EOF

    # Configure PAM limits
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi

    success "Ulimits and file descriptors optimized"
}

#==============================================================================
# PHP-FPM Optimization
#==============================================================================

optimize_php_fpm() {
    info "Optimizing PHP-FPM configuration..."

    # Detect PHP version
    local php_version
    if command -v php >/dev/null 2>&1; then
        php_version=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    else
        warning "PHP not found, skipping PHP-FPM optimization"
        return 0
    fi

    local fpm_config="/etc/php/${php_version}/fpm/pool.d/www.conf"
    local php_ini="/etc/php/${php_version}/fpm/php.ini"

    if [[ ! -f "$fpm_config" ]]; then
        warning "PHP-FPM configuration not found at $fpm_config"
        return 0
    fi

    backup_file "$fpm_config" "php-fpm-www.conf"
    backup_file "$php_ini" "php.ini"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would optimize PHP-FPM configuration for PHP $php_version"
        return 0
    fi

    # Calculate optimal settings based on available memory
    local total_mem_gb=$(($(free -m | awk '/^Mem:/ {print $2}') / 1024))
    local max_children=$((total_mem_gb * 8))
    local start_servers=$((max_children / 4))
    local min_spare_servers=$((max_children / 8))
    local max_spare_servers=$((max_children / 2))

    # Ensure minimum values
    [[ $max_children -lt 16 ]] && max_children=16
    [[ $start_servers -lt 4 ]] && start_servers=4
    [[ $min_spare_servers -lt 2 ]] && min_spare_servers=2
    [[ $max_spare_servers -lt 8 ]] && max_spare_servers=8

    # Configure PHP-FPM pool
    cat > "$fpm_config" << EOF
[www]
user = www-data
group = www-data
listen = /run/php/php${php_version}-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = $max_children
pm.start_servers = $start_servers
pm.min_spare_servers = $min_spare_servers
pm.max_spare_servers = $max_spare_servers
pm.max_requests = 1000
pm.process_idle_timeout = 30s

request_terminate_timeout = 300
request_slowlog_timeout = 10s
slowlog = /var/log/php${php_version}-fpm-slow.log

rlimit_files = 65536
rlimit_core = 0

catch_workers_output = yes
decorate_workers_output = no

env[HOSTNAME] = \$HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp

php_admin_value[error_log] = /var/log/php${php_version}-fpm.log
php_admin_flag[log_errors] = on
php_admin_value[memory_limit] = 256M
php_admin_value[max_execution_time] = 300
php_admin_value[max_input_time] = 300
php_admin_value[post_max_size] = 100M
php_admin_value[upload_max_filesize] = 100M
php_admin_value[max_file_uploads] = 20
EOF

    success "PHP-FPM optimized for PHP $php_version (max_children: $max_children)"
}

#==============================================================================
# MySQL/MariaDB Optimization
#==============================================================================

optimize_mysql() {
    info "Optimizing MySQL/MariaDB configuration..."

    local mysql_config=""
    local service_name=""

    # Detect MySQL/MariaDB
    if check_service "mysql"; then
        service_name="mysql"
        mysql_config="/etc/mysql/mysql.conf.d/mysqld.cnf"
    elif check_service "mariadb"; then
        service_name="mariadb"
        mysql_config="/etc/mysql/mariadb.conf.d/50-server.cnf"
    else
        warning "MySQL/MariaDB not found, skipping database optimization"
        return 0
    fi

    if [[ ! -f "$mysql_config" ]]; then
        warning "MySQL configuration file not found at $mysql_config"
        return 0
    fi

    backup_file "$mysql_config" "mysql.cnf"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would optimize $service_name configuration"
        return 0
    fi

    # Calculate memory-based settings
    local total_mem_mb=$(free -m | awk '/^Mem:/ {print $2}')
    local innodb_buffer_pool=$((total_mem_mb * 70 / 100))  # 70% of total memory
    local max_connections=500

    # Ensure minimum buffer pool size
    [[ $innodb_buffer_pool -lt 128 ]] && innodb_buffer_pool=128

    # Create optimized MySQL configuration
    cat > "/etc/mysql/conf.d/pterodactyl-optimization.cnf" << EOF
[mysqld]
# Pterodactyl VPS Optimization - MySQL Configuration

# Connection Settings
max_connections = $max_connections
max_connect_errors = 1000000
max_allowed_packet = 256M
interactive_timeout = 3600
wait_timeout = 3600

# InnoDB Settings
innodb_buffer_pool_size = ${innodb_buffer_pool}M
innodb_buffer_pool_instances = $(nproc)
innodb_log_file_size = 256M
innodb_log_buffer_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_open_files = 65535
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
innodb_read_io_threads = 8
innodb_write_io_threads = 8
innodb_thread_concurrency = 0
innodb_lock_wait_timeout = 120

# Query Cache (if supported)
query_cache_type = 1
query_cache_size = 64M
query_cache_limit = 8M

# MyISAM Settings
key_buffer_size = 32M
myisam_sort_buffer_size = 128M

# Temporary Tables
tmp_table_size = 256M
max_heap_table_size = 256M

# Logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
log_queries_not_using_indexes = 0

# Binary Logging
binlog_cache_size = 1M
max_binlog_cache_size = 2G
max_binlog_size = 1G
expire_logs_days = 7

# Thread Settings
thread_cache_size = 50
thread_stack = 256K

# Table Settings
table_open_cache = 4000
table_definition_cache = 2000

# Network Settings
bind-address = 127.0.0.1
skip-external-locking
skip-name-resolve
EOF

    success "MySQL/MariaDB optimized with ${innodb_buffer_pool}MB buffer pool"
}

#==============================================================================
# Redis Optimization
#==============================================================================

optimize_redis() {
    info "Optimizing Redis configuration..."

    if ! check_service "redis-server" && ! check_service "redis"; then
        warning "Redis not found, skipping Redis optimization"
        return 0
    fi

    local redis_config="/etc/redis/redis.conf"

    if [[ ! -f "$redis_config" ]]; then
        warning "Redis configuration file not found at $redis_config"
        return 0
    fi

    backup_file "$redis_config" "redis.conf"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would optimize Redis configuration"
        return 0
    fi

    # Calculate optimal maxmemory (25% of total RAM)
    local total_mem_mb=$(free -m | awk '/^Mem:/ {print $2}')
    local redis_maxmem=$((total_mem_mb * 25 / 100))

    # Ensure minimum memory allocation
    [[ $redis_maxmem -lt 64 ]] && redis_maxmem=64

    # Apply Redis optimizations
    sed -i "s/^# maxmemory <bytes>/maxmemory ${redis_maxmem}mb/" "$redis_config"
    sed -i "s/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/" "$redis_config"
    sed -i "s/^save /# save /" "$redis_config"  # Disable RDB snapshots for performance
    sed -i "s/^# tcp-keepalive 300/tcp-keepalive 60/" "$redis_config"
    sed -i "s/^timeout 0/timeout 300/" "$redis_config"

    # Add additional optimizations
    cat >> "$redis_config" << EOF

# Pterodactyl VPS Optimization - Redis Settings
tcp-backlog 511
databases 16
stop-writes-on-bgsave-error no
rdbcompression yes
rdbchecksum yes
maxclients 10000
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes
replica-lazy-flush yes
EOF

    success "Redis optimized with ${redis_maxmem}MB max memory"
}

#==============================================================================
# Nginx Web Server Optimization
#==============================================================================

optimize_nginx() {
    info "Optimizing Nginx configuration..."

    if ! check_service "nginx"; then
        warning "Nginx not found, skipping web server optimization"
        return 0
    fi

    local nginx_config="/etc/nginx/nginx.conf"

    if [[ ! -f "$nginx_config" ]]; then
        warning "Nginx configuration file not found at $nginx_config"
        return 0
    fi

    backup_file "$nginx_config" "nginx.conf"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would optimize Nginx configuration"
        return 0
    fi

    # Calculate worker processes and connections
    local worker_processes=$(nproc)
    local worker_connections=4096

    # Create optimized Nginx configuration
    cat > "$nginx_config" << EOF
# Pterodactyl VPS Optimization - Nginx Configuration
user www-data;
worker_processes $worker_processes;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    worker_connections $worker_connections;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 1000;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size 100M;

    # Buffer Settings
    client_body_buffer_size 128k;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
    output_buffers 1 32k;
    postpone_output 1460;

    # Timeout Settings
    client_body_timeout 12;
    client_header_timeout 12;
    send_timeout 10;

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # File Caching
    open_file_cache max=200000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;

    # MIME Types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Virtual Host Configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

    success "Nginx optimized with $worker_processes workers and $worker_connections connections per worker"
}

#==============================================================================
# Wings Daemon Optimization
#==============================================================================

optimize_wings() {
    info "Optimizing Wings daemon configuration..."

    local wings_config="/etc/pterodactyl/config.yml"

    if [[ ! -f "$wings_config" ]]; then
        warning "Wings configuration not found at $wings_config, skipping Wings optimization"
        return 0
    fi

    backup_file "$wings_config" "wings-config.yml"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would optimize Wings daemon configuration"
        return 0
    fi

    # Create Wings systemd override for resource limits
    mkdir -p /etc/systemd/system/wings.service.d
    cat > /etc/systemd/system/wings.service.d/override.conf << 'EOF'
[Service]
LimitNOFILE=1048576
LimitNPROC=1048576
OOMScoreAdjust=-500

# Resource limits
CPUQuota=80%
MemoryHigh=80%
TasksMax=8192

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/pterodactyl /tmp /var/log
EOF

    # Configure Docker daemon for Wings optimization
    local docker_config="/etc/docker/daemon.json"
    backup_file "$docker_config" "docker-daemon.json"

    cat > "$docker_config" << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 1048576,
            "Soft": 1048576
        },
        "nproc": {
            "Name": "nproc",
            "Hard": 1048576,
            "Soft": 1048576
        }
    },
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 5,
    "default-shm-size": "128M"
}
EOF

    systemctl daemon-reload

    success "Wings daemon and Docker optimized for container performance"
}

#==============================================================================
# Rollback Functionality
#==============================================================================

rollback_changes() {
    info "Rolling back changes..."

    if [[ ! -d "$BACKUP_DIR" ]]; then
        error "Backup directory not found: $BACKUP_DIR"
        exit 1
    fi

    local rollback_count=0

    # Restore backed up files
    for backup_file in "$BACKUP_DIR"/*.bak; do
        if [[ -f "$backup_file" ]]; then
            local original_file=$(basename "$backup_file" | sed 's/_[0-9]*_[0-9]*\.bak$//')
            local target_path

            case "$original_file" in
                "sysctl.conf")
                    target_path="/etc/sysctl.conf"
                    ;;
                "limits.conf")
                    target_path="/etc/security/limits.conf"
                    ;;
                "irqbalance")
                    target_path="/etc/default/irqbalance"
                    ;;
                "fstab")
                    target_path="/etc/fstab"
                    ;;
                "php-fpm-www.conf")
                    # Find PHP version and restore
                    local php_version=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null || echo "8.1")
                    target_path="/etc/php/${php_version}/fpm/pool.d/www.conf"
                    ;;
                "mysql.cnf")
                    if [[ -f "/etc/mysql/mysql.conf.d/mysqld.cnf" ]]; then
                        target_path="/etc/mysql/mysql.conf.d/mysqld.cnf"
                    else
                        target_path="/etc/mysql/mariadb.conf.d/50-server.cnf"
                    fi
                    ;;
                "redis.conf")
                    target_path="/etc/redis/redis.conf"
                    ;;
                "nginx.conf")
                    target_path="/etc/nginx/nginx.conf"
                    ;;
                "wings-config.yml")
                    target_path="/etc/pterodactyl/config.yml"
                    ;;
                "docker-daemon.json")
                    target_path="/etc/docker/daemon.json"
                    ;;
            esac

            if [[ -n "$target_path" ]] && [[ -f "$target_path" ]]; then
                info "Restoring $target_path from backup"
                cp "$backup_file" "$target_path"
                ((rollback_count++))
            fi
        fi
    done

    # Remove optimization files
    local opt_files=(
        "/etc/sysctl.d/99-pterodactyl-optimization.conf"
        "/etc/systemd/system/thp-settings.service"
        "/etc/systemd/system.conf.d/limits.conf"
        "/usr/local/bin/irqbalance-policy.sh"
        "/etc/mysql/conf.d/pterodactyl-optimization.cnf"
        "/etc/systemd/system/wings.service.d/override.conf"
    )

    for opt_file in "${opt_files[@]}"; do
        if [[ -f "$opt_file" ]]; then
            info "Removing optimization file: $opt_file"
            rm -f "$opt_file"
            ((rollback_count++))
        fi
    done

    # Reload configurations
    systemctl daemon-reload
    sysctl -p /etc/sysctl.conf 2>/dev/null || true

    success "Rollback completed. $rollback_count files restored/removed."
    warning "Please reboot the system to ensure all changes are reverted."
}

#==============================================================================
# Interactive Mode Functions
#==============================================================================

show_optimization_menu() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                        Optimization Categories                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo "1. Kernel Parameters (sysctl, network, memory)"
    echo "2. CPU & Load Balancing (governor, IRQ balance)"
    echo "3. Memory Management (THP, swap, cache)"
    echo "4. Disk I/O Optimization (schedulers, file systems)"
    echo "5. Network Interface Tuning (buffers, offloading)"
    echo "6. File Descriptors & Ulimits"
    echo "7. PHP-FPM Configuration"
    echo "8. MySQL/MariaDB Optimization"
    echo "9. Redis Configuration"
    echo "10. Nginx Web Server Tuning"
    echo "11. Wings Daemon & Docker Optimization"
    echo "12. Apply All Optimizations"
    echo "0. Exit"
    echo ""
}

interactive_mode() {
    info "Starting interactive optimization mode..."

    while true; do
        show_optimization_menu
        read -p "Select optimization category (0-12): " choice

        case $choice in
            1)
                optimize_kernel_parameters
                ;;
            2)
                optimize_cpu_performance
                ;;
            3)
                optimize_memory_management
                optimize_swap_configuration
                ;;
            4)
                optimize_disk_scheduler
                ;;
            5)
                optimize_network_interface
                ;;
            6)
                optimize_ulimits
                ;;
            7)
                optimize_php_fpm
                ;;
            8)
                optimize_mysql
                ;;
            9)
                optimize_redis
                ;;
            10)
                optimize_nginx
                ;;
            11)
                optimize_wings
                ;;
            12)
                run_all_optimizations
                break
                ;;
            0)
                info "Exiting interactive mode"
                break
                ;;
            *)
                warning "Invalid selection. Please choose 0-12."
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
        clear
    done
}

#==============================================================================
# Main Optimization Functions
#==============================================================================

run_all_optimizations() {
    info "Running all system optimizations..."

    collect_before_metrics

    # System-level optimizations
    optimize_kernel_parameters
    optimize_cpu_performance
    optimize_memory_management
    optimize_swap_configuration
    optimize_disk_scheduler
    optimize_network_interface
    optimize_ulimits

    # Service-specific optimizations
    optimize_php_fpm
    optimize_mysql
    optimize_redis
    optimize_nginx
    optimize_wings

    collect_after_metrics

    success "All optimizations completed successfully!"
}

restart_services() {
    info "Restarting optimized services..."

    local services=("php8.1-fpm" "php8.0-fpm" "php7.4-fpm" "mysql" "mariadb" "redis-server" "nginx" "wings")

    for service in "${services[@]}"; do
        if check_service "$service"; then
            if [[ "$DRY_RUN" == "true" ]]; then
                info "[DRY RUN] Would restart service: $service"
            else
                info "Restarting $service..."
                systemctl restart "$service" 2>/dev/null || warning "Failed to restart $service"
            fi
        fi
    done

    success "Service restart completed"
}

#==============================================================================
# Usage and Help Functions
#==============================================================================

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Pterodactyl VPS Optimizer v${SCRIPT_VERSION}
Comprehensive system optimization for Ubuntu 22.04 with Pterodactyl Panel and Wings

OPTIONS:
    -h, --help          Show this help message
    -i, --interactive   Run in interactive mode
    -d, --dry-run       Preview changes without applying them
    -f, --force         Skip confirmation prompts
    -r, --rollback      Rollback previous optimizations
    -v, --verbose       Enable verbose logging
    --version           Show version information

EXAMPLES:
    $0                  Run all optimizations with prompts
    $0 -i               Run in interactive mode
    $0 -d               Preview all changes (dry run)
    $0 -f               Run all optimizations without prompts
    $0 -r               Rollback previous optimizations

FEATURES:
    • Kernel parameter tuning (sysctl.conf)
    • TCP/IP stack optimization (BBR, buffers)
    • CPU governor and IRQ balance optimization
    • Memory management (THP, swap, cache)
    • Disk I/O scheduler optimization
    • Network interface tuning
    • File descriptor and ulimit adjustments
    • PHP-FPM pool configuration
    • MySQL/MariaDB optimization
    • Redis configuration tuning
    • Nginx web server optimization
    • Wings daemon and Docker tuning
    • Automatic backup and rollback capability
    • System resource monitoring

REQUIREMENTS:
    • Ubuntu 22.04 LTS
    • Root or sudo privileges
    • Pterodactyl Panel installation (recommended)

For more information, visit: https://github.com/pterodactyl/panel
EOF
}

show_version() {
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "Compatible with: $SUPPORTED_OS"
    echo "Optimized for: Pterodactyl Panel and Wings"
}

#==============================================================================
# Command Line Argument Parsing
#==============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -i|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE_MODE=true
                shift
                ;;
            -r|--rollback)
                ROLLBACK_MODE=true
                shift
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            --version)
                show_version
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

#==============================================================================
# Main Execution Function
#==============================================================================

main() {
    # Parse command line arguments first (for help/version)
    parse_arguments "$@"

    # Initialize logging (only if not help/version)
    if [[ "$*" != *"--help"* ]] && [[ "$*" != *"--version"* ]]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || LOG_FILE="/tmp/vps-optimizer.log"
        touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/vps-optimizer.log"
    fi

    print_banner

    # Perform initial checks
    check_root
    check_os_compatibility
    get_system_info

    # Handle rollback mode
    if [[ "$ROLLBACK_MODE" == "true" ]]; then
        rollback_changes
        exit 0
    fi

    # Create backup directory
    create_backup_dir

    # Show dry run notice
    if [[ "$DRY_RUN" == "true" ]]; then
        warning "DRY RUN MODE: No changes will be applied to the system"
        echo ""
    fi

    # Confirmation prompt (unless force mode or dry run)
    if [[ "$FORCE_MODE" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        echo -e "${YELLOW}This script will optimize your Ubuntu 22.04 system for Pterodactyl Panel and Wings.${NC}"
        echo -e "${YELLOW}All configuration files will be backed up to: $BACKUP_DIR${NC}"
        echo ""
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Operation cancelled by user"
            exit 0
        fi
    fi

    # Run optimizations
    if [[ "$INTERACTIVE" == "true" ]]; then
        interactive_mode
    else
        run_all_optimizations
    fi

    # Restart services (unless dry run)
    if [[ "$DRY_RUN" != "true" ]]; then
        restart_services
    fi

    # Final summary
    echo ""
    success "Pterodactyl VPS optimization completed!"
    info "Backup directory: $BACKUP_DIR"
    info "Log file: $LOG_FILE"

    if [[ "$DRY_RUN" != "true" ]]; then
        warning "It is recommended to reboot the system to ensure all optimizations take effect."
        echo ""
        read -p "Would you like to reboot now? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Rebooting system in 10 seconds... (Ctrl+C to cancel)"
            sleep 10
            reboot
        fi
    fi
}

# Execute main function with all arguments
main "$@"
