#!/bin/sh
# Read the tmux selection on stdin and push it to the browser clipboard
# via OSC 52. ttyd/xterm.js turns that into a real clipboard write.
# Falls back silently if base64 or the tty is unavailable.
b64=$(base64 -w0 2>/dev/null || base64 2>/dev/null | tr -d '\n')
[ -n "$b64" ] || exit 0
printf '\033]52;c;%s\007' "$b64" > /dev/tty
