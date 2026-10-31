// Included in the transaction engine. The pure checker's semantics have a
// separate unconstrained proof against pinned external-artifact type lists.
`ifdef FORMAL
    logic past_valid=0;
    logic [3:0] reads_seen, writes_seen;
    logic [47:0] captured;
    logic saw_stall, saw_busy_start;
    always_ff @(posedge clk) begin
        past_valid<=1;
        if (!past_valid) assume(!rst_n);
        if (!rst_n) begin
            reads_seen<=0; writes_seen<=0; captured<=0;
            saw_stall<=0; saw_busy_start<=0;
        end else begin
            if (state==IDLE && start_i) begin
                reads_seen<=0; writes_seen<=0; captured<=0;
                saw_stall<=0; saw_busy_start<=0;
            end
            if (bus_req_o && !bus_ready_i) saw_stall<=1;
            if (busy_o && start_i) saw_busy_start<=1;
            if (bus_req_o && bus_ready_i && !bus_write_o) begin
                if (reads_seen<6) captured[reads_seen*8 +: 8]<=bus_rdata_i;
                reads_seen<=reads_seen+4'd1;
            end
            if (bus_req_o && bus_ready_i && bus_write_o) writes_seen<=writes_seen+4'd1;
        end
        if (past_valid) begin
            assert(state<=WRITE_ACCESSED);
            assert(descriptor==captured);
            assert(reads_seen<=8 && writes_seen<=1);
            if (busy_o) assert(writes_seen==0);
            if (!rst_n) assert(!bus_req_o);
            if (state==READ_DESCRIPTOR) begin
                assert(check_needed && byte_index==reads_seen && reads_seen<8);
                assert(!done_o);
            end
            if (state==VALIDATE || state==WRITE_ACCESSED) begin
                assert(check_needed && check_done && reads_seen==8 && writes_seen==0);
            end
            if (state==WRITE_ACCESSED) begin
                assert(check_valid && !check_fault);
                assert(bus_wdata_o==(captured[47:40]|8'h01));
            end
            if (state==READ_DESCRIPTOR || state==VALIDATE || state==WRITE_ACCESSED)
                assert(descriptor_address==(saved_table_base+{8'h0,check_offset}));
            if (!$past(rst_n)) begin
                assert(!busy_o && !done_o && !fault_o && !cache_valid_o);
                assert(selector_o==0 && base_o==0 && limit_o==0 && access_o==0);
            end
            if (rst_n && $past(rst_n && state==IDLE && start_i)) begin
                assert(saved_selector==$past(selector_i) && saved_cpl==$past(cpl_i));
                assert(saved_stack==$past(stack_i) && saved_ldt_valid==$past(ldt_valid_i));
                assert(saved_table_base==($past(selector_i[2]) ? $past(ldt_base_i) : $past(gdt_base_i)));
                assert(saved_table_limit==($past(selector_i[2]) ? $past(ldt_limit_i) : $past(gdt_limit_i)));
            end
            if (rst_n && $past(rst_n && busy_o)) begin
                assert($stable(saved_selector) && $stable(saved_cpl) && $stable(saved_stack));
                assert($stable(saved_table_base) && $stable(saved_table_limit) && $stable(saved_ldt_valid));
            end
            if (rst_n && $past(rst_n && bus_req_o && !bus_ready_i)) begin
                assert(bus_req_o && $stable(bus_addr_o) && $stable(bus_write_o));
                if (bus_write_o) assert($stable(bus_wdata_o));
                assert(!done_o);
            end
            if (rst_n && $past(rst_n) && !done_o) begin
                assert($stable(selector_o) && $stable(base_o) && $stable(limit_o) && $stable(access_o));
                assert($stable(cache_valid_o) && $stable(fault_o));
                assert($stable(fault_vector_o) && $stable(fault_error_o));
            end
            if (done_o) begin
                assert(!busy_o && $past(rst_n));
                assert($past((state==PRECHECK && check_done) || (state==VALIDATE && check_fault) ||
                             (state==WRITE_ACCESSED && bus_ready_i)));
                assert(selector_o==$past(saved_selector));
                assert(fault_o==$past(check_fault) && cache_valid_o==$past(check_valid));
                assert(fault_vector_o==$past(check_vector) && fault_error_o==$past(check_error));
                assert(base_o==$past(check_base) && limit_o==$past(check_limit) && access_o==$past(check_access));
                if (cache_valid_o) assert(reads_seen==8 && writes_seen==1 && !fault_o);
                else assert(writes_seen==0);
            end
            cover(done_o && cache_valid_o && saw_stall && saw_busy_start);
            cover(done_o && fault_o && reads_seen==0);
            cover(done_o && fault_o && fault_vector_o==11 && reads_seen==8);
            cover(done_o && !fault_o && !cache_valid_o && reads_seen==0);
            cover(!rst_n && state==WRITE_ACCESSED);
            cover(!rst_n && state==READ_DESCRIPTOR && reads_seen==3);
        end
    end
`endif
