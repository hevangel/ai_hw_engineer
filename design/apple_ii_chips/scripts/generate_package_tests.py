"""Regenerate package tests from manufacturer truth tables and physical pin facts.

The oracle code below is independent of the package RTL. Board metadata supplies
pin identities/directions only. Manually authored analog/ROM/bus tests are retained.
"""
from pathlib import Path
import json
import xml.etree.ElementTree as ET
L=Path(__file__).resolve().parents[1]
manifest=L.parents[1]/'system/apple_ii/board/rev0_connectivity.json'
components=json.loads(manifest.read_text())['components']
parts={}
for component in components.values():
    part=component['part']
    if part in parts: continue
    element=ET.Element('libpart',part=part)
    pins=ET.SubElement(element,'pins')
    for number,pin in component['pins'].items():
        ET.SubElement(pins,'pin',num=number,name=pin['name'],type=pin['kind'])
    parts[part]=element

def bench(part,name,body):
    pins=parts[part].findall('./pins/pin')
    module='a2_'+part.lower().replace('-','_')
    if part=='8T97': module='a2_8t97_appleii'
    s='`timescale 1ns/1ps\nmodule '+name+';\n    logic [40:1] d;\n    tri [40:1] p;\n'
    for pin in pins:
        if pin.get('type') in ['input','power_in']: s+=f'    assign p[{pin.get("num")}] = d[{pin.get("num")}];\n'
    s+=f'    {module} dut('+','.join(f'.p{p.get("num")}(p[{p.get("num")}])' for p in pins)+');\n'
    s+='    initial begin\n        d = 0;\n'
    for pin in pins:
        if pin.get('type')=='power_in' and pin.get('name')!='GND': s+=f'        d[{pin.get("num")}] = 1;\n'
    s+=body+'\n        $display("PASS '+name+'");\n        $finish;\n    end\nendmodule\n'
    (L/'tb').mkdir(exist_ok=True)
    (L/'tb'/f'{name}.sv').write_text(s,encoding='utf8',newline='\n')

bench('74LS161','tb_counter','''        d[1]=0; #1; d[1]=1; d[9]=1; d[7]=1; d[10]=1;
        for (int i=1; i<=32; i++) begin
            d[2]=0; #1; d[2]=1; #1;
            if ({p[11],p[12],p[13],p[14]} !== 4'(i)) $fatal(1,"count %0d",i);
            if (p[15] !== ((i%16)==15)) $fatal(1,"carry");
        end
        d[9]=0; {d[6],d[5],d[4],d[3]}=4'hb; d[7]=0;
        d[2]=0; #1; d[2]=1; #1;
        if ({p[11],p[12],p[13],p[14]} !== 4'hb) $fatal(1,"load overrides disabled count");
        d[9]=1; d[2]=0; #1; d[2]=1; #1;
        if ({p[11],p[12],p[13],p[14]} !== 4'hb) $fatal(1,"disabled hold");
        d[1]=0; #1;
        if ({p[11],p[12],p[13],p[14]} !== 0) $fatal(1,"asynchronous clear");''')
bench('74LS194','tb_shift','''        d[1]=0; #1; d[1]=1;
        {d[10],d[9]}=3; {d[6],d[5],d[4],d[3]}=4'b1010;
        d[11]=0; #1; d[11]=1; #1;
        if ({p[12],p[13],p[14],p[15]} !== 4'b1010) $fatal(1,"parallel load");
        {d[10],d[9]}=1; d[2]=1;
        d[11]=0; #1; d[11]=1; #1;
        if ({p[12],p[13],p[14],p[15]} !== 4'b0101) $fatal(1,"right shift");
        {d[10],d[9]}=2; d[7]=1;
        d[11]=0; #1; d[11]=1; #1;
        if ({p[12],p[13],p[14],p[15]} !== 4'b1010) $fatal(1,"left shift");
        {d[10],d[9]}=0; d[11]=0; #1; d[11]=1; #1;
        if ({p[12],p[13],p[14],p[15]} !== 4'b1010) $fatal(1,"hold");''')
