from pathlib import Path
p = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\work\probe\tb_refresh_measure.sv')
t = p.read_text()
old = """    time last [0:127];
    time worst = 0;"""
new = """    time last [0:127];
    time row_worst [0:127];
    int row_hits [0:127];
    time worst = 0;"""
assert t.count(old) == 1
t = t.replace(old, new)

old2 = """    initial for (int i = 0; i < 128; i++) last[i] = 0;"""
new2 = """    initial for (int i = 0; i < 128; i++) begin last[i] = 0; row_worst[i] = 0; row_hits[i] = 0; end"""
assert t.count(old2) == 1
t = t.replace(old2, new2)

old3 = """            if (gap > worst) begin worst = gap; row_at_worst = r; end"""
new3 = """            if (gap > worst) begin worst = gap; row_at_worst = r; end
            if (gap > row_worst[r]) row_worst[r] = gap;"""
assert t.count(old3) == 1
t = t.replace(old3, new3)

old4 = """        last[r] = $time;
        accesses++;"""
new4 = """        last[r] = $time;
        row_hits[r]++;
        accesses++;"""
assert t.count(old4) == 1
t = t.replace(old4, new4)

old5 = """        $display("accesses=%0d distinct_rows=%0d worst_gap_ns=%0d row=%0d",
                 accesses, seen, worst, row_at_worst);"""
new5 = """        $display("accesses=%0d distinct_rows=%0d worst_gap_ns=%0d row=%0d",
                 accesses, seen, worst, row_at_worst);
        for (int i = 0; i < 128; i++)
            if (row_worst[i] > 1000000)
                $display("row %0d hits=%0d worst_gap_ns=%0d", i, row_hits[i], row_worst[i]);"""
assert t.count(old5) == 1
t = t.replace(old5, new5)
p.write_text(t, newline='\r\n')
print('per-row stats added')
