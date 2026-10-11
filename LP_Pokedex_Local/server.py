"""Serve the read-only Pokédex locally and rebuild when PBS or sprites change."""
from http.server import SimpleHTTPRequestHandler, HTTPServer
from pathlib import Path
import sys
import threading
import webbrowser

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))
from build_data import main as build_data  # noqa: E402

STAMP = None


def source_directories():
    paths = {"PBS": ROOT / "PBS", "SPRITE": ROOT / "Sprite"}
    config = ROOT / "PATHS.txt"
    if config.is_file():
        for line in config.read_text(encoding="utf-8-sig").splitlines():
            if "=" not in line or line.strip().startswith("#"):
                continue
            key, value = line.split("=", 1)
            if key.strip().upper() in paths and value.strip():
                paths[key.strip().upper()] = Path(value.strip().strip('"'))
    return paths["PBS"], paths["SPRITE"]


def input_stamp():
    result = []
    for directory in source_directories():
        if not directory.is_dir():
            raise FileNotFoundError(f"Thiếu thư mục {directory.name}")
        for path in directory.iterdir():
            if path.is_file() and (path.suffix.lower() == ".txt" or path.suffix.lower() == ".png"):
                stat = path.stat()
                result.append((directory.name, path.name, stat.st_mtime_ns, stat.st_size))
    return tuple(sorted(result))


def rebuild_if_changed():
    global STAMP
    latest = input_stamp()
    if latest != STAMP:
        build_data(*source_directories())
        STAMP = latest


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT / "dist"), **kwargs)

    def do_GET(self):
        try:
            rebuild_if_changed()
        except Exception as exc:
            self.send_error(500, f"Không đọc được PBS/Sprite: {exc}")
            return
        super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    rebuild_if_changed()
    try:
        server = HTTPServer(("127.0.0.1", 8765), Handler)
    except OSError as exc:
        raise SystemExit(f"Không mở được cổng 8765: {exc}. Hãy đóng cửa sổ Pokédex cũ rồi chạy lại.")
    address = "http://127.0.0.1:8765"
    print(f"\nPokédex chạy tại {address}")
    print("Sau khi sửa PBS hoặc Sprite: lưu file, quay lại trình duyệt và bấm Làm mới dữ liệu.")
    print("Đóng cửa sổ này hoặc nhấn Ctrl+C để tắt.\n")
    threading.Timer(0.8, lambda: webbrowser.open(address)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()
