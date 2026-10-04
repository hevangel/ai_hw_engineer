#!/usr/bin/env python3
"""Compile the transcribed manufacturer command table, never RTL, to decode."""
from pathlib import Path
import csv,argparse
ROOT=Path(__file__).resolve().parents[1]
def build():
    rows=list(csv.DictReader((ROOT/'references/commands.csv').read_text(encoding='utf-8').splitlines()))
    if len(rows)!=43 or len({r['code'] for r in rows})!=43:raise ValueError('expected 43 distinct manufacturer commands')
    lines=['// Generated from manufacturer commands.csv. {engine[1:0],fixed_op[2:0],status_mask[6:0]}.\n',
           'function automatic [11:0] command_descriptor(input logic [6:0] command);\n case(command)\n']
    fixed={'SADD':0,'DADD':0,'SSUB':1,'DSUB':1,'SMUL':2,'DMUL':2,'SMUU':3,'DMUU':3,'SDIV':4,'DDIV':4,'CHSS':5,'CHSD':5}
    floating={'FADD','FSUB','FMUL','FDIV','FLTS','FLTD','FIXS','FIXD'}
    derived={'SQRT','SIN','COS','TAN','ASIN','ACOS','ATAN','LOG','LN','EXP','PWR'}
    for r in rows:
        n=r['mnemonic'];engine=1 if n in fixed else 2 if n in floating else 3 if n in derived else 0
        mask=127 if r['affected']=='ALL' else (64 if 'S' in r['affected'] else 0)|(32 if 'Z' in r['affected'] else 0)|(30 if 'E' in r['affected'] else 0)|(1 if 'C' in r['affected'] else 0)
        descriptor=(engine<<10)|(fixed.get(n,0)<<7)|mask
        lines.append(f"  7'h{r['code']}: command_descriptor=12'h{descriptor:03x}; // {n}\n")
    lines.append("  default: command_descriptor=0;\n endcase\nendfunction\n")
    return ''.join(lines)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    path=ROOT/'src/amd_am9511_commands.svh';value=build()
    if args.check:
        if not path.exists() or path.read_text(encoding='utf-8')!=value:raise SystemExit('stale command decode')
    else:path.write_bytes(value.encode('utf-8'))
