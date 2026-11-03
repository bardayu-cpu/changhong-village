"""Foreground, LAN-only static server for this release's dedicated Web export."""
import argparse
import functools
import http.server
import ipaddress
import socket
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPORT = ROOT / "发布/试玩收尾-1028/Web"


def lan_address():
    for interface in ["en0", "en1", "en2"]:
        result = subprocess.run(["/usr/sbin/ipconfig", "getifaddr", interface],
                                capture_output=True, text=True)
        address = result.stdout.strip()
        try:
            value = ipaddress.ip_address(address)
            if value.is_private and not value.is_loopback and not value.is_link_local:
                return address
        except ValueError:
            pass
    return "127.0.0.1"


class ExportHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".pck": "application/octet-stream"}

    def translate_path(self, path):
        candidate = Path(super().translate_path(path)).resolve()
        if not candidate.is_relative_to(EXPORT.resolve()):
            return str(EXPORT / "__outside_export_forbidden__")
        return str(candidate)

    def list_directory(self, path):
        self.send_error(403, "Directory listing disabled")

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--local-only", action="store_true")
    args = parser.parse_args()
    if not (EXPORT.parent / ".verified-1028.5").is_file():
        raise SystemExit("本轮Web试玩包尚未完成核验，未开启旧包服务。")
    if not (EXPORT / "index.html").is_file():
        raise SystemExit("尚未找到本轮Web试玩包，请先完成导出。")
    if EXPORT.is_symlink() or any(p.is_symlink() for p in EXPORT.rglob("*")):
        raise SystemExit("Web导出目录含链接，未启动服务。")
    address = "127.0.0.1" if args.local_only else lan_address()
    handler = functools.partial(ExportHandler, directory=str(EXPORT))
    server = None
    for port in range(args.port, args.port + 12):
        try:
            server = http.server.ThreadingHTTPServer((address, port), handler)
            break
        except OSError as error:
            if error.errno not in [48, 98]:
                raise
    if server is None:
        raise SystemExit("附近端口都被占用，请稍后重试；未结束任何已有进程。")
    print("裳泓村 · 手机试玩", flush=True)
    print("访问地址：http://%s:%d/" % server.server_address, flush=True)
    if address == "127.0.0.1":
        print("未检测到局域网地址：目前仅本机可访问。", flush=True)
    else:
        print("手机与电脑连接同一Wi-Fi，在手机浏览器输入上面地址。", flush=True)
    print("电脑保持运行；按 Control+C 停止。本服务仅提供本轮Web导出文件。", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
