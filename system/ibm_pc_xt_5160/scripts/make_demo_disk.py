"""A new FAT12 data disk containing the assembled CPU/8087 demonstration."""
from pathlib import Path
import struct
ROOT=Path(__file__).resolve().parents[1]
def main():
 code=(ROOT/'work/FPU8087.COM').read_bytes();assert len(code)<512
 image=bytearray(184320);image[:512]=(ROOT/'work/reference/pcdos200.img').read_bytes()[:512]
 for fat in (512,1536):image[fat:fat+6]=b'\xfc\xff\xff\xff\x0f\x00'
 entry=bytearray(32);entry[:11]=b'FPU8087 COM';entry[11]=0x20
 struct.pack_into('<HI',entry,26,2,len(code));image[2560:2592]=entry;image[4608:4608+len(code)]=code
 (ROOT/'work/fpu-demo.img').write_bytes(image)
if __name__=='__main__':main()
