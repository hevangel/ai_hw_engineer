// ASSUMPTION: the OSCILLATOR pin is driven by an external digital clock (the
// source allows an external clock); the KBM RC debounce mask is analog and
// outside the contract, normalized to DEBOUNCE_CYCLES consecutive column
// visits (0 models the omitted-capacitor defeat). Scan order X1..X4 ascending
// and the rising-clock tick are not stated by the source. DATA AVAILABLE
// powers up low; the last-key register powers up unspecified. Simultaneous
// keys on one column detect the lowest-numbered row.
module ttl_74x922 #(
    parameter int DEBOUNCE_CYCLES = 2  // consecutive column visits to accept
) (
    input  logic       osc,         // OSCILLATOR pin 5, external clock
    input  logic [3:0] row,         // matrix rows Y1-Y4 (pins 4-1), pull-ups external
    output logic [3:0] col_n,       // matrix columns X1-X4, active low
    input  logic       oe_n,        // output enable, pin 13, active low
    output logic [3:0] data,        // DATA OUT D,C,B,A (pins 14-17)
    output logic       data_drive,
    output logic       da           // DATA AVAILABLE, pin 12
);
    logic [1:0]  scan;                   // column being driven: 0=X1..3=X4
    logic [3:0]  keyreg;                 // last-key register, unspecified at power-up
    logic        da_q;
    logic        entered_held;
    logic [1:0]  entered_row;
    logic [1:0]  entered_col;
    logic        cand_active;
    logic        cand_confirmed;
    logic [1:0]  cand_row;
    logic [1:0]  cand_col;
    logic [31:0] cand_count;
    initial begin                  // defined control start; no reset pin exists
        scan           = 2'd0;
        da_q           = 1'b0;
        entered_held   = 1'b0;
        entered_row    = 2'd0;
        entered_col    = 2'd0;
        cand_active    = 1'b0;
        cand_confirmed = 1'b0;
        cand_row       = 2'd0;
        cand_col       = 2'd0;
        cand_count     = 32'd0;
    end


    // Detection for the cycle ending at the coming edge: col_n still shows
    // `scan`, so a key is detected when its row is low while its column is
    // the driven one. Lowest-numbered low row wins.
    logic        det_found;
    logic [1:0]  det_row;
    always_comb begin
        det_found = 1'b0;
        det_row   = 2'd0;
        for (int r = 3; r >= 0; r--) begin
            if (!row[r]) begin
                det_found = 1'b1;
                det_row   = 2'(r);
            end
        end
    end

    /* verilator lint_off MULTIDRIVEN */
    always_ff @(posedge osc) begin
        // Entered-key hold tracking at its column visits.
        if (da_q && scan == entered_col) begin
            if (det_found && det_row == entered_row) begin
                entered_held <= 1'b1;
            end else begin
                entered_held <= 1'b0;
                da_q         <= 1'b0;
            end
        end

        // Debounce: the candidate must be detected on DEBOUNCE_CYCLES
        // consecutive visits of its column; visits of other columns retain it.
        if (det_found) begin
            if (cand_active && det_row == cand_row && scan == cand_col) begin
                cand_count <= cand_count + 32'd1;
                if (cand_count + 32'd1 >= 32'(DEBOUNCE_CYCLES)) begin
                    cand_confirmed <= 1'b1;
                end
            end else begin
                cand_active    <= 1'b1;
                cand_row       <= det_row;
                cand_col       <= scan;
                cand_count     <= 32'd1;
                cand_confirmed <= (32'd1 >= 32'(DEBOUNCE_CYCLES));
            end
        end else if (cand_active && scan == cand_col) begin
            // Candidate's column visited with its row released: stale.
            cand_active    <= 1'b0;
            cand_confirmed <= 1'b0;
            cand_count     <= 32'd0;
        end

        // Acceptance: needs a debounced key and either no current entry or an
        // entered key that has been released (two-key rollover).
        if (cand_confirmed && (!da_q || !entered_held)) begin
            keyreg         <= {cand_row[1], cand_row[0], cand_col[1], cand_col[0]};
            entered_row    <= cand_row;
            entered_col    <= cand_col;
            entered_held   <= 1'b1;
            da_q           <= 1'b1;
            cand_active    <= 1'b0;
            cand_confirmed <= 1'b0;
            cand_count     <= 32'd0;
        end

        scan <= scan + 2'd1;
    end
    /* verilator lint_on MULTIDRIVEN */

    assign col_n       = ~(4'b0001 << scan);
    assign data_drive  = !oe_n;
    assign data        = data_drive ? keyreg : 4'b0000;
    assign da          = da_q;
endmodule
