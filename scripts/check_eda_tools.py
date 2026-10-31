#!/usr/bin/env python3
"""Reproducible positive/negative EDA baseline probes; run inside the tools image.

Use --tools iverilog in the Apple II overlay. Other probes run in the base
image. Generated fixtures, logs and results stay in the ignored scratchpad.
Surfer GUI acceptance is a separate browser interaction, not inferred here.
"""
import argparse
from datetime import datetime, timezone
import json
import re
from pathlib import Path
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir', default='scratchpad/eda-audit')
parser.add_argument('--tools', default='xezim,uvm,verilator,yosys,eqy,sby,verible')
args = parser.parse_args()
work = Path(args.work_dir).resolve()
work.mkdir(parents=True, exist_ok=True)
results = []

def write(name, text):
    target = work / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding='utf-8')
    return str(target)

def check(tool, name, command, fail=False, marker=None, timeout=180, pattern=None, forbidden=None):
    logfile = work / (tool+'-'+name+'.log')
    try:
        run = subprocess.run(command, cwd=work, text=True, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, timeout=timeout)
        output = run.stdout
        passed = (run.returncode != 0 if fail else run.returncode == 0)
        if marker:
            passed = passed and marker in output
        if pattern:
            passed = passed and re.search(pattern, output) is not None
        if forbidden:
            passed = passed and forbidden not in output
        result = dict(tool=tool, check=name, command=command, returncode=run.returncode,
                      expectedFailure=fail, passed=passed, log=logfile.name)
    except (OSError, subprocess.TimeoutExpired) as error:
        output = str(error)
        result = dict(tool=tool, check=name, command=command, passed=False,
                      expectedFailure=fail, error=str(error), log=logfile.name)
    logfile.write_text(output, encoding='utf-8')
    results.append(result)
    print(('PASS' if result['passed'] else 'FAIL')+' '+tool+' '+name, flush=True)
    return result['passed']

good = write('good/audit_and.sv', '''`timescale 1ns/1ps
module audit_and (
  input logic a_i,
  input logic b_i,
  output logic y_o
);
  assign y_o = a_i & b_i;
endmodule
''')
bad_gate = write('bad/audit_and.sv', Path(good).read_text().replace('a_i & b_i', 'a_i | b_i'))
tb = write('tb.sv', '''`timescale 1ns/1ps
module tb;
  logic a_i, b_i, y_o;
  audit_and dut (.*);
  initial begin
    a_i = 0; b_i = 0; #1; assert (y_o == 0) else $fatal(1, "00");
    a_i = 1; b_i = 0; #1; assert (y_o == 0) else $fatal(1, "10");
    a_i = 1; b_i = 1; #1; assert (y_o == 1) else $fatal(1, "11");
    $dumpfile("audit.vcd"); $dumpvars(0, tb);
    a_i = 0; #1; a_i = 1; #1;
    $display("AUDIT PASS"); $finish;
  end
endmodule
''')
fatal = write('negative.sv', '''module negative;
initial begin $fatal(1, "EXPECTED AUDIT FAILURE"); end
endmodule
''')
selected = set(args.tools.split(','))
if 'xezim' in selected:
    check('xezim', 'version', ['xezim', '-V'])
    check('xezim', 'simulate', ['xezim', '--simulate', '--sv2017', '--error-exit', '--wave', '-s', 'tb', good, tb], marker='AUDIT PASS')
    check('xezim', 'fatal-exit', ['xezim', '--simulate', '--error-exit', '-s', 'negative', fatal], fail=True, marker='EXPECTED AUDIT FAILURE')
if 'uvm' in selected:
    # UVM's fatal action calls $finish; inspect severity counts and stopped
    # execution instead of assuming a direct SystemVerilog $fatal exit code.
    uvm = '/opt/uvm/1800.2-2017/src'
    for label,statement in [('positive','`uvm_info("AUDIT", "UVM AUDIT PASS", UVM_LOW)'),('negative','`uvm_fatal("AUDIT", "EXPECTED UVM AUDIT FAILURE")')]:
        source = write('uvm_'+label+'.sv', '''`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
class audit_test extends uvm_test;
  `uvm_component_utils(audit_test)
  function new(string name="audit_test", uvm_component parent=null);
    super.new(name,parent);
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    '''+statement+'''
    $display("UVM AFTER REPORT");
    #1; phase.drop_objection(this);
  endtask
endclass
module uvm_top;
  initial run_test("audit_test");
endmodule
''')
        check('uvm', label, ['xezim', '--simulate', '--sv2017', '--error-exit', '-I', uvm, '-D', 'UVM_NO_DPI', '-D', 'UVM_REPORT_DISABLE_FILE_LINE', '-s', 'uvm_top', uvm+'/uvm_pkg.sv', source], marker='UVM AUDIT PASS' if label=='positive' else 'EXPECTED UVM AUDIT FAILURE', pattern=r'UVM_FATAL\s*:\s*1' if label=='negative' else r'UVM_FATAL\s*:\s*0', forbidden='UVM AFTER REPORT' if label=='negative' else None)
if 'verilator' in selected:
    check('verilator','version',['verilator','--version'])
    if check('verilator','compile',['verilator','--binary','--timing','--assert','-Wall','--top-module','tb','--Mdir',str(work/'obj'),good,tb]):
        check('verilator','simulate',[str(work/'obj/Vtb')],marker='AUDIT PASS')
    check('verilator','bad-syntax',['verilator','--lint-only',write('broken.sv','module broken(input a; endmodule\n')],fail=True,marker='%Error')
