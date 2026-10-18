"""Exercise the HTTP panel against a separate real RTL process."""
import json,os,subprocess,time,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 env={**os.environ,'IBM_XT_PORT':'8090'}
 log=(ROOT/'work/backend.log').open('w')
 p=subprocess.Popen(['python3',str(ROOT/'host/server.py')],env=env,stdout=log,stderr=log)
 def request(path,body=None):
  data=None if body is None else json.dumps(body).encode()
  return urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:8090'+path,data=data),timeout=30)
 def control(action,**kw):return json.load(request('/api/control',dict(action=action,**kw)))
 try:
  for _ in range(100):
   try:
    assert json.load(request('/api/health'))['ok'];break
   except OSError:time.sleep(.1)
  else:raise AssertionError('server startup')
  assert not json.load(request('/api/state'))['powered']
  control('AUTO');control('PAUSE')
  before=json.load(request('/api/state'))['cycles'];after=control('STEP')['cycles']
  assert after>before
  captured=control('CAPTURE',cycles=256);assert captured['captureVersion']>0
  assert len(request('/waveform.fst').read())>100
  assert len(request('/api/harddisk').read())==10653696
  control('EJECT',drive=0)
  try:control('EJECT',drive=2)
  except urllib.error.HTTPError as error:assert error.code==400
  else:raise AssertionError('invalid drive accepted')
  control('OFF');assert not json.load(request('/api/state'))['powered']
  print('PASS HTTP power, pause, step, FST capture, hard-disk export and input validation',flush=True)
 finally:
  p.terminate();p.wait(timeout=20);log.close()
if __name__=='__main__':main()
