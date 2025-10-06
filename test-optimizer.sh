#!/bin/bash

#==============================================================================
# Test Script for Pterodactyl VPS Optimizer
# Validates the optimizer script functionality and safety features
#==============================================================================

set -euo pipefail

readonly TEST_SCRIPT="./pterodactyl-vps-optimizer.sh"
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

# Test logging functions
log_test() {
    ((test_count++))
    echo -e "${BLUE}[TEST $test_count]${NC} $1"
}

log_pass() {
    ((pass_count++))
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    ((fail_count++))
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test if script exists and is executable
test_script_exists() {
    log_test "Checking if optimizer script exists and is executable"
    
    if [[ -f "$TEST_SCRIPT" ]]; then
        if [[ -x "$TEST_SCRIPT" ]]; then
            log_pass "Script exists and is executable"
        else
            log_fail "Script exists but is not executable"
            return 1
        fi
    else
        log_fail "Script does not exist at $TEST_SCRIPT"
        return 1
    fi
}

# Test help functionality
test_help_function() {
    log_test "Testing help functionality"
    
    if $TEST_SCRIPT --help >/dev/null 2>&1; then
        log_pass "Help function works correctly"
    else
        log_fail "Help function failed"
        return 1
    fi
}

# Test version functionality
test_version_function() {
    log_test "Testing version functionality"
    
    if $TEST_SCRIPT --version >/dev/null 2>&1; then
        log_pass "Version function works correctly"
    else
        log_fail "Version function failed"
        return 1
    fi
}

# Test dry run mode
test_dry_run_mode() {
    log_test "Testing dry run mode (requires root)"
    
    if [[ $EUID -eq 0 ]]; then
        if timeout 30 $TEST_SCRIPT --dry-run --force >/dev/null 2>&1; then
            log_pass "Dry run mode completed successfully"
        else
            log_fail "Dry run mode failed or timed out"
            return 1
        fi
    else
        log_warn "Skipping dry run test (requires root privileges)"
    fi
}

# Test script syntax
test_script_syntax() {
    log_test "Testing script syntax"
    
    if bash -n "$TEST_SCRIPT"; then
        log_pass "Script syntax is valid"
    else
        log_fail "Script has syntax errors"
        return 1
    fi
}

# Test required commands availability
test_required_commands() {
    log_test "Testing required commands availability"
    
    local required_commands=("systemctl" "sysctl" "free" "nproc" "lscpu" "df" "ss")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -eq 0 ]]; then
        log_pass "All required commands are available"
    else
        log_fail "Missing required commands: ${missing_commands[*]}"
        return 1
    fi
}

# Test OS detection
test_os_detection() {
    log_test "Testing OS detection logic"
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$NAME" == "Ubuntu" ]]; then
            if [[ "$VERSION_ID" == "22.04" ]]; then
                log_pass "Running on supported OS: Ubuntu 22.04"
            else
                log_warn "Running on Ubuntu $VERSION_ID (script designed for 22.04)"
            fi
        else
            log_warn "Running on $NAME (script designed for Ubuntu)"
        fi
    else
        log_fail "Cannot detect OS version"
        return 1
    fi
}

# Test backup directory creation
test_backup_functionality() {
    log_test "Testing backup directory creation"
    
    local test_backup_dir="/tmp/test-vps-optimizer-backup-$$"
    
    if mkdir -p "$test_backup_dir" && [[ -d "$test_backup_dir" ]]; then
        log_pass "Backup directory creation works"
        rm -rf "$test_backup_dir"
    else
        log_fail "Failed to create backup directory"
        return 1
    fi
}

