# GROK.md

Guidance for Grok (or a human) working in this repository.

## What this repo is

A thin Home Assistant app: ttyd + tmux + the official Grok Build CLI, with
`/config` mounted. Job is to run `grok` reliably inside HA OS. Do not add a
custom chat UI or session picker.

Fork lineage:

- Claude Terminal (heytcass/home-assistant-addons) — terminal architecture
- BONOBOGAMES/agent-terminal 1.0.3 — Grok rewire
- This repo — CodyJon’s public personal fork

## Design rules

- Nothing on the boot path may hit the network or block on input.
- Persistent state lives in `/data` (`HOME=/data/home`). Caches stay in `/tmp`.
- Two Grok copies: bundled `/usr/local/bin/grok` (image, fallback) and
  `$HOME/.grok/bin/grok` (persistent, wins on PATH). A persistent binary that
  exists but cannot run must be deleted so it cannot shadow the bundled copy.
- `version:` in `agent-terminal/config.yaml` is the release. Bump it and
  CHANGELOG together or HA will not offer an update.
- `image:` must match GHCR names produced by `.github/workflows/publish-images.yml`.

## Layout

- `repository.yaml` — HA app store metadata
- `agent-terminal/config.yaml` — slug, version, options, ingress, maps
- `agent-terminal/Dockerfile` — Alpine base, baked runtime, bundled grok
- `agent-terminal/run.sh` — boot path
- `agent-terminal/scripts/` — welcome, doctor, ha-context, MCP, persist-install

## Commands

```bash
# Lint
hadolint ./agent-terminal/Dockerfile
shellcheck -s bash -e SC1008 -e SC1091 agent-terminal/run.sh agent-terminal/scripts/*.sh

# Local image (no Supervisor)
docker build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.21 \
  -t local/grok-terminal:test ./agent-terminal
```

See DEVELOPMENT.md for the full local loop.

## Do not

- Commit API keys
- Expand `SUPERVISOR_TOKEN` into files under `/data`
- Re-enable `auth_api` without a caller
- Point `image:` or install URLs back at BONOBOGAMES
