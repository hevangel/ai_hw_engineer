#!/usr/bin/env python3
"""Local HTTP cabinet for the persistent RTL Space Invaders board."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import subprocess
import threading
from pathlib import Path
from urllib.parse import urlsplit, unquote

ROOT = Path(__file__).resolve().parents[1]
SURFER_ROOT = Path('/opt/surfer/webapp')
PANEL_ACTIONS = ('RESET',)


class Simulator:
    def __init__(self):
        self.lock = threading.RLock()
        self.switch_on = False
        self.waveform_path = ROOT / 'work' / f'invaders-waveform-{os.environ.get("INVADERS_PORT", "8080")}.fst'
        self.log = (ROOT / 'work/server_simulator.log').open('w')
        self.process = subprocess.Popen(
            [str(ROOT / 'work/obj/Vspace_invaders'), f'+rom={ROOT / "work/si_rom.hex"}'],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.log,
            text=True, bufsize=1,
            env={**os.environ, 'INVADERS_FST_PATH': str(self.waveform_path)})

    def command(self, command):
        with self.lock:
            if command == 'POLL':
                command = 'RUN 400000' if self.switch_on else 'STATE'
            if command in ('RUNSW',):
                self.switch_on = not self.switch_on
                command = f'RUNSW {1 if self.switch_on else 0}'
            if self.process.poll() is not None:
                raise RuntimeError('RTL simulator exited; inspect its log')
            self.process.stdin.write(command + '\n')
            self.process.stdin.flush()
            line = self.process.stdout.readline()
            if not line:
                raise RuntimeError('RTL simulator returned no state')
            return json.loads(line)

    def capture(self, cycles):
        with self.lock:
            return self.command(f'CAPTURE {cycles}')

    def waveform(self):
        with self.lock:
            state = self.command('STATE')
            if not state.get('captureVersion'):
                return None, 0
            return self.waveform_path.read_bytes(), state['captureVersion']

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.write('QUIT\n')
            self.process.stdin.flush()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                self.process.wait(timeout=5)
        self.log.close()


def main():
    sim = Simulator()

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(ROOT / 'host/web'), **kwargs)

        def translate_path(self, path):
            name = unquote(urlsplit(path).path)
            if name.startswith('/surfer/'):
                candidate = (SURFER_ROOT / name[len('/surfer/'):]).resolve()
                if not candidate.is_relative_to(SURFER_ROOT):
                    return str(SURFER_ROOT / 'not-found')
                return str(candidate)
            return super().translate_path(path)

        def send(self, payload, status=200, kind='application/json', version=None, head=False):
            data = json.dumps(payload).encode() if kind == 'application/json' else payload
            self.send_response(status)
            self.send_header('Content-Type', kind)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            if version is not None:
                self.send_header('X-Waveform-Version', str(version))
            self.end_headers()
            if not head:
                self.wfile.write(data)

        def serve_waveform(self, head=False):
            data, version = sim.waveform()
            if data is None:
                self.send({'error': 'Capture a waveform first'}, 404, head=head)
            else:
                self.send(data, kind='application/octet-stream', version=version, head=head)

        def do_HEAD(self):
            if urlsplit(self.path).path == '/waveform.fst':
                try:
                    self.serve_waveform(head=True)
                except (OSError, RuntimeError) as error:
                    self.send({'error': str(error)}, 500, head=True)
            else:
                super().do_HEAD()

        def do_GET(self):
            try:
                if urlsplit(self.path).path == '/waveform.fst':
                    self.serve_waveform()
                elif self.path == '/api/state':
                    self.send(sim.command('POLL'))
                elif self.path == '/api/health':
                    self.send({'ok': sim.process.poll() is None})
                else:
                    super().do_GET()
            except (OSError, RuntimeError, json.JSONDecodeError) as error:
                self.send({'error': str(error)}, 500)

        def do_POST(self):
            if self.path != '/api/control':
                self.send({'error': 'unknown endpoint'}, 404)
                return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 2048:
                    raise ValueError('invalid request size')
                body = json.loads(self.rfile.read(length))
                if not isinstance(body, dict):
                    raise ValueError('expected a control object')
                action = body.get('action')
                if action in PANEL_ACTIONS:
                    self.send(sim.command(action))
                elif action in ('IN0', 'IN1', 'IN2'):
                    value = body.get('value', 0)
                    if type(value) is not int or not 0 <= value <= 255:
                        raise ValueError('input ports are 0..255')
                    self.send(sim.command(f'{action} {value}'))
                elif action == 'RUNSW':
                    self.send(sim.command('RUNSW'))
                elif action == 'CAPTURE':
                    cycles = body.get('cycles', 4096)
                    if type(cycles) is not int or not 1 <= cycles <= 65536:
                        raise ValueError('Capture requires 1..65536 steps')
                    self.send(sim.capture(cycles))
                else:
                    raise ValueError('invalid control')
            except (ValueError, TypeError, json.JSONDecodeError) as error:
                self.send({'error': str(error)}, 400)
            except (OSError, RuntimeError) as error:
                self.send({'error': str(error)}, 500)

    try:
        port = int(os.environ.get('INVADERS_PORT', '8080'))
        print(f'Space Invaders cabinet: http://localhost:{port}/', flush=True)
        ThreadingHTTPServer(('0.0.0.0', port), Handler).serve_forever()
    finally:
        sim.close()


if __name__ == '__main__':
    main()
