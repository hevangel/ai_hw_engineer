    logic bus_owner_past_valid=0;
    always_ff @(posedge clk) begin
        bus_owner_past_valid<=1;
        if (!bus_owner_past_valid) assume(!rst_n);
        if (rst_n) begin
            assert(owner<=EVENT);
            assert(!inflight || held_req);
            assert(cpu_grant_o || descriptor_grant_o || event_grant_o);
            assert(!(cpu_grant_o && descriptor_grant_o));
            assert(!(cpu_grant_o && event_grant_o));
            assert(!(descriptor_grant_o && event_grant_o));
            assert(cpu_ready_o==(rst_n && cpu_grant_o && bus_req_o && bus_ready_i));
            assert(descriptor_ready_o==(rst_n && descriptor_grant_o && bus_req_o && bus_ready_i));
            assert(event_ready_o==(rst_n && event_grant_o && bus_req_o && bus_ready_i));
        end
        if (bus_owner_past_valid) begin
            if (rst_n && $past(rst_n && bus_req_o && !bus_ready_i)) begin
                assert(bus_req_o && owner==$past(owner));
                assert($stable(bus_addr_o) && $stable(bus_write_o) && $stable(bus_wdata_o));
                assert($stable(bus_context_o));
            end
            if ($past(rst_n && owner==CPU && bus_req_o &&
                      (event_claim_i || descriptor_claim_i))) assert(owner==CPU);
            if ($past(rst_n && owner==CPU && !bus_req_o && event_claim_i)) assert(owner==EVENT);
            if ($past(rst_n && owner==CPU && !bus_req_o && !event_claim_i && descriptor_claim_i))
                assert(owner==DESCRIPTOR);
            if ($past(rst_n && owner==DESCRIPTOR && descriptor_release_i &&
                      bus_req_o && !bus_ready_i)) assert(owner==DESCRIPTOR);
            if ($past(rst_n && owner==EVENT && event_release_i && bus_req_o && !bus_ready_i))
                assert(owner==EVENT);
            if (!$past(rst_n)) assert(owner==CPU);

            cover(owner==DESCRIPTOR && descriptor_ready_o);
            cover(owner==EVENT && event_ready_o);
            cover(cpu_grant_o && cpu_req_i && descriptor_claim_i && !descriptor_grant_o);
        end
    end
