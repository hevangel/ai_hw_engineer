#!/usr/bin/env python3
from pathlib import Path
import json,os,struct,subprocess,time,urllib.request,urllib.error,urllib.parse,zlib
ROOT=Path(__file__).resolve().parents[1];BASE='http://127.0.0.1:18084'
def _checked(url):
    # The panel under test is the local simulator this script launches;
    # refuse any non-loopback target before opening the connection.
    parsed=urllib.parse.urlsplit(url)
    if parsed.scheme!='http' or parsed.hostname not in ('localhost','127.0.0.1','::1'):
        raise ValueError('panel URL must be loopback http: '+url)
    return url
def get(path):return urllib.request.urlopen(_checked(BASE+path),timeout=5).read()
def post(path,obj=None,origin=None):
    headers={'Content-Type':'application/json'}
    if origin:headers['Origin']=origin
    return urllib.request.urlopen(urllib.request.Request(_checked(BASE+path),data=json.dumps(obj or {}).encode(),headers=headers),timeout=5)
def wait_for(test,label,seconds=int(os.environ.get("PANEL_TIMEOUT","90"))):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        try:
            if test():return
        except (OSError,ValueError):pass
        time.sleep(.1)
    raise AssertionError(label)
with (ROOT/'work/host_test.log').open('w') as log:
    process=subprocess.Popen(['sh','scripts/run_host.sh','--port','18084'],cwd=ROOT,stdout=log,stderr=log)
    try:
        wait_for(lambda:'Apple ][' in '\n'.join(json.loads(get('/state'))['rows']) and any(row.rstrip(' '+chr(127))==']' for row in json.loads(get('/state'))['rows']),'real ROM banner and BASIC prompt')
        post('/keys',{'text':'PRINT 6*7\r'})
        wait_for(lambda:any(row.strip()=='42' for row in json.loads(get('/state'))['rows']),'keyboard BASIC PRINT')
        post('/keys',{'text':'PR#3\rPRINT 12345\r'})
        wait_for(lambda:any(row.strip()=='12345' for row in json.loads(get('/state'))['rows']),'80-column auxiliary/main ordering')
        data=get('/screen.png');assert data.startswith(b'\x89PNG\r\n\x1a\n')
        assert struct.unpack('>II',data[16:24])==(560,192)
        offset=8;compressed=b''
        while offset<len(data):
            size=struct.unpack('>I',data[offset:offset+4])[0];kind=data[offset+4:offset+8];chunk=data[offset+8:offset+8+size]
            assert struct.unpack('>I',data[offset+8+size:offset+12+size])[0]==zlib.crc32(kind+chunk)&0xffffffff
            if kind==b'IDAT':compressed+=chunk
            offset+=size+12
        pixels=zlib.decompress(compressed);assert len(pixels)==192*(560*3+1) and len(set(pixels))>4
        (ROOT/'work/panel_screen.png').write_bytes(data)
        post('/capture');wait_for(lambda:len(json.loads(get('/wave')))==140,'live waveform')
        wave=json.loads(get('/wave'));assert sum(row[0] for row in wave)==70;assert sum(row[1] for row in wave)==80;assert sum(row[2] for row in wave)==40
        try:post('/keys',{'text':'x'},'https://invalid.example');raise AssertionError('Origin allowed')
        except urllib.error.HTTPError as e:assert e.code==403
        post('/reset');wait_for(lambda:json.loads(get('/state')).get('resets',0)>=1,'actual RTL reset observed');post('/keys',{'text':'PRINT 9*9\r'});wait_for(lambda:any(row.strip()=='81' for row in json.loads(get('/state'))['rows']),'warm reset and real BASIC restart')
        print('PASS live HTTP panel: real ROM, keyboard PRINT 42, 80-column PRINT 12345, pin-derived PNG, 140-tick waveform, Origin rejection and warm-reset PRINT 81')
    finally:process.terminate();process.wait(timeout=10)
