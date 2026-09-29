module tb_top;
    logic clk;
    logic rst_n;
    logic [15:0] bus_addr, pc;
    logic [7:0] bus_data_i, bus_data_o;
    logic bus_we, fetch, fault;
    logic [7:0] mem [0:65535];
    logic [15:0] expected_pc [0:6];
    integer fetch_count;
    logic [7:0] status;
    logic [7:0] x, y;

    always #5 clk = ~clk;
    assign bus_data_i = mem[bus_addr];
    mos_6502 dut (
        .clk(clk), .rst_n(rst_n), .bus_addr(bus_addr),
        .bus_data_i(bus_data_i), .bus_data_o(bus_data_o),
        .bus_we(bus_we), .fetch_o(fetch), .fault_o(fault), .pc_o(pc),
        .status_o(status), .x_o(x), .y_o(y)
    );

    always @(posedge clk) begin
        if (rst_n && bus_we) mem[bus_addr] <= bus_data_o;
        if (rst_n && fetch) begin
            if (fetch_count > 6) $fatal(1, "unexpected fetch at %h", pc);
            if (pc !== expected_pc[fetch_count])
                $fatal(1, "fetch %0d: got %h expected %h", fetch_count, pc, expected_pc[fetch_count]);
            fetch_count <= fetch_count + 1;
        end
    end

    initial begin
        clk = 0;
        rst_n = 0;
        fetch_count = 0;
        for (integer i = 0; i < 65536; i++) mem[i] = 8'h00;
        mem[16'hfffc] = 8'h00; mem[16'hfffd] = 8'h80;
        // LDA #$42; STA $0200; LDX #0; LDY #5; JMP $800c; NOP.
        mem[16'h8000] = 8'ha9; mem[16'h8001] = 8'h42;
        mem[16'h8002] = 8'h8d; mem[16'h8003] = 8'h00; mem[16'h8004] = 8'h02;
        mem[16'h8005] = 8'ha2; mem[16'h8006] = 8'h00;
        mem[16'h8007] = 8'ha0; mem[16'h8008] = 8'h05;
        mem[16'h8009] = 8'h4c; mem[16'h800a] = 8'h0c; mem[16'h800b] = 8'h80;
        mem[16'h800c] = 8'hea;
        expected_pc[0] = 16'h8000; expected_pc[1] = 16'h8002;
        expected_pc[2] = 16'h8005; expected_pc[3] = 16'h8007;
        expected_pc[4] = 16'h8009; expected_pc[5] = 16'h800c;
        expected_pc[6] = 16'h800d;
        repeat (2) @(negedge clk);
        rst_n = 1;
        wait (fault);
        if (fetch_count != 7) $fatal(1, "fetch count %0d", fetch_count);
        if (mem[16'h0200] !== 8'h42) $fatal(1, "STA failed");
        if (bus_data_o !== 8'h42 || x !== 8'h00 || y !== 8'h05)
            $fatal(1, "register mismatch");
        if (status !== 8'h24)
            $fatal(1, "status mismatch");
        $display("PASS: reset, loads, store, jump, NOP, exact fetch sequence");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "timeout");
    end
endmodule
