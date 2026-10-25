#!/usr/bin/env python3
"""Compile semantic manufacturer table to generic action lookup; no RTL read."""
import csv
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
rows=list(csv.DictReader((ROOT/'references/instructions.csv').open(encoding='utf-8')))
assert [int(r['code'],16) for r in rows]==list(range(16))
fields={
 'mask':['hold','zero','ones','andnot','or','bus'],
 'status':['hold','zero','bus','vector'],
 'group':['hold','gar','ge','advance'],
 'clear':['none','all','bus','mask','held'],
 'irq':['hold','on','off'],
 'vector':['hold','zero','load'],
 'm_output':['0','1'],'s_output':['0','1'],
 'overflow':['hold','reset','set']}
values=[];bit=0;shifts={}
for k,opts in fields.items():shifts[k]=bit;bit+=(len(opts)-1).bit_length()
for r in rows:values.append(sum(fields[k].index(r[k])<<shifts[k] for k in fields))
sv=['// Generated solely from original instruction effects.',
 f'function automatic [{bit-1}:0] manufacturer_actions(input logic [3:0] op,input logic disabled);',
 'begin manufacturer_actions=0; if(!disabled)begin case(op)']
sv+=[f"4'h{i:x}:manufacturer_actions={bit}'d{v};" for i,v in enumerate(values)]
sv+=['endcase end end endfunction']
cpp=['// Generated solely from original instruction effects.',
 'static const unsigned actions[16]={'+','.join(str(v) for v in values)+'};']
for k,shift in shifts.items():cpp+=[f'static constexpr unsigned {k.upper()}_SHIFT={shift};']
for name,lines in [('formal/manufacturer_actions.svh',sv),('tb/manufacturer_actions.hpp',cpp)]:
 p=ROOT/name;data='\n'.join(lines)+'\n'
 if '--check' in sys.argv:assert p.read_text(encoding='utf-8')==data,f'stale {p}'
 else:p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data.encode())
print('Am2914 manufacturer actions:',shifts,'width',bit)
