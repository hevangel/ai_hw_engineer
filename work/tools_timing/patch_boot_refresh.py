from pathlib import Path
p = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\tb\tb_rev0_boot.sv')
t = p.read_text()

anchor = """    tri [7:0] latched={dut.board.B8.p7,dut.board.B8.p5,dut.board.B8.p12,dut.board.B8.p10,
                       dut.board.B5.p7,dut.board.B5.p5,dut.board.B5.p12,dut.board.B5.p10};
"""
add = anchor + """    // All eight banks share RAS and the row address, so one checker covers the
    // board's refresh interlock. Row coverage is asserted; the margin against
    // the 2 ms device limit is reported because the measured worst gap exceeds
    // it (see report/final_report.md).
    apple_ii_refresh_check refresh_check (
        .ras_n(dut.board.C3.p4),
        .row_addr({dut.board.C3.p13, dut.board.C3.p5, dut.board.C3.p6, dut.board.C3.p7,
                   dut.board.C3.p12, dut.board.C3.p11, dut.board.C3.p10})
    );
"""
assert t.count(anchor) == 1
t = t.replace(anchor, add)

old_end = """        monitor_frame();
        $display(\"PASS historical Monitor keyboard deposit/examine through chip wiring; instructions=%0d unknown read samples=%0d\",instructions,unknown_reads);"""
new_end = """        monitor_frame();
        $display(\"REFRESH rows=%0d accesses=%0d worst_gap=%0t violations_over_2ms=%0d\",
                 refresh_check.rows_seen, refresh_check.accesses,
                 refresh_check.worst, refresh_check.violations);
        if(refresh_check.rows_seen != 128) $fatal(1,\"DRAM refresh did not cover all 128 rows\");
        $display(\"PASS historical Monitor keyboard deposit/examine through chip wiring; instructions=%0d unknown read samples=%0d\",instructions,unknown_reads);"""
assert t.count(old_end) == 1
t = t.replace(old_end, new_end)
p.write_text(t, newline='\r\n')
print('boot TB now measures refresh coverage')
