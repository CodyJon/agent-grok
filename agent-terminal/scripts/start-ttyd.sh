#!/usr/bin/env bash
# Bind ttyd on localhost and put the dictate/paste bar proxy on 7681.
set -euo pipefail

workdir=${GROK_TTYD_WORKDIR:-/config}
cmd=${GROK_TTYD_CMD:-grok}
theme=${GROK_TTYD_THEME:-}

ttyd \
  --port 7682 \
  --interface 127.0.0.1 \
  --writable \
  --ping-interval 30 \
  --client-option enableReconnect=true \
  --client-option reconnect=10 \
  --client-option reconnectInterval=5 \
  --client-option "theme=${theme}" \
  --client-option fontSize=14 \
  tmux new-session -A -s grok -c "$workdir" "$cmd" &

# Give ttyd a moment to bind so the first ingress request does not race.
for _ in $(seq 1 20); do
  if (echo >/dev/tcp/127.0.0.1/7682) >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

exec python3 /opt/scripts/overlay_proxy.py --listen 7681 --upstream 7682
