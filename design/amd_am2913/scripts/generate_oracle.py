#!/usr/bin/env python3
"""Compile external truth tables into lookup/case oracles; never read RTL."""
from pathlib import Path
import csv
import sys
ROOT=Path(__file__).resolve().parents[1]
enc=list(csv.DictReader((ROOT/'references/encoder.csv').open(encoding='utf-8')))
gates=list(csv.DictReader((ROOT/'references/gates.csv').open(encoding='utf-8')))
def matches(pattern,value):
 return all(c=='x' or c==v for c,v in zip(pattern,value))
sv=['// Generated from manufacturer truth tables.',
 'logic [2:0] gold_a; logic gold_eo, gold_enable;',
 'always_comb begin gold_a=0;gold_eo=1;',
 'casez({ei_n_i,request_n_i})']
for r in enc:
 sv.append(f"9'b{r['ei']}{r['i7_i0'].replace('x','?')}:begin gold_a=3'b{r['a2_a0']};gold_eo=1'b{r['eo']};end")
sv+=['endcase','gold_enable=0;','casez({g5_n_i,g4_n_i,g3_n_i,g2_i,g1_i})']
for r in gates:sv.append(f"5'b{r['g5_g1'].replace('x','?')}:gold_enable=1'b{r['enable']};")
sv+=['endcase','end']
values=[]
for x in range(16384):
 req=format(x&255,'08b');ei=str((x>>8)&1);gate=format((x>>9)&31,'05b')
 es=[r for r in enc if r['ei']==ei and matches(r['i7_i0'],req)]
 gs=[int(r['enable']) for r in gates if matches(r['g5_g1'],gate)]
 assert len(es)==1 and gs and len(set(gs))==1
 r=es[0];values.append(int(r['a2_a0'],2)|(int(r['eo'])<<3)|(gs[0]<<4))
cpp=['// Generated from original tables, indexed by {g5..g1,EI,I7..I0}.',
 'static const unsigned char manufacturer[16384]={']
cpp+= [','.join(str(v) for v in values[i:i+128])+',' for i in range(0,len(values),128)]
cpp+=['};']
for name,lines in [('formal/manufacturer_oracle.svh',sv),('tb/manufacturer_oracle.hpp',cpp)]:
 path=ROOT/name;data='\n'.join(lines)+'\n'
 if '--check' in sys.argv:assert path.read_text(encoding='utf-8')==data,f'stale {path}'
 else:path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data.encode())
print('Manufacturer truth table: all 16384 combinations checked')
