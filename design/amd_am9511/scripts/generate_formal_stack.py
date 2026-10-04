#!/usr/bin/env python3
"""Compile independent stack-survivor assertions directly from AMD's CSV."""
from pathlib import Path
import argparse,csv
ROOT=Path(__file__).resolve().parents[1]
def build():
 rows=list(csv.DictReader((ROOT/'references/commands.csv').read_text(encoding='utf-8').splitlines()))
 out=['// Independent survivor checker compiled directly from manufacturer CSV.\nfunction automatic [255:0] documented_stack(input logic [6:0] cmd,input logic [127:0] old_stack,input logic [31:0] result,input logic overflow_format);\n logic [127:0] value,mask;\n begin value=0;mask=0;case(cmd)\n']
 for row in rows:
  width=16 if row['code']=='1f' else int(row['width']);tokens=row['result_stack'].split();value=[];mask=[]
  assert width*len(tokens)==128
  for token in tokens:
   mask.append(f"{width}'h"+('0'*(width//4) if token=='?' else 'f'*(width//4)))
   if token=='?':value.append(f"{width}'d0")
   elif token=='R':value.append('result' if width==32 else 'result[15:0]')
   elif token=='Rhi':value.append('result[31:16]')
   elif token=='Rlo':value.append('result[15:0]')
   elif token=='PI':value.append("32'h02c90fda")
   else:
    source=ord(token[0])-ord('A');sourcewidth=32 if len(token)>1 else width;high=127-source*sourcewidth
    if token.endswith('lo'):high-=16
    value.append(f'old_stack[{high}:{high-width+1}]')
  line=f"7'h{row['code']}:begin value={{{','.join(value)}}};mask={{{','.join(mask)}}};"
  if row['code']=='15':line+="value[127:96]=old_stack[119]?old_stack[127:96]^32'h80000000:old_stack[127:96];"
  if row['code']=='1f':line+="if(overflow_format)begin value={old_stack[127:32],32'd0};mask={96'hffffffffffffffffffffffff,32'd0};end "
  out.append(line+'end\n')
 out.append('default:begin end\nendcase documented_stack={mask,value};end\nendfunction\n')
 out.append('function automatic [6:0] documented_flags(input logic [6:0] cmd);begin case(cmd)\n')
 for row in rows:
  mask=127 if row['affected']=='ALL' else sum(v for c,v in [('S',64),('Z',32),('E',30),('C',1)] if c in row['affected'])
  out.append(f"7'h{row['code']}:documented_flags=7'd{mask};\n")
 out.append('default:documented_flags=0;endcase end endfunction\n')
 return ''.join(out)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args();target=ROOT/'formal/documented_stack.svh';value=build()
 if args.check:
  if target.read_text(encoding='utf-8')!=value:raise SystemExit('stale manufacturer survivor checker')
 else:target.write_bytes(value.encode())