bench('74LS259','tb_latch','''        d[15]=0; d[14]=1; #1;
        if ({p[12:9],p[7:4]} !== 0) $fatal(1,"clear");
        d[15]=1; d[14]=0; d[13]=1;
        for(int i=0; i<8; i++) begin
            d[3:1]=3'(i); #1;
            if ({p[12:9],p[7:4]} !== 8'((1<<(i+1))-1)) $fatal(1,"addressable set");
        end
        d[14]=1; d[13]=0; #1;
        if ({p[12:9],p[7:4]} !== 8'hff) $fatal(1,"hold");
        d[15]=0; d[14]=0; d[13]=1; d[3:1]=3; #1;
        if ({p[12:9],p[7:4]} !== 8'h08) $fatal(1,"demux mode");''')
bench('8T97','tb_buffer','''        {d[14],d[12],d[10],d[6],d[4],d[2]}=6'b101010;
        d[1]=0; d[15]=0; #1;
        if ({p[13],p[11],p[9],p[7],p[5],p[3]} !== 6'b101010) $fatal(1,"buffer data");
        d[1]=1; #1;
        if ({p[13],p[11],p[9],p[7],p[5],p[3]} !== 6'b10zzzz) $fatal(1,"disable four");
        d[1]=0; d[15]=1; #1;
        if ({p[13],p[11],p[9],p[7],p[5],p[3]} !== 6'bzz1010) $fatal(1,"disable two");''')
bench('74LS74','tb_dff','''        d[1]=0; d[4]=1; d[13]=1; d[10]=1; #1;
        if({p[5],p[6]} !== 2'b01) $fatal(1,"clear");
        d[2]=1; d[1]=1; #1;
        if({p[5],p[6]} !== 2'b01) $fatal(1,"release does not clock");
        d[3]=1; #1;
        if({p[5],p[6]} !== 2'b10) $fatal(1,"clock capture");
        d[1]=0; d[4]=0; #1;
        if({p[5],p[6]} !== 2'b11) $fatal(1,"both async controls");
        d[1]=1; #1;
        if({p[5],p[6]} !== 2'b10) $fatal(1,"release clear while preset asserted");
        d[2]=0; d[4]=1; #1;
        if({p[5],p[6]} !== 2'b10) $fatal(1,"preset release does not clock high level");
        d[3]=0; #1; d[3]=1; #1;
        if({p[5],p[6]} !== 2'b01) $fatal(1,"next clock capture");''')
for part,ds,qs,nqs in [('74LS174',[3,4,6,11,13,14],[2,5,7,10,12,15],[]),('74LS175',[4,5,12,13],[2,7,10,15],[3,6,11,14])]:
    outs=','.join(f'p[{p}]' for p in reversed(qs))
    ins=','.join(f'd[{p}]' for p in reversed(ds))
    body=f'''        d[1]=0; #1; d[1]=1;
        for(int i=0;i<{1<<len(ds)};i++) begin
            {{{ins}}}={len(ds)}'(i); d[9]=0; #1; d[9]=1; #1;
            if({{{outs}}} !== {len(ds)}'(i)) $fatal(1,"parallel data %0d",i);
        end
        d[1]=0; #1;
        if({{{outs}}} !== 0) $fatal(1,"asynchronous reset");'''
    if nqs:body+='\n        if({'+','.join(f'p[{p}]' for p in reversed(nqs))+"} !== 4'hf) $fatal(1,\"complement outputs\");"
    bench(part,'tb_'+part.lower(),body)
bench('74LS195','tb_jk_shift','''        d[1]=0; #1; d[1]=1; d[9]=0;
        {d[7],d[6],d[5],d[4]}=4'b0011; d[10]=1; #1;
        if({p[12],p[13],p[14],p[15]}!==4'b0011) $fatal(1,"load");
        d[9]=1; d[2]=1; d[3]=0; d[10]=0; #1; d[10]=1; #1;
        if({p[12],p[13],p[14],p[15]}!==4'b0110) $fatal(1,"J=1,Kbar=0 toggles");
        d[2]=0; d[3]=1; d[10]=0; #1; d[10]=1; #1;
        if({p[12],p[13],p[14],p[15]}!==4'b1100) $fatal(1,"J=0,Kbar=1 holds");
        d[2]=1; d[3]=1; d[10]=0; #1; d[10]=1; #1;
        if({p[12],p[13],p[14],p[15]}!==4'b1001 || p[11]!==0) $fatal(1,"serial one");
        d[2]=0; d[3]=0; d[10]=0; #1; d[10]=1; #1;
        if({p[12],p[13],p[14],p[15]}!==4'b0010 || p[11]!==1) $fatal(1,"serial zero");''')
