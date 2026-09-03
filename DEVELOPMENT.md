# Development Guide

Local loop for Grok Terminal without publishing a new HA version.

## Prerequisites

- Docker or Podman
- Git clone of this repository

## Quick test

```bash
docker build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.21 \
  -t local/grok-terminal:test ./agent-terminal

mkdir -p /tmp/test-config /tmp/test-data
echo '{"auto_launch_grok": false}' > /tmp/test-data/options.json

docker run -d --name test-grok-dev \
  -p 7681:7681 \
  -v /tmp/test-config:/config \
  -v /tmp/test-data:/data \
  local/grok-terminal:test

docker logs -f test-grok-dev
# browser: http://localhost:7681

docker stop test-grok-dev && docker rm test-grok-dev
```

`bashio::config` reads `/data/options.json`. Outside Supervisor, bashio
calls fall back to defaults.

## Hot-reload a script

```bash
docker cp ./agent-terminal/scripts/welcome.sh test-grok-dev:/opt/scripts/welcome.sh
docker exec test-grok-dev chmod +x /opt/scripts/welcome.sh
```

## Production release

1. Bump `version:` in `agent-terminal/config.yaml`
2. Add a matching section to `agent-terminal/CHANGELOG.md`
3. Commit and push `main` (or tag `v<version>`)
4. `publish-images.yml` pushes `ghcr.io/codyjon/{arch}-addon-grok-terminal`
5. First time only: GitHub \u2192 Packages \u2192 set both arch packages **public**

Home Assistant installs the tag that matches `version:`. An unbumped
version ships nothing new to existing installs.
