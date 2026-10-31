module intel_80286_pedc_owner_tb;
    logic clk, rst_n=0, arm=0, busy=0, pereq=0, cpu_req=0, event_claim=0;
    logic bus_ready=0;
    logic [15:0] bus_rdata=0, bus_wdata, channel_wdata;
    logic [23:0] bus_addr, channel_addr;
    logic bus_req, bus_write, channel_req, channel_write, channel_io;
    logic [1:0] channel_bytes, owner;
    logic [31:0] bus_context;
    logic cpu_grant, event_grant, channel_grant, cpu_ready, event_ready, channel_ready;
    logic peack_n, active, transfer, done;
    always #5 clk=~clk;

    intel_80286_pedc channel(.clk(clk),.rst_n(rst_n),.arm_i(arm),
        .address_i(24'h001001),.words_i(16'd1),.to_memory_i(1'b0),
        .busy_i(busy),.pereq_i(pereq),.grant_i(channel_grant),
        .ready_i(channel_ready),.rdata_i(bus_rdata),.request_o(channel_req),
        .write_o(channel_write),.io_o(channel_io),.address_o(channel_addr),
        .bytes_o(channel_bytes),.wdata_o(channel_wdata),.peack_n_o(peack_n),
        .active_o(active),.transfer_o(transfer),.done_o(done));

    /* verilator lint_off PINCONNECTEMPTY */
    intel_80286_bus_owner owner_unit(.clk(clk),.rst_n(rst_n),
        .cpu_req_i(cpu_req),.cpu_addr_i(24'habc000),.cpu_write_i(1'b0),
        .cpu_wdata_i(16'd0),.cpu_context_i(32'h1),
        .descriptor_claim_i(1'b0),.descriptor_release_i(1'b0),.descriptor_req_i(1'b0),
        .descriptor_addr_i(24'd0),.descriptor_write_i(1'b0),.descriptor_wdata_i(16'd0),
        .descriptor_context_i(32'd0),.descriptor_grant_o(),.descriptor_ready_o(),
        .event_claim_i(event_claim),.event_release_i(1'b0),.event_req_i(event_claim),
        .event_addr_i(24'hfed000),.event_write_i(1'b0),.event_wdata_i(16'd0),
        .event_context_i(32'h2),.event_grant_o(event_grant),.event_ready_o(event_ready),
        .pedc_claim_i(channel_req),.pedc_release_i(transfer),.pedc_req_i(channel_req),
        .pedc_addr_i(channel_addr),.pedc_write_i(channel_write),.pedc_wdata_i(channel_wdata),
        .pedc_context_i({29'd0,channel_io,channel_bytes}),
        .pedc_grant_o(channel_grant),.pedc_ready_o(channel_ready),
        .bus_ready_i(bus_ready),.bus_rdata_i(bus_rdata),.bus_req_o(bus_req),
        .bus_addr_o(bus_addr),.bus_write_o(bus_write),.bus_wdata_o(bus_wdata),
        .bus_context_o(bus_context),.cpu_grant_o(cpu_grant),.cpu_ready_o(cpu_ready),
        .bus_rdata_o(),.owner_o(owner));
    /* verilator lint_on PINCONNECTEMPTY */

    task automatic cycle;
        @(posedge clk); #1;
    endtask
    task automatic check_bus(input logic [23:0] addr, input logic wr,
                             input logic [2:0] ctx, input logic [15:0] data);
        if (!bus_req || bus_addr!==addr || bus_write!==wr || bus_context!=={29'd0,ctx} ||
            (wr && bus_wdata!==data)) $fatal(1,"owner/channel bus beat mismatch");
    endtask
    initial begin
        clk=0; cycle(); rst_n=1;
        cpu_req=1; arm=1; cycle(); arm=0; busy=1; cycle(); pereq=1; cycle();
        if (!active || !channel_req || !cpu_grant || channel_grant || !peack_n || bus_addr!=24'habc000)
            $fatal(1,"PEDC preempted outstanding CPU beat");
        bus_ready=1; #1; if (!cpu_ready || channel_ready) $fatal(1,"CPU response routing");
        cycle(); cpu_req=0; bus_ready=0; cycle();
        if (!channel_grant || peack_n || owner!=3) $fatal(1,"PEDC did not obtain ownership");
        event_claim=1; pereq=0; bus_rdata=16'h3400;
        check_bus(24'h001001,0,3'b001,0);
        repeat (3) begin cycle(); if (!channel_grant || event_grant || event_ready || peack_n)
            $fatal(1,"PEDC lost ownership or acknowledgement during stall"); end
        bus_ready=1; cycle(); bus_ready=0;
        check_bus(24'h001002,0,3'b001,0);
        if (!peack_n || event_grant) $fatal(1,"second beat acknowledgement/owner");
        bus_rdata=16'h0012; bus_ready=1; cycle(); bus_ready=0;
        check_bus(24'h0000fa,1,3'b110,16'h1234);
        if (event_grant) $fatal(1,"event split PEDC word");
        bus_ready=1; cycle(); bus_ready=0;
        if (!transfer || !done || !channel_grant) $fatal(1,"word completion/release timing");
        cycle(); if (!cpu_grant || channel_grant) $fatal(1,"owner did not release word");
        cycle(); if (!event_grant || owner!=2) $fatal(1,"waiting event lost");
        $display("PASS: PEDC and bus owner preserve CPU beat, odd word and waiting event");
        $finish;
    end
endmodule
