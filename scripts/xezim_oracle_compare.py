#!/usr/bin/env python3
"""Differential SystemVerilog semantics check: Xezim against Verilator as an independent oracle.

Run inside the tools image (both simulators are in the base image). Every case
prints deterministic `R:` result lines. A case passes only when both simulators
exit 0 and print byte-identical `R:` lines. A mismatch is a recorded finding,
not something to hide: the report lists unsupported or divergent constructs.
Generated sources, binaries and logs stay in the ignored scratchpad.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir', default='scratchpad/xezim-oracle')
parser.add_argument('--only', default='', help='comma separated case names')
args = parser.parse_args()
work = Path(args.work_dir).resolve()
work.mkdir(parents=True, exist_ok=True)

CASES = {}

def case(name, source):
    CASES[name] = source

case('signed_arithmetic', '''
module top;
  logic signed [7:0] a, b;
  logic [7:0] u;
  int i;
  initial begin
    a = -8'sd100; b = 8'sd50; u = 8'd200;
    $display("R:sum=%0d", a + b);
    $display("R:wrap=%0d", a - b);
    $display("R:shr_arith=%0d", a >>> 2);
    $display("R:shr_logic=%0d", u >> 2);
    $display("R:signed_cmp=%0d unsigned_cmp=%0d", a < b, u < 8'd100);
    $display("R:mixed=%0d", $signed(u) < 0);
    i = -7; $display("R:div=%0d mod=%0d", i / 2, i % 3);
    $display("R:pow=%0d", 3 ** 4);
    $display("R:ternary=%0d", (a < 0) ? 11 : 22);
  end
endmodule
''')

case('bit_operations', '''
module top;
  logic [15:0] v;
  logic [7:0] hi, lo;
  initial begin
    v = 16'hA5C3;
    $display("R:redand=%0d redor=%0d redxor=%0d", &v, |v, ^v);
    hi = v[15:8]; lo = v[7:0];
    $display("R:concat=%h repl=%h", {lo, hi}, {2{lo}});
    $display("R:pluspart=%h minuspart=%h", v[4 +: 4], v[11 -: 4]);
    v[3:0] = 4'hF;
    $display("R:setslice=%h", v);
    $display("R:shift=%h %h", v << 4, v >> 4);
    $display("R:onehot=%0d countones=%0d", $onehot(16'h0400), $countones(v));
    $display("R:clog2=%0d %0d %0d", $clog2(1), $clog2(9), $clog2(1024));
  end
endmodule
''')

case('struct_enum_typedef', '''
module top;
  typedef struct packed { logic [3:0] op; logic [3:0] arg; } insn_t;
  typedef enum logic [1:0] { IDLE = 0, RUN = 1, DONE = 3 } state_t;
  insn_t insn;
  state_t st;
  initial begin
    insn = 8'h5A;
    $display("R:op=%h arg=%h whole=%h", insn.op, insn.arg, insn);
    st = RUN;
    $display("R:state=%0d next=%0d", st, st.next());
    st = state_t'(3);
    $display("R:name=%s", st.name());
    insn.arg = 4'h1;
    $display("R:modified=%h", insn);
  end
endmodule
''')

case('functions_tasks', '''
module top;
  function automatic int fact(input int n);
    if (n <= 1) return 1;
    return n * fact(n - 1);
  endfunction
  function automatic int addk(input int a, input int k = 5);
    return a + k;
  endfunction
  task automatic divmod(input int a, input int b, output int q, output int r);
    q = a / b; r = a % b;
  endtask
  int q, r;
  initial begin
    $display("R:fact=%0d", fact(10));
    $display("R:default=%0d explicit=%0d", addk(1), addk(1, 9));
    divmod(47, 5, q, r);
    $display("R:divmod=%0d,%0d", q, r);
  end
endmodule
''')

case('sequential_logic', '''
module top;
  logic clk = 0;
  logic [3:0] count = 0;
  logic [3:0] shadow = 0;
  always #5 clk = ~clk;
  always_ff @(posedge clk) begin
    count <= count + 1;
    shadow <= count;
  end
  initial begin
    repeat (6) @(posedge clk);
    #1;
    $display("R:count=%0d shadow=%0d time=%0t", count, shadow, $time);
    $finish;
  end
endmodule
''')

case('nba_ordering', '''
module top;
  int a, b, c;
  initial begin
    a = 1; b = 2;
    a <= b; b <= a;
    #1;
    $display("R:swap=%0d,%0d", a, b);
    c = 1; c = c + 1; c <= c + 10;
    #1;
    $display("R:nba=%0d", c);
  end
endmodule
''')

case('generate_parameters', '''
module leaf #(parameter int W = 4) (input logic [W-1:0] i, output logic [$clog2(W+1)-1:0] o);
  assign o = $countones(i);
endmodule
module top;
  logic [7:0] x; logic [3:0] y8; logic [2:0] y4;
  leaf #(.W(8)) u8 (.i(x), .o(y8));
  leaf #(.W(4)) u4 (.i(x[3:0]), .o(y4));
  genvar g;
  int total;
  generate for (g = 0; g < 4; g++) begin : blk
    localparam int SQ = g * g;
    initial total += SQ;
  end endgenerate
  initial begin
    total = 0;
    x = 8'b1011_0110;
    #1;
    $display("R:ones8=%0d ones4=%0d", y8, y4);
    $display("R:total_after=%0d", total);
  end
endmodule
''')

case('arrays_queues', '''
module top;
  int fixed [4];
  int dyn [];
  int q [$];
  int assoc [string];
  int sum, front, back;
  initial begin
    foreach (fixed[i]) fixed[i] = i * 10;
    dyn = new[3];
    dyn[0] = 7; dyn[1] = 8; dyn[2] = 9;
    q.push_back(1); q.push_back(2); q.push_front(0);
    assoc["a"] = 1; assoc["b"] = 2;
    sum = 0;
    foreach (fixed[i]) sum += fixed[i];
    $display("R:fixedsum=%0d dynsize=%0d", sum, dyn.size());
    $display("R:queue=%0d,%0d,%0d size=%0d", q[0], q[1], q[2], q.size());
    front = q.pop_front(); back = q.pop_back();
    $display("R:pop=%0d,%0d left=%0d", front, back, q.size());
    $display("R:assoc=%0d exists=%0d count=%0d", assoc["b"], assoc.exists("z"), assoc.num());
  end
endmodule
''')

case('strings_formatting', '''
module top;
  string s, t;
  initial begin
    s = "Hello";
    t = {s, ", ", "World"};
    $display("R:len=%0d", t.len());
    $display("R:upper=%s", t.toupper());
    $display("R:sub=%s", t.substr(7, 11));
    $display("R:fmt=%s", $sformatf("%04h|%-4d|%4d", 16'hBEEF >> 4, 12, 34));
    $display("R:cmp=%0d %0d", s == "Hello", s.compare("Help") < 0);
  end
endmodule
''')

case('classes_polymorphism', '''
module top;
  class base;
    int id;
    function new(int i); id = i; endfunction
    virtual function int area(); return 0; endfunction
    function int tag(); return id * 100 + area(); endfunction
  endclass
  class square extends base;
    int side;
    function new(int i, int s); super.new(i); side = s; endfunction
    virtual function int area(); return side * side; endfunction
  endclass
  class rect extends base;
    int w, h;
    function new(int i, int a, int b); super.new(i); w = a; h = b; endfunction
    virtual function int area(); return w * h; endfunction
  endclass
  initial begin
    base list [2];
    square sq = new(1, 4);
    rect rc = new(2, 3, 5);
    list[0] = sq;
    list[1] = rc;
    foreach (list[i]) $display("R:shape%0d tag=%0d", i, list[i].tag());
  end
endmodule
''')

case('case_inside_loops', '''
module top;
  int n, acc;
  function automatic string classify(input int v);
    case (v) inside
      [0:9]: return "digit";
      [10:99]: return "two";
      default: return "big";
    endcase
  endfunction
  initial begin
    $display("R:%s %s %s", classify(5), classify(42), classify(1000));
    acc = 0;
    for (n = 0; n < 20; n++) begin
      if (n == 3) continue;
      if (n == 8) break;
      acc += n;
    end
    $display("R:acc=%0d", acc);
    n = 0; do n += 3; while (n < 10);
    $display("R:dowhile=%0d", n);
    repeat (4) n--;
    $display("R:repeat=%0d", n);
  end
endmodule
''')

case('real_math', '''
module top;
  real r;
  int i;
  initial begin
    r = 2.5;
    i = int'(r * 4.0);
    $display("R:real_to_int=%0d", i);
    $display("R:sqrt=%0d", int'($sqrt(144.0)));
    $display("R:floor=%0d ceil=%0d", int'($floor(3.7)), int'($ceil(3.2)));
    $display("R:pow=%0d", int'($pow(2.0, 10.0)));
    $display("R:rtoi=%0d itor=%0d", $rtoi(9.99), int'($itor(7)));
  end
endmodule
''')

case('assertion_fatal_exit', '''
module top;
  initial begin
    $display("R:before");
    $fatal(1, "intentional");
    $display("R:after");
  end
endmodule
''')
EXPECT_NONZERO = {'assertion_fatal_exit'}

def run(command, cwd):
    return subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, timeout=300)

def results_lines(output):
    return [line for line in output.splitlines() if line.startswith('R:')]

selected = [name for name in CASES if not args.only or name in args.only.split(',')]
records = []
for name in selected:
    directory = work / name
    directory.mkdir(parents=True, exist_ok=True)
    source = directory / (name + '.sv')
    source.write_text(CASES[name].lstrip(), encoding='utf-8')
    xezim = run(['xezim', '--simulate', '--sv2017', '--error-exit', '-s', 'top', str(source)], directory)
    build = run(['verilator', '--binary', '--timing', '-Wno-fatal', '-Wno-lint', '-Wno-style',
                 '--top-module', 'top', '--Mdir', str(directory / 'obj'), str(source)], directory)
    verilator_ok = build.returncode == 0
    verilator_run = run([str(directory / 'obj' / 'Vtop')], directory) if verilator_ok else build
    (directory / 'xezim.log').write_text(xezim.stdout, encoding='utf-8')
    (directory / 'verilator.log').write_text((build.stdout if not verilator_ok else '') + verilator_run.stdout, encoding='utf-8')
    x_lines, v_lines = results_lines(xezim.stdout), results_lines(verilator_run.stdout)
    if name in EXPECT_NONZERO:
        passed = xezim.returncode != 0 and verilator_run.returncode != 0 and x_lines == v_lines == ['R:before']
    else:
        passed = (xezim.returncode == 0 and verilator_ok and verilator_run.returncode == 0
                  and bool(x_lines) and x_lines == v_lines)
    record = dict(case=name, passed=passed, xezimExit=xezim.returncode,
                  verilatorBuilt=verilator_ok, verilatorExit=verilator_run.returncode,
                  lines=len(x_lines))
    if not passed:
        record['xezim'] = x_lines
        record['verilator'] = v_lines
    records.append(record)
    print(('PASS ' if passed else 'DIFF ') + name, flush=True)

summary = dict(recordedAt=datetime.now(timezone.utc).isoformat(), oracle='Verilator',
               cases=records, passed=all(item['passed'] for item in records),
               matched=sum(item['passed'] for item in records), total=len(records))
(work / 'results.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
print(f"Matched {summary['matched']}/{summary['total']} cases; results: {work / 'results.json'}")
sys.exit(0 if summary['passed'] else 1)
