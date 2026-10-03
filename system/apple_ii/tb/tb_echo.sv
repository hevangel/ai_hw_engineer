module tb_echo;
    logic clk, rst_n, key_valid;
    logic [6:0] key_data;
    logic [7:0] text_data, cpu_status, cpu_x, cpu_y;
    logic cpu_fault, cpu_fetch;
    logic [15:0] cpu_pc;
    logic [15:0] next_pc;
    integer fetches;
    apple_ii #(.ROM_FILE("tb/echo.hex")) dut (
        .clk(clk), .rst_n(rst_n), .key_data(key_data), .key_valid(key_valid),
        .text_addr(10'd0), .text_data(text_data), .cpu_fault(cpu_fault),
        .cpu_fetch(cpu_fetch), .cpu_pc(cpu_pc), .cpu_status(cpu_status),
        .cpu_x(cpu_x), .cpu_y(cpu_y)
    );
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            next_pc <= 16'hd000;
            fetches <= 0;
        end else begin
            if (cpu_fault) $fatal(1, "CPU fault at %h", cpu_pc);
            if (cpu_fetch) begin
                if (cpu_status != 8'h24 && cpu_status != 8'h26 && cpu_status != 8'ha4)
                    $fatal(1, "unexpected echo status %h", cpu_status);
                if (cpu_pc !== next_pc) $fatal(1, "fetch %h expected %h", cpu_pc, next_pc);
                if (cpu_x !== 0 || cpu_y !== 0) $fatal(1, "echo changed X/Y");
                fetches <= fetches + 1;
                case (cpu_pc)
                    16'hd000: next_pc <= 16'hd003;
                    16'hd003: next_pc <= cpu_status[7] ? 16'hd005 : 16'hd000;
                    16'hd005: next_pc <= 16'hd008;
                    16'hd008: next_pc <= 16'hd00b;
                    16'hd00b: next_pc <= 16'hd000;
                    default: $fatal(1, "unexpected opcode fetch");
                endcase
            end
        end
    end
    task automatic send_key(input logic [6:0] value);
        @(negedge clk); key_data = value; key_valid = 1;
        @(negedge clk); key_valid = 0;
        wait (text_data == {1'b1, value});
        wait (cpu_fetch && cpu_pc == 16'hd000);
        if (dut.memory.key_strobe !== 0) $fatal(1, "CPU did not acknowledge key");
    endtask
    initial begin
        rst_n = 0; key_valid = 0; key_data = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;
        wait (fetches >= 6);
        send_key(7'h41);
        send_key(7'h5a);
        $display("PASS: integrated CPU polls, echoes A/Z to text RAM, clears keyboard strobe");
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "echo timeout");
    end
endmodule
