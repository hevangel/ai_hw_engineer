module intel_80286_at_port61_tb;
    logic clk, reset_n, req, ready, write, refresh, timer2, iochck, pck;
    logic selected, valid;
    logic [15:0] addr;
    logic [3:0] wdata;
    logic [7:0] rdata;
    logic [3:0] control;
    intel_80286_at_port61 dut (
        .clk(clk), .reset_n(reset_n), .io_req_i(req), .io_ready_i(ready),
        .io_write_i(write), .io_addr_i(addr), .io_wdata_i(wdata),
        .refresh_detect_i(refresh), .timer2_out_i(timer2), .iochck_i(iochck),
        .pck_i(pck), .selected_o(selected), .rdata_valid_o(valid),
        .rdata_o(rdata), .control_o(control)
    );
    task automatic tick;
        clk=0; #1; clk=1; #1; clk=0; #1;
    endtask
    initial begin
        clk=0; reset_n=1; req=0; ready=0; write=0; addr=0; wdata=0;
        refresh=0; timer2=0; iochck=0; pck=0;
        #1 reset_n=0; #1;
        assert(control==0) else $fatal(1,"port B latch reset failed");
        reset_n=1;
        req=1; write=1; addr=16'h61; wdata=4'hf; ready=0;
        repeat (3) tick();
        assert(selected && control==0) else $fatal(1,"stalled write changed latch");
        ready=1; tick();
        assert(control==4'hf) else $fatal(1,"accepted write lost low nibble");
        write=0; ready=0; #1;
        assert(selected && !valid) else $fatal(1,"stalled read drove bus");
        ready=1;
        for (int i=0;i<16;i++) begin
            {pck,iochck,timer2,refresh}=4'(i); #1;
            assert(valid && rdata=={4'(i),4'hf})
                else $fatal(1,"port B read mapping failed at %0d",i);
        end
        addr=16'h60; #1;
        assert(!selected && !valid) else $fatal(1,"port 60 alias selected");
        addr=16'h161; #1;
        assert(!selected && !valid) else $fatal(1,"unmodeled port alias selected");
        reset_n=0; #1;
        assert(control==0) else $fatal(1,"asynchronous reset failed");
        $display("PASS: AT port 61h latch, READY waits, input mapping and reset");
        $finish;
    end
endmodule
