module tb_scelbal;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic ready = 1;
    logic [13:0] mem_addr;
    logic mem_read, mem_write;
    logic [7:0] mem_data_i, mem_data_o;
    logic [4:0] io_port;
    logic io_read, io_write;
    logic [7:0] io_data_i = 0;
    logic [7:0] io_data_o;
    logic interrupt_i = 0;
    logic [7:0] interrupt_opcode = 0;
    logic halted, retire;
    logic [13:0] pc_debug;
    logic [7:0] a_debug;
    logic [3:0] flags_debug;
    logic [7:0] mem [0:16383];
    logic [7:0] final_mem [0:16383];
    logic [76:0] expected [0:199999];
    logic [76:0] actual;
    integer cycles;
    integer reads = 0, writes = 0, inputs = 0, outputs = 0;

    intel_8008 dut (.*);
    assign mem_data_i = mem[mem_addr];
    assign actual = {pc_debug, dut.r[0], dut.r[1], dut.r[2], dut.r[3],
                     dut.r[4], dut.r[5], dut.r[6], flags_debug, dut.sp};
    always @(posedge clk) begin
        if (rst_n && ready) begin
            if (mem_read) reads <= reads + 1;
            if (mem_write) begin mem[mem_addr] <= mem_data_o; writes <= writes + 1; end
            if (io_read) inputs <= inputs + 1;
            if (io_write) outputs <= outputs + 1;
        end
    end

    initial begin
        $readmemh("design/intel_8008/build/scelbal_mem.hex", mem);
        $readmemh("design/intel_8008/build/scelbal_expected.hex", expected);
        $readmemh("design/intel_8008/build/scelbal_final_mem.hex", final_mem);
        repeat (2) @(negedge clk);
        rst_n = 1;
        for (integer n=0; n<200000; n=n+1) begin
            cycles = 0;
            do begin
                @(negedge clk);
                cycles = cycles + 1;
                if (cycles > 10) $fatal(1,"SCELBAL timeout at instruction %0d PC %04x",n,pc_debug);
            end while (!retire);
            if (actual !== expected[n])
                $fatal(1,"SCELBAL mismatch at %0d expected %020x got %020x",n,expected[n],actual);
        end
        for (integer i=0; i<16384; i=i+1)
            if (mem[i] !== final_mem[i]) $fatal(1,"SCELBAL memory mismatch at %04x",i);
        if (halted) $fatal(1,"SCELBAL unexpectedly halted");
        $display("PASS: 200000 authentic SCELBAL instructions; %0d reads, %0d writes, %0d inputs, %0d outputs",
                 reads,writes,inputs,outputs);
        $finish;
    end
endmodule
