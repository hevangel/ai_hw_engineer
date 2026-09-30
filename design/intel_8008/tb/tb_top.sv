module tb_top;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic ready = 1;
    logic [13:0] mem_addr;
    logic mem_read, mem_write;
    logic [7:0] mem_data_i, mem_data_o;
    logic [4:0] io_port;
    logic io_read, io_write;
    logic [7:0] io_data_i = 8'h37;
    logic [7:0] io_data_o;
    logic interrupt_i = 0;
    logic [7:0] interrupt_opcode = 0;
    logic halted, retire;
    logic [13:0] pc_debug;
    logic [7:0] a_debug;
    logic [3:0] flags_debug;
    logic [7:0] mem [0:16383];
    integer writes = 0;
    integer outs = 0;

    intel_8008 dut (.*);
    assign mem_data_i = mem[mem_addr];
    always @(posedge clk) begin
        if (mem_write && ready) begin mem[mem_addr] <= mem_data_o; writes <= writes + 1; end
        if (io_write && ready) begin
            if (io_port != 5'd8 || io_data_o != 8'h55)
                $fatal(1, "OUT mismatch port=%0d data=%02x", io_port, io_data_o);
            outs <= outs + 1;
        end
    end

    task automatic step(input logic [13:0] expected_pc,
                        input logic [7:0] expected_a);
        integer cycles;
        begin
            cycles = 0;
            do begin
                @(negedge clk);
                cycles = cycles + 1;
                if (cycles > 10) $fatal(1, "instruction timeout at PC %04x", pc_debug);
            end while (!retire);
            if (pc_debug !== expected_pc || a_debug !== expected_a)
                $fatal(1, "PC/A expected %04x/%02x got %04x/%02x", expected_pc,
                       expected_a, pc_debug, a_debug);
        end
    endtask

    initial begin
        for (integer i=0; i<16384; i=i+1) mem[i] = 8'h00;
        mem['h00]=8'h06; mem['h01]=8'h7f; // LAI
        mem['h02]=8'h04; mem['h03]=8'h01; // ADI
        mem['h04]=8'h0e; mem['h05]=8'h05; // LBI
        mem['h06]=8'hc1;                 // LAB
        mem['h07]=8'h08;                 // INB
        mem['h08]=8'h2e; mem['h09]=8'h20; // LHI
        mem['h0a]=8'h36; mem['h0b]=8'h00; // LLI
        mem['h0c]=8'h3e; mem['h0d]=8'haa; // LMI
        mem['h0e]=8'hc7;                 // LAM
        mem['h0f]=8'h3c; mem['h10]=8'haa; // CPI
        mem['h11]=8'h68; mem['h12]=8'h20; mem['h13]=8'h00; // JTZ
        mem['h20]=8'h46; mem['h21]=8'h28; mem['h22]=8'h00; // CAL
        mem['h23]=8'h06; mem['h24]=8'h55; // LAI
        mem['h25]=8'h51;                 // OUT 8
        mem['h26]=8'h00;                 // HLT
        mem['h28]=8'h02;                 // RLC
        mem['h29]=8'h07;                 // RET
        mem['h38]=8'h07;                 // interrupt vector 7: RET
        repeat (2) @(negedge clk);
        rst_n = 1;
        step('h02,'h7f);
        step('h04,'h80);
        if (flags_debug[1] !== 1'b1) $fatal(1,"ADI sign");
        step('h06,'h80);
        step('h07,'h05);
        step('h08,'h05);
        step('h0a,'h05);
        step('h0c,'h05);
        step('h0e,'h05);
        if (mem['h2000] !== 8'haa || writes != 1) $fatal(1,"LMI memory write");
        step('h0f,'haa);
        step('h11,'haa);
        if (flags_debug[2] !== 1'b1) $fatal(1,"CPI zero");
        step('h20,'haa);
        step('h28,'haa);
        step('h29,'h55);
        step('h23,'h55);
        step('h25,'h55);
        step('h26,'h55);
        if (outs != 1) $fatal(1,"OUT missing");
        step('h27,'h55);
        if (!halted) $fatal(1,"HLT missing");
        interrupt_opcode = 8'h3d; // RST 7, injected without PC increment
        interrupt_i = 1;
        step('h38,'h55);
        interrupt_i = 0;
        step('h27,'h55);
        step('h28,'h55); // blank memory is HLT, next PC 28
        if (!halted) $fatal(1,"second HLT missing");
        $display("PASS: exact PC, ALU, memory, branch, call, return, I/O, HLT, interrupt");
        $finish;
    end
endmodule
