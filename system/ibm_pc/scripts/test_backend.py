#!/usr/bin/env python3
"""Check public controls, pause serialization and disk I/O against real RTL."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
BASE='http://127.0.0.1:18088'

def request(path='/api/state',body=None,raw=False):
    data=json.dumps(body).encode() if isinstance(body,dict) else body
    headers={'Content-Type':'application/json'} if isinstance(body,dict) else {}
    req=urllib.request.Request(BASE+path,data,headers)
    with urllib.request.urlopen(req,timeout=30) as response:
        content=response.read()
        return content if raw else json.loads(content)

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
    environment={**os.environ,'IBM_PC_PORT':'18088'}
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
            control('KEY',codes=[30,158]);assert request()['keysQueued']==2
            reject('/api/control',{'action':'KEY','codes':[True]})
            reject('/api/control',{'action':'KEY','codes':[256]})
            reject('/api/control',{'action':'POKE','address':0})
            reject('/api/control',b'[]')
            reject('/api/control',b'null')
            reject('/api/disk/1',b'not an image')
            assert len(request('/api/font',raw=True))==8192
            assert request('/api/disk/0',raw=True)==(ROOT/'work/reference/pcdos100.img').read_bytes()
            blank=(ROOT/'work/reference/workdisk.img').read_bytes()
            mounted=request('/api/disk/1',blank)
            assert not mounted['running']
            assert request('/api/disk/1',raw=True)==blank
            off=control('OFF');assert not off['powered'] and not off['running']
            assert request()['cycles']==off['cycles']
            reset=control('RESET')
            assert reset['powered'] and reset['cycles']==0 and reset['instructions']==0 and reset['keysQueued']==0
            assert (reset['cs'],reset['ip'])==(65535,0)
            print('PASS: real RTL HTTP power/step/run/pause/reset, keyboard validation and disk mount/export')
        finally:
            process.terminate()
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)

if __name__=='__main__':
    main()
