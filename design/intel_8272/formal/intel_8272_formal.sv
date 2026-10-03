module intel_8272_formal;
    (* gclk *) logic clk;
    `ifndef FORMAL_COVER
    (* anyseq *)
`endif
    logic rst_n, us_tick;
    `ifndef FORMAL_COVER
    (* anyseq *)
`endif
    logic cs_n, rd_n, wr_n, dack_n, a0, tc;
    `ifndef FORMAL_COVER
    (* anyseq *)
`endif
    logic [7:0] db_in;
    logic [7:0] db_out;
    logic db_oe, irq, drq;
    `ifndef FORMAL_COVER
    (* anyseq *)
`endif
    logic [3:0] ready, write_protect, track0, two_sided, fault;
    logic [3:0] step, direction;
    logic [1:0] unit;
    logic head, mfm, head_load, media_active, media_write, media_format;
    `ifndef FORMAL_COVER
    (* anyseq *)
`endif
    logic index_pulse, header_valid;
    `ifndef FORMAL_COVER
    (* anyseq *)
`endif
    logic [7:0] header_c, header_h, header_r, header_n;
    `ifndef FORMAL_COVER
    (* anyseq *)
`endif
    logic header_deleted, header_missing_data, header_crc_error;
    `ifndef FORMAL_COVER
    (* anyseq *)
`endif
    logic media_byte_valid;
    `ifndef FORMAL_COVER
    (* anyseq *)
`endif
    logic [7:0] media_byte;
    `ifndef FORMAL_COVER
    (* anyseq *)
`endif
    logic media_end, media_crc_error, write_slot;
    logic sector_begin, sector_end, tx_valid;
    logic [7:0] tx_byte, sector_c, sector_h, sector_r, sector_n;
    logic sector_deleted;
    intel_8272 #(.RQM_DELAY_US(1),.MS_US(1)) dut (.*);
    logic initial_cycle=1;
    always_ff @(posedge clk) begin
        if (initial_cycle) assume(!rst_n);
        initial_cycle<=0;
    end
`ifdef FORMAL_COVER
    localparam logic [1:0] scenario=2'(`FORMAL_SCENARIO);
    logic [6:0] cycle=0;
    always_ff @(posedge clk) if(cycle!=127) cycle<=cycle+1;
    always_comb begin
        rst_n=cycle!=0; us_tick=1; cs_n=1; rd_n=1; wr_n=1; dack_n=1;
        a0=0; tc=0; db_in=0; ready=1; write_protect=0; track0=0;
        two_sided=0; fault=0; index_pulse=0; header_valid=0;
        header_c=3; header_h=0; header_r=1; header_n=0;
        header_deleted=0; header_missing_data=0; header_crc_error=0;
        media_byte_valid=0; media_byte=8'h5a; media_end=0; media_crc_error=0; write_slot=0;
        // Independent legal prefixes: DMA read, DMA write, seek/SIS, ND read.
        case(scenario)
            0,1: begin
                case(cycle)
                    2: begin cs_n=0; a0=1; wr_n=0; db_in=8'hff; end
                    5: begin cs_n=0; a0=1; rd_n=0; end
                    10: begin cs_n=0; a0=1; wr_n=0; db_in=scenario==0 ? 8'h46 : 8'h45; end
                    14,22,30,42: begin cs_n=0; a0=1; wr_n=0; db_in=0; end
                    18: begin cs_n=0; a0=1; wr_n=0; db_in=3; end
                    26,34: begin cs_n=0; a0=1; wr_n=0; db_in=1; end
                    38: begin cs_n=0; a0=1; wr_n=0; db_in=8'h1b; end
                    47: header_valid=1;
                    49: if(scenario==0) media_byte_valid=1;
                    51: begin dack_n=0; tc=1; if(scenario==0) rd_n=0; else wr_n=0; end
                    53: if(scenario==0) media_end=1; else write_slot=1;
                endcase
            end
            2: begin
                case(cycle)
                    2: begin cs_n=0; a0=1; wr_n=0; db_in=8'h0f; end
                    6: begin cs_n=0; a0=1; wr_n=0; db_in=0; end
                    10: begin cs_n=0; a0=1; wr_n=0; db_in=1; end
                    35: begin cs_n=0; a0=1; wr_n=0; db_in=8'h08; end
                    40,44: begin cs_n=0; a0=1; rd_n=0; end
                endcase
            end
            3: begin
                case(cycle)
                    2: begin cs_n=0; a0=1; wr_n=0; db_in=8'h03; end
                    6: begin cs_n=0; a0=1; wr_n=0; db_in=8'hf1; end
                    10: begin cs_n=0; a0=1; wr_n=0; db_in=1; end
                    14: begin cs_n=0; a0=1; wr_n=0; db_in=8'h46; end
                    18,26,34,46: begin cs_n=0; a0=1; wr_n=0; db_in=0; end
                    22: begin cs_n=0; a0=1; wr_n=0; db_in=3; end
                    30,38: begin cs_n=0; a0=1; wr_n=0; db_in=1; end
                    42: begin cs_n=0; a0=1; wr_n=0; db_in=8'h1b; end
                    51: header_valid=1;
                    53: media_byte_valid=1;
                    55: begin cs_n=0; a0=1; rd_n=0; tc=1; end
                    57: media_end=1;
                endcase
            end
        endcase
    end
`endif
endmodule
