# Grok Terminal for Home Assistant

Custom **Home Assistant app** (formerly *add-on*) that runs xAI’s Grok Build CLI (`grok`) in a browser terminal with your `/config` mounted.

Maintained by [CodyJon](https://github.com/CodyJon). Unofficial — not affiliated with, endorsed by, or sponsored by xAI, SpaceXAI, Anthropic, or Home Assistant.

Based on [Agent Terminal](https://github.com/BONOBOGAMES/agent-terminal) and [Claude Terminal](https://github.com/heytcass/home-assistant-addons) (MIT).

## What this is for

- Write and fix automations, scripts, and YAML with an agent that can see your live config
- Debug dashboards, templates, and entity issues from the same machine that runs HA
- Optionally let Grok talk to Home Assistant via [ha-mcp](https://github.com/homeassistant-ai/ha-mcp)

**Requirements:** Home Assistant OS or Supervised (Apps / Supervisor). An **xAI account** and either an **API key** (recommended) or interactive login. Not available on plain Container/Core installs without Supervisor.

## Installation

Requires [Home Assistant OS](https://www.home-assistant.io/installation/) or Supervised.

**Quick path** (opens the add-repository dialog on a machine that can reach your HA instance):

[![Open your Home Assistant instance and show the add app repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FCodyJon%2Fagent-terminal)

Or manually:

1. Go to **[Settings → Apps](https://my.home-assistant.io/redirect/supervisor)** → open the app store (**Install app** / store icon)
2. ⋮ (top right) → **Repositories**
3. Add: `https://github.com/CodyJon/agent-terminal`
4. Find **Grok Terminal**, install, set **xai_api_key** (recommended), start

> Since Home Assistant 2026.2 the UI says **Apps** instead of **Add-ons**. Same Supervisor packaging model.

Prebuilt images are published to GHCR (`ghcr.io/codyjon/{arch}-addon-grok-terminal`). After the first Actions run, set those packages to **public** so Supervisor can pull them.

## Documentation

- [App docs](agent-terminal/DOCS.md) — options, auth, security, troubleshooting
- [Development](DEVELOPMENT.md) — local container loop
- [GROK.md](GROK.md) — notes for Grok (or you) working in this repo

## License

MIT — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
