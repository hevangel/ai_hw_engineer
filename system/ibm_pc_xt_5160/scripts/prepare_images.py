#!/usr/bin/env python3
"""Pinned unmodified firmware/media. Never overwrite the persistent hard disk."""
import hashlib,ipaddress,json,re,socket,struct
import urllib.parse,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'work/reference'
HOST='raw.githubusercontent.com'
PCJS='1a91d38eb12e5fdf91116b21ad9ef1935710a496'
DISKS='cd3433748b09837a4c60ca7066f3642772b2d711'
ARTIFACTS=[
 ('jeffpar/pcjs',PCJS,'machines/pcx86/ibm/5160/rom/bios/1982-11-08/XTBIOS-REV1.rom','f75320f4970a8fbcadcda90542f4e3e2e95816f9','bios.bin'),
 ('jeffpar/pcjs',PCJS,'machines/pcx86/ibm/5160/rom/basic/BASIC110.rom','897e689b5606d3837ba810e2d4695e8aa0602c09','basic.bin'),
 ('jeffpar/pcjs',PCJS,'machines/pcx86/ibm/5160/rom/hdc/IBM-XEBEC-1982.rom','6fbc1b275a345f91842637dc5cf60a1a8bf5c07a','hdrom.bin'),
 ('jeffpar/pcjs',PCJS,'machines/pcx86/ibm/video/cga/IBM-CGA.json5','43944e8cb6c539e5faea06bdf1e5ba92eaab36c6','cga.bin'),
 ('jeffpar/pcjs-diskettes',DISKS,'pcx86/sys/dos/ibm/2.00/PCDOS200-DISK1.json','0e834efc93bf0c720bbbfa73aef6964f9b20a477','pcdos200.img'),
 ('jeffpar/pcjs-diskettes',DISKS,'pcx86/sys/dos/ibm/2.00/PCDOS200-DISK2.json','f728ce4968f6a0cb9aa75aa473b280696665d426','tools200.img'),
]
class _NoRedirect(urllib.request.HTTPRedirectHandler):
 def redirect_request(self,req,fp,code,msg,headers,newurl):
  raise ValueError('redirect refused: '+newurl)

_OPENER=urllib.request.build_opener(_NoRedirect)

def open_pinned(url,timeout=60):
 # Downloads only from the pinned GitHub raw host; the host is resolved up
 # front with non-global addresses refused (DNS-rebinding guard; TLS pins
 # the connection), redirects refused, and every artifact blob-hash
 # verified before use.
 parsed=urllib.parse.urlsplit(url)
 if parsed.scheme!='https' or parsed.hostname!=HOST:raise ValueError('download host not allowed: '+url)
 for info in socket.getaddrinfo(parsed.hostname,443):
  address=ipaddress.ip_address(info[4][0])
  if not address.is_global:raise ValueError('resolved address is not global: '+str(address))
 return _OPENER.open(url,timeout=timeout)

def main():
 DEST.mkdir(parents=True,exist_ok=True);manifest=[]
 for repo,rev,path,blob,name in ARTIFACTS:
  url=f'https://raw.githubusercontent.com/{repo}/{rev}/{path}';cache=DEST/Path(path).name
  if not cache.exists():
   with open_pinned(url) as r:cache.write_bytes(r.read())
  raw=cache.read_bytes()
  if hashlib.sha1(f'blob {len(raw)}\0'.encode()+raw).hexdigest()!=blob:raise ValueError('archive integrity: '+path)
  data=raw
  if path.endswith('.json5'):
   text=re.sub(r'//[^\n]*','',raw.decode());text=re.sub(r'0x[0-9a-fA-F]+',lambda m:str(int(m[0],16)),text)
   text=re.sub(r',\s*([\]}])',r'\1',text);data=bytes(json.loads(text)['values'])
  elif path.endswith('.json'):
   image=json.loads(raw);sectors=[]
   for cylinder in image['diskData']:
    for head in cylinder:
     for sector in sorted(head,key=lambda x:x['s']):
      words=sector.get('d',[0]);words=words+[words[-1]]*(sector['l']//4-len(words))
      sectors.append(b''.join(struct.pack('<I',v&0xffffffff) for v in words))
   data=b''.join(sectors)
   if len(data) not in (184320,368640) or hashlib.md5(data).hexdigest()!=image['imageInfo']['hash']:raise ValueError('DOS image integrity')
  (DEST/name).write_bytes(data)
  manifest.append(dict(url=url,git_blob=blob,output=name,bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
 (DEST/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 disk=ROOT/'work/harddisk.img'
 if not disk.exists():disk.write_bytes(bytes(10653696))
 if disk.stat().st_size!=10653696:raise ValueError('persistent hard disk must be 306/4/17: 10653696 bytes')
 from create_disk import main as create_disk
 create_disk()
 print('PASS pinned XT BIOS/BASIC/Xebec/CGA and original PC DOS 2.00; persistent 10 MB disk retained')
if __name__=='__main__':main()
