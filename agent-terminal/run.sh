#!/usr/bin/with-contenv bashio

# Grok Terminal — Grok Build CLI in a browser terminal (ttyd + tmux).
# Adapted from Claude Terminal (heytcass) and Agent Terminal (BONOBOGAMES), MIT.
#
# Startup philosophy: everything the terminal needs is baked into the image,
# and nothing on the boot path may depend on the network or block on input.
# Network work (Grok updates, HA context generation) happens in the
# background after the terminal is already available.

set -e
set -o pipefail

init_environment() {
    local data_home="/data/home"
    local config_dir="/data/.config"
    local cache_dir="/data/.cache"
    local state_dir="/data/.local/state"
    local grok_home="${data_home}/.grok"

    bashio::log.info "Initializing Grok Build environment in /data..."

    if ! mkdir -p "$data_home" "$config_dir" "$cache_dir" "$state_dir" \
        "/data/.local" "$grok_home" "$grok_home/bin" "$grok_home/downloads"; then
        bashio::log.error "Failed to create directories in /data"
        exit 1
    fi

    chmod 755 "$data_home" "$config_dir" "$cache_dir" "$state_dir" "$grok_home"

    export HOME="$data_home"
    export XDG_CONFIG_HOME="$config_dir"
    export XDG_CACHE_HOME="$cache_dir"
    export XDG_STATE_HOME="$state_dir"
    export XDG_DATA_HOME="/data/.local/share"

    export PATH="$grok_home/bin:/usr/local/bin:$PATH"

    if bashio::config.has_value 'xai_api_key'; then
        local key
        key=$(bashio::config 'xai_api_key')
        if [ -n "$key" ] && [ "$key" != "null" ]; then
            export XAI_API_KEY="$key"
            bashio::log.info "XAI_API_KEY loaded from add-on options"
        fi
    fi

    if [ -f "/opt/scripts/tmux.conf" ]; then
        cp /opt/scripts/tmux.conf "$data_home/.tmux.conf"
        chmod 644 "$data_home/.tmux.conf"
    fi

    bashio::log.info "Environment initialized (HOME=${HOME})"
}

setup_commands() {
    local entry name script
    for entry in \
        "welcome:/opt/scripts/welcome.sh" \
        "persist-install:/opt/scripts/persist-install.sh" \
        "ha-context:/opt/scripts/ha-context.sh" \
        "grok-doctor:/opt/scripts/health-check.sh" \
        "grok-login-url:/opt/scripts/grok-login-url.sh"; do
        name="${entry%%:*}"
        script="${entry#*:}"
        if [ -f "$script" ]; then
            cp "$script" "/usr/local/bin/$name"
            chmod +x "/usr/local/bin/$name"
        else
            bashio::log.warning "Script not found: $script"
        fi
    done

    bashio::addon.version > /opt/scripts/addon-version 2>/dev/null \
        || echo "unknown" > /opt/scripts/addon-version
}

persistent_grok_runs() {
    timeout 10 "$HOME/.grok/bin/grok" --version >/dev/null 2>&1
}

ensure_persistent_grok_usable() {
    [ -x "$HOME/.grok/bin/grok" ] || return 1
    if persistent_grok_runs; then
        return 0
    fi
    bashio::log.warning "Persistent Grok is present but fails to run; removing it and falling back to the bundled copy"
    rm -f "$HOME/.grok/bin/grok"
    return 1
}

update_grok() {
    local persistent_usable=0
    ensure_persistent_grok_usable || persistent_usable=$?

    if [ "$(bashio::config 'grok_auto_update' 'true')" != "true" ]; then
        if [ "$persistent_usable" -eq 0 ]; then
            bashio::log.info "Grok auto-update disabled; using persistent grok binary"
        else
            bashio::log.info "Grok auto-update disabled; using bundled grok binary"
        fi
        return 0
    fi

    if [ "$persistent_usable" -eq 0 ]; then
        bashio::log.info "Persistent Grok found; checking for updates in background"
        (
            installer=$(mktemp /tmp/grok-install.XXXXXX.sh)
            if curl -fsSL --connect-timeout 10 https://x.ai/cli/install.sh -o "$installer"; then
                bash "$installer" </dev/null >/dev/null 2>&1 || true
            fi
            rm -f "$installer"
            if [ -x "$HOME/.grok/bin/grok" ] && ! persistent_grok_runs; then
                bashio::log.warning "Updated Grok no longer runs in this image; removing it and falling back to the bundled copy"
                rm -f "$HOME/.grok/bin/grok"
            fi
        ) &
        return 0
    fi

    bashio::log.info "Installing persistent Grok into /data (background)..."
    (
        installer=$(mktemp /tmp/grok-install.XXXXXX.sh)
        if curl -fsSL --connect-timeout 10 https://x.ai/cli/install.sh -o "$installer" \
            && bash "$installer" </dev/null >/dev/null 2>&1 \
            && [ -x "$HOME/.grok/bin/grok" ] && persistent_grok_runs; then
            bashio::log.info "Persistent Grok installed: $("$HOME/.grok/bin/grok" --version 2>/dev/null || echo 'version unknown')"
        else
            rm -f "$HOME/.grok/bin/grok"
            bashio::log.warning "Persistent Grok install failed or unrunnable; using bundled copy for now"
        fi
        rm -f "$installer"
    ) &
}

