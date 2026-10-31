module intel_80286_pedc_tb;
    logic clk, rst_n=0, arm=0, busy=0, pereq=0, grant=0, ready=0;
    logic [23:0] start_address=0, address;
    logic [15:0] words=0, rdata=0, wdata;
    logic to_memory=0, request, write_bus, io_bus, peack_n, active, transfer, done;
    logic [1:0] bytes_bus;
    always #5 clk=~clk;
    intel_80286_pedc dut(.clk(clk),.rst_n(rst_n),.arm_i(arm),
        .address_i(start_address),.words_i(words),.to_memory_i(to_memory),
        .busy_i(busy),.pereq_i(pereq),.grant_i(grant),.ready_i(ready),.rdata_i(rdata),
        .request_o(request),.write_o(write_bus),.io_o(io_bus),.address_o(address),
        .bytes_o(bytes_bus),.wdata_o(wdata),.peack_n_o(peack_n),
        .active_o(active),.transfer_o(transfer),.done_o(done));

    task automatic cycle;
        @(posedge clk); #1;
    endtask
    task automatic check_beat(input logic [23:0] a, input logic [1:0] n,
                              input logic wr, input logic io, input logic [15:0] data,
                              input logic first);
        if (!request || address!==a || bytes_bus!==n || write_bus!==wr || io_bus!==io ||
            (wr && wdata!==data)) $fatal(1,"wrong transfer beat");
        grant=1; ready=0; #1;
        if (peack_n===first) $fatal(1,"incorrect PEACK phase");
        repeat (2) begin
            cycle();
            if (!request || address!==a || bytes_bus!==n || write_bus!==wr || io_bus!==io ||
                (wr && wdata!==data) || peack_n===first)
                $fatal(1,"transfer changed while stalled");
        end
        ready=1; cycle(); ready=0;
    endtask
    task automatic run_word(input logic direction, input logic odd);
        rst_n=0; grant=0; ready=0; busy=0; pereq=0; arm=0; cycle();
        rst_n=1; start_address=24'h001000+{23'd0,odd}; words=1;
        to_memory=direction; arm=1; cycle(); arm=0;
        busy=1; cycle(); pereq=1; cycle();
        if (!request || !peack_n) $fatal(1,"request/grant qualification");
        pereq=0;
        if (!direction) begin
            rdata=odd ? 16'h3400 : 16'h1234;
            check_beat(24'h001000+{23'd0,odd},odd ? 2'd1 : 2'd2,0,0,0,1);
            if (odd) begin
                rdata=16'h0012;
                check_beat(24'h001002,1,0,0,0,0);
            end
            check_beat(24'h0000fa,2,1,1,16'h1234,0);
        end else begin
            rdata=16'h1234;
            check_beat(24'h0000fa,2,0,1,0,1);
            check_beat(24'h001000+{23'd0,odd},odd ? 2'd1 : 2'd2,1,0,
                       odd ? 16'h3400 : 16'h1234,0);
            if (odd) check_beat(24'h001002,1,1,0,16'h0012,0);
        end
        if (!transfer || !done || active || request || !peack_n)
            $fatal(1,"word did not complete exactly once");
        cycle(); if (transfer || done) $fatal(1,"completion pulse repeated");
    endtask
    task automatic repeat_and_stop;
        rst_n=0; grant=0; ready=0; busy=0; pereq=0; arm=0; cycle();
        rst_n=1; start_address=24'h002000; words=3; to_memory=0;
        arm=1; cycle(); arm=0; busy=1; cycle(); pereq=1; cycle();
        rdata=16'h1234;
        check_beat(24'h002000,2,0,0,0,1);
        check_beat(24'h0000fa,2,1,1,16'h1234,0);
        if (!transfer || done || !active) $fatal(1,"first word completion");
        // A held request is not a second transfer under assumption A26.
        repeat (3) begin cycle(); if (request || done) $fatal(1,"held PEREQ retriggered"); end
        pereq=0; cycle(); pereq=1; cycle();
        rdata=16'h5678;
        check_beat(24'h002002,2,0,0,0,1);
        check_beat(24'h0000fa,2,1,1,16'h5678,0);
        if (!transfer || done || !active) $fatal(1,"second word completion");
        busy=0; pereq=0; cycle();
        if (!done || active || request) $fatal(1,"BUSY fall did not stop channel");
        cycle(); if (done) $fatal(1,"BUSY completion pulse repeated");
    endtask
    task automatic reset_during_transfer;
        rst_n=0; grant=0; ready=0; busy=0; pereq=0; arm=0; cycle();
        rst_n=1; start_address=24'h003001; words=1; to_memory=1;
        arm=1; cycle(); arm=0; busy=1; cycle(); pereq=1; cycle();
        grant=1; ready=0; #1;
        if (!request || peack_n) $fatal(1,"reset test did not start transfer");
        rst_n=0; cycle();
        if (request || active || !peack_n || transfer || done)
            $fatal(1,"reset did not cancel transfer");
    endtask
    initial begin
        clk=0;
        run_word(0,0); run_word(0,1); run_word(1,0); run_word(1,1);
        repeat_and_stop(); reset_during_transfer();
        $display("PASS: PEDC directions, even/odd beats, stalls, requests, BUSY and reset");
        $finish;
    end
endmodule
