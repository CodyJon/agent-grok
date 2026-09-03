# Grok Terminal

Grok Build CLI in a web terminal, as a Home Assistant **app** (formerly called an
*add-on*).

**Unofficial.** Not affiliated with, endorsed by, or sponsored by xAI, SpaceXAI,
Anthropic, or Home Assistant. Based on [Agent Terminal](https://github.com/BONOBOGAMES/agent-terminal)
and [Claude Terminal](https://github.com/heytcass/home-assistant-addons) (MIT).

Repository: [github.com/CodyJon/agent-terminal](https://github.com/CodyJon/agent-terminal)

## About

This app runs xAI’s [Grok Build](https://docs.x.ai/build/overview) CLI (`grok`)
in a browser-based terminal (ttyd + tmux) with your Home Assistant configuration
mounted. Open it from the sidebar, authenticate once, and ask Grok to write
automations, debug YAML, or manage your setup.

**Platform:** Home Assistant OS or Supervised only (Apps / Supervisor). Not for
plain Container or Core installs.

## Installation

**One-click repository add:**

[![Open your Home Assistant instance and show the add app repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FCodyJon%2Fagent-terminal)

Manual steps:

1. In Home Assistant, open **[Settings → Apps](https://my.home-assistant.io/redirect/supervisor)** and open the app store (**Install app**)
2. ⋮ → **Repositories** → add:

   `https://github.com/CodyJon/agent-terminal`

3. Install **Grok Terminal**
4. (Recommended) Open **Configuration** and set **xai_api_key**
5. Start the app
6. Optional: **Info** tab → enable **Show in sidebar**
7. Open the web UI (or use the sidebar)

Credentials and agent state live under `/data` and persist across restarts and
app updates.

Using Grok Build Service features requires accepting [xAI Terms of Service](https://x.ai/legal/terms-of-service).

`panel_admin` only hides the sidebar entry. Any signed-in Home Assistant user
who knows the ingress URL can open the terminal. Publishing port 7681 exposes
an unauthenticated root shell — leave it unset.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `auto_launch_grok` | `true` | Start Grok immediately when the terminal opens. Set to `false` for a shell. |
| `grok_auto_update` | `true` | Install the official binary into `/data` and refresh it in the background on each startup. |
| `working_directory` | `""` | Session start directory. Empty means `/config`. Must exist or the app falls back to `/config`. |
| `xai_api_key` | `""` | **Recommended.** xAI API key (`xai-...`). Exported as `XAI_API_KEY`. |
| `always_approve` | `false` | Launch with `--permission-mode bypassPermissions`. **Read the security note.** |
| `grok_extra_args` | `""` | Extra flags on every Grok launch, e.g. `-m grok-4`. Ordinary quoting works. |
| `ha_smart_context` | `true` | Generate `~/.grok/AGENTS.md` with HA system info. |
| `enable_ha_mcp` | `true` | Register [ha-mcp](https://github.com/homeassistant-ai/ha-mcp). |
| `ha_mcp_version` | `"7.11.0"` | ha-mcp release to run. |
| `persistent_apk_packages` | `[]` | APK packages reinstalled on every startup. |
| `persistent_pip_packages` | `[]` | Python packages reinstalled on every startup. |

## Usage

With default settings, Grok launches inside a tmux session named `grok`.
Navigating away in Home Assistant and coming back reattaches to the same
session.

```bash
grok               # start Grok Build
grok -c            # continue the most recent conversation
grok -r            # pick a past conversation to resume
grok-doctor        # diagnose network, auth, and environment issues
grok-login-url     # save the OAuth login URL to /config
persist-install apk htop   # install packages that survive restarts
ha-context         # refresh the Home Assistant context file
```

### Terminal tips

- **Scrolling**: mouse wheel — tmux copy-mode. Press `q` to jump back to the bottom.
- **Copying**: select with the mouse; on release it copies via OSC 52. HTTPS required. On plain `http://`, use Shift+drag.
- **Pasting**: `Ctrl+Shift+V` (or right-click).

### File access

Starts in `/config` unless `working_directory` is set. Also mounted:

- `/addon_configs`
- `/share`

## Authentication

### API key (recommended)

1. Create an API key in the xAI console.
2. Paste it into **xai_api_key**.
3. Restart the app.

### Interactive login

Run `grok` and follow prompts. If the login URL is too long to copy, use
`grok-login-url` and open `/config/grok-login-url.txt`.

## Home Assistant MCP

Bundled [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) talks to HA through
the Supervisor API. The Supervisor token is **not** written into `/data`; the
MCP config stores the literal `${SUPERVISOR_TOKEN}` and Grok expands it at
launch.

ha-mcp needs Python 3.13. The app provisions a managed build via uv into
`/data` on first use (~150–250 MB, persists).

Disable with `enable_ha_mcp: false` if you do not want the agent to control HA.

## Security notes

This app runs as root in its container, has read/write access to `/config`,
`/addon_configs`, and `/share`, and (with MCP) can control devices and
automations.

**`always_approve` removes the last human checkpoint.** Leave it off unless you
accept that trade-off.

Never commit API keys. Keys belong in Supervisor app options only.

## Troubleshooting

- **Can't copy the OAuth login URL**: second tmux window (`Ctrl+B` then `C`), run `grok-login-url`, open `/config/grok-login-url.txt`. Prefer **xai_api_key**.
- **Grok exits immediately**: app log; set `xai_api_key` or finish login; run `grok-doctor`.
- **Blank terminal after an update**: a broken persistent binary in `/data` used to shadow the bundled copy. 1.1.0 removes an unrunnable persistent `grok` automatically. Run `grok-doctor` to confirm.
- **Install fails pulling the image**: host must reach `ghcr.io`. Packages must be public: `ghcr.io/codyjon/amd64-addon-grok-terminal` and `aarch64-addon-grok-terminal`.

## Credits

- Architecture from **Claude Terminal** by Tom Cassady (MIT)
- Grok rewire from **Agent Terminal** by BONOBOGAMES (MIT)
- **Grok Build** by xAI / SpaceXAI
- **ha-mcp** by homeassistant-ai (MIT)
