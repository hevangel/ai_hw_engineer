"""Original XT ROM/DOS plus real filesystem and CPU/8087 application checks."""
import os,re,shutil,json
from pathlib import Path
from xt_console import Console,ROOT,screen
from create_disk import files
def main():
 private=ROOT/'work/test-harddisk.img'
 shutil.copyfile(ROOT/'work/harddisk.img',private)
 os.environ['IBM_XT_DISK']=str(private)
 c=Console('software_trace.log')
 try:
  c.wait(lambda s,t,h:'Enter new date' in t,200000000,'original POST, adapter diagnostics and hard-disk DOS boot')
  assert c.state['mediaReads']==0 and c.state['hdReads']>32768
  equipment=c.cmd('PEEK 1040 2')['data'];assert equipment[0]&2,'8087 equipment bit'
  assert c.cmd('PEEK 1043 2')['data']==[0,1],'256 KiB reported by BIOS'
  assert c.cmd('PEEK 1141 1')['data']==[1],'exactly one fixed disk'
  c.type('10-16-83\r');c.wait(lambda s,t,h:'Enter new time' in t,label='DOS date entry')
  c.type('\r');c.wait(lambda s,t,h:s['keysQueued']==0 and t.rstrip().endswith('C>'),label='original COMMAND.COM C prompt')
  c.type('dir\r');listing=c.wait(lambda s,t,h:s['keysQueued']==0 and re.search(r'COMMAND\s+COM',h) and t.rstrip().endswith('C>'),label='DOS DIR through fixed-disk DMA')
  assert 'bytes free' in listing.lower()
  before=c.state['hdWrites'];c.type('echo XT 5160 WITH 8087>xttest.txt\r')
  c.wait(lambda s,t,h:s['keysQueued']==0 and s['hdWrites']>before and t.rstrip().endswith('C>'),label='DOS creates fixed-disk file')
  c.type('type xttest.txt\r');c.wait(lambda s,t,h:s['keysQueued']==0 and 'XT 5160 WITH 8087' in t and t.rstrip().endswith('C>'),label='DOS reads its file back')
  c.type('basic\r');c.wait(lambda s,t,h:'Ok' in t and ('Basic' in t or 'BASIC' in t),label='original BASIC.COM and BASIC 1.10 ROM')
  c.type('print 6*7\r');c.wait(lambda s,t,h:s['keysQueued']==0 and re.search(r'\b42\b',t) and 'Ok' in t,label='original BASIC arithmetic')
  c.type('system\r');c.wait(lambda s,t,h:s['keysQueued']==0 and t.rstrip().endswith('C>'),label='original BASIC returns to DOS')
  c.cmd(f'MOUNT 0 {ROOT}/work/fpu-demo.img');c.type('a:fpu8087\r')
  before=c.state['fpuCommands'];c.wait(lambda s,t,h:s['keysQueued']==0 and '8087 PASS:' in t and t.rstrip().endswith('C>'),label='DOS application executes actual 8087 arithmetic and square root')
  assert c.state['fpuCommands']>=before+7
  c.type('copy a:fpu8087.com c:\\fpu8087.com\r');c.wait(lambda s,t,h:s['keysQueued']==0 and 'copied' in h.lower() and t.rstrip().endswith('C>'),label='DOS copies FPU application to fixed disk')
  c.cmd('EJECT 0')
  c.cmd(f'HDSAVE {ROOT}/work/verified-harddisk.img')
  image=(ROOT/'work/verified-harddisk.img').read_bytes();volume=image[17*512:]
  extracted={name:data for name,entry,data in files(volume)}
  assert extracted[b'XTTEST  TXT'].strip()==b'XT 5160 WITH 8087'
  assert extracted[b'FPU8087 COM']==(ROOT/'work/FPU8087.COM').read_bytes()
  (ROOT/'work/software_results.json').write_text(json.dumps({k:c.state[k] for k in ('cycles','instructions','hdCommands','hdReads','hdWrites','fpuCommands','refresh','dma')},indent=2))
  print('PASS independent FAT12 byte comparison of DOS-created file and copied FPU application',flush=True)
 finally:c.close()
 # The next process reads the actual persisted image; no memory/CPU injection.
 os.environ.pop('IBM_XT_RESUME',None)
 c=Console('reboot_trace.log')
 try:
  c.wait(lambda s,t,h:'Enter new date' in t,200000000,'cold process restart from persisted fixed disk')
  c.type('10-16-83\r');c.wait(lambda s,t,h:'Enter new time' in t,label='reboot date')
  c.type('\r');c.wait(lambda s,t,h:s['keysQueued']==0 and t.rstrip().endswith('C>'),label='reboot C prompt')
  c.type('type xttest.txt\r');c.wait(lambda s,t,h:s['keysQueued']==0 and 'XT 5160 WITH 8087' in t and t.rstrip().endswith('C>'),label='DOS file survives process restart')
  c.type('fpu8087\r');c.wait(lambda s,t,h:s['keysQueued']==0 and '8087 PASS:' in t and t.rstrip().endswith('C>'),label='persisted FPU application runs after restart')
 finally:c.close()
if __name__=='__main__':main()
