module intel_80286_at_refresh_arbiter_tb;
    logic clk, refresh_req, dma_req, hlda, permit;
    logic hold_req, refresh, refresh_n, dma_hlda, refresh_sel, dma_sel;
    intel_80286_at_refresh_arbiter dut (
        .sys_clk_i(clk), .refresh_request_i(refresh_req), .dma_request_i(dma_req),
        .cpu_hlda_i(hlda), .hold_permit_i(permit), .cpu_hold_o(hold_req),
        .refresh_o(refresh), .refresh_n_o(refresh_n), .dma_hlda_o(dma_hlda),
        .refresh_selected_o(refresh_sel), .dma_selected_o(dma_sel)
    );
    task automatic tick;
        clk=0; #1; clk=1; #1; clk=0; #1;
    endtask
    initial begin
        clk=0; refresh_req=0; dma_req=0; hlda=0; permit=0;
        repeat (3) tick();
        assert(!hold_req && !refresh_sel && !dma_sel && !refresh && refresh_n && !dma_hlda)
            else $fatal(1,"arbiter did not settle idle");

        refresh_req=1; #1; tick();
        assert(refresh_sel && !dma_sel && !hold_req && !refresh)
            else $fatal(1,"inhibited refresh request or selection was lost");
        permit=1; #1;
        assert(hold_req && !refresh && !dma_hlda)
            else $fatal(1,"refresh drove bus before CPU grant");
        hlda=1; #1;
        assert(hold_req && refresh && !refresh_n && !dma_hlda)
            else $fatal(1,"refresh was not granted after HLDA");

        dma_req=1; tick();
        assert(refresh && !dma_hlda && refresh_sel && !dma_sel)
            else $fatal(1,"DMA displaced an active refresh selection");
        refresh_req=0; tick(); tick();
        assert(!refresh && refresh_n && dma_hlda && !refresh_sel && dma_sel && hold_req)
            else $fatal(1,"queued DMA did not receive the existing grant");

        refresh_req=1; tick();
        assert(!refresh && dma_hlda && !refresh_sel && dma_sel)
            else $fatal(1,"refresh displaced an active DMA selection");
        dma_req=0; tick(); tick();
        assert(refresh && !dma_hlda && refresh_sel && !dma_sel && hold_req)
            else $fatal(1,"queued refresh did not receive the existing grant");
        refresh_req=0; #1;
        assert(!hold_req && !refresh && refresh_n && !dma_hlda)
            else $fatal(1,"bus controls did not release after requests fell");
        hlda=0; repeat (2) tick();
        assert(!refresh_sel && !dma_sel) else $fatal(1,"selections did not return idle");
        $display("PASS: AT refresh/DMA arbiter holds CPU request and transfers granted ownership");
        $finish;
    end
endmodule
