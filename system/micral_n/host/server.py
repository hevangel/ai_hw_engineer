#!/usr/bin/env python3
"""HTTP front panel for the persistent Verilator Micral N process."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import os
import subprocess
import threading

system = Path(__file__).resolve().parents[1]
simulator = os.environ.get("MICRAL_SIMULATOR", str(system / "build/obj_dir/Vmicral_n"))
image = os.environ.get("MICRAL_IMAGE", str(system / "build/mo5_input_output.hex"))
port = int(os.environ.get("MICRAL_PORT", "8080"))
process = subprocess.Popen([simulator, f"+image={image}"], stdin=subprocess.PIPE,
                           stdout=subprocess.PIPE, text=True, bufsize=1)
lock = threading.Lock()
last_state = None

def command(line):
    global last_state
    with lock:
        if process.poll() is not None:
            raise RuntimeError("simulator exited")
        process.stdin.write(line + "\n")
        process.stdin.flush()
        result = process.stdout.readline()
        if not result:
            raise RuntimeError("simulator returned no state")
        last_state = json.loads(result)
        return last_state

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(system / "host/web"), **kwargs)

    def send_json(self, result, code=200):
        data = json.dumps(result).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/api/state":
            try:
                self.send_json(command("RUN 1200" if last_state and last_state["running"] else "STATE"))
            except Exception as exc:
                self.send_json({"error": str(exc)}, 500)
        elif self.path == "/api/health":
            self.send_json({"ok": process.poll() is None})
        else:
            super().do_GET()

    def do_POST(self):
        if self.path != "/api/control":
            self.send_json({"error": "unknown endpoint"}, 404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length > 1024:
                raise ValueError("request too large")
            body = json.loads(self.rfile.read(length))
            action = body.get("action")
            value = int(body.get("value", 0))
            address = int(body.get("address", 0))
            if action in {"AUTO", "PAUSE", "STEP", "CYCLE", "RESET"}:
                line = action
            elif action == "INPUT" and 0 <= value <= 255:
                line = f"INPUT {value}"
            elif action == "SUB" and 0 <= value <= 255:
                line = f"SUB {int(bool(body.get('enabled')))} {value}"
            elif action == "TRAP" and 0 <= address < 16384:
                line = f"TRAP {int(bool(body.get('enabled')))} {address}"
            elif action == "POKE" and 0 <= address < 16384 and 0 <= value <= 255:
                line = f"POKE {address} {value}"
            else:
                raise ValueError("invalid control")
            self.send_json(command(line))
        except (ValueError, TypeError, json.JSONDecodeError) as exc:
            self.send_json({"error": str(exc)}, 400)
        except Exception as exc:
            self.send_json({"error": str(exc)}, 500)

try:
    print(f"Micral N panel: http://0.0.0.0:{port}/", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
finally:
    if process.poll() is None:
        process.stdin.write("QUIT\n")
        process.stdin.flush()
        process.wait(timeout=2)
