#!/usr/bin/env python3
"""Local HTTP panel for the persistent RTL NES board."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import subprocess
import sys
import threading
from pathlib import Path
from urllib.parse import urlsplit, unquote

ROOT = Path(__file__).resolve().parents[1]
ROMS = ROOT / 'work/roms'
SURFER_ROOT = Path('/opt/surfer/webapp')
DEFAULT_ROM = 'other/nestest.nes'
sys.path.insert(0, str(ROOT / 'scripts'))
from prepare_rom import prepare  # noqa: E402


def rom_list():
    roms = []
    for path in sorted(ROMS.rglob('*.nes')):
        header = path.read_bytes()[:8]
        mapper = (header[6] >> 4) | (header[7] & 0xF0) if len(header) == 8 else -1
        if header[:4] == b'NES\x1a' and mapper in (0, 1, 2, 3):
            roms.append(str(path.relative_to(ROMS)))
    return roms


class Simulator:
    def __init__(self):
        self.lock = threading.RLock()
        self.running = False
        self.process = None
        self.rom = None
        self.region = int(os.environ.get('NES_REGION', '0'))
        self.waveform_path = ROOT / 'work' / f'nes-waveform-{os.environ.get("NES_PORT", "8080")}.fst'
        self.log = (ROOT / 'work/server_simulator.log').open('w')
        self.load(DEFAULT_ROM if (ROMS / DEFAULT_ROM).exists() else (rom_list() or [None])[0])

    def load(self, rom):
        with self.lock:
            if rom is None:
                raise RuntimeError('no ROM available: run scripts/fetch_roms.py')
            if rom not in rom_list():
                raise ValueError('unknown ROM')
            self.stop()
            args = prepare(ROMS / rom, ROOT / 'work/panel/cart')['args']
            binary = ROOT / ('work/obj_pal/Vnes' if self.region else 'work/obj/Vnes')
            self.process = subprocess.Popen(
                [str(binary), *args], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=self.log, text=True, bufsize=1,
                env={**os.environ, 'NES_FST_PATH': str(self.waveform_path)})
            self.rom = rom
            self.running = True

    def raw(self, command):
        if self.process is None or self.process.poll() is not None:
            raise RuntimeError('RTL simulator exited; inspect its log')
        self.process.stdin.write(command + '\n')
        self.process.stdin.flush()
        line = self.process.stdout.readline()
        if not line:
            raise RuntimeError('RTL simulator returned no state')
        data = json.loads(line)
        if 'error' in data:
            raise RuntimeError(data['error'])
        return data

    def command(self, command):
        with self.lock:
            if command == 'POLL':
                state = self.raw('FRAMES 1' if self.running else 'STATE')
            elif command == 'RUNSW':
                self.running = not self.running
                state = self.raw('STATE')
            else:
                state = self.raw(command)
            state['screen'] = self.raw('SCREEN')['screen']
            state['audio'] = self.raw('AUDIO')['samples'] if self.running else ''
            status = bytes.fromhex(self.raw('MEM 24576 256')['hex'])
            # blargg test ROMs mirror their console text at $6004.
            state['testText'] = (status[4:].split(b'\0')[0].decode('ascii', 'replace')
                                 if status[1:4] == b'\xde\xb0\x61' else '')
            state.update(running=self.running, rom=self.rom, region=self.region)
            return state

    def waveform(self):
        with self.lock:
            state = self.raw('STATE')
            if not state.get('captureVersion'):
                return None, 0
            return self.waveform_path.read_bytes(), state['captureVersion']

    def stop(self):
        if self.process is not None and self.process.poll() is None:
            self.process.stdin.write('QUIT\n')
            self.process.stdin.flush()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                self.process.wait(timeout=5)

    def close(self):
        self.stop()
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
                    self.send(sim.command('POLL'))
                elif path == '/api/roms':
                    self.send({'roms': rom_list(), 'current': sim.rom})
                elif path == '/api/health':
                    self.send({'ok': sim.process is not None and sim.process.poll() is None})
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
                if action in ('RESET', 'RUNSW'):
                    self.send(sim.command(action))
                elif action in ('PAD1', 'PAD2'):
                    value = body.get('value', 0)
                    if type(value) is not int or not 0 <= value <= 255:
                        raise ValueError('controller state is 0..255')
                    self.send(sim.command(f'{action} {value}'))
                elif action == 'LOAD':
                    rom = body.get('rom')
                    if not isinstance(rom, str):
                        raise ValueError('LOAD requires a ROM name')
                    sim.load(rom)
                    self.send(sim.command('STATE'))
                elif action == 'CAPTURE':
                    cycles = body.get('cycles', 20000)
                    if type(cycles) is not int or not 1 <= cycles <= 200000:
                        raise ValueError('Capture requires 1..200000 master clocks')
                    self.send(sim.command(f'CAPTURE {cycles}'))
                else:
                    raise ValueError('invalid control')
            except (ValueError, TypeError, json.JSONDecodeError) as error:
                self.send({'error': str(error)}, 400)
            except (OSError, RuntimeError) as error:
                self.send({'error': str(error)}, 500)

    try:
        port = int(os.environ.get('NES_PORT', '8080'))
        print(f'NES panel: http://localhost:{port}/', flush=True)
        ThreadingHTTPServer(('0.0.0.0', port), Handler).serve_forever()
    finally:
        sim.close()


if __name__ == '__main__':
    main()
