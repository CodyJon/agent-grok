#!/usr/bin/with-contenv bashio

# Health check / grok-doctor for Grok Terminal

check_system_resources() {
    bashio::log.info "=== System Resources Check ==="

    local mem_total mem_free
    mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    mem_free=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
    bashio::log.info "Memory: ${mem_free}MB free of ${mem_total}MB total"

    if [ "$mem_free" -lt 256 ]; then
        bashio::log.error "Low memory warning: Less than 256MB available"
        bashio::log.info "This may cause installation or runtime issues"
    fi

    local disk_free
    disk_free=$(df -m /data | tail -1 | awk '{print $4}')
    bashio::log.info "Disk space in /data: ${disk_free}MB free"

    if [ "$disk_free" -lt 100 ]; then
        bashio::log.error "Low disk space warning: Less than 100MB in /data"
    fi
}

check_directory_permissions() {
    bashio::log.info "=== Directory Permissions Check ==="

    if [ -w "/data" ]; then
        bashio::log.info "/data directory: Writable ✓"
    else
        bashio::log.error "/data directory: Not writable ✗"
        return 1
    fi

    local test_dir="/data/.test_$$"
    if mkdir -p "$test_dir" 2>/dev/null; then
        bashio::log.info "Can create directories in /data ✓"
        rmdir "$test_dir"
    else
        bashio::log.error "Cannot create directories in /data ✗"
        return 1
    fi
}

check_grok_cli() {
    bashio::log.info "=== Grok CLI Check ==="

    if ! command -v grok >/dev/null 2>&1; then
        bashio::log.error "Grok CLI not found ✗"
        return 1
    fi

    bashio::log.info "Grok CLI found at: $(command -v grok) ✓"

    local ver
    if ! ver=$(timeout 10 grok --version 2>&1); then
        bashio::log.error "Grok is present but does not run (grok --version failed) ✗"
        bashio::log.error "$ver"
        return 1
    fi
    bashio::log.info "Version: $ver"
}

check_auth() {
    bashio::log.info "=== Auth Check ==="

    if [ -n "${XAI_API_KEY:-}" ]; then
        bashio::log.info "XAI_API_KEY is set ✓"
    elif [ -s "${HOME}/.grok/auth.json" ]; then
        bashio::log.info "Found ~/.grok/auth.json ✓"
    elif [ -n "${GROK_DEPLOYMENT_KEY:-}" ]; then
        bashio::log.info "GROK_DEPLOYMENT_KEY is set ✓"
    else
        bashio::log.warning "No XAI_API_KEY, auth.json, or GROK_DEPLOYMENT_KEY found"
        bashio::log.info "Set xai_api_key in add-on options (recommended) or run interactive login"
    fi
}

check_network_connectivity() {
    bashio::log.info "=== Network Connectivity Check ==="

    if host x.ai >/dev/null 2>&1 || nslookup x.ai >/dev/null 2>&1; then
        bashio::log.info "DNS resolution working ✓"
    else
        bashio::log.error "DNS resolution failing - check network configuration"
        bashio::log.info "Try setting custom DNS servers (e.g., 8.8.8.8, 1.1.1.1)"
    fi

    if curl -s --head --connect-timeout 10 --max-time 15 https://x.ai/cli/stable > /dev/null; then
        bashio::log.info "Can reach x.ai CLI CDN ✓"
    else
        bashio::log.warning "Cannot reach x.ai CLI CDN - Grok install/update may fail"
    fi

    if curl -s --head --connect-timeout 10 --max-time 15 https://api.x.ai > /dev/null; then
        bashio::log.info "Can reach api.x.ai ✓"
    else
        bashio::log.warning "Cannot reach api.x.ai - Grok API calls may fail"
    fi

    if curl -s --head --connect-timeout 10 --max-time 15 https://ghcr.io > /dev/null; then
        bashio::log.info "Can reach GitHub Container Registry ✓"
    else
        bashio::log.warning "Cannot reach ghcr.io - image pulls may fail"
    fi
}

check_runtime_tools() {
    bashio::log.info "=== Runtime Tools Check ==="

    local errors=0
    for bin in git tmux ttyd jq curl uv; do
        if command -v "$bin" >/dev/null 2>&1; then
            bashio::log.info "$bin: OK"
        else
            bashio::log.error "$bin: missing ✗"
            errors=$((errors + 1))
        fi
    done
    return $errors
}

run_diagnostics() {
    bashio::log.info "========================================="
    bashio::log.info "Grok Terminal — Health Check"
    bashio::log.info "========================================="

    local errors=0

    check_system_resources || ((errors++))
    check_directory_permissions || ((errors++))
    check_grok_cli || ((errors++))
    check_auth || true
    check_runtime_tools || ((errors++))
    check_network_connectivity || ((errors++))

    bashio::log.info "========================================="

    if [ "$errors" -eq 0 ]; then
        bashio::log.info "✅ All checks passed successfully!"
    else
        bashio::log.error "❌ $errors check(s) failed"
        bashio::log.info "Please review the errors above"
    fi

    return $errors
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_diagnostics
fi
