// Paper-tape reader testbench for the SCELBI 8B.
//
// Proves the PTR card works with real 8008 code. The test preloads the reader
// FIFO with a short tape, then runs a loader that reads INP 3 and stores each
// byte to memory. The bytes that land in memory must equal the tape exactly.
//
// Loader at 0x0200 (opcodes from the 8008 user manual, November 1973):
//   0200  Lh  0x10        ; H = 0x10
//   0202  Ll  0x00        ; L = 0x00   -> HL = 0x1000
//   0204  INP 3           ; A = tape byte, advances the head
//   0205  Lm  M           ; store A at [HL]  (M-(A), 11 111 000)
//   0206  INL             ; HL++
//   0207  JMP 0x0204
//   020A  HLT
//
// The loader stops by falling into HLT after the test has supplied a sentinel
// count; the test drives only as many bytes as the tape holds and then checks
// memory.
module tb_ptr;
    localparam [7:0] OP_LHI  = 8'h2E;   // Lh i   (00 101 110)
    localparam [7:0] OP_LLI  = 8'h36;   // Ll i   (00 110 110)
    localparam [7:0] OP_INP3 = 8'h47;   // INP 3  (0100 011 1)
    localparam [7:0] OP_LMM  = 8'hF8;   // Lm M, source A (11 111 000)
    localparam [7:0] OP_INL  = 8'h30;   // INR L  (0011 0000)
    localparam [7:0] OP_JMP  = 8'h44;   // JMP a
    localparam [7:0] OP_HLT  = 8'h00;

    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic cpu_enable = 0;
    logic tty_rx_push = 0;
    logic [7:0] tty_rx_data = 0;
    logic tty_rx_full;
    logic [7:0] tty_tx_data;
    logic tty_tx_strobe;
    logic [13:0] host_mem_addr = 0;
    logic [7:0] host_mem_data = 0;
    logic host_mem_write = 0;
    logic [7:0] host_mem_read;
    logic [13:0] pc;
    logic [7:0] accumulator;
    logic [3:0] flags;
    logic halted, retired;
    logic [13:0] bus_addr;
    logic [7:0] bus_data;
    logic bus_mem_read, bus_write, bus_io_read, bus_io_write;
    logic [4:0] last_output_port;
    logic [7:0] last_output_data;
    logic [31:0] cycle_count, instruction_count;

    logic ptr_push = 0;
    logic [7:0] ptr_data = 0;
    logic ptr_empty;
    logic ptr_full;
    logic [7:0] ptr_byte;
    logic [31:0] ptr_read_count;

    scelbi_8b dut (.*);

    reg [7:0] tape [0:31];
    integer tape_len = 0;
    integer k, errors = 0;

    localparam [13:0] DEST = 14'h1000;

    task automatic load_loader;
        begin
            dut.memory[14'h0200] = OP_LHI;
            dut.memory[14'h0201] = 8'h10;
            dut.memory[14'h0202] = OP_LLI;
            dut.memory[14'h0203] = 8'h00;
            dut.memory[14'h0204] = OP_INP3;
            dut.memory[14'h0205] = OP_LMM;
            dut.memory[14'h0206] = OP_INL;
            dut.memory[14'h0207] = OP_JMP;
            dut.memory[14'h0208] = 8'h04;
            dut.memory[14'h0209] = 8'h02;
            dut.memory[14'h0000] = OP_JMP;
            dut.memory[14'h0001] = 8'h00;
            dut.memory[14'h0002] = 8'h02;
        end
    endtask

    task automatic push_tape(input [7:0] value);
        begin
            while (ptr_full) @(negedge clk);
            @(negedge clk);
            ptr_data = value;
            ptr_push = 1;
            @(negedge clk);
            ptr_push = 0;
        end
    endtask



    initial begin
        tape[0] = "S"; tape[1] = "C"; tape[2] = "E"; tape[3] = "L";
        tape[4] = "B"; tape[5] = "A"; tape[6] = "L"; tape_len = 7;
        for (k = 7; k < 24; k = k + 1) begin
            tape[k] = k;
            tape_len = tape_len + 1;
        end

        repeat (2) @(negedge clk);
        rst_n = 1;
        load_loader;
        repeat (2) @(negedge clk);   // let the memory array settle
        for (k = 0; k < tape_len; k = k + 1) push_tape(tape[k]);
        cpu_enable = 1;

        // The loader runs until the tape is drained, then keeps reading zeros
        // (INP 3 on an empty reader returns 0), which would store zeros and
        // never halt. Stop it once the tape is consumed.
        begin : wait_loop
            integer guard;
            guard = 0;
            while (ptr_read_count != tape_len && guard < 400000) begin
                @(negedge clk);
                guard = guard + 1;
            end
        end
        repeat (100) @(negedge clk);
        cpu_enable = 0;

        for (k = 0; k < tape_len; k = k + 1) begin
            if (dut.memory[DEST + k[13:0]] !== tape[k]) begin
                $display("FAIL: byte %0d at %04x: got %02x expected %02x",
                         k, DEST + k[13:0], dut.memory[DEST + k[13:0]], tape[k]);
                errors = errors + 1;
            end
        end
        if (ptr_read_count !== tape_len) begin
            $display("FAIL: read %0d bytes, expected %0d (pc=%04x)",
                     ptr_read_count, tape_len, pc);
            errors = errors + 1;
        end
        if (errors != 0) $fatal(1, "%0d paper-tape errors", errors);
        $display("PASS: paper-tape reader loaded %0d bytes through INP 3 into 0x%04x (%0d instructions)",
                 tape_len, DEST, instruction_count);
        $finish;
    end
endmodule