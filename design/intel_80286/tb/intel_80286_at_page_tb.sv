module intel_80286_at_page_tb;
    logic clk, rst_n, io_req, io_ready, io_write;
    logic [15:0] io_addr;
    logic [7:0] io_wdata, rdata, map_data;
    logic [3:0] map_index;
    logic selected, rdata_valid;

    intel_80286_at_page dut (
        .clk(clk), .rst_n(rst_n), .io_req_i(io_req), .io_ready_i(io_ready),
        .io_write_i(io_write), .io_addr_i(io_addr), .io_wdata_i(io_wdata),
        .map_index_i(map_index), .selected_o(selected), .rdata_valid_o(rdata_valid),
        .rdata_o(rdata), .map_data_o(map_data)
    );

    task automatic tick;
        clk=0; #5; clk=1; #5;
    endtask

    task automatic write_byte(input logic [15:0] address, input logic [7:0] value);
        io_req=1; io_ready=1; io_write=1; io_addr=address; io_wdata=value;
        tick(); io_req=0; io_ready=0; tick();
    endtask

    task automatic read_byte(input logic [15:0] address, output logic [7:0] value);
        io_req=1; io_ready=0; io_write=0; io_addr=address; #1;
        if (!selected || rdata_valid) $fatal(1, "stalled read drove data");
        tick(); io_ready=1; #1;
        if (!rdata_valid) $fatal(1, "accepted read did not drive data");
        value=rdata; tick(); io_req=0; io_ready=0; tick();
    endtask

    initial begin
        clk=0; rst_n=0; io_req=0; io_ready=0; io_write=0;
        io_addr=0; io_wdata=0; map_index=0;
        tick(); tick(); rst_n=1; tick();
        for (int index=0; index<16; index++)
            write_byte(16'h0080 | 16'(index), 8'ha0 ^ 8'(index));

        // An unaccepted write may not alter the selected register.
        io_req=1; io_ready=0; io_write=1; io_addr=16'h0083; io_wdata=8'h5c;
        repeat (4) tick(); io_req=0; tick();
        map_index=4'h3; #1;
        if (map_data !== 8'ha3) $fatal(1, "stalled write changed page register");
        write_byte(16'h0083, 8'h5c);
        #1;
        if (map_data !== 8'h5c) $fatal(1, "accepted write not visible to map output");
        for (int index=0; index<16; index++) begin
            logic [7:0] value;
            read_byte(16'h0080 | 16'(index), value);
            if (value !== (index==3 ? 8'h5c : (8'ha0 ^ 8'(index))))
                $fatal(1, "page register isolation/readback mismatch at %0d", index);
        end
        io_req=1; io_ready=1; io_write=0; io_addr=16'h0090; #1;
        if (selected || rdata_valid) $fatal(1, "unmodeled alias decoded");
        $display("PASS: AT page-register storage, isolated slots, READY stalls and map output");
        $finish;
    end
endmodule
