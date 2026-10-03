module intel_8275_formal;
    (* gclk *) logic clk;
`ifdef FORMAL_COVER
    logic rst_n, cclk_en, cs_n, rd_n, wr_n, a0, dack_n, lpen;
    logic [7:0] db_in;
`else
    (* anyseq *) logic rst_n, cclk_en, cs_n, rd_n, wr_n, a0, dack_n, lpen;
    (* anyseq *) logic [7:0] db_in;
`endif
    logic [7:0] db_out;
    logic db_oe, drq, irq;
    logic [6:0] cc;
    logic [3:0] lc;
    logic [1:0] la, gpa;
    logic hrtc, vrtc, vsp, lten, rvv, hlgt;
    intel_8275 #(.MAX_COLS(4)) dut(.*);
`ifdef FORMAL_COVER
    logic [7:0] cycle = 0;
    logic [2:0] byte_index = 0;
    (* anyconst *) logic miss_dma;
    always_ff @(posedge clk) begin
        if (cycle != 255) cycle<=cycle+1;
        if (!dack_n) byte_index<=byte_index+1;
    end
    always_comb begin
        rst_n = cycle != 0;
        cclk_en = cycle >= 12;
        rd_n = 1;
        lpen = cycle == 30;
        cs_n = !(cycle == 2 || cycle == 4 || cycle == 6 || cycle == 8 ||
                 cycle == 10 || cycle == 12 || cycle == 14 || cycle == 16 || cycle == 18);
        wr_n = cs_n;
        a0 = cycle == 2 || cycle == 12 || cycle == 14;
        dack_n = !(drq && !miss_dma && cycle[0]);
        case (cycle)
            2: db_in=0;
            4: db_in=3;
            6: db_in=1;
            8: db_in=8'h11;
            10: db_in=0;
            12: db_in=8'h23;
            14: db_in=8'h80;
            16,18: db_in=0;
            default: case (byte_index)
                0: db_in=8'h80;
                1: db_in=8'h41;
                2: db_in=8'hc0;
                default: db_in=8'h42;
            endcase
        endcase
    end
`endif
endmodule