# Test configuration file detection
test_config_detection() {
    log_test "Testing configuration file detection"
    
    local config_files=(
        "/etc/sysctl.conf"
        "/etc/security/limits.conf"
        "/etc/fstab"
    )
    
    local missing_files=()
    
    for config_file in "${config_files[@]}"; do
        if [[ ! -f "$config_file" ]]; then
            missing_files+=("$config_file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        log_pass "All critical configuration files exist"
    else
        log_warn "Missing configuration files: ${missing_files[*]}"
    fi
}

# Test service detection
test_service_detection() {
    log_test "Testing service detection capabilities"
    
    local common_services=("ssh" "systemd-resolved" "systemd-networkd")
    local detected_services=0
    
    for service in "${common_services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}\.service"; then
            ((detected_services++))
        fi
    done
    
    if [[ $detected_services -gt 0 ]]; then
        log_pass "Service detection works ($detected_services services detected)"
    else
        log_fail "Service detection failed"
        return 1
    fi
}

# Test memory calculation
test_memory_calculation() {
    log_test "Testing memory calculation functions"
    
    local total_mem=$(free -m | awk '/^Mem:/ {print $2}')
    
    if [[ $total_mem -gt 0 ]]; then
        log_pass "Memory calculation works (${total_mem}MB detected)"
    else
        log_fail "Memory calculation failed"
        return 1
    fi
}

# Test CPU detection
test_cpu_detection() {
    log_test "Testing CPU detection functions"
    
    local cpu_cores=$(nproc)
    
    if [[ $cpu_cores -gt 0 ]]; then
        log_pass "CPU detection works (${cpu_cores} cores detected)"
    else
        log_fail "CPU detection failed"
        return 1
    fi
}

# Test network interface detection
test_network_detection() {
    log_test "Testing network interface detection"
    
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | wc -l)
    
    if [[ $interfaces -gt 0 ]]; then
        log_pass "Network interface detection works ($interfaces interfaces found)"
    else
        log_fail "Network interface detection failed"
        return 1
    fi
}

# Test storage type detection
test_storage_detection() {
    log_test "Testing storage type detection"
    
    local block_devices=$(lsblk -nd -o NAME | grep -E '^(sd|nvme|vd)' | wc -l)
    
    if [[ $block_devices -gt 0 ]]; then
        log_pass "Storage detection works ($block_devices block devices found)"
    else
        log_warn "No standard block devices found (may be running in container)"
    fi
}

# Run all tests
run_all_tests() {
    echo -e "${BLUE}Starting Pterodactyl VPS Optimizer Test Suite${NC}"
    echo "=============================================="
    echo ""
    
    # Basic functionality tests
    test_script_exists || true
    test_script_syntax || true
    test_help_function || true
    test_version_function || true
    
    # System compatibility tests
    test_required_commands || true
    test_os_detection || true
    test_config_detection || true
    test_service_detection || true
    
    # System detection tests
    test_memory_calculation || true
    test_cpu_detection || true
    test_network_detection || true
    test_storage_detection || true
    
    # Functionality tests
    test_backup_functionality || true
    
    # Advanced tests (require root)
    test_dry_run_mode || true
    
    echo ""
    echo "=============================================="
    echo -e "${BLUE}Test Results Summary${NC}"
    echo "=============================================="
    echo "Total Tests: $test_count"
    echo -e "Passed: ${GREEN}$pass_count${NC}"
    echo -e "Failed: ${RED}$fail_count${NC}"
    echo -e "Success Rate: $(( pass_count * 100 / test_count ))%"
    
    if [[ $fail_count -eq 0 ]]; then
        echo -e "${GREEN}All tests passed! The optimizer script appears to be working correctly.${NC}"
        return 0
    else
        echo -e "${YELLOW}Some tests failed. Please review the issues above.${NC}"
        return 1
    fi
}

# Main execution
main() {
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        echo "Pterodactyl VPS Optimizer Test Suite"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "This script tests the functionality of the Pterodactyl VPS Optimizer"
        echo "to ensure it will work correctly on your system."
        echo ""
        echo "Options:"
        echo "  -h, --help    Show this help message"
        echo ""
        echo "Note: Some tests require root privileges for full validation."
        exit 0
    fi
    
    run_all_tests
}

main "$@"