install_persistent_packages() {
    local persist_config="/data/persistent-packages.json"
    local apk_packages=""
    local pip_packages=""

    if bashio::config.has_value 'persistent_apk_packages'; then
        local config_apk
        config_apk=$(bashio::config 'persistent_apk_packages')
        if [ -n "$config_apk" ] && [ "$config_apk" != "null" ]; then
            apk_packages="$config_apk"
        fi
    fi

    if bashio::config.has_value 'persistent_pip_packages'; then
        local config_pip
        config_pip=$(bashio::config 'persistent_pip_packages')
        if [ -n "$config_pip" ] && [ "$config_pip" != "null" ]; then
            pip_packages="$config_pip"
        fi
    fi

    if [ -f "$persist_config" ]; then
        local local_apk local_pip
        local_apk=$(jq -r '.apk_packages | join(" ")' "$persist_config" 2>/dev/null || echo "")
        if [ -n "$local_apk" ]; then
            apk_packages="$apk_packages $local_apk"
        fi

        local_pip=$(jq -r '.pip_packages | join(" ")' "$persist_config" 2>/dev/null || echo "")
        if [ -n "$local_pip" ]; then
            pip_packages="$pip_packages $local_pip"
        fi
    fi

    apk_packages=$(echo "$apk_packages" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
    pip_packages=$(echo "$pip_packages" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

    if [ -n "$apk_packages" ]; then
        bashio::log.info "Installing persistent APK packages: $apk_packages"
        # shellcheck disable=SC2086
        if apk add --no-cache $apk_packages; then
            bashio::log.info "APK packages installed successfully"
        else
            bashio::log.warning "Some APK packages failed to install"
        fi
    fi

    if [ -n "$pip_packages" ]; then
        bashio::log.info "Installing persistent pip packages: $pip_packages"
        # shellcheck disable=SC2086
        if pip3 install --break-system-packages --no-cache-dir $pip_packages; then
            bashio::log.info "pip packages installed successfully"
        else
            bashio::log.warning "Some pip packages failed to install"
        fi
    fi
}

generate_ha_context() {
    if [ "$(bashio::config 'ha_smart_context' 'true')" != "true" ]; then
        bashio::log.info "HA Smart Context disabled in configuration"
        return 0
    fi

    if [ -f /usr/local/bin/ha-context ]; then
        bashio::log.info "Generating Home Assistant context in background"
        (/usr/local/bin/ha-context >/dev/null 2>&1 || true) &
    fi
}

build_grok_flags() {
    local flags=""

    if [ "$(bashio::config 'always_approve' 'false')" = "true" ]; then
        flags="--permission-mode bypassPermissions"
    fi

    local extra
    extra=$(bashio::config 'grok_extra_args' '')
    if [ -n "$extra" ] && [ "$extra" != "null" ]; then
        flags="${flags:+$flags }$extra"
    fi

    echo "$flags"
}

get_working_directory() {
    local dir
    dir=$(bashio::config 'working_directory' '')
    if [ -z "$dir" ] || [ "$dir" = "null" ]; then
        echo "/config"
        return 0
    fi
    if [ -d "$dir" ]; then
        echo "$dir"
    else
        bashio::log.warning "working_directory '$dir' does not exist; starting in /config instead"
        echo "/config"
    fi
}

get_session_command() {
    local flags="$1"

    if [ "$(bashio::config 'auto_launch_grok' 'true')" = "true" ]; then
        echo "grok${flags:+ $flags}"
    else
        echo "/usr/local/bin/welcome --shell"
    fi
}

start_web_terminal() {
    local port=7681
    local flags
    flags=$(build_grok_flags)

    if [[ "$flags" == *"bypassPermissions"* ]] || [[ "$flags" == *"--always-approve"* ]]; then
        bashio::log.warning "always_approve / bypassPermissions is ENABLED."
    fi

    local session_command workdir
    session_command=$(get_session_command "$flags")
    workdir=$(get_working_directory)

    bashio::log.info "Starting web terminal on port ${port} with dictate/paste bar"

    local ttyd_theme='{"background":"#1a1b26","foreground":"#c0caf5","cursor":"#f59e0b","cursorAccent":"#1a1b26","selectionBackground":"#33467c","selectionForeground":"#c0caf5","black":"#15161e","red":"#f7768e","green":"#9ece6a","yellow":"#e0af68","blue":"#7aa2f7","magenta":"#bb9af7","cyan":"#7dcfff","white":"#a9b1d6","brightBlack":"#414868","brightRed":"#f7768e","brightGreen":"#9ece6a","brightYellow":"#e0af68","brightBlue":"#7aa2f7","brightMagenta":"#bb9af7","brightCyan":"#7dcfff","brightWhite":"#c0caf5"}'

    export GROK_TTYD_WORKDIR="$workdir"
    export GROK_TTYD_CMD="$session_command"
    export GROK_TTYD_THEME="$ttyd_theme"
    chmod +x /opt/scripts/start-ttyd.sh /opt/scripts/overlay_proxy.py 2>/dev/null || true
    exec /opt/scripts/start-ttyd.sh
}

setup_ha_mcp() {
    if [ -f "/opt/scripts/setup-ha-mcp.sh" ]; then
        bashio::log.info "Setting up Home Assistant MCP integration..."
        chmod +x /opt/scripts/setup-ha-mcp.sh
        source /opt/scripts/setup-ha-mcp.sh
        configure_ha_mcp_server || bashio::log.warning "ha-mcp setup encountered issues but continuing..."
    fi
}

main() {
    bashio::log.info "Starting Grok Terminal add-on..."

    init_environment
    setup_commands
    update_grok
    install_persistent_packages
    generate_ha_context
    setup_ha_mcp
    start_web_terminal
}

main "$@"
