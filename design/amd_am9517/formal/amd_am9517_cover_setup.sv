// Cover-only environment: eight real programming sequences keep reachability
// searches small. This file is never included by BMC or safety prove tasks.
`ifdef FORMAL_COVER
    logic [5:0] cover_cycle = 0;
    (* anyconst *) logic [2:0] cover_case;
    logic [1:0] cover_channel;
    logic [7:0] cover_mode;
    always_comb begin
        cover_channel = cover_case < 4 ? cover_case[1:0] : 2'b00;
        cover_mode = {4'b1000, 2'b10, cover_channel};
        if (cover_case == 4) cover_mode = 8'h80;
        if (cover_case == 5) cover_mode = 8'hc0;
        if (cover_case == 6) cover_mode = 8'h98;
    end
    always_ff @(posedge clk) begin
        if (cover_cycle < 63) cover_cycle <= cover_cycle + 1'b1;
        assume(rst_n == (cover_cycle != 0));
        assume(eop_n);
        assume(hlda == hrq);
        // Cover wait states, then permit progress; verify holds READY low.
        assume(ready == (cover_case != 4 && cover_cycle >= 12));
        if (cover_cycle >= 1 && cover_cycle <= 4) begin
            assume(!cs_n && ior_n && !iow_n);
            case (cover_cycle)
                1: begin assume(reg_addr == 11); assume(data_i == cover_mode); end
                2: begin assume(reg_addr == 11); assume(data_i == 8'h85); end
                3: begin assume(reg_addr == 8); assume(data_i == (cover_case == 7 ? 8'h01 : 8'h00)); end
                4: begin assume(reg_addr == (cover_case == 7 ? 9 : 15)); assume(data_i == (cover_case == 7 ? 4 : 0)); end
                default: begin end
            endcase
            assume(dreq == 0);
        end else begin
            assume(cs_n && ior_n && iow_n);
            assume(dreq == (cover_cycle >= 5 ? (4'b0001 << cover_channel) : 0));
        end
    end
`endif
