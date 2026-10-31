from pathlib import Path
p = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\work\probe\tb_refresh_measure.sv')
t = p.read_text()
old = """    always @(negedge ras_n) begin
        automatic time now = $time;
        automatic int r = row_addr;
        if (last[r] != 0) begin
            automatic time gap = now - last[r];
            if (gap > worst) begin worst = gap; row_at_worst = r; end
        end else begin
            seen++;
        end
        last[r] = now;
        accesses++;
    end
"""
new = """    time gap;
    int r;
    always @(negedge ras_n) begin
        r = row_addr;
        if (last[r] != 0) begin
            gap = $time - last[r];
            if (gap > worst) begin worst = gap; row_at_worst = r; end
        end else begin
            seen++;
        end
        last[r] = $time;
        accesses++;
    end
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), newline='\r\n')
print('probe fixed for Icarus')
