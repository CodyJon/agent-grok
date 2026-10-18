#!/usr/bin/env python3
"""Inject the mobile bar into ttyd HTML. WebSockets are spliced raw.

Document requests have Accept-Encoding stripped so ttyd returns plain HTML.
Otherwise gzip hides </body> and the Mic/Paste bar never appears.
"""
import asyncio
import os
import sys
import time

LISTEN = int(sys.argv[sys.argv.index("--listen") + 1]) if "--listen" in sys.argv else 7681
UPSTREAM = int(sys.argv[sys.argv.index("--upstream") + 1]) if "--upstream" in sys.argv else 7682


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] proxy: {msg}", flush=True)


def load_overlay() -> bytes:
    for path in ("/opt/scripts/overlay.js", os.path.join(os.path.dirname(__file__), "overlay.js")):
        try:
            with open(path, "rb") as fh:
                return fh.read()
        except OSError:
            continue
    return b"console.warn('grok overlay missing');\n"


def inject(body: bytes) -> bytes:
    tag = b"<script>" + load_overlay() + b"</script>"
    low = body.lower()
    for marker in (b"</body>", b"</html>"):
        idx = low.rfind(marker)
        if idx != -1:
            return body[:idx] + tag + body[idx:]
    return body + tag


def strip_encoding(req: bytes) -> bytes:
    """Drop Accept-Encoding so upstream sends uncompressed HTML."""
    head, sep, rest = req.partition(b"\r\n\r\n")
    lines = [
        ln for ln in head.split(b"\r\n")
        if not ln.lower().startswith(b"accept-encoding:")
    ]
    return b"\r\n".join(lines) + sep + rest


async def pipe(reader, writer, label: str) -> None:
    try:
        while True:
            chunk = await reader.read(65536)
            if not chunk:
                break
            writer.write(chunk)
            await writer.drain()
    except (ConnectionError, asyncio.CancelledError, BrokenPipeError, OSError) as exc:
        log(f"{label} ended: {type(exc).__name__}")
    except Exception as exc:
        log(f"{label} error: {exc}")


async def read_headers(reader) -> bytes:
    data = b""
    while b"\r\n\r\n" not in data and len(data) < 65536:
        chunk = await reader.read(4096)
        if not chunk:
            break
        data += chunk
    return data


async def read_http_response(up_r, first_chunk: bytes = b"") -> tuple[bytes, bytes]:
    raw = first_chunk
    while b"\r\n\r\n" not in raw and len(raw) < 2_000_000:
        chunk = await up_r.read(65536)
        if not chunk:
            break
        raw += chunk
    if b"\r\n\r\n" not in raw:
        return raw, b""
    hdr, _, body = raw.partition(b"\r\n\r\n")
    clen = 0
    for line in hdr.split(b"\r\n"):
        if line.lower().startswith(b"content-length:"):
            try:
                clen = int(line.split(b":", 1)[1].strip())
            except ValueError:
                clen = 0
    if clen:
        while len(body) < clen:
            chunk = await up_r.read(clen - len(body))
            if not chunk:
                break
            body += chunk
    else:
        while len(body) < 2_000_000:
            chunk = await up_r.read(65536)
            if not chunk:
                break
            body += chunk
    return hdr, body


async def handle(client_r, client_w):
    peer = "?"
    up_w = None
    try:
        peer_info = client_w.get_extra_info("peername")
        peer = f"{peer_info[0]}:{peer_info[1]}" if peer_info else "?"
    except Exception:
        pass

    try:
        req = await read_headers(client_r)
        if not req:
            client_w.close()
            return

        up_r = up_w = None
        for attempt in range(40):
            try:
                up_r, up_w = await asyncio.open_connection("127.0.0.1", UPSTREAM)
                break
            except OSError:
                if attempt == 0:
                    log(f"waiting for ttyd on :{UPSTREAM}")
                await asyncio.sleep(0.25)
        if up_w is None:
            log(f"502 {peer} — ttyd not ready")
            client_w.write(b"HTTP/1.1 502 Bad Gateway\r\nContent-Length: 11\r\n\r\nttyd down\n")
            await client_w.drain()
            client_w.close()
            return

        head, _, rest = req.partition(b"\r\n\r\n")
        first = head.split(b"\r\n", 1)[0]
        is_ws = b"upgrade: websocket" in head.lower()
        path = b"/"
        if b" " in first:
            path = first.split(b" ")[1].split(b"?")[0]

        if is_ws:
            log(f"WS open  {peer} {path.decode(errors='replace')}")
            up_w.write(req)
            await up_w.drain()
            await asyncio.gather(
                pipe(client_r, up_w, f"client→ttyd {peer}"),
                pipe(up_r, client_w, f"ttyd→client {peer}"),
            )
            log(f"WS close {peer}")
            return

        rewrite = path in (b"/", b"")
        if rewrite:
            req = strip_encoding(req)
        log(f"HTTP {peer} {path.decode(errors='replace')} rewrite={rewrite}")
        up_w.write(req)
        await up_w.drain()

        if not rewrite:
            await asyncio.gather(
                pipe(client_r, up_w, f"client→ttyd {peer}"),
                pipe(up_r, client_w, f"ttyd→client {peer}"),
            )
            return

        hdr, body = await read_http_response(up_r, rest)
        if b"<html" in body.lower() or b"<!doctype" in body.lower():
            body = inject(body)
            lines = [
                ln for ln in hdr.split(b"\r\n")
                if not ln.lower().startswith(b"content-length:")
                and not ln.lower().startswith(b"transfer-encoding:")
                and not ln.lower().startswith(b"content-encoding:")
            ]
            hdr = b"\r\n".join(lines) + b"\r\nContent-Length: " + str(len(body)).encode()
            log(f"injected overlay ({len(body)} bytes)")
        else:
            log(f"no html to inject ({len(body)} bytes)")
        client_w.write(hdr + b"\r\n\r\n" + body)
        await client_w.drain()

    except Exception as exc:
        log(f"handle error {peer}: {exc}")
    finally:
        for w in (client_w, up_w):
            if w is not None:
                try:
                    w.close()
                except Exception:
                    pass


async def main():
    log(f"listening on :{LISTEN}, upstream :{UPSTREAM}")
    server = await asyncio.start_server(handle, "0.0.0.0", LISTEN)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
