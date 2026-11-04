#!/usr/bin/env python3
"""Local HTTP front panel for the PDP-1 Am29xx machine.

Serves the panel, proxies a fixed command set to the Verilator model over
stdin/stdout, exposes the Type 30 display/typewriter events, and serves a
recorded FST waveform to the bundled Surfer viewer.
"""
import json
import os
import re
import subprocess
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
SIM = ROOT / "work/obj/Vpdp1_am29xx"
WAVE = ROOT / "work/waveform.fst"
SURFER_ROOT = Path("/opt/surfer/webapp")
ALLOWED = re.compile(
    r"^(STATE|EVENTS|TW [0-7]{1,6}|SS [0-7]{1,2}|RUN \d{1,6}|STEP \d{1,5}|RESET|RESUME|"
    r"LOAD [\w./-]+|DEPOSIT [0-7]+ [0-7]+|EXAMINE [0-7]+|KEY [0-9a-fA-F]{1,6}|"
    r"KEYCLEAR|TAPE [\w./-]+|TAPECLEAR|WAVE( \d{1,6})?( [\w./-]+)?)$")


class Simulator:
    def __init__(self):
        self.lock = threading.RLock()
        self.process = subprocess.Popen(
            [str(SIM)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=(ROOT / "work/server_simulator.log").open("w"),
            text=True, bufsize=1, cwd=ROOT)

    def command(self, line):
        with self.lock:
            if self.process.poll() is not None:
                raise RuntimeError("RTL simulator exited; see work/server_simulator.log")
            self.process.stdin.write(line + "\n")
            self.process.stdin.flush()
            reply = self.process.stdout.readline()
            if not reply:
                raise RuntimeError("RTL simulator returned no reply")
            return json.loads(reply)

    def state(self):
        with self.lock:
            state = self.command("STATE")
            events = self.command("EVENTS")
            state["plots"] = events.get("plots", [])
            state["tty"] = events.get("tty", "")
            return state

    def waveform(self):
        with self.lock:
            self.command(f"WAVE 4000 {WAVE}")
            return WAVE.read_bytes()

    def close(self):
        with self.lock:
            if self.process.poll() is None:
                self.process.stdin.write("QUIT\n")
                self.process.stdin.flush()
                try:
                    self.process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    self.process.terminate()


def tape_words(path: Path):
    """Decode a RIM-format PDP-1 paper tape into 18-bit words.

    RIM block: word count, origin, data..., checksum (one's-complement sum of
    count, origin and data). Words are 18 bits, stored little-endian in three
    6-bit characters on the tape; this helper accepts the octal text form that
    scripts/pdp1asm.py and the repository's reference tapes use.
    """
    words = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith(("#", ";")):
            continue
        for token in line.split():
            words.append(int(token, 8) & 0o777777)
    return words


def main():
    sim = Simulator()

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(ROOT / "host/web"), **kwargs)

        def translate_path(self, path):
            name = unquote(urlsplit(path).path)
            if name.startswith("/surfer/"):
                candidate = (SURFER_ROOT / name[len("/surfer/"):]).resolve()
                if not candidate.is_relative_to(SURFER_ROOT):
                    return str(SURFER_ROOT / "not-found")
                return str(candidate)
            return super().translate_path(path)

        def log_message(self, *args):
            pass

        def do_GET(self):
            parts = urlsplit(self.path)
            if parts.path == "/api/state":
                self._json(sim.state())
            elif parts.path == "/api/command":
                query = parse_qs(parts.query)
                command = (query.get("c") or [""])[0]
                self._command(command)
            elif parts.path == "/waveform.fst":
                data = sim.waveform()
                self.send_response(200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            elif parts.path == "/api/tape":
                name = (parse_qs(parts.query).get("file") or [""])[0]
                path = (ROOT / name).resolve()
                if not path.is_relative_to(ROOT) or not path.is_file():
                    self._json({"ok": False, "error": "tape file not found"})
                    return
                words = tape_words(path)
                tape = ROOT / "work/panel_tape.hex"
                tape.write_text("\n".join(f"{i:04o} {w:06o}" for i, w in enumerate(words)) + "\n")
                self._json(sim.command(f"TAPE {tape}"))
            else:
                super().do_GET()

        def do_POST(self):
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length).decode("utf-8", "replace")
            if self.path.startswith("/api/command"):
                self._command(body.strip())
            elif self.path.startswith("/api/upload"):
                name = (parse_qs(urlsplit(self.path).query).get("name") or ["program.hex"])[0]
                target = ROOT / "work" / Path(name).name
                target.write_text(body)
                self._json(sim.command(f"LOAD {target}"))
            else:
                self.send_error(404)

        def _command(self, command):
            if not ALLOWED.match(command or ""):
                self._json({"ok": False, "error": f"rejected command {command!r}"})
                return
            try:
                self._json(sim.command(command))
            except Exception as exc:  # surfaced to the panel, not swallowed
                self._json({"ok": False, "error": str(exc)})

        def _json(self, payload):
            data = json.dumps(payload).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    port = int(os.environ.get("PDP1_PORT", "8090"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"PDP-1 panel on http://127.0.0.1:{port}/", flush=True)
    try:
        server.serve_forever()
    finally:
        sim.close()


if __name__ == "__main__":
    main()
