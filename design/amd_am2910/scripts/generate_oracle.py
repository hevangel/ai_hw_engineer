#!/usr/bin/env python3
"""External AMD Table I interpreter; no RTL parsing or imported DUT logic."""
import csv, itertools, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
rows=list(csv.reader(line for line in (ROOT/'references/instructions.csv').read_text().splitlines() if not line.startswith('#')))

def row_for(op, rc):
    return next(row for row in rows if int(row[0],16)==op and (row[2]=='X' or int(row[2])==int(rc!=0)))

def packed(op, nz, passed):
    row=row_for(op,nz)
    src,act=row[5:7] if passed else row[3:5]
    mode=row[7]
    return ['PC','D','R','F','Z'].index(src) | (['HOLD','PUSH','POP','CLEAR'].index(act)<<3) | ((mode=='LOAD' or (mode=='CONDLOAD' and passed))<<5) | ((mode=='DEC')<<6)

def table_text():
    s='// Generated exclusively from references/instructions.csv (AMD Table I).\n'
    s+='function automatic [6:0] manufacturer_table(input [3:0] op, input nz, passed);\n  case ({op,nz,passed})\n'
    for op,nz,p in itertools.product(range(16),range(2),range(2)):
        s+=f"    6'd{op*4+nz*2+p}: manufacturer_table=7'd{packed(op,nz,p)};\n"
    return s+"    default: manufacturer_table=0;\n  endcase\nendfunction\n"

if len(sys.argv)>1 and sys.argv[1]=='--write-table':
    (ROOT/'formal/table_oracle.svh').write_text(table_text());sys.exit(0)
if len(sys.argv)>1 and sys.argv[1]=='--check-table':
    assert (ROOT/'formal/table_oracle.svh').read_text()==table_text(), 'formal table differs from manufacturer CSV'
    print('Manufacturer table transcription/generation check PASSED');sys.exit(0)

# Deterministic xorshift32 stimulus: reproducible runs without the random
# module (same practice as the LFSR stimulus in the SV benches).
class _Rng:
    def __init__(self,seed): self.s=(seed&0xFFFFFFFF) or 0x29101978
    def randrange(self,n):
        s=self.s
        s^=(s<<13)&0xFFFFFFFF;s^=s>>17;s^=(s<<5)&0xFFFFFFFF
        self.s=s
        return s%n

lines=[]
def emit(op,pins,depth,rc,pc,words,d):
    cc,ce,ci,rld,oe=[(pins>>i)&1 for i in range(5)]
    passed=ce or not cc
    row=row_for(op,rc); src,act=row[5:7] if passed else row[3:5]
    valid=src!='F' or depth!=0
    y={'PC':pc,'D':d,'R':rc,'F':words[max(0,depth-1)],'Z':0}[src]
    # Bottom-first external list, not DUT pointer/index decoding.
    after=list(words); nd=depth
    if act=='PUSH': after[min(depth,4)]=pc; nd=min(depth+1,5)
    elif act=='POP': nd=max(depth-1,0)
    elif act=='CLEAR': nd=0
    mode=row[7]
    nr=d if not rld or mode=='LOAD' or (mode=='CONDLOAD' and passed) else ((rc-1)&4095 if mode=='DEC' else rc)
    values=[op,pins,depth,rc,pc,*words,d,int(valid),y,(y+ci)&4095,nd,nr,*after]
    lines.append(' '.join(format(v,'x') for v in values))

rng=_Rng(0x29101978);count=0
for op,pins,depth,rc in itertools.product(range(16),range(32),range(6),[0,1,2,2047,2048,4094,4095]):
    pc=rng.randrange(4096); d=rng.randrange(4096); words=[rng.randrange(4096) for _ in range(5)]
    emit(op,pins,depth,rc,pc,words,d);count+=1
for _ in range(65536):
    emit(rng.randrange(16),rng.randrange(32),rng.randrange(6),rng.randrange(4096),rng.randrange(4096),[rng.randrange(4096) for _ in range(5)],rng.randrange(4096));count+=1
# Generated vectors always live in the design's own work tree.
out_path=(ROOT/'work'/'sim'/'vectors.txt').resolve()
out_path.parent.mkdir(parents=True,exist_ok=True)
out_path.write_text(''.join(line+'\n' for line in lines))
print(f'Manufacturer Table I oracle: {count} independent transitions')