if 'yosys' in selected:
    check('yosys','version',['yosys','--version'])
    check('yosys','synthesis',['yosys','-Q','-p',f'read_verilog -sv {good}; hierarchy -check -top audit_and; synth -top audit_and; check -assert; write_json {work}/synth.json'])
    missing=write('missing.v','module missing; absent_cell u(); endmodule\n')
    check('yosys','missing-cell',['yosys','-Q','-p',f'read_verilog {missing}; hierarchy -check -top missing'],fail=True,marker='ERROR')
if 'eqy' in selected:
    for name,gate in [('equivalent',good),('inequivalent',bad_gate)]:
        cfg=write(name+'.eqy',f'[gold]\nread_verilog -sv {good}\nprep -top audit_and\n\n[gate]\nread_verilog -sv {gate}\nsynth -top audit_and\n\n[strategy prove]\nuse sat\ndepth 4\n')
        check('eqy',name,['eqy','-f','-d',str(work/('eqy-'+name)),cfg],fail=name=='inequivalent',marker='FAIL' if name=='inequivalent' else 'PASS')
if 'sby' in selected:
    rtl=write('counter.sv', '''module counter(input clk);
  reg [3:0] count = 0;
  reg past_valid = 0;
  always @(posedge clk) begin
    past_valid <= 1;
    count <= count + 1'b1;
    if (past_valid) assert(count == $past(count) + 4'd1);
    cover(count == 3);
  end
endmodule
''')
    cfg=write('counter.sby',f'[tasks]\nbmc\nprove\ncover\n[options]\nbmc: mode bmc\nprove: mode prove\ncover: mode cover\ndepth 10\n[engines]\nsmtbmc z3\n[script]\nread -formal {rtl}\nprep -top counter\n[files]\n{rtl}\n')
    check('sby','bmc-prove-cover',['sby','-f',cfg],marker='PASS')
    bad=write('counter_bad.sv',Path(rtl).read_text().replace('assert(count == $past(count) + 4\'d1);','assert(count < 2);'))
    cfg=write('counter_bad.sby',f'[options]\nmode bmc\ndepth 10\n[engines]\nsmtbmc z3\n[script]\nread -formal {bad}\nprep -top counter\n[files]\n{bad}\n')
    check('sby','counterexample',['sby','-f',cfg],fail=True,marker='FAIL')
if 'verible' in selected:
    check('verible','version',['verible-verilog-lint','--version'])
    check('verible','format',['verible-verilog-format','--inplace',good])
    check('verible','lint',['verible-verilog-lint',good])
    check('verible','bad-syntax',['verible-verilog-syntax',write('parse_error.sv','module parse_error(input a; endmodule\n')],fail=True,marker='syntax error')
if 'iverilog' in selected:
    check('iverilog','version',['iverilog','-V'])
    source=write('four_state.sv', '''module four_state;
reg drive=0; wire pad; assign pad=drive ? 1'b1 : 1'bz;
initial begin #1; if(pad !== 1'bz) $fatal(1,"Z"); drive=1;
#1; if(pad !== 1'b1) $fatal(1,"one"); $display("FOUR STATE PASS"); $finish; end
endmodule
''')
    check('iverilog','compile',['iverilog','-g2012','-s','four_state','-o',str(work/'four_state.vvp'),source])
    c=write('audit_vpi.c', '''#include <vpi_user.h>
static PLI_INT32 started(p_cb_data data) { (void)data; vpi_printf("VPI AUDIT PASS\\n"); return 0; }
static void register_audit(void) { s_cb_data cb={0}; cb.reason=cbStartOfSimulation; cb.cb_rtn=started; vpi_register_cb(&cb); }
void (*vlog_startup_routines[])(void)={register_audit,0};
''')
    check('iverilog','packaged-vpi-helper',['iverilog-vpi',c])
    check('iverilog','documented-vpi-build',['cc','-std=c11','-shared','-fPIC','-O2','-I/usr/include/iverilog','-o',str(work/'audit_vpi.vpi'),c])
    check('iverilog','four-state-vpi',['vvp','-M',str(work),'-m','audit_vpi',str(work/'four_state.vvp')],marker='VPI AUDIT PASS')
    cpp=write('audit_vpi_cpp.cpp', '#include <vpi_user.h>\nextern "C" {\nstatic PLI_INT32 started(p_cb_data data) { (void)data; vpi_printf("VPI CXX AUDIT PASS\\n"); return 0; }\nstatic void register_audit(void) { s_cb_data cb={}; cb.reason=cbStartOfSimulation; cb.cb_rtn=started; vpi_register_cb(&cb); }\nvoid (*vlog_startup_routines[])(void)={register_audit,0};\n}\n')
    check('iverilog','packaged-vpi-cxx-helper',['iverilog-vpi',cpp])
    check('iverilog','cxx-vpi-load',['vvp','-M',str(work),'-m','audit_vpi_cpp',str(work/'four_state.vvp')],marker='VPI CXX AUDIT PASS')
    check('iverilog','negative-compile',['iverilog','-g2012','-s','negative','-o',str(work/'negative.vvp'),fatal])
    check('iverilog','fatal-exit',['vvp',str(work/'negative.vvp')],fail=True,marker='EXPECTED AUDIT FAILURE')
summary=dict(recordedAt=datetime.now(timezone.utc).isoformat(),checks=results,
             passed=all(item['passed'] for item in results))
(work/'results.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
print('Results:',work/'results.json',flush=True)
sys.exit(0 if summary['passed'] else 1)
