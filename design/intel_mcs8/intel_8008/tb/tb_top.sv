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
    logic [7:0] regs_snapshot [0:6];
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
        int cycles;
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

    task automatic check_regs_unchanged;
        for (int k = 0; k < 7; k = k + 1)
            if (dut.r[k] !== regs_snapshot[k])
                $fatal(1, "register %0d changed: %02x -> %02x", k,
                       regs_snapshot[k], dut.r[k]);
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
        mem['h30]=8'h38;                 // INR M (undefined encoding, NOP)
        mem['h31]=8'h39;                 // DCR M (undefined encoding, NOP)
        mem['h32]=8'h46; mem['h33]=8'h40; mem['h34]=8'h00; // CAL 0x040
        mem['h35]=8'h07;                 // RET (end of RST 6 service)
        mem['h40]=8'h0b;                 // RFZ: return if zero false sense
        mem['h41]=8'h2b;                 // RTZ: return if zero true sense
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

        // Undefined INR/DCR M (octal 070/071) must be a full NOP: no register
        // write, no flag change, PC still advances by one (spec assumption).
        // The earlier RLC/RET subroutine is finished; park both of its bytes
        // at HLT so returns from the routines below halt cleanly. Flags at
        // this point: carry=1 (RLC), zero=1 (CPI found A=0xaa equal).
        mem['h28] = 8'h00;
        mem['h29] = 8'h00;
        for (int k = 0; k < 7; k = k + 1) regs_snapshot[k] = dut.r[k];
        interrupt_opcode = 8'h35; // RST 6
        interrupt_i = 1;
        step('h30,'h55);
        interrupt_i = 0;
        step('h31,'h55); // INR M
        if (flags_debug !== 4'hd) $fatal(1,"INR M changed flags: %01x", flags_debug);
        step('h32,'h55); // DCR M
        if (flags_debug !== 4'hd) $fatal(1,"DCR M changed flags: %01x", flags_debug);
        check_regs_unchanged();
        step('h40,'h55); // CAL 0x040

        // Conditional returns with zero=1: RFZ (false sense) falls through,
        // RTZ (true sense) returns — the true-sense encoding was decoded as a
        // NOP before the review fix.
        step('h41,'h55); // RFZ with zero=1: not taken
        step('h35,'h55); // RTZ with zero=1: taken
        step('h28,'h55); // RET back to a parked HLT
        step('h29,'h55);
        if (!halted) $fatal(1,"HLT after RST 6 service missing");

        // Same encodings with zero=0 (CPI sets it): RTZ falls through, RFZ
        // returns.
        mem['h40]=8'h3c; mem['h41]=8'h00; // CPI 0x00: zero=0, carry=0
        mem['h42]=8'h2b;                 // RTZ
        mem['h43]=8'h0b;                 // RFZ
        interrupt_opcode = 8'h35;
        interrupt_i = 1;
        step('h30,'h55);
        interrupt_i = 0;
        step('h31,'h55);
        step('h32,'h55);
        step('h40,'h55);
        step('h42,'h55); // CPI 0x00: A unchanged, zero=0
        if (flags_debug !== 4'h1) $fatal(1,"CPI 0 flags: %01x", flags_debug);
        step('h43,'h55); // RTZ with zero=0: not taken
        step('h35,'h55); // RFZ with zero=0: taken
        step('h29,'h55); // RET back to a parked HLT
        step('h2a,'h55);
        if (!halted) $fatal(1,"HLT after round 2 missing");

        // ALU with memory (absent from the SCELBAL trace) and conditional
        // calls in both senses, with the flag state left by round 2
        // (A=0x55, carry=0, zero=0, parity=1).
        mem['h30]=8'h2e; mem['h31]=8'h30; // LHI 0x30: H=0x30
        mem['h32]=8'h36; mem['h33]=8'h40; // LLI 0x40: HL -> 0x3040
        mem['h34]=8'h3e; mem['h35]=8'h20; // LMI: mem[0x3040] = 0x20
        mem['h36]=8'h87;                 // ADM: A = 0x55 + 0x20 = 0x75
        mem['h37]=8'hbf;                 // CPM: compare A with 0x20
        mem['h38]=8'h42; mem['h39]=8'h60; mem['h3a]=8'h00; // CFc 0x060
        mem['h3b]=8'h62; mem['h3c]=8'h60; mem['h3d]=8'h00; // CTc 0x060
        mem['h3e]=8'h07;                 // RET
        mem['h60]=8'h07;                 // conditional-call target: RET
        interrupt_opcode = 8'h35;
        interrupt_i = 1;
        step('h30,'h55);
        interrupt_i = 0;
        step('h32,'h55); // LHI
        step('h34,'h55); // LLI
        step('h36,'h55); // LMI (second memory write)
        step('h37,'h75); // ADM: carry unchanged (0), 0x75 has odd parity
        if (flags_debug !== 4'h0) $fatal(1,"ADM flags: %01x", flags_debug);
        step('h38,'h75); // CPM: A unchanged, zero=0, parity=1, carry=0
        if (flags_debug !== 4'h1) $fatal(1,"CPM flags: %01x", flags_debug);
        step('h60,'h75); // CFc with carry=0: taken
        step('h3b,'h75); // RET back
        step('h3e,'h75); // CTc with carry=0: not taken
        step('h2a,'h75); // RET back to a parked HLT
        step('h2b,'h75);
        if (!halted) $fatal(1,"final HLT missing");
        $display("PASS: exact PC, ALU, memory, branch, call/return (incl. RFc/RTc), I/O, HLT, interrupt, undefined INR/DCR M NOP");
        $finish;
    end
endmodule