bench('74LS166','tb_serial','''        d[9]=0; #1; d[9]=1; d[15]=0;
        {d[14],d[12],d[11],d[10],d[5],d[4],d[3],d[2]}=8'hb3;
        d[7]=1; #1;
        if(p[13]!==1) $fatal(1,"parallel load");
        d[15]=1;
        for(int i=0;i<7;i++) begin
            d[7]=0; #1; d[7]=1; #1;
            if(p[13]!==1'(8'hb3>>(6-i))) $fatal(1,"serial bit %0d",i);
        end
        d[6]=1; d[7]=0; #1; d[7]=1; #1;
        if(p[13]!==1) $fatal(1,"clock inhibit");
        d[9]=0; #1;
        if(p[13]!==0) $fatal(1,"async clear");''')
bench('4116','tb_dram','''        d[4]=1; d[15]=1; d[3]=1; #2;
        if (p[14] !== 1'bz) $fatal(1,"unselected DRAM must release bus");
        // Write all 128 rows at different column addresses, detect aliasing.
        for(int i=0; i<128; i++) begin
            {d[13],d[5],d[6],d[7],d[12],d[11],d[10]}=7'(i);
            #1; d[4]=0; #1;
            {d[13],d[5],d[6],d[7],d[12],d[11],d[10]}=7'(127-i);
            d[3]=0; d[2]=1'(i); #1; d[15]=0; #1;
            if(p[14] !== 1'bz) $fatal(1,"early write must not drive data");
            d[15]=1; d[4]=1; d[3]=1; #1;
        end
        for(int i=0; i<128; i++) begin
            {d[13],d[5],d[6],d[7],d[12],d[11],d[10]}=7'(i);
            #1; d[4]=0; #1;
            {d[13],d[5],d[6],d[7],d[12],d[11],d[10]}=7'(127-i);
            #1; d[15]=0; #1;
            if(p[14] !== 1'(i)) $fatal(1,"DRAM read row %0d",i);
            // RAS may release before CAS; output stays latched until CAS rises.
            d[4]=1; #1;
            if(p[14] !== 1'(i)) $fatal(1,"output retention");
            d[15]=1; #1;
        end
        // Read-modify-write must retain the old output until CAS releases.
        {d[13],d[5],d[6],d[7],d[12],d[11],d[10]}=0;
        #1; d[4]=0; #1;
        {d[13],d[5],d[6],d[7],d[12],d[11],d[10]}=127;
        #1; d[15]=0; #1; d[2]=1; d[3]=0; #1;
        if(p[14] !== 0) $fatal(1,"late write output");
        d[15]=1; d[3]=1; #1; d[15]=0; #1;
        if(p[14] !== 1) $fatal(1,"late write data");''')

