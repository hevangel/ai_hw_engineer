`ifdef FORMAL
    logic md_past_valid=0;
    logic [15:0] md_saved_ax,md_saved_dx,md_saved_flags,md_saved_divisor;
    logic [1:0] md_saved_operation;
    logic md_saved_wide;
    always_ff @(posedge clk) begin
        md_past_valid<=1;
        if (!md_past_valid) assume(!rst_n);
        if (start_i && !busy) begin
            md_saved_ax<=ax_i; md_saved_dx<=dx_i; md_saved_flags<=flags_i;
            md_saved_operation<=operation_i; md_saved_wide<=wide_i; md_saved_divisor<=divisor;
        end
        if (md_past_valid) begin
            if (!$past(rst_n)) assert(!busy && !done_o && !fault_o);
            if (busy) begin
                assert(md_saved_operation[1] && md_saved_wide==wide);
                assert(ax_o==md_saved_ax && dx_o==md_saved_dx && flags_o==md_saved_flags);
                assert(bits_left>=1 && bits_left<=32);
                assert(denominator!=0 && remainder<denominator);
                if (!wide) assert(bits_left<=16);
            end
            if (rst_n && $past(rst_n && busy)) begin
                if ($past(bits_left)==1) assert(done_o && !busy);
                else assert(busy && bits_left==$past(bits_left)-6'd1);
            end
            if (done_o && $past(rst_n)) begin
                assert(!busy);
                if (fault_o) assert(ax_o==md_saved_ax && dx_o==md_saved_dx && flags_o==md_saved_flags);
                if (md_saved_operation[1]) assert(flags_o==md_saved_flags);
                else begin
                    assert(flags_o[0]==flags_o[11]);
                    assert(((flags_o^md_saved_flags)&16'hf7fe)==0);
                end
                if (!md_saved_wide) assert(dx_o==md_saved_dx);
            end
            cover(done_o && !md_saved_operation[1] && flags_o[0]);
            cover(done_o && md_saved_operation[1] && md_saved_wide && !fault_o);
            cover(done_o && fault_o && md_saved_divisor!=0);
            cover(busy && !rst_n);
        end
    end
`endif
