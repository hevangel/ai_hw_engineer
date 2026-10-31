module intel_80286_at_refresh_request_tb;
    logic reset_n, timer_out1, dma_clk_n, sys_clk, refresh_n, io_ready;
    logic timer_latched, request;
    logic [3:0] chain;
    intel_80286_at_refresh_request dut (
        .reset_n_i(reset_n), .timer_out1_i(timer_out1), .dma_clk_n_i(dma_clk_n),
        .sys_clk_i(sys_clk), .refresh_n_i(refresh_n), .io_ready_i(io_ready),
        .timer_latched_o(timer_latched), .refresh_request_o(request),
        .clear_chain_o(chain)
    );
    task automatic sys_tick;
        sys_clk=0; #1; sys_clk=1; #1; sys_clk=0; #1;
    endtask
    task automatic dma_tick;
        dma_clk_n=0; #1; dma_clk_n=1; #1; dma_clk_n=0; #1;
    endtask
    initial begin
        reset_n=1; timer_out1=0; dma_clk_n=0; sys_clk=0;
        refresh_n=1; io_ready=0;
        #1 reset_n=0;
        #1 assert(chain==0 && !timer_latched && !request)
            else $fatal(1,"reset did not clear request chain");
        timer_out1=1; #1;
        dma_tick();
        assert(!timer_latched && !request)
            else $fatal(1,"clock captured a request while U68 clear was asserted");
        reset_n=1;
        sys_tick();
        assert(chain==4'b1000 && !timer_latched && !request)
            else $fatal(1,"releasing clear fabricated a request");
        timer_out1=0; #1;

        timer_out1=1; #1;
        assert(timer_latched && !request) else $fatal(1,"timer edge was not captured independently");
        timer_out1=0; #1;
        assert(timer_latched && !request) else $fatal(1,"timer falling edge lost the request");
        dma_tick();
        assert(request) else $fatal(1,"DMA clock did not sample timer request");
        refresh_n=0;
        sys_tick();
        assert(chain==4'b1001 && request) else $fatal(1,"refresh did not enter U95 stage 1");
        sys_tick();
        assert(chain==4'b1011 && request) else $fatal(1,"refresh did not enter U95 stage 2");
        repeat (4) begin
            sys_tick();
            assert(chain==4'b1011 && request) else $fatal(1,"READY stall dropped or advanced request");
        end
        io_ready=1;
        sys_tick();
        assert(chain==4'b1111 && request) else $fatal(1,"READY did not advance stage 3");
        sys_tick();
        assert(!chain[3] && !timer_latched && !request)
            else $fatal(1,"stage 4 did not asynchronously clear U68");
        refresh_n=1;
        repeat (4) sys_tick();
        assert(chain==4'b1000 && !request) else $fatal(1,"chain did not return to idle");

        timer_out1=1; #1; timer_out1=0; #1;
        dma_tick();
        assert(request) else $fatal(1,"second request was not captured");
        reset_n=0; #1;
        assert(chain==0 && !timer_latched && !request)
            else $fatal(1,"asynchronous reset did not clear active request");
        $display("PASS: AT U68/U95 timer request, READY stalls, clear pulse and reset");
        $finish;
    end
endmodule
