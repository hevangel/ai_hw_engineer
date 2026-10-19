#!/usr/bin/env python3
"""Local physical-motherboard front panel. No emulation in the host."""
import argparse
import json
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def reply(self, code, body, kind='application/json'):
        self.send_response(code)
        self.send_header('Content-Type', kind)
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == '/':
            self.reply(200, (ROOT/'host/index.html').read_bytes(), 'text/html; charset=utf-8')
        elif self.path == '/frame':
            path = ROOT/'work/front_panel.frame'
            if path.exists():
                self.reply(200, path.read_bytes(), 'application/octet-stream')
            else:
                self.reply(204, b'')
        elif self.path == '/status':
            self.reply(200, json.dumps({'running': self.server.simulator.poll() is None,
                                       'frame': (ROOT/'work/front_panel.frame').exists()}).encode())
        else:
            self.reply(404, b'{"error":"Unknown endpoint"}')

    def do_POST(self):
        # Browser same-origin requests only; no cross-origin control of the machine.
        if self.headers.get('Origin') not in (None, f'http://{self.headers.get("Host")}'):
            self.reply(403, b'{"error":"Origin mismatch"}'); return
        try:
            count = int(self.headers.get('Content-Length', '0'))
            if count < 0 or count > 4096:
                raise ValueError('Request must be at most 4096 bytes')
            body = self.rfile.read(count)
            if self.path == '/reset':
                keys = b'R'
                endpoint = 'front_panel.reset'
            elif self.path == '/keys':
                endpoint = 'front_panel.keys'
                text = json.loads(body)['text']
                if not isinstance(text, str):
                    raise ValueError('Text must be a string')
                keys = text.replace('\n', '\r').encode('ascii')
                if len(keys) > 2048:
                    raise ValueError('Send at most 2048 keys at once')
            else:
                self.reply(404, b'{"error":"Unknown endpoint"}'); return
            if self.server.simulator.poll() is not None:
                raise ValueError('Simulator has stopped; see work/front_panel.log')
            with LOCK, (ROOT/'work'/endpoint).open('ab') as f:
                f.write(keys)
            self.reply(200, b'{"queued":true}')
        except (ValueError, KeyError, TypeError, UnicodeError) as error:
            self.reply(400, json.dumps({'error': str(error)}).encode())

    def log_message(self, *_):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bind', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8080)
    args = parser.parse_args()
    (ROOT/'work/front_panel.keys').write_bytes(b'')
    (ROOT/'work/front_panel.reset').write_bytes(b'')
    (ROOT/'work/front_panel.frame').unlink(missing_ok=True)
    server = ThreadingHTTPServer((args.bind, args.port), Handler)
    with (ROOT/'work/front_panel.log').open('w') as log:
        simulator = subprocess.Popen(['vvp', '-Mwork', '-mfront_panel',
                                      'work/front_panel.vvp'], cwd=ROOT, stdout=log, stderr=log)
        server.simulator = simulator
        print(f'Apple II front panel: http://{args.bind}:{args.port}', flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            server.server_close()
            simulator.terminate()
            simulator.wait()


if __name__ == '__main__':
    main()
