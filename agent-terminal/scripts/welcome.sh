#!/bin/bash

# Grok Terminal banner — compact, non-blocking header.
# With --shell, drops into an interactive bash afterwards (shell mode).
# Runs inside ttyd/tmux (user-visible) — plain bash, no bashio.

AMBER='\033[38;2;245;158;11m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

version=$(cat /opt/scripts/addon-version 2>/dev/null || echo "unknown")

echo ""
echo -e "  ${AMBER}Grok Terminal${NC}  ${DIM}v${version} · Home Assistant add-on${NC}"
echo ""
echo -e "  ${WHITE}grok${NC}              start Grok Build  ${DIM}(-c continue · -r resume a session)${NC}"
echo -e "  ${WHITE}grok-doctor${NC}       diagnose network, auth, and environment issues"
echo -e "  ${WHITE}grok-login-url${NC}    save OAuth login URL to /config (if browser auth)"
echo -e "  ${WHITE}persist-install${NC}   install apk/pip packages that survive restarts"
echo -e "  ${WHITE}ha-context${NC}        refresh the Home Assistant context file for Grok"
echo ""
echo -e "  ${DIM}Auth: set xai_api_key in add-on options, or export XAI_API_KEY${NC}"
echo ""

if [ "$1" = "--shell" ]; then
    exec bash
fi
