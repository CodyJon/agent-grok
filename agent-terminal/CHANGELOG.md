# Changelog

## 1.1.0

Personal fork of BONOBOGAMES/agent-terminal 1.0.3, rebranded and brought
in line with Claude Terminal 2.5.1–2.5.4 reliability fixes.

- Identity: Grok Terminal, slug `grok_terminal`, images at
  `ghcr.io/codyjon/{arch}-addon-grok-terminal`
- Quotes in `grok_extra_args` no longer blank the terminal (ttyd execs
  tmux directly; flags are parsed once)
- `working_directory` option (defaults to `/config`)
- ha-mcp stores literal `${SUPERVISOR_TOKEN}` so the live Supervisor
  token is not written into `/data` (and therefore not into HA backups)
- MCP add/remove wrapped in 30s timeouts so a wedged `grok` cannot
  block startup
- Persistent Grok binary is verified with `grok --version`; an
  unrunnable copy is removed so it cannot shadow the bundled binary
- Official installer downloaded to a file and run with stdin closed
  (avoids `curl | bash` hanging on an inherited pipe)
- Unused `auth_api` permission dropped
- Port 7681 description warns it is an unauthenticated root shell
- `grok-doctor` treats a present-but-unrunnable `grok` as a failure

## 1.0.3

- Docs: install path updated for Home Assistant **Apps** rename (2026.2+)
- My Home Assistant repository link
- Use-case / xAI account requirements clarified

## 1.0.2

- CI: Node 24-compatible GitHub Actions; ShellCheck via apt

## 1.0.1

- Ship prebuilt multi-arch images from GHCR (`image:` in `config.yaml`)

## 1.0.0

- Initial release: fork of [Claude Terminal](https://github.com/heytcass/home-assistant-addons) **v2.5.0** (commit `cebf29eb`) rewired for xAI Grok Build (`grok`)
