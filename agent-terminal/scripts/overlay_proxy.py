#!/usr/bin/env python3
"""Proxy ttyd and inject the Grok mobile bar into HTML responses."""
import argparse
import asyncio
import os
import sys

from aiohttp import ClientSession, WSMsgType, web

INJECT = b'<script src="/grok-overlay.js"></script></body>'


def load_overlay() -> bytes:
    for path in (
        "/opt/scripts/overlay.js",
        os.path.join(os.path.dirname(__file__), "overlay.js"),
    ):
        try:
            with open(path, "rb") as fh:
                return fh.read()
        except OSError:
            continue
    return b"console.warn('grok overlay missing');\n"


async def handle_overlay(_request: web.Request) -> web.Response:
    return web.Response(
        body=load_overlay(),
        content_type="application/javascript; charset=utf-8",
        headers={"Cache-Control": "no-store"},
    )


async def proxy(request: web.Request) -> web.StreamResponse:
    upstream = request.app["upstream"]
    url = f"http://127.0.0.1:{upstream}{request.path_qs}"
    if request.headers.get("Upgrade", "").lower() == "websocket":
        return await ws_proxy(request, url)

    hdrs = {
        k: v
        for k, v in request.headers.items()
        if k.lower() not in {"host", "content-length", "transfer-encoding", "connection"}
    }
    data = await request.read() if request.can_read_body else None
    async with request.app["session"].request(
        request.method, url, headers=hdrs, data=data, allow_redirects=False
    ) as resp:
        body = await resp.read()
        ctype = resp.headers.get("Content-Type", "")
        if "text/html" in ctype and b"</body>" in body:
            body = body.replace(b"</body>", INJECT, 1)
        headers = {
            k: v
            for k, v in resp.headers.items()
            if k.lower()
            not in {"content-length", "transfer-encoding", "content-encoding", "connection"}
        }
        return web.Response(status=resp.status, body=body, headers=headers)


async def ws_proxy(request: web.Request, url: str) -> web.WebSocketResponse:
    ws_server = web.WebSocketResponse()
    await ws_server.prepare(request)
    ws_url = url.replace("http://", "ws://", 1)
    proto = request.headers.get("Sec-WebSocket-Protocol")
    async with request.app["session"].ws_connect(
        ws_url,
        protocols=[proto] if proto else [],
        headers={
            k: v
            for k, v in request.headers.items()
            if k.lower() in {"cookie", "origin", "sec-websocket-protocol"}
        },
    ) as ws_client:

        async def c2s():
            async for msg in ws_server:
                if msg.type == WSMsgType.TEXT:
                    await ws_client.send_str(msg.data)
                elif msg.type == WSMsgType.BINARY:
                    await ws_client.send_bytes(msg.data)
                elif msg.type in {WSMsgType.CLOSE, WSMsgType.ERROR}:
                    break

        async def s2c():
            async for msg in ws_client:
                if msg.type == WSMsgType.TEXT:
                    await ws_server.send_str(msg.data)
                elif msg.type == WSMsgType.BINARY:
                    await ws_server.send_bytes(msg.data)
                elif msg.type in {WSMsgType.CLOSE, WSMsgType.ERROR}:
                    break

        tasks = [asyncio.create_task(c2s()), asyncio.create_task(s2c())]
        _done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for task in pending:
            task.cancel()
    await ws_server.close()
    return ws_server


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen", type=int, default=7681)
    parser.add_argument("--upstream", type=int, default=7682)
    args = parser.parse_args()

    app = web.Application()
    app["upstream"] = args.upstream
    app.router.add_get("/grok-overlay.js", handle_overlay)
    app.router.add_route("*", "/{path:.*}", proxy)

    async def session_ctx(app: web.Application):
        app["session"] = ClientSession()
        yield
        await app["session"].close()

    app.cleanup_ctx.append(session_ctx)
    web.run_app(app, host="0.0.0.0", port=args.listen, print=lambda *_: None)
    return 0


if __name__ == "__main__":
    sys.exit(main())
