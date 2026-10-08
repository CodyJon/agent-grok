# Changelog

## 1.2.3

- Fix blank terminal under HA ingress: WebSocket proxy no longer closes early
- Add proxy logging (visible in addon log)
- More robust HTML inject (full body read)
- Wait for ttyd to bind before starting the proxy

## 1.2.2

- Pass ttyd WebSockets through raw so the terminal stops loading blank

## 1.2.1

- Fix mobile bar missing under Home Assistant ingress (script is inlined)

## 1.2.0

- Bottom bar: Mic, Paste, Esc, Tab, Ctrl-C, Enter
- Mic inserts one final transcript (no iPhone dictation doubling)

## 1.1.0

Personal fork of BONOBOGAMES/agent-terminal 1.0.3, rebranded and brought
in line with Claude Terminal 2.5.1–2.5.4 reliability fixes.

## 1.0.0

- Initial Grok Terminal release
