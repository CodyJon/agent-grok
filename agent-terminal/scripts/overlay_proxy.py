#!/usr/bin/env python3
"""Inject the mobile bar into ttyd HTML. Websockets are spliced raw.

The previous aiohttp websocket client rewrote ttyd frames and left a blank
terminal until refresh. A byte pipe does not touch the protocol.
"""
import asyncio
import os
import sys

LISTEN = int(sys.argv[sys.argv.index("--listen") + 1]) if "--listen" in sys.argv else 7681
UPSTREAM = int(sys.argv[sys.argv.index("--upstream") + 1]) if "--upstream" in sys.argv else 7682


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


async def pipe(reader, writer):
    try:
        while True:
            chunk = await reader.read(65536)
            if not chunk:
                break
            writer.write(chunk)
            await writer.drain()
    except (ConnectionError, asyncio.CancelledError, BrokenPipeError):
        pass
    finally:
        try:
            writer.close()
        except Exception:
            pass


async def read_headers(reader):
    data = b""
    while b"\r\n\r\n" not in data and len(data) < 65536:
        chunk = await reader.read(4096)
        if not chunk:
            break
        data += chunk
    return data


async def handle(client_r, client_w):
    try:
        req = await read_headers(client_r)
        if not req:
            client_w.close()
            return
        up_r = up_w = None
        for _ in range(40):
            try:
                up_r, up_w = await asyncio.open_connection("127.0.0.1", UPSTREAM)
                break
            except OSError:
                await asyncio.sleep(0.25)
        if up_w is None:
            client_w.write(b"HTTP/1.1 502 Bad Gateway\r\nContent-Length: 11\r\n\r\nttyd down\n")
            await client_w.drain()
            client_w.close()
            return

        head, _, rest = req.partition(b"\r\n\r\n")
        first = head.split(b"\r\n", 1)[0].lower()
        is_ws = b"upgrade: websocket" in head.lower()
        if is_ws:
            up_w.write(req)
            await up_w.drain()
            await asyncio.gather(pipe(client_r, up_w), pipe(up_r, client_w))
            return

        # Only rewrite the document. Everything else is a straight pipe.
        path = first.split(b" ")[1] if b" " in first else b"/"
        rewrite = path.split(b"?", 1)[0] in (b"/", b"")
        up_w.write(req)
        await up_w.drain()
        if not rewrite:
            await asyncio.gather(pipe(client_r, up_w), pipe(up_r, client_w))
            return

        raw = rest
        while b"\r\n\r\n" not in raw and len(raw) < 2_000_000:
            chunk = await up_r.read(65536)
            if not chunk:
                break
            raw += chunk
        hdr, _, body = raw.partition(b"\r\n\r\n")
        # Read a declared content-length if present so we do not cut the page.
        clen = 0
        for line in hdr.split(b"\r\n"):
            if line.lower().startswith(b"content-length:"):
                try:
                    clen = int(line.split(b":", 1)[1].strip())
                except ValueError:
                    clen = 0
        while clen and len(body) < clen:
            chunk = await up_r.read(clen - len(body))
            if not chunk:
                break
            body += chunk
        if b"<html" in body.lower() or b"<!doctype" in body.lower():
            body = inject(body)
            lines = [ln for ln in hdr.split(b"\r\n") if not ln.lower().startswith(b"content-length:") and not ln.lower().startswith(b"transfer-encoding:")]
            hdr = b"\r\n".join(lines) + b"\r\nContent-Length: " + str(len(body)).encode()
        client_w.write(hdr + b"\r\n\r\n" + body)
        await client_w.drain()
    except Exception:
        pass
    finally:
        try:
            client_w.close()
        except Exception:
            pass


async def main():
    server = await asyncio.start_server(handle, "0.0.0.0", LISTEN)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
