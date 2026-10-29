#!/usr/bin/env python3
"""Local HTTP front panel for the persistent RTL Commodore 64 board."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import subprocess
import threading
from collections import deque
from pathlib import Path
from urllib.parse import urlsplit, unquote

import c64_keys

ROOT = Path(__file__).resolve().parents[1]
SURFER_ROOT = Path('/opt/surfer/webapp')
VARIANT = int(os.environ.get('C64_VARIANT', '0'))
# Frames a typed character is held, then released, so the KERNAL scan
# (one per 60 Hz CIA1 timer IRQ) sees both edges.
TYPE_HOLD, TYPE_GAP = 2, 2


class Simulator:
    def __init__(self):
        self.lock = threading.RLock()
        self.running = False
        self.typed = deque()
        self.held = 0
        self.waveform_path = ROOT / 'work' / f'c64-waveform-{os.environ.get("C64_PORT", "8080")}.fst'
        self.log = (ROOT / 'work/server_simulator.log').open('w')
        work = ROOT / 'work'
        self.process = subprocess.Popen(
            [str(work / f'obj_v{VARIANT}' / 'Vc64_board'), f'+basic={work / "basic.hex"}',
             f'+kernal={work / "kernal.hex"}', f'+chargen={work / "chargen.hex"}'],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.log,
            text=True, bufsize=1,
            env={**os.environ, 'C64_FST_PATH': str(self.waveform_path)})

    def raw(self, command):
        if self.process.poll() is not None:
            raise RuntimeError('RTL simulator exited; inspect its log')
        self.process.stdin.write(command + '\n')
        self.process.stdin.flush()
        line = self.process.stdout.readline()
        if not line:
            raise RuntimeError('RTL simulator returned no state')
        return json.loads(line)

    def poll(self):
        with self.lock:
            if self.running and self.typed:
                self.raw(f'KEYS {c64_keys.mask(self.typed.popleft()) | self.held:x}')
                self.raw(f'RUN {TYPE_HOLD}')
                self.raw(f'KEYS {self.held:x}')
                state = self.raw(f'RUNF {TYPE_GAP}')
            else:
                state = self.raw('RUNF 1' if self.running else 'FRAME')
            return self.decorate(state)

    def decorate(self, state):
        state['running'] = self.running
        state['queued'] = len(self.typed)
        state['variant'] = 'NTSC 6567R8' if VARIANT else 'PAL 6569R3'
        return state

    def control(self, body):
        action = body.get('action')
        with self.lock:
            if action == 'RUNSW':
                self.running = not self.running
                return self.decorate(self.raw('STATE'))
            if action == 'RESET':
                self.typed.clear()
                return self.decorate(self.raw('RESET'))
            if action == 'TYPE':
                text = body.get('text', '')
                if type(text) is not str or len(text) > 256:
                    raise ValueError('TYPE takes up to 256 characters')
                for char in text:
                    self.typed.append(c64_keys.chord(char))
                return self.decorate(self.raw('STATE'))
            if action == 'KEYS':
                names = body.get('keys', [])
                if type(names) is not list or any(name not in c64_keys.KEYS for name in names):
                    raise ValueError('KEYS takes a list of C64 key names')
                self.held = c64_keys.mask(names)
                return self.decorate(self.raw(f'KEYS {self.held:x}'))
            if action in ('RESTORE', 'STOPRESTORE'):
                # Pulse the RESTORE key (the NMI line; see the spec ledger); with
                # RUN/STOP held this is the KERNAL warm start.
                if action == 'STOPRESTORE':
                    self.raw(f'KEYS {c64_keys.mask(["STOP"]) | self.held:x}')
                    self.raw('RUN 2')
                self.raw('RESTORE 1')
                self.raw('RUN 2')
                self.raw('RESTORE 0')
                self.raw('RUN 4')
                return self.decorate(self.raw(f'KEYS {self.held:x}'))
            if action in ('JOY1', 'JOY2'):
                value = body.get('value', 31)
                if type(value) is not int or not 0 <= value <= 31:
                    raise ValueError('joystick lines are 0..31 (active low)')
                return self.decorate(self.raw(f'{action} {value}'))
            if action == 'CAPTURE':
                cycles = body.get('cycles', 2000)
                if type(cycles) is not int or not 1 <= cycles <= 20000:
                    raise ValueError('Capture requires 1..20000 CPU cycles')
                return self.decorate(self.raw(f'CAPTURE {cycles}'))
        raise ValueError('invalid control')

    def waveform(self):
        with self.lock:
            state = self.raw('STATE')
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

        def log_message(self, *args):
            pass

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
                path = urlsplit(self.path).path
                if path == '/waveform.fst':
                    self.serve_waveform()
                elif path == '/api/state':
                    self.send(sim.poll())
                elif path == '/api/health':
                    self.send({'ok': sim.process.poll() is None,
                               'surfer': (SURFER_ROOT / 'index.html').is_file()})
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
                if not 0 < length <= 4096:
                    raise ValueError('invalid request size')
                body = json.loads(self.rfile.read(length))
                if not isinstance(body, dict):
                    raise ValueError('expected a control object')
                self.send(sim.control(body))
            except (ValueError, TypeError, json.JSONDecodeError) as error:
                self.send({'error': str(error)}, 400)
            except (OSError, RuntimeError) as error:
                self.send({'error': str(error)}, 500)

    try:
        port = int(os.environ.get('C64_PORT', '8080'))
        print(f'Commodore 64 front panel: http://localhost:{port}/', flush=True)
        ThreadingHTTPServer(('0.0.0.0', port), Handler).serve_forever()
    finally:
        sim.close()


if __name__ == '__main__':
    main()
