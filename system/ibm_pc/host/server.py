#!/usr/bin/env python3
"""Local HTTP front panel for the persistent RTL IBM PC."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import threading
import tempfile

ROOT = Path(__file__).resolve().parents[1]

class Simulator:
    def __init__(self):
        self.lock = threading.Lock()
        self.log = (ROOT/'work/server_simulator.log').open('w')
        self.process = subprocess.Popen(
            [str(ROOT/'work/obj/Vibm_pc'), str(ROOT/'work/reference')],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.log,
            text=True, bufsize=1)
        self.running = False

    def command(self, command):
        with self.lock:
            if command=='POLL':
                command='RUN 500000' if self.running else 'STATE'
            if command in ('AUTO','PAUSE','RESET','STEP','OFF'):
                self.running=command=='AUTO'
            if self.process.poll() is not None:
                raise RuntimeError('RTL simulator exited; inspect its log')
            self.process.stdin.write(command+'\n')
            self.process.stdin.flush()
            line = self.process.stdout.readline()
            if not line:
                raise RuntimeError('RTL simulator returned no state')
            return json.loads(line)

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
            super().__init__(*args, directory=str(ROOT/'host/web'), **kwargs)

        def send(self, payload, status=200, kind='application/json', filename=None):
            data = json.dumps(payload).encode() if kind=='application/json' else payload
            self.send_response(status)
            self.send_header('Content-Type', kind)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            if filename:
                self.send_header('Content-Disposition',f'attachment; filename="{filename}"')
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            try:
                if self.path=='/api/state':
                    self.send(sim.command('POLL'))
                elif self.path=='/api/font':
                    self.send((ROOT/'work/reference/cga.bin').read_bytes(), kind='application/octet-stream')
                elif self.path=='/api/health':
                    self.send({'ok': sim.process.poll() is None})
                elif self.path in ('/api/disk/0','/api/disk/1'):
                    drive=int(self.path[-1])
                    with tempfile.NamedTemporaryFile(dir=ROOT/'work',suffix='.img',delete=False) as file:
                        path=Path(file.name)
                    try:
                        sim.command(f'SAVE {drive} {path}')
                        self.send(path.read_bytes(),kind='application/octet-stream',
                            filename=f'ibm-pc-drive-{chr(97+drive)}.img')
                    finally:
                        path.unlink(missing_ok=True)
                else:
                    super().do_GET()
            except (OSError, RuntimeError, json.JSONDecodeError) as error:
                self.send({'error': str(error)}, 500)

        def do_POST(self):
            if self.path in ('/api/disk/0','/api/disk/1'):
                try:
                    length=int(self.headers.get('Content-Length','0'))
                    if length!=163840:
                        raise ValueError('Use a 160 KB single-sided image (163840 bytes)')
                    data=self.rfile.read(length)
                    if len(data)!=length:
                        raise ValueError('Incomplete disk image')
                    with tempfile.NamedTemporaryFile(dir=ROOT/'work',suffix='.img',delete=False) as file:
                        file.write(data);path=Path(file.name)
                    try:
                        sim.command('PAUSE')
                        self.send(sim.command(f'MOUNT {self.path[-1]} {path}'))
                    finally:
                        path.unlink(missing_ok=True)
                except (OSError,RuntimeError,ValueError) as error:
                    self.send({'error': str(error)},400)
                return
            if self.path!='/api/control':
                self.send({'error': 'unknown endpoint'}, 404)
                return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0<length<=2048:
                    raise ValueError('invalid request size')
                body = json.loads(self.rfile.read(length))
                if not isinstance(body,dict):
                    raise ValueError('expected a control object')
                action = body.get('action')
                if action in ('AUTO','PAUSE','RESET','STEP','OFF'):
                    self.send(sim.command(action))
                elif action=='KEY':
                    codes = body.get('codes')
                    if not isinstance(codes, list) or not 0<len(codes)<=64 or any(
                            type(code) is not int or not 0<=code<=255 for code in codes):
                        raise ValueError('expected 1..64 byte scan codes')
                    state = None
                    for code in codes:
                        state = sim.command(f'KEY {code}')
                    self.send(state)
                else:
                    raise ValueError('invalid control')
            except (ValueError, TypeError, json.JSONDecodeError) as error:
                self.send({'error': str(error)}, 400)
            except (OSError, RuntimeError) as error:
                self.send({'error': str(error)}, 500)

    try:
        port = int(os.environ.get('IBM_PC_PORT', '8088'))
        print(f'IBM PC 5150: http://localhost:{port}/', flush=True)
        ThreadingHTTPServer(('0.0.0.0',port), Handler).serve_forever()
    finally:
        sim.close()

if __name__=='__main__':
    main()