# Exhaustive boolean cases at physical pins. The oracle deliberately expresses
# decoder/multiplexer behavior procedurally instead of copying RTL equations.
for part in ['74LS00','74LS02','74LS04','74LS08','74LS11','74LS20','74LS32','74LS51','74LS86','74LS138','74LS139','74LS153','74LS151','74LS251','74LS257','74LS283']:
    pins=parts[part].findall('./pins/pin')
    inputs=[int(p.get('num')) for p in pins if p.get('type')=='input']
    outputs=[int(p.get('num')) for p in pins if p.get('type') in ['output','tri_state']]
    lines=[]
    def oracle(v):
        out={}
        def put(o,val):out[o]='z' if val=='z' else str(int(bool(val)))
        if part in ['74LS00','74LS08','74LS32','74LS86','74LS02']:
            groups=[(1,2,3),(4,5,6),(9,10,8),(12,13,11)] if part!='74LS02' else [(2,3,1),(5,6,4),(8,9,10),(11,12,13)]
            for a,b,o in groups:
                ones=v[a]+v[b]
                put(o, {'74LS00':ones!=2,'74LS08':ones==2,'74LS32':ones>0,'74LS86':ones==1,'74LS02':ones==0}[part])
        elif part=='74LS04':
            for a,o in [(1,2),(3,4),(5,6),(9,8),(11,10),(13,12)]:put(o,not v[a])
        elif part=='74LS11':
            for o,g in [(12,[1,2,13]),(6,[3,4,5]),(8,[9,10,11])]: put(o,all(v[x] for x in g))
        elif part=='74LS20':
            for o,g in [(6,[1,2,4,5]),(8,[9,10,12,13])]: put(o,not all(v[x] for x in g))
        elif part=='74LS51':
            for o,g,h in [(6,[2,3],[4,5]),(8,[1,12,13],[9,10,11])]:put(o,not (all(v[x] for x in g) or all(v[x] for x in h)))
        elif part in ['74LS138','74LS139']:
            groups=[([1,2,3],[15,14,13,12,11,10,9,7],v[6] and not v[4] and not v[5])] if part=='74LS138' else [([2,3],[4,5,6,7],not v[1]),([14,13],[12,11,10,9],not v[15])]
            for addr,outs,en in groups:
                select=sum(v[p]<<i for i,p in enumerate(addr))
                for i,o in enumerate(outs):put(o,not(en and i==select))
        elif part=='74LS153':
            select=v[14]+2*v[2]
            for o,enable,data in [(7,1,[6,5,4,3]),(9,15,[10,11,12,13])]:put(o,0 if v[enable] else v[data[select]])
        elif part in ['74LS151','74LS251']:
            data=v[[4,3,2,1,15,14,13,12][v[11]+2*v[10]+4*v[9]]]
            put(5,('z' if part=='74LS251' else 0) if v[7] else data)
            put(6,('z' if part=='74LS251' else 1) if v[7] else not data)
        elif part=='74LS257':
            for a,b,o in [(2,3,4),(5,6,7),(14,13,12),(11,10,9)]:put(o,'z' if v[15] else v[b if v[1] else a])
        elif part=='74LS283':
            a=sum(v[p]<<i for i,p in enumerate([5,3,14,12])); b=sum(v[p]<<i for i,p in enumerate([6,2,15,11]))
            for i,o in enumerate([4,1,13,10,9]):put(o,((a+b+v[7])>>i)&1)
        return ''.join(out[o] for o in reversed(outputs))
    for case in range(1<<len(inputs)):
        v={p:(case>>i)&1 for i,p in enumerate(inputs)}
        lines.append(format(case,f'0{len(inputs)}b')+oracle(v))
    (L/'tb'/f'{part.lower()}.mem').write_text('\n'.join(lines)+'\n',encoding='utf8')
    width=len(inputs)+len(outputs)
    name='tb_'+part.lower()
    body=f'''        begin
            logic [{width-1}:0] vectors [0:{len(lines)-1}];
            $readmemb("tb/{part.lower()}.mem",vectors);
            for(int i=0; i<{len(lines)}; i++) begin
                {{{','.join(f'd[{p}]' for p in reversed(inputs))}}}=vectors[i][{width-1}:{len(outputs)}];
                #1;
                if ({{{','.join(f'p[{p}]' for p in reversed(outputs))}}} !== vectors[i][{len(outputs)-1}:0]) $fatal(1,"{part} pins case %0d",i);
            end
        end'''
    bench(part,name,body)
(L/'scripts').mkdir(exist_ok=True)
(L/'scripts/run_sim.sh').write_text('''#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
for test in tb/tb_*.sv; do
    top=$(basename "$test" .sv)
    [ "$top" != tb_analog ] || continue
    echo "Simulating $top"
    XEZIM_TWO_STATE=0 xezim --simulate --error-exit -s "$top" src/*.sv "$test" --max-time 1ms >"work/$top.log" 2>&1 || { cat "work/$top.log"; exit 1; }
    cat "work/$top.log"
    grep -q 'PASS ' "work/$top.log" || { echo "Missing success marker: $top" >&2; exit 1; }
done
''',encoding='utf8',newline='\n')
print('Generated package regressions.')
