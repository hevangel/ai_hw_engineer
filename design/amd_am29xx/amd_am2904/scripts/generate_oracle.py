#!/usr/bin/env python3
"""Compile the prior manufacturer CSV transcription; never read RTL."""
import ast
import csv
from pathlib import Path
import sys
import re
ROOT=Path(__file__).resolve().parents[1]
STATUS=list(csv.DictReader((ROOT/'references/status.csv').open(encoding='utf-8')))
SHIFT=list(csv.DictReader((ROOT/'references/shift.csv').open(encoding='utf-8')))
assert [int(r['code'],16) for r in STATUS]==list(range(64))
assert [int(r['code'],16) for r in SHIFT]==list(range(32))
def expression(s):
 def visit(n):
  if isinstance(n,ast.Name):
   assert n.id in 'UZ UC UN UV MZ MC MN MV IZ IC IN IV YZ YC YN YV S0 SN Q0 QN'.split()
   return n.id
  if isinstance(n,ast.Constant):
   assert n.value in [0,1];return str(n.value)
  if isinstance(n,ast.UnaryOp) and isinstance(n.op,ast.Invert):return '('+visit(n.operand)+' ^ 1)'
  if isinstance(n,ast.BinOp):
   return '('+visit(n.left)+{ast.BitOr:' | ',ast.BitAnd:' & ',ast.BitXor:' ^ '}[type(n.op)]+visit(n.right)+')'
  raise ValueError(ast.dump(n))
 return visit(ast.parse(s,mode='eval').body)
sv=['// Generated from manufacturer CSV by generate_oracle.py; do not edit.',
 'logic [3:0] gold_u, gold_m, gold_y, gold_shift, gold_shift_oe;',
 'logic gold_y_oe, gold_ct, gold_ct_oe, gold_carry;',
 'logic UZ,UC,UN,UV,MZ,MC,MN,MV,IZ,IC,IN,IV,YZ,YC,YN,YV,S0,SN,Q0,QN;',
 'always_comb begin',
 '{UV,UN,UC,UZ}=usr; {MV,MN,MC,MZ}=msr;',
 '{IV,IN,IC,IZ}=status_i; {YV,YN,YC,YZ}=y_i; {QN,Q0,SN,S0}=shift_i;',
 'gold_u=0; gold_m=0; gold_y=0; gold_ct=0; gold_carry=0;',
 'gold_shift=0; gold_shift_oe=0;',
 'gold_ct_oe=!oect_n_i; gold_y_oe=!oey_n_i && instruction_i[5:0]!=0;',
 'case (instruction_i[5:0])']
cpp=['// Generated only from manufacturer CSV; independent of RTL.',
 'struct Golden { unsigned pins, next; };',
 'static Golden golden(unsigned inst,unsigned controls,unsigned u,unsigned m) {',
 'const unsigned input=controls&15, y=(controls>>4)&15, serial=(controls>>8)&15;',
 'const unsigned UZ=u&1,UC=(u>>1)&1,UN=(u>>2)&1,UV=(u>>3)&1;',
 'const unsigned MZ=m&1,MC=(m>>1)&1,MN=(m>>2)&1,MV=(m>>3)&1;',
 'const unsigned IZ=input&1,IC=(input>>1)&1,IN=(input>>2)&1,IV=(input>>3)&1;',
 'const unsigned YZ=y&1,YC=(y>>1)&1,YN=(y>>2)&1,YV=(y>>3)&1;',
 'const unsigned S0=serial&1,SN=(serial>>1)&1,Q0=(serial>>2)&1,QN=(serial>>3)&1;',
 'unsigned un=0,mn=0,out_y=0,ct=0,carry=0,sh=0,en=0;',
 'switch(inst&63) {']
for r in STATUS:
 op=int(r['code'],16)
 ue=[expression(r[k]) for k in ['uz','uc','un','uv']]
 me=[expression(r[k]) for k in ['mz','mc','mn','mv']]
 yexpr={'U':'usr','M':'msr','I':'status_i'}[r['y']]
 sv+= [f"6'h{op:02x}: begin gold_u={{{','.join(reversed(ue))}}}; gold_m={{{','.join(reversed(me))}}}; gold_y={yexpr}; gold_ct={expression(r['ct'])}; gold_carry={expression(r['carry'])}; end"]
 def pack(parts):return ' | '.join(f'(({p})<<{i})' for i,p in enumerate(parts))
 cpp+=[f"case {op}: un={pack(ue)}; mn={pack(me)}; out_y={dict(U='u',M='m',I='input')[r['y']]}; ct={expression(r['ct'])}; carry={expression(r['carry'])}; break;"]
sv+=['endcase', 'if (ceu_n_i) gold_u=usr;',
 'for (integer b=0;b<4;b=b+1) if(cem_n_i || e_n_i[b]) gold_m[b]=msr[b];',
 'case (instruction_i[12:11])', "2'd0:gold_carry=0; 2'd1:gold_carry=1; 2'd2:gold_carry=cx_i; default:begin end endcase",
 'if (!se_n_i) begin', 'case (instruction_i[10:6])']
cpp+=['}', 'if(controls&(1u<<13))un=u;',
 'for(unsigned b=0;b<4;++b)if((controls&(1u<<14)) || (controls&(1u<<(15+b))))mn=(mn&~(1u<<b))|(m&(1u<<b));',
 'switch(inst>>11){case 0:carry=0;break;case 1:carry=1;break;case 2:carry=(controls>>12)&1;break;default:break;}',
 'if(!(controls&(1u<<21)))switch((inst>>6)&31){']
for r in SHIFT:
 op=int(r['code'],16);parts=[r[k] for k in ['s0','sn','q0','qn']]
 en=sum(1<<i for i,p in enumerate(parts) if p!='-');vals=[expression(p) if p!='-' else '0' for p in parts]
 mc='' if r['load_mc']=='-' else 'gold_m[1]='+expression(r['load_mc'])+';'
 sv+=[f"5'h{op:02x}:begin gold_shift={{{','.join(reversed(vals))}}}; gold_shift_oe=4'd{en}; {mc} end"]
 mc='' if r['load_mc']=='-' else 'mn=(mn&~2u)|('+expression(r['load_mc'])+'<<1);'
 cpp+=[f'case {op}:sh={pack(vals)};en={en};{mc}break;']
sv+=['endcase','end','end']
cpp+=['}',
 'const unsigned ye=!(controls&(1u<<19)) && (inst&63)!=0,ce=!(controls&(1u<<20));',
 'return {out_y|(ye<<4)|(ct<<5)|(ce<<6)|(carry<<7)|(sh<<8)|(en<<12),un|(mn<<4)};', '}']
# Expressions are single-bit. Size their literals before SV concatenation.
sv=[re.sub(r'\b[01]\b',lambda m:"1'b"+m.group(),line) if 'gold_u={' in line or 'gold_shift={' in line else line for line in sv]
for path,lines in [(ROOT/'formal/manufacturer_oracle.svh',sv),(ROOT/'tb/manufacturer_oracle.hpp',cpp)]:
 data=('\n'.join(lines)+'\n').encode()
 if '--check' in sys.argv:
  assert path.read_text(encoding='utf-8')==data.decode(),f'stale {path}'
 else:path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
print('Manufacturer oracle tables: 64 status/condition rows, 32 shift rows checked')
