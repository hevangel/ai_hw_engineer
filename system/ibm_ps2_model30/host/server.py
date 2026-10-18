#!/usr/bin/env python3
"""Local HTTP front panel for the persistent RTL IBM PS/2 Model 30."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import threading
import tempfile
from urllib.parse import urlsplit, unquote

ROOT = Path(__file__).resolve().parents[1]
SURFER_ROOT = Path('/opt/surfer/webapp')

class Simulator:
    def __init__(self):
        self.lock = threading.RLock()
        self.waveform_path=ROOT/'work'/f'cpu-waveform-{os.environ.get("IBM_PS2_MODEL30_PORT","8530")}.fst'
        self.log = (ROOT/'work/server_simulator.log').open('w')
        self.process = subprocess.Popen(
            [str(ROOT/'work/obj/Vibm_ps2_model30'), str(ROOT/'work/reference')],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.log,
            text=True, bufsize=1,env={**os.environ,'IBM_PS2_MODEL30_FST_PATH':str(self.waveform_path),
                'IBM_PS2_MODEL30_HDD_PATH':str(ROOT/'work'/f'harddisk-{os.environ.get("IBM_PS2_MODEL30_PORT","8530")}.m30'),
                'IBM_PS2_MODEL30_NVRAM_PATH':str(ROOT/'work'/f'rtc-{os.environ.get("IBM_PS2_MODEL30_PORT","8530")}.bin')})
        self.running = False

    def command(self, command):
        with self.lock:
            if command=='POLL':
                command='RUN 500000' if self.running else 'STATE'
            if command in ('AUTO','PAUSE','RESET','STEP','OFF'):
                self.running=command=='AUTO'
            if command.startswith('CAPTURE '):
                self.running=False
            if self.process.poll() is not None:
                raise RuntimeError('RTL simulator exited; inspect its log')
            self.process.stdin.write(command+'\n')
            self.process.stdin.flush()
            line = self.process.stdout.readline()
            if not line:
                raise RuntimeError('RTL simulator returned no state')
            state=json.loads(line)
            if 'error' in state:
                raise ValueError(state['error'])
            return state

    def capture(self,cycles):
        with self.lock:
            if not self.command('STATE')['powered']:
                raise ValueError('Power on the PC before capturing a waveform')
            return self.command(f'CAPTURE {cycles}')

    def waveform(self):
        with self.lock:
            state=self.command('STATE')
            if not state['captureVersion']:
                return None,0
            return self.waveform_path.read_bytes(),state['captureVersion']

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

        def translate_path(self,path):
            name=unquote(urlsplit(path).path)
            if name.startswith('/surfer/'):
                candidate=(SURFER_ROOT/name[len('/surfer/'):]).resolve()
                if not candidate.is_relative_to(SURFER_ROOT):
                    return str(SURFER_ROOT/'not-found')
                return str(candidate)
            return super().translate_path(path)

        def send(self, payload, status=200, kind='application/json', filename=None,version=None,head=False):
            data = json.dumps(payload).encode() if kind=='application/json' else payload
            self.send_response(status)
            self.send_header('Content-Type', kind)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            if filename:
                self.send_header('Content-Disposition',f'attachment; filename="{filename}"')
            if version is not None:
                self.send_header('X-Waveform-Version',str(version))
            self.end_headers()
            if not head:
                self.wfile.write(data)

        def serve_waveform(self,head=False):
            data,version=sim.waveform()
            if data is None:
                self.send({'error':'Capture a CPU waveform first'},404,head=head)
            else:
                self.send(data,kind='application/octet-stream',version=version,head=head)

        def do_HEAD(self):
            if urlsplit(self.path).path=='/waveform.fst':
                try:
                    self.serve_waveform(head=True)
                except (OSError,RuntimeError) as error:
                    self.send({'error':str(error)},500,head=True)
            else:
                super().do_HEAD()

        def do_GET(self):
            try:
                if urlsplit(self.path).path=='/waveform.fst':
                    self.serve_waveform()
                elif self.path=='/api/state':
                    self.send(sim.command('POLL'))
                elif self.path=='/api/font':
                    self.send(bytes.fromhex(sim.command('STATE')['font']), kind='application/octet-stream')
                elif self.path=='/api/health':
                    self.send({'ok': sim.process.poll() is None})
                elif self.path in ('/api/disk/0','/api/disk/1','/api/disk/2','/api/disk/2/raw'):
                    drive=int(self.path.split('/')[3])
                    bundle=drive==2 and not self.path.endswith('/raw')
                    with tempfile.NamedTemporaryFile(dir=ROOT/'work',suffix='.m30' if bundle else '.img',delete=False) as file:
                        path=Path(file.name)
                    try:
                        sim.command(f'SAVE {drive} {path}')
                        self.send(path.read_bytes(),kind='application/octet-stream',
                            filename=('ibm-ps2-model30-harddisk.m30' if bundle else 'ibm-ps2-model30-harddisk.img') if drive==2 else f'ibm-ps2-model30-drive-{chr(97+drive)}.img')
                    finally:
                        path.unlink(missing_ok=True)
                else:
                    super().do_GET()
            except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as error:
                self.send({'error': str(error)}, 500)

        def do_POST(self):
            if self.path in ('/api/disk/0','/api/disk/1','/api/disk/2'):
                try:
                    length=int(self.headers.get('Content-Length','0'))
                    drive=int(self.path[-1])
                    if length not in ((21307392,21806800) if drive==2 else (737280,)):
                        raise ValueError('Use a type-26 20 MB raw image or complete .m30 bundle' if drive==2 else 'Use a 720 KB double-sided image (737280 bytes)')
                    data=self.rfile.read(length)
                    if len(data)!=length:
                        raise ValueError('Incomplete disk image')
                    with tempfile.NamedTemporaryFile(dir=ROOT/'work',suffix='.img',delete=False) as file:
                        file.write(data);path=Path(file.name)
                    try:
                        with sim.lock:
                            sim.command('PAUSE')
                            self.send(sim.command(f'MOUNT {drive} {path}'))
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
                elif action=='CAPTURE':
                    cycles=body.get('cycles',4096)
                    if type(cycles) is not int or not 1<=cycles<=65536:
                        raise ValueError('Capture requires 1..65536 CPU clocks')
                    self.send(sim.capture(cycles))
                elif action=='EJECT':
                    drive=body.get('drive')
                    if type(drive) is not int or drive not in (0,1):
                        raise ValueError('Choose floppy drive A or B')
                    with sim.lock:
                        sim.command('PAUSE')
                        self.send(sim.command(f'EJECT {drive}'))
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
        port = int(os.environ.get('IBM_PS2_MODEL30_PORT', '8530'))
        print(f'IBM PS/2 Model 30: http://localhost:{port}/', flush=True)
        ThreadingHTTPServer(('0.0.0.0',port), Handler).serve_forever()
    finally:
        sim.close()

if __name__=='__main__':
    main()
