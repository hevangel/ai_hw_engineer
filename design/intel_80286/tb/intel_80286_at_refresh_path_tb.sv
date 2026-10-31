module intel_80286_at_refresh_path_tb;
    logic reset_n, sys_clk, dma_clk_n, timer_out1, dma_request, hlda, permit, ready;
    logic hold_req, refresh, refresh_n, dma_hlda, detect, request, latched;
    logic refresh_sel, dma_sel, row_oe, memr_n, memr_oe;
    logic [7:0] row;
    logic [3:0] chain;
    logic expected_detect;
    intel_80286_at_refresh_path dut (
        .reset_n_i(reset_n), .sys_clk_i(sys_clk), .dma_clk_n_i(dma_clk_n),
        .timer_out1_i(timer_out1), .dma_request_i(dma_request), .cpu_hlda_i(hlda),
        .hold_permit_i(permit), .io_ready_i(ready), .cpu_hold_o(hold_req),
        .refresh_o(refresh), .refresh_n_o(refresh_n), .dma_hlda_o(dma_hlda),
        .detect_o(detect), .request_o(request), .timer_latched_o(latched),
        .refresh_selected_o(refresh_sel), .dma_selected_o(dma_sel), .clear_chain_o(chain),
        .refresh_row_o(row), .refresh_row_oe_o(row_oe),
        .refresh_memr_n_o(memr_n), .refresh_memr_oe_o(memr_oe)
    );
    task automatic sys_tick;
        sys_clk=0; #1; sys_clk=1; #1; sys_clk=0; #1;
    endtask
    task automatic dma_tick;
        dma_clk_n=0; #1; dma_clk_n=1; #1; dma_clk_n=0; #1;
    endtask
    initial begin
        reset_n=1; sys_clk=0; dma_clk_n=0; timer_out1=0;
        dma_request=0; hlda=0; permit=1; ready=0;
        #1 reset_n=0; #1; reset_n=1;
        repeat (3) sys_tick();
        assert(chain==4'b1000 && !request && !hold_req && !refresh && !dma_hlda && !dma_sel)
            else $fatal(1,"refresh path failed to settle idle");
        // The board does not reset U118: verify transitions relative to its
        // observed startup state, without asserting a physical initial value.
        expected_detect=detect;
        for (int cycle=0;cycle<2;cycle++) begin
            timer_out1=1; #1; timer_out1=0; #1;
            assert(latched && !request && !refresh) else $fatal(1,"timer capture failed");
            dma_tick();
            assert(request && hold_req && !refresh && detect===expected_detect)
                else $fatal(1,"request did not wait for CPU HLDA");
            sys_tick();
            assert(refresh_sel && !refresh && !dma_hlda)
                else $fatal(1,"refresh selector did not wait for HLDA");
            hlda=1; #1; expected_detect=!expected_detect;
            assert(refresh && !refresh_n && detect===expected_detect && !dma_hlda)
                else $fatal(1,"grant did not trigger the refresh-signal/detect edge");
            repeat (4) sys_tick();
            assert(refresh && request && detect===expected_detect && chain==4'b1011 &&
                   row_oe && memr_oe && !memr_n && row==8'(cycle))
                else $fatal(1,"IOCHRDY stall did not hold refresh and detection");
            ready=1; sys_tick(); sys_tick();
            assert(!request && !latched && !hold_req && !refresh && refresh_n &&
                   detect===expected_detect)
                else $fatal(1,"completed refresh did not clear request exactly once");
            hlda=0; ready=0;
            repeat (4) sys_tick();
            assert(chain==4'b1000 && !refresh_sel && !dma_sel)
                else $fatal(1,"refresh path did not return to idle");
        end
        $display("PASS: AT timer request to HLDA-gated refresh and detect, including READY stalls");
        $finish;
    end
endmodule
