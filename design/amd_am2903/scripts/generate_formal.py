#!/usr/bin/env python3
"""Compile the independently transcribed manufacturer CSVs to assertions."""
import ast,sys
from pathlib import Path
from table_oracle import ALU,SPECIAL,DEST,ROOT
mapping={'r':'r_i','s':'s_i','q':'q_i','f':'mf','cn':"4'(cn_i)",'z':'z_i','mss':'mss','lss':'lss','si0':'sio0_i','si3':'sio3_i','carry':'mc[4]','overflow':'(mc[3]^mc[4])'}
ops={ast.Add:'+',ast.Sub:'-',ast.Mult:'*',ast.BitAnd:'&',ast.BitOr:'|',ast.BitXor:'^',ast.LShift:'<<',ast.RShift:'>>'}
def sv(expr):
    def tr(n):
        if isinstance(n,ast.Name):return mapping[n.id]
        if isinstance(n,ast.Constant):return "4'd"+str(n.value)
        if isinstance(n,ast.BinOp):return '('+tr(n.left)+ops[type(n.op)]+tr(n.right)+')'
        if isinstance(n,ast.UnaryOp):return ('~' if isinstance(n.op,ast.Invert) else '!')+'('+tr(n.operand)+')'
        if isinstance(n,ast.IfExp):return '('+tr(n.test)+' ? '+tr(n.body)+' : '+tr(n.orelse)+')'
        if isinstance(n,ast.Call):return tr(n.args[0])+'['+n.func.id[1]+']'
        raise ValueError(ast.dump(n))
    return tr(ast.parse(expr,mode='eval').body)
s='// Generated from original manufacturer CSVs; no RTL inspection.\n'
s+='logic [3:0] mf,mg,mp,my,mq,ms,me;\nlogic [4:0] mc;\nlogic mcn,mgn,mpov,mz,mwrite,mqe,msc;\nlogic mpn,mgn_n;\n'
s+='always_comb begin\n  mf=0;mg=0;mp=15;\n  if(instruction_i[4:0]!=0) begin\n    case(instruction_i[4:1])\n'
for op,row in ALU.items():s+=f"      4'd{op}: begin mf={sv(row[0])};mg={sv(row[1])};mp={sv(row[2])};end\n"
s+='    endcase\n  end else begin\n    case(instruction_i[8:5])\n'
for op,row in SPECIAL.items():s+=f"      4'd{op}: begin mf={sv(row[0])};mg={sv(row[1])};mp={sv(row[2])};end\n"
s+='      default: begin end\n    endcase\n  end\nend\n'
s+='assign mc[0]=cn_i;\nfor(genvar k=0;k<4;k++) begin: table_carry\n assign mc[k+1]=mg[k]|(mp[k]&mc[k]);\nend\n'
s+='assign mpn=!(&mp);\nassign mgn_n=!(mg[3]|(mg[2]&mp[3])|(mg[1]&mp[2]&mp[3])|(mg[0]&mp[1]&mp[2]&mp[3]));\n'
def serial(tag,idx):
    pin='sio0_i' if idx==0 else 'sio3_i'
    if tag in ['INPUT','OFF']:return ("1'b0","1'b0")
    return {'F0':('mf[0]',"1'b1"),'F2':('mf[2]',"1'b1"),'F3':('mf[3]',"1'b1"),'SIGN':('sio0_i',"1'b1"),'PARITY':('(^mf)^sio3_i',"1'b1"),'XNOR':('mss ? ~(r_i[3]^mf[3]):mf[3]',"1'b1")}[tag]
def qa(action):
    if action=='HOLD':return "mq=q_i;mqe=0;"
    if action=='LOAD':return "mq=mf;mqe=!ien_n_i;"
    if action=='RIGHT':return "mq={qio3_i,q_i[3:1]};mqe=!ien_n_i;ms[2]=q_i[0];me[2]=1;"
    return "mq={q_i[2:0],qio0_i};mqe=!ien_n_i;ms[3]=q_i[3];me[3]=1;"
s+='always_comb begin\n my=0;mq=q_i;ms=0;me=0;mcn=0;mgn=0;mpov=0;mz=0;mwrite=1;mqe=0;msc=0;\n if(instruction_i[4:0]!=0) begin\n case(instruction_i[8:5])\n'
for op,row in DEST.items():
    ss3,e3=serial(row[2],1);so3,oe3=serial(row[3],1);s0,e0=serial(row[4],0)
    s+=f"  4'd{op}: begin my=mss ? {sv(row[0])}:{sv(row[1])};ms[1]=mss ? ({ss3}):({so3});me[1]=mss ? {e3}:{oe3};ms[0]={s0};me[0]={e0};mwrite=ien_n_i || 1'b{row[5]};{qa(row[6])}end\n"
s+=' endcase\n case(instruction_i[4:1])\n'
for op,row in ALU.items():
    ar=row[3]=='1'
    s+=f"  4'd{op}: begin mcn={'mc[4]' if ar else '0'};mgn=mss ? mf[3]:mgn_n;mpov={'(mss ? (mc[3]^mc[4]):mpn)' if ar else '0'};end\n"
s+=' endcase\n mz=(oe_y_n_i ? y_i:my)!=0;\n end else begin\n case(instruction_i[8:5])\n'
for op,row in SPECIAL.items():
    s0='F0' if op in [0,2,6] else 'PARITY' if op in [4,5] else 'INPUT' if op in [10,12] else 'OFF'
    a,b=serial(s0,0);c,d=serial(row[7],1)
    zm={'Y':'(oe_y_n_i ? y_i:my)!=0','Q':'q_i!=0','QF':'(q_i|mf)!=0','Q0':'lss && !q_i[0]','S3':'mss && !s_i[3]','SC':'mss && !sc_i'}[row[6]]
    s+=f"  4'd{op}: begin my={sv(row[8])};ms[0]={a};me[0]={b};ms[1]={c};me[1]={d};{qa(row[9])}mwrite=ien_n_i;mcn=mss ? {sv(row[3])}:mc[4];mpov=mss ? {sv(row[4])}:mpn;mgn=mss ? {sv(row[5])}:mgn_n;mz={zm};msc={'!ien_n_i' if op in [10,12] else '0'};end\n"
s+=' default: begin end\n endcase\n end\nend\n'
s+='always_comb begin\n if(instruction_i[4:0]!=0 || '+ ' || '.join(f"instruction_i[8:5]==4'd{v}" for v in SPECIAL) +') begin\n'
s+=' assert(f==mf && gi==mg && pi==mp);\n assert(y_o==my && cn4_o==mcn && gn_o==mgn && povr_o==mpov);\n assert(z_pull_low_o==mz && write_n_o==mwrite);\n assert(shift_o==ms && shift_oe_o==me);\n assert(q_enable_o==mqe && sc_enable_o==msc);\n if(mqe) assert(q_next_o==mq);\n if(msc) assert(sc_next_o==~(r_i[3]^mf[3]));\n end\nend\n'
s+='always_ff @($global_clock) begin\n'
for op in SPECIAL:s+=f" cover(instruction_i[4:0]==0 && instruction_i[8:5]==4'd{op} && !ien_n_i && mss && r_i!=s_i && cn_i);\n"
s+=' cover(instruction_i[4:0]!=0 && instruction_i[8:5]==14 && y_o==15);\n cover(instruction_i[4:0]!=0 && instruction_i[8:5]==6 && q_enable_o);\nend\n'
p=ROOT/'formal/manufacturer_datapath.svh'
if '--check' in sys.argv:assert p.read_text()==s, 'generated formal differs from external tables'
else:p.write_text(s)
