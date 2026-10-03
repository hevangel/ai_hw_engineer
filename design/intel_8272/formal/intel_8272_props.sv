    logic past_valid=0;
    always_ff @(posedge clk) begin
        past_valid<=1;
        if (rst_n) begin
            assert(command_index<=9);
            assert(result_length>=1 && result_length<=7);
            assert(result_index<result_length);
            assert(format_index<=3);
            // These two stronger bounds also imply byte_count <= 8192.
            assert(sector_size<=8192);
            assert(byte_count<=sector_size);
            assert(!(drq && nd));
            assert(!drq || (data_pending && !dma_token));
            if (phase==RESULT) begin
                assert(!data_pending);
                if (result_length==7) begin
                    assert((result[1]&8'h48)==0);
                    assert(!result[2][7]);
                end
            end
            for (integer f=0;f<4;f=f+1) assert(recal_steps[f]<=77);
            if (past_valid && $past(rst_n && phase==RESULT &&
                !(cpu_read && a0 && rqm))) assert(result_index==$past(result_index));
        end
`ifdef FORMAL_COVER
`ifdef COVER_READ
        cover(rst_n && phase==RESULT && result_length==1);
        cover(rst_n && phase==SEARCH);
        cover(rst_n && drq);
        cover(rst_n && phase==RESULT && result_length==7);
`endif
`ifdef COVER_WRITE
        cover(rst_n && phase==WRITE_DATA);
`endif
`ifdef COVER_ND
        cover(rst_n && nd && data_pending);
`endif
`ifdef COVER_SEEK
        cover(rst_n && step!=0);
        cover(rst_n && sis_event && phase==RESULT);
`endif
`endif
    end
