"""Create FAT12 metadata around unchanged original DOS boot code and files.

Geometry/BPB handling is cross-checked against pinned PCjs diskinfo.js.
Existing nonblank user disks are never overwritten.
"""
from pathlib import Path
import hashlib,struct,urllib.request
ROOT=Path(__file__).resolve().parents[1]
def files(image):
 bps=struct.unpack_from('<H',image,11)[0];spc=image[13];reserved=struct.unpack_from('<H',image,14)[0]
 nf=image[16];entries=struct.unpack_from('<H',image,17)[0];fs=struct.unpack_from('<H',image,22)[0]
 root=(reserved+nf*fs)*bps;data=root+((entries*32+bps-1)//bps)*bps;fat=image[reserved*bps:(reserved+fs)*bps]
 for pos in range(root,root+entries*32,32):
  entry=image[pos:pos+32]
  if entry[0] in (0,0xe5) or entry[11]&0x18:continue
  cluster=struct.unpack_from('<H',entry,26)[0];size=struct.unpack_from('<I',entry,28)[0];out=bytearray();seen=set()
  while len(out)<size:
   if cluster<2 or cluster>=0xff0 or cluster in seen:raise ValueError('source FAT12 chain')
   seen.add(cluster);start=data+(cluster-2)*spc*bps;out.extend(image[start:start+spc*bps])
   offset=cluster+cluster//2;pair=int.from_bytes(fat[offset:offset+2],'little');cluster=pair>>4 if cluster&1 else pair&0xfff
  yield entry[:11],entry,bytes(out[:size])
def main():
 disk=ROOT/'work/harddisk.img'
 if disk.exists() and any(disk.read_bytes()):print('Retained existing nonblank XT hard disk');return
 ref=ROOT/'work/reference';mbr=ref/'DOS.mbr'
 if not mbr.exists():
  mbr.write_bytes(urllib.request.urlopen('https://raw.githubusercontent.com/jeffpar/pcjs/1a91d38eb12e5fdf91116b21ad9ef1935710a496/tools/pc/DOS.mbr',timeout=60).read())
 raw=mbr.read_bytes()
 if hashlib.sha1(f'blob {len(raw)}\0'.encode()+raw).hexdigest()!='38f265836be4887fdf0396ae3b558dec65e95070':raise ValueError('pinned MBR integrity')
 image=bytearray(10653696);image[:446]=raw[:446]
 struct.pack_into('<BBBBBBBBII',image,446,0x80,1,1,0,1,3,0x51,0x31,17,20791);image[510:512]=b'\x55\xaa'
 boot=bytearray((ref/'pcdos200.img').read_bytes()[:512]);base=17*512
 struct.pack_into('<HBHBHHBHHHH',boot,11,512,8,1,2,512,20791,0xf8,8,17,4,17)
 boot[30]=0x80;boot[31]=0;image[base:base+512]=boot
 fat=bytearray(4096);fat[:3]=b'\xf8\xff\xff';cluster=2;root=base+17*512;data=base+49*512
 def set_fat(c,value):
  off=c+c//2;pair=int.from_bytes(fat[off:off+2],'little')
  pair=(pair&0x000f)|(value<<4) if c&1 else (pair&0xf000)|value
  fat[off:off+2]=pair.to_bytes(2,'little')
 entries={}
 for source in ('pcdos200.img','tools200.img'):
  for name,entry,payload in files((ref/source).read_bytes()):entries.setdefault(name,(entry,payload))
 ordered=[b'IBMBIO  COM',b'IBMDOS  COM',b'COMMAND COM']+[n for n in entries if n not in (b'IBMBIO  COM',b'IBMDOS  COM',b'COMMAND COM')]
 for i,name in enumerate(ordered):
  entry,payload=entries[name];entry=bytearray(entry);count=(len(payload)+4095)//4096
  struct.pack_into('<H',entry,26,cluster if count else 0);image[root+i*32:root+(i+1)*32]=entry
  image[data+(cluster-2)*4096:data+(cluster-2)*4096+len(payload)]=payload
  for n in range(count):set_fat(cluster+n,0xfff if n+1==count else cluster+n+1)
  cluster+=count
 image[base+512:base+9*512]=fat;image[base+9*512:base+17*512]=fat
 disk.write_bytes(image);(ref/'initial-harddisk.sha256').write_text(hashlib.sha256(image).hexdigest()+'\n')
 print('Created bootable 306/4/17 FAT12 hard disk with unchanged DOS boot code and',len(ordered),'original files')
if __name__=='__main__':main()
