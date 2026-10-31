    logic pedc_past_valid=0;
    always_ff @(posedge clk) begin
        pedc_past_valid<=1;
        if (!pedc_past_valid) assume(!rst_n);
        if (rst_n) begin
            assert(state<=THIRD);
            assert(request_o==(state==FIRST || state==SECOND || state==THIRD));
            assert(peack_n_o==!(state==FIRST && grant_i));
            if (request_o && io_o) begin
                assert(address_o==24'h0000fa && bytes_o==2);
                assert(write_o==!to_memory);
            end
            if (request_o && !io_o) assert(write_o==to_memory);
        end
        if (pedc_past_valid) begin
            if (!$past(rst_n)) assert(state==IDLE && !transfer_o && !done_o);
            if (rst_n && $past(rst_n && request_o && !(grant_i && ready_i))) begin
                assert(request_o && state==$past(state));
                assert($stable(address_o) && $stable(bytes_o) && $stable(io_o));
                assert($stable(write_o) && $stable(wdata_o));
            end
            cover(rst_n && state==THIRD && !to_memory && grant_i && ready_i);
            cover(rst_n && state==THIRD && to_memory && grant_i && ready_i);
            cover(rst_n && transfer_o && !done_o);
            cover(rst_n && done_o && !transfer_o);
        end
    end
