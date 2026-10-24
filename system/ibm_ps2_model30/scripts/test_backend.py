#!/usr/bin/env python3
"""Check public controls, pause serialization and disk I/O against real RTL."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import struct
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
BASE='http://127.0.0.1:18530'

def _checked_base():
    # The backend under test is the local server this script just spawned;
    # refuse any edited non-loopback target before opening connections.
    parsed=urllib.parse.urlsplit(BASE)
    if parsed.scheme!='http' or parsed.hostname not in ('localhost','127.0.0.1','::1'):
        raise ValueError('backend base URL must be loopback http: '+BASE)
    return BASE

def request(path='/api/state',body=None,raw=False):
    data=json.dumps(body).encode() if isinstance(body,dict) else body
    headers={'Content-Type':'application/json'} if isinstance(body,dict) else {}
    req=urllib.request.Request(_checked_base()+path,data,headers)
    with urllib.request.urlopen(req,timeout=30) as response:
        content=response.read()
        return content if raw else json.loads(content)

def open_local(url,timeout=30,method='GET'):
    # Same loopback-only contract as request(), for direct file fetches.
    parsed=urllib.parse.urlsplit(url)
    if parsed.scheme!='http' or parsed.hostname not in ('localhost','127.0.0.1','::1'):
        raise ValueError('backend URL must be loopback http: '+url)
    return urllib.request.urlopen(urllib.request.Request(url,method=method),timeout=timeout)

def control(action,**kwargs):
    return request('/api/control',{'action':action,**kwargs})

def reject(path,body,code=400):
    try:
        request(path,body)
    except urllib.error.HTTPError as error:
        assert error.code==code
    else:
        raise AssertionError('invalid request was accepted')

def main():
    environment={**os.environ,'IBM_PS2_MODEL30_PORT':'18530'}
    with (ROOT/'work/backend_server.log').open('w') as log:
        process=subprocess.Popen(['python3',str(ROOT/'host/server.py')],env=environment,
                                 stdout=log,stderr=subprocess.STDOUT)
        try:
            deadline=time.monotonic()+15
            while True:
                try:
                    assert request('/api/health')['ok'];break
                except OSError:
                    if process.poll() is not None or time.monotonic()>deadline:
                        raise RuntimeError('backend startup failed; inspect backend_server.log')
                    time.sleep(.1)
            initial=request()
            assert not initial['powered'] and not initial['running'] and initial['cycles']==0
            reject('/waveform.fst',None,404)
            reject('/api/control',{'action':'CAPTURE','cycles':1024})
            stepped=control('STEP')
            assert stepped['powered'] and stepped['instructions']==1 and (stepped['cs'],stepped['ip'])==(0xf000,0xe05b)
            assert request()['cycles']==stepped['cycles']
            control('AUTO');advanced=request()
            assert advanced['cycles']>=500000 and advanced['instructions']>100
            with ThreadPoolExecutor(max_workers=2) as pool:
                polling=pool.submit(request)
                paused=control('PAUSE');polling.result()
            assert not paused['running']
            assert request()['cycles']==request()['cycles']==paused['cycles']
            for cycles in (True,0,-1,65537,'4096'):
                reject('/api/control',{'action':'CAPTURE','cycles':cycles})
            before=request()['cycles']
            captured=control('CAPTURE',cycles=1024)
            assert not captured['running'] and captured['captureVersion']==1
            assert captured['captureStart']==before and captured['cycles']==before+1024
            waveform=request('/waveform.fst?capture=1',raw=True)
            # FST HEADER layout from the independent fstcpp Writer::writeHeader_.
            assert len(waveform)>128 and waveform[0]==0
            assert struct.unpack_from('>QQ',waveform,9)==(0,1024*125000)
            assert struct.unpack_from('b',waveform,73)[0]==-12
            with open_local(BASE+'/waveform.fst',method='HEAD') as response:
                assert int(response.headers['Content-Length'])==len(waveform)
                assert response.headers['X-Waveform-Version']=='1' and not response.read()
            assert request()['cycles']==captured['cycles']
            control('RESET');second=control('CAPTURE',cycles=4096)
            assert second['captureStart']==0 and second['captureVersion']==2 and second['cycles']==4096
            second_waveform=request('/waveform.fst',raw=True)
            assert struct.unpack_from('>QQ',second_waveform,9)==(0,4096*125000)
            assert b'Surfer' in request('/surfer/',raw=True)
            with open_local(BASE+'/surfer/surfer_bg.wasm') as response:
                assert response.headers['Content-Type']=='application/wasm'
                assert response.read(4)==b'\0asm'
            reject('/surfer/%2e%2e/%2e%2e/AGENTS.md',None,404)
            with ThreadPoolExecutor(max_workers=2) as pool:
                download=pool.submit(request,'/waveform.fst',None,True)
                third=control('CAPTURE',cycles=16384)
                concurrent=download.result()
            assert third['captureVersion']==3 and not third['running']
            assert struct.unpack_from('>QQ',concurrent,9) in ((0,4096*125000),(0,16384*125000))
            control('KEY',codes=[30,158]);assert request()['keysQueued']==2
            reject('/api/control',{'action':'KEY','codes':[True]})
            reject('/api/control',{'action':'KEY','codes':[256]})
            reject('/api/control',{'action':'POKE','address':0})
            reject('/api/control',b'[]')
            reject('/api/control',b'null')
            reject('/api/disk/1',b'not an image')
            assert len(request('/api/font',raw=True))==8192
            assert request('/api/disk/0',raw=True)==(ROOT/'work/reference/boot.img').read_bytes()
            blank=(ROOT/'work/reference/workdisk.img').read_bytes()
            mounted=request('/api/disk/1',blank)
            assert not mounted['running']
            assert request('/api/disk/1',raw=True)==blank
            hdd=request('/api/disk/2',raw=True)
            assert len(hdd)==21806800 and hdd[:8]==b'M30DISK1'
            assert request('/api/disk/2/raw',raw=True)==hdd[8:8+21307392]
            corrupt=bytearray(hdd);corrupt[100]^=1
            reject('/api/disk/2',bytes(corrupt))
            assert request('/api/disk/2',raw=True)==hdd
            mounted=request('/api/disk/2',hdd)
            assert mounted['hardDiskPresent'] and not mounted['running']
            assert request('/api/disk/2',raw=True)==hdd
            reject('/api/disk/2',b'not a hard disk')
            reject('/api/control',{'action':'EJECT','drive':True})
            assert not control('EJECT',drive=0)['diskInserted']&1
            reinserted=request('/api/disk/0',(ROOT/'work/reference/boot.img').read_bytes())
            assert reinserted['diskInserted']&1
            off=control('OFF');assert not off['powered'] and not off['running']
            assert request()['cycles']==off['cycles']
            reset=control('RESET')
            assert reset['powered'] and reset['cycles']==0 and reset['instructions']==0 and reset['keysQueued']==0
            assert (reset['cs'],reset['ip'])==(65535,0)
            print('PASS: real RTL HTTP controls, keyboard/disks, bounded repeated FST captures, headers/timing and self-hosted Surfer')
        finally:
            process.terminate()
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)

if __name__=='__main__':
    main()
