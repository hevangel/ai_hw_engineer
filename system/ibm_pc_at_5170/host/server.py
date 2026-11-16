#!/usr/bin/env python3
"""Local HTTP front end for the RTL IBM PC AT 5170 with the VGA card.

usage: server.py SIMULATOR BIOS_ROM VGA_ROM [--port N] [--ext-kb N]
                 [--batch-dir DIR] [--script FILE]

Runs host/simulator.cpp as a persistent process speaking its line protocol
and serves host/web/. While the machine is powered and running, a
background thread keeps it running in slices of about a quarter of a
second of wall time, so the machine runs with or without a browser open.
--batch-dir lets the page show the live progress and saved frames of an
unattended batch run (scripts/run_batch.sh) in that directory.
"""
import argparse
import base64
import json
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re
import subprocess
import threading
import time
from urllib.parse import urlsplit, unquote

HOST = Path(__file__).resolve().parent
SURFER_ROOT = Path('/opt/surfer/webapp')
SLICE_SECONDS = 0.25


class Simulator:
    def __init__(self, args, work):
        self.lock = threading.RLock()
        self.waveform_path = work / f'cpu-waveform-{args.port}.fst'
        self.log = (work / f'simulator-{args.port}.log').open('w')
        cmd = [args.simulator, args.bios, args.vga_rom, f'--fst={self.waveform_path}',
               f'--ext-kb={args.ext_kb}']
        if args.script:
            cmd.append(f'--script={args.script}')
        self.process = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=self.log, text=True, bufsize=1)
        self.running = False
        self.powered = True
        self.slice = 200000
        self.state = self.command('STATE')
        self.frame = (0, b'')

    def command(self, line):
        with self.lock:
            if self.process.poll() is not None:
                raise RuntimeError('the RTL simulator exited; see its log in work/')
            self.process.stdin.write(line + '\n')
            self.process.stdin.flush()
            reply = self.process.stdout.readline()
            if not reply:
                raise RuntimeError('the RTL simulator returned nothing')
            data = json.loads(reply)
            if 'error' in data:
                raise ValueError(data['error'])
            if 'clocks' in data:
                data['running'] = self.running
                data['powered'] = self.powered
                self.state = data
            return data

    def step(self):
        """One run slice; adapts its size to SLICE_SECONDS of wall time."""
        with self.lock:
            if not (self.running and self.powered):
                return False
            start = time.monotonic()
            state = self.command(f'RUN {self.slice}')
            spent = time.monotonic() - start
            if spent > 0:
                self.slice = max(10000, min(int(self.slice * SLICE_SECONDS / spent), 20000000))
            if state['stopped']:
                self.running = False
                self.state['running'] = False
            return True

    def png(self):
        with self.lock:
            if self.frame[0] != self.state['frames']:
                reply = self.command('FRAME')
                self.frame = (reply['frames'], base64.b64decode(reply['png']) if reply['png'] else b'')
            return self.frame

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.write('QUIT\n')
            self.process.stdin.flush()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.terminate()
        self.log.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('simulator')
    parser.add_argument('bios')
    parser.add_argument('vga_rom')
    parser.add_argument('--port', type=int, default=8286)
    parser.add_argument('--ext-kb', type=int, default=0)
    parser.add_argument('--batch-dir')
    parser.add_argument('--script')
    args = parser.parse_args()
    work = HOST.parent / 'work' / 'web'
    work.mkdir(parents=True, exist_ok=True)
    sim = Simulator(args, work)
    batch_dir = Path(args.batch_dir).resolve() if args.batch_dir else None

    def runner():
        while True:
            try:
                if not sim.step():
                    time.sleep(0.05)
            except (RuntimeError, ValueError, OSError):
                sim.running = False
                time.sleep(0.5)
    threading.Thread(target=runner, daemon=True).start()

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=str(HOST / 'web'), **kw)

        def log_message(self, *a):
            pass

        def translate_path(self, path):
            name = unquote(urlsplit(path).path)
            if name.startswith('/surfer/'):
                candidate = (SURFER_ROOT / name[len('/surfer/'):]).resolve()
                if not candidate.is_relative_to(SURFER_ROOT):
                    return str(SURFER_ROOT / 'not-found')
                return str(candidate)
            return super().translate_path(path)

        def send(self, payload, status=200, kind='application/json', head=False, filename=None):
            data = json.dumps(payload).encode() if kind == 'application/json' else payload
            self.send_response(status)
            self.send_header('Content-Type', kind)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            if filename:
                self.send_header('Content-Disposition', f'attachment; filename="{filename}"')
            self.end_headers()
            if not head:
                self.wfile.write(data)

        def do_HEAD(self):
            if urlsplit(self.path).path == '/waveform.fst':
                self.serve_waveform(head=True)
            else:
                super().do_HEAD()

        def serve_waveform(self, head=False):
            if not sim.state.get('captureVersion'):
                self.send({'error': 'capture a waveform first'}, 404, head=head)
            else:
                self.send(sim.waveform_path.read_bytes(), kind='application/octet-stream', head=head)

        def do_GET(self):
            path = urlsplit(self.path).path
            try:
                if path == '/api/state':
                    self.send(sim.state)
                elif path == '/api/frame.png':
                    _, data = sim.png()
                    if not data:
                        self.send({'error': 'no complete frame yet'}, 404)
                    else:
                        self.send(data, kind='image/png')
                elif path == '/api/screen':
                    self.send(sim.command('TEXT'))
                elif path == '/waveform.fst':
                    self.serve_waveform()
                elif path == '/api/batch':
                    if not batch_dir:
                        self.send({'batch': False})
                        return
                    status = batch_dir / 'status.json'
                    frames = batch_dir / 'frames.json'
                    self.send({'batch': True, 'dir': str(batch_dir),
                               'status': json.loads(status.read_text()) if status.exists() else None,
                               'frames': json.loads(frames.read_text()) if frames.exists() else []})
                elif path.startswith('/api/batch/'):
                    name = path[len('/api/batch/'):]
                    if not batch_dir or not re.fullmatch(r'(latest|frames/[0-9A-F]{12})\.png', name):
                        self.send({'error': 'not found'}, 404)
                        return
                    self.send((batch_dir / name).read_bytes(), kind='image/png')
                else:
                    super().do_GET()
            except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as error:
                self.send({'error': str(error)}, 500)

        def do_POST(self):
            if urlsplit(self.path).path != '/api/control':
                self.send({'error': 'unknown endpoint'}, 404)
                return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 4096:
                    raise ValueError('invalid request size')
                body = json.loads(self.rfile.read(length))
                action = body.get('action') if isinstance(body, dict) else None
                with sim.lock:
                    if action == 'RUN':
                        sim.powered = True
                        sim.running = not sim.state['stopped']
                        reply = sim.command('STATE')
                    elif action == 'PAUSE':
                        sim.running = False
                        reply = sim.command('STATE')
                    elif action == 'POWER':
                        on = bool(body.get('on'))
                        sim.running = False
                        if on:
                            sim.command('RESET')
                            sim.powered = sim.running = True
                        else:
                            sim.powered = False
                        reply = sim.command('STATE')
                    elif action == 'RESET':
                        sim.command('RESET')
                        sim.powered = True
                        reply = sim.command('STATE')
                    elif action == 'KEY':
                        events = body.get('events')
                        if not isinstance(events, list) or not 0 < len(events) <= 32:
                            raise ValueError('expected 1..32 key events')
                        for ev in events:
                            code, make = ev.get('code'), ev.get('make')
                            if type(code) is not int or not 0 <= code <= 0xff or type(make) is not bool:
                                raise ValueError('a key event is {code: 0..255, make: bool}')
                            reply = sim.command(f'KEY {code:02X} {int(make)}')
                    elif action == 'TYPE':
                        keys = body.get('keys')
                        if not isinstance(keys, str) or not keys or len(keys) > 200 or '\n' in keys:
                            raise ValueError('expected a key string')
                        reply = sim.command(f'TYPE {keys}')
                    elif action == 'CAPTURE':
                        clocks = body.get('clocks', 4096)
                        if type(clocks) is not int or not 1 <= clocks <= 1000000:
                            raise ValueError('capture 1..1,000,000 processor clocks')
                        if not sim.powered:
                            raise ValueError('power on before capturing')
                        sim.running = False
                        reply = sim.command(f'CAPTURE {clocks}')
                    else:
                        raise ValueError('invalid control')
                self.send(reply)
            except (ValueError, TypeError, json.JSONDecodeError) as error:
                self.send({'error': str(error)}, 400)
            except (OSError, RuntimeError) as error:
                self.send({'error': str(error)}, 500)

    print(f'IBM PC AT 5170 (VGA): http://localhost:{args.port}/', flush=True)
    try:
        ThreadingHTTPServer(('0.0.0.0', args.port), Handler).serve_forever()
    finally:
        sim.close()


if __name__ == '__main__':
    main()
