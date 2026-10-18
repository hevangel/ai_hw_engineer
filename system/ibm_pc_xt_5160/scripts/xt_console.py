"""Public simulator protocol and actual XT keyboard input for regressions."""
import json,subprocess,sys,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT.parents[0]/'ibm_pc/scripts'))
from test_software import screen,SCAN,SHIFT
SCAN['\\']=43
SHIFT['>']='.'
SHIFT['<']=','
class Console:
 def __init__(self,log='console.log'):
  self.log=(ROOT/'work'/log).open('w')
  args=[str(ROOT/'work/obj/Vibm_pc_xt_5160'),str(ROOT/'work/reference')]
  if os.environ.get('IBM_XT_RESUME'):args+=['--resume',os.environ['IBM_XT_RESUME']]
  self.p=subprocess.Popen(args,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.log,text=True,bufsize=1)
  self.state=self.cmd('STATE')
 def cmd(self,line):
  self.p.stdin.write(line+'\n');self.p.stdin.flush();raw=self.p.stdout.readline()
  if not raw:raise RuntimeError('simulator exited; inspect '+self.log.name)
  result=json.loads(raw)
  if 'fault' in result:
   self.state=result
   if result['fault']:raise RuntimeError('RTL fault')
  return result
 def type(self,text):
  for char in text:
   shifted=char in SHIFT or char.isupper();key=SCAN[SHIFT.get(char,char.lower())]
   if shifted:self.cmd('KEY 42')
   self.cmd(f'KEY {key}');self.cmd(f'KEY {key|128}')
   if shifted:self.cmd('KEY 170')
 def wait(self,predicate,limit=180000000,label='screen'):
  end=self.state['cycles']+limit;history=''
  while True:
   text=screen(self.state);history+=text+'\n'
   if 'ERROR. (RESUME' in text:
    (ROOT/'work/failed_boot.json').write_text(json.dumps(self.state))
    raise RuntimeError('Original POST diagnostic:\n'+text)
   if predicate(self.state,text,history):
    print('PASS',label,'at',self.state['cycles'],'clocks',flush=True);return text
   if self.state['cycles']>=end:raise RuntimeError(f'{label} timeout at {self.state["cs"]:04x}:{self.state["ip"]:04x}\n{text}\n'+str({k:self.state[k] for k in ('hdCommands','hdReads','hdWrites','fpuCommands','fpuControl','fpuStatus')}))
   self.cmd('RUN 1000000')
   if self.state['cycles']%10000000==0:
    print(label,self.state['cycles'],f'{self.state["cs"]:04x}:{self.state["ip"]:04x}',
          'HD',self.state['hdCommands'],'FPU',self.state['fpuCommands'],flush=True)
 def close(self):
  if self.p.poll() is None:
   try:self.p.stdin.write('QUIT\n');self.p.stdin.flush()
   except BrokenPipeError:pass
   self.p.wait(timeout=20)
  self.log.close()
if __name__=='__main__':
 c=Console('boot.log')
 try:
  c.wait(lambda s,t,h:'date' in t.lower() or 'A>' in t,label='XT POST, original fixed-disk ROM and DOS boot')
  print(screen(c.state));print({k:v for k,v in c.state.items() if k not in ('vram','crtc')})
 finally:c.close()
