`timescale 1ns/1ps
// Refresh checker for a bank of 4116 DRAMs.
//
// Every RAS falling edge refreshes (and reads or writes) one row. The checker
// records the gap between successive accesses to the same row, so the board's
// video-refresh interlock becomes a measured property instead of the model's
// "ideal retention" assumption. All eight banks share RAS and the row address,
// so one instance covers the motherboard.
//
// `rows_seen` proves non-vacuity: a run that never touches all rows cannot
// claim a refresh result. `worst_gap` and `violations` report the margin against
// `LIMIT_NS`, which defaults to the 4116 requirement of 128 refreshes per 2 ms.
module apple_ii_refresh_check #(
    parameter integer ROWS = 128,
    parameter time LIMIT_NS = 2000000,
    parameter bit TRACE = 1'b0
) (
    input wire ras_n,
    input wire [6:0] row_addr
);
    time last [0:ROWS-1];
    time worst = 0;
    time gap;
    int worst_row = -1;
    int violations = 0;
    int rows_seen = 0;
    int accesses = 0;
    int r;

    initial for (int i = 0; i < ROWS; i++) last[i] = 0;

    always @(negedge ras_n) begin
        r = row_addr;
        if (last[r] != 0) begin
            gap = $time - last[r];
            if (gap > worst) begin
                worst = gap;
                worst_row = r;
            end
            if (gap > LIMIT_NS) begin
                violations++;
                if (TRACE) $display("refresh violation: row %0d gap %0t", r, gap);
            end
        end else begin
            rows_seen++;
        end
        last[r] = $time;
        accesses++;
    end
endmodule
