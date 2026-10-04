#!/usr/bin/env python3
"""Interpret primary manufacturer expressions. Authored before RTL."""
import csv
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(name):
    return {int(row[0],16):row[1:] for row in csv.reader(line for line in (ROOT/'references'/name).read_text().splitlines() if not line.startswith('#'))}
COMPILED={}
ALU=read('alu.csv');SPECIAL=read('special.csv');DEST=read('destinations.csv')
def bit(v,n): return (v>>n)&1
def oracle(word,r,s,q,sc,role,cn,z,shift,oe_y,y_in,ien):
    dst=word>>5;fn=(word>>1)&15;special=(word&31)==0
    ctx=dict(r=r,s=s,q=q,cn=cn,z=z,mss=role==2,lss=role==0,si0=bit(shift,0),si3=bit(shift,1),b3=lambda v:bit(v,3),b2=lambda v:bit(v,2),b1=lambda v:bit(v,1))
    def ex(expr): return eval(COMPILED[expr] if expr in COMPILED else COMPILED.setdefault(expr,compile(expr,'manufacturer-table','eval')),{'__builtins__':{}},ctx)
    if special:
        row=SPECIAL[dst];fe,ge,pe=row[:3]
    else: fe,ge,pe,arithmetic=ALU[fn]
    f=ex(fe)&15;g=ex(ge)&15;p=ex(pe)&15;ctx['f']=f
    # Independent per-bit truth-chain in Table5, including non-ALU Gi/Pi.
    c=[cn]; gc=0
    for i in range(4):
        c.append(bit(g,i)|(bit(p,i)&c[-1]));gc=bit(g,i)|(bit(p,i)&gc)
    carry=c[4];overflow=c[3]^c[4];ctx.update(carry=carry,overflow=overflow)
    gn=1-gc;pn=1-int(p==15)
    if special:
        cn4=ex(row[3]) if role==2 else carry
        ovr=ex(row[4]);n=ex(row[5]);zm=row[6];s3=row[7]
        if s3=='XNOR' and role!=2:s3='F3'
        y=ex(row[8]);qa=row[9];write=0
        s0='F0' if dst in [0,2,6] else 'PARITY' if dst in [4,5] else 'INPUT' if dst in [10,12] else 'OFF'
        sc_next=1-(bit(r,3)^bit(f,3)) if dst in [10,12] and not ien else sc
    else:
        row=DEST[dst];y=ex(row[0 if role==2 else 1]);s3=row[2 if role==2 else 3];s0=row[4];write=int(row[5]);qa=row[6]
        cn4=carry if int(arithmetic) else 0;ovr=overflow if int(arithmetic) else 0;pn=pn if int(arithmetic) else 0;n=bit(f,3);zm='Y';sc_next=sc
    so=[0,0,0,0];en=[0,0,0,0]
    if s0=='F0':so[0]=bit(f,0);en[0]=1
    if s0=='PARITY':so[0]=(f.bit_count()+bit(shift,1))&1;en[0]=1
    if s3 not in ['OFF','INPUT']:
        so[1]=bit(f,2) if s3=='F2' else bit(f,3) if s3=='F3' else bit(shift,0) if s3=='SIGN' else 1-(bit(r,3)^bit(f,3));en[1]=1
    qn=q
    if qa=='RIGHT':qn=(bit(shift,3)<<3)|(q>>1);so[2]=q&1;en[2]=1
    if qa=='LEFT':qn=((q<<1)|bit(shift,2))&15;so[3]=bit(q,3);en[3]=1
    if qa=='LOAD':qn=f
    if ien:qn=q;write=1
    zv=True;z_en=True;bus_y=y_in if oe_y else y
    if zm=='Y':zv=bus_y==0
    elif zm=='Q':zv=q==0
    elif zm=='QF':zv=(q|f)==0
    elif zm=='Q0':z_en=role==0;zv=bool(q&1)
    elif zm=='S3':z_en=role==2;zv=bool(bit(s,3))
    elif zm=='SC':z_en=role==2;zv=bool(sc)
    return [y,qn,sc_next,cn4,n if role==2 else gn,ovr if role==2 else pn,int(z_en and not zv),write,sum(v<<i for i,v in enumerate(so)),sum(v<<i for i,v in enumerate(en))]

if __name__=='__main__':
    import itertools,random,sys
    rng=random.Random(0x29031978);count=0
    with open(sys.argv[1],'w') as out:
        def emit(word,role,a,b,q,sc,da,db,exty,pins,shift,aa,bb,seed):
            global count
            sc&=1
            ea=pins&1;ob=(pins>>1)&1;oy=(pins>>2)&1;cn=(pins>>3)&1;z=(pins>>4)&1;ien=(pins>>5)&1;we=(pins>>6)&1
            # a,b are independently set before read; alias gets one physical value.
            if aa==bb:b=a
            rr=da if ea else a;ss=q if word&1 else db if ob else b
            expected=oracle(word,rr,ss,q,sc,role,cn,z,shift,oy,exty,ien)
            out.write(' '.join(format(v,'x') for v in [word,role,a,b,q,sc,da,db,exty,pins,shift,aa,bb,seed,*expected])+'\n');count+=1
        words=[w for w in range(512) if w&31 or (w>>5) in SPECIAL]
        for w,role,source,iteration in itertools.product(words,range(3),range(8),range(16)):
            pins=source|((iteration&1)<<3)|(((iteration>>1)&1)<<4)|(((iteration>>2)&1)<<5)|(((iteration>>3)&1)<<6)
            vals=[rng.randrange(16) for _ in range(9)]
            emit(w,role,*vals[:7],pins,rng.randrange(16),*vals[7:],rng.randrange(0x100000000))
        # Every normal ALU function with all 4-bit R/S/Cn for all roles.
        for fn,role,a,b,cn in itertools.product(range(16),range(3),range(16),range(16),range(2)):
            emit((12<<5)|(fn<<1)|1,role,a,b,b,0,a,b,0,3|(cn<<3)|64,0,1,2,0)
        # Every F/Q/shift-pin combination and normal destination/role.
        for dst,role,f,q,shift in itertools.product(range(16),range(3),range(16),range(16),range(16)):
            emit((dst<<5)|12,role,f,0,q,1,f,0,0,3|64,shift,1,2,0)
    print(f'AMD Tables1–5 oracle: {count} vectors, {len(words)} documented words')
