#!/usr/bin/env python3
"""Local HTTP bridge. All displayed samples come from the running RTL backend."""
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import argparse, json, os, signal, struct, subprocess, threading, urllib.parse, zlib
ROOT=Path(__file__).resolve().parents[1]; WORK=ROOT/'work'
LOCK=threading.Lock()

def samples():
    p=WORK/'frame.bin'
    raw=p.read_bytes() if p.exists() else bytes(38400)
    if len(raw)!=38400: raise ValueError('Incomplete scanner frame')
    return raw

def text_rows(raw):
    rows=[]
    for row in range(24):
        chars=[]
        for col in range(40):
            i=(row*8*40+col)*5
            codes=[raw[i+1],raw[i]] if raw[i+4]&1 else [raw[i]]
            for c in codes:
                c&=127;chars.append(chr(c+64 if c<32 else c))
        rows.append(''.join(chars))
    return rows

def png(raw,font):
    scan=bytearray()
    for y in range(192):
        scan.append(0)
        for x in range(40):
            i=(y*40+x)*5;m,a,graphics,line,mode=raw[i:i+5]
            if not graphics:
                codes=[(a,(mode>>1)&3),(m,(line>>3)&3)] if mode&1 else [(m,(line>>3)&3)]
                for c,pins in codes:
                    address=(pins<<9)|((c&63)<<3)|(line&7)
                    bits=font[address]^255
                    for bit in range(7):
                        rgb=bytes((112,255,176)) if bits&(1<<bit) else b'\x00\x08\x05'
                        scan.extend(rgb*(1 if mode&1 else 2))
            elif line&2: # IOU SEGB=1 is low-resolution graphics.
                level=((m>>4) if line&4 else (m&15))*17
                scan.extend(bytes((level,level,level))*14)
            else: # Digital hires bit samples; no artifact color/half-dot claim.
                for bit in range(7):scan.extend((b'\xd8\xff\xe5' if m&(1<<bit) else b'\x00\x08\x05')*2)
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',560,192,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(scan))+chunk(b'IEND',b'')

class Handler(BaseHTTPRequestHandler):
    def reply(self,status,data,mime='application/json'):
        self.send_response(status);self.send_header('Content-Type',mime);self.send_header('Content-Length',str(len(data)))
        self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(data)
    def do_GET(self):
        path=urllib.parse.urlsplit(self.path).path
        try:
            if path=='/':self.reply(200,(ROOT/'host/index.html').read_bytes(),'text/html; charset=utf-8')
            elif path=='/state':
                p=WORK/'state.json';state=json.loads(p.read_text()) if p.exists() else {'cycles':0,'frames':0,'pc':0,'fault':0}
                state['running']=self.server.simulator.poll() is None
                state['rows']=text_rows(samples());self.reply(200,json.dumps(state).encode())
            elif path=='/screen.png':self.reply(200,png(samples(),self.server.font),'image/png')
            elif path=='/wave':
                p=WORK/'wave.json';self.reply(200,p.read_bytes() if p.exists() else b'[]')
            else:self.reply(404,b'{"error":"Unknown endpoint"}')
        except (ValueError,OSError) as e:self.reply(503,json.dumps({'error':str(e)}).encode())
    def do_POST(self):
        if self.headers.get('Origin') not in (None,'http://'+self.headers.get('Host','')):
            self.reply(403,b'{"error":"Origin mismatch"}');return
        try:
            length=int(self.headers.get('Content-Length','0'))
            if not 0<=length<=4096:raise ValueError('Request too large')
            body=self.rfile.read(length)
            if self.server.simulator.poll() is not None:raise ValueError('Simulator stopped; inspect work/panel.log')
            with LOCK:
                if self.path=='/keys':
                    text=json.loads(body)['text']
                    if not isinstance(text,str) or len(text)>256:raise ValueError('Send at most 256 ASCII keys')
                    data=text.replace('\n','\r').encode('ascii')
                    with (WORK/'keys').open('ab') as f:f.write(data)
                elif self.path=='/capture':
                    (WORK/'wave.json').unlink(missing_ok=True);(WORK/'capture').touch()
                elif self.path=='/reset':(WORK/'reset').touch()
                else:self.reply(404,b'{"error":"Unknown endpoint"}');return
            self.reply(200,b'{"queued":true}')
        except (ValueError,TypeError,KeyError,UnicodeError) as e:self.reply(400,json.dumps({'error':str(e)}).encode())
    def log_message(self,*args):pass

def stop_server(*_):
    raise KeyboardInterrupt

def main():
    signal.signal(signal.SIGTERM,stop_server)
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--bind',default='127.0.0.1');parser.add_argument('--port',type=int,default=8080)
    args=parser.parse_args();(WORK/'keys').write_bytes(b'')
    for name in ('frame.bin','state.json','wave.json','capture','reset'):(WORK/name).unlink(missing_ok=True)
    server=ThreadingHTTPServer((args.bind,args.port),Handler)
    server.font=(WORK/'Apple2e_Enhanced_Video.rom').read_bytes()
    command=['work/firmware/Vapple_iie','--serve']
    if os.environ.get('SIMULATOR')=='xezim':
        sources=(WORK/'panel_sources.txt').read_text().split()
        command=['xezim','--simulate','--sv2017','--error-exit','--dpi-lib','work/panel.so','-s','tb_panel',*sources,'tb/tb_panel.sv','--max-time','100000000000000ns']
    with (WORK/'panel.log').open('w') as log:
        server.simulator=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=log)
        print(f'Apple IIe panel: http://{args.bind}:{args.port}',flush=True)
        try:server.serve_forever()
        except KeyboardInterrupt:pass
        finally:
            server.server_close();server.simulator.terminate();server.simulator.wait(timeout=10)
if __name__=='__main__':main()
