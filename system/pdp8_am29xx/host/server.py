#!/usr/bin/env python3
"""Local HTTP front panel for the PDP-8 Am29xx reconstruction.

Serves ``host/web`` and proxies a small command protocol to the persistent RTL
simulator in ``work/obj_host/Vpdp8_top``.  All machine state comes from the RTL;
this process only drives switches, keys and console wires.
"""

from __future__ import annotations

import json
import os
import subprocess
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = Path(__file__).resolve().parent / "web"
SIMULATOR = ROOT / "work" / "obj_host" / "Vpdp8_top"
PORT = int(os.environ.get("PDP8_PORT", "8080"))


class Simulator:
    def __init__(self) -> None:
        self.lock = threading.RLock()
        self.log = (ROOT / "work" / "host_simulator.log").open("w", encoding="utf-8")
        self.process = subprocess.Popen(
            [str(SIMULATOR)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=self.log,
            text=True,
            bufsize=1,
        )

    def command(self, text: str) -> dict:
        """Send one command and read its reply, plus the console drains.

        The whole exchange is atomic: the browser polls several endpoints and
        replies must not be interleaved across threads.
        """
        with self.lock:
            if self.process.poll() is not None:
                raise RuntimeError("RTL simulator exited; inspect work/host_simulator.log")
            self.process.stdin.write(text + "\n")
            self.process.stdin.flush()
            line = self.process.stdout.readline()
            if not line:
                raise RuntimeError("RTL simulator closed its output")
            state = json.loads(line) if line.lstrip().startswith("{") else {"text": line.rstrip()}
            tty = bytes.fromhex(self.raw("TTY").strip()).decode("latin-1")
            ptp = bytes.fromhex(self.raw("PTP").strip()).decode("latin-1")
            state["tty"] = tty
            state["ptp"] = ptp
            return state

    def raw(self, text: str) -> str:
        with self.lock:
            if self.process.poll() is not None:
                raise RuntimeError("RTL simulator exited")
            self.process.stdin.write(text + "\n")
            self.process.stdin.flush()
            return self.process.stdout.readline().rstrip()




SIM = Simulator()


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB), **kwargs)

    def log_message(self, fmt, *args):  # quieter console
        pass

    def do_GET(self):
        if self.path == "/":
            self.path = "/index.html"
        super().do_GET()

    def do_POST(self):
        if self.path != "/api":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length) or b"{}")
        text = str(body.get("cmd", ""))
        try:
            state = SIM.command(text)
            payload = json.dumps(state).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except Exception as exc:  # noqa: BLE001 - surface the message to the panel
            payload = json.dumps({"error": str(exc)}).encode()
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)


def main() -> None:
    if not SIMULATOR.exists():
        raise SystemExit(f"simulator not built: {SIMULATOR}")
    print(f"PDP-8 panel on http://localhost:{PORT}")
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
