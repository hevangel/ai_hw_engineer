// Micral N functional system board. Source: spec/spec.md.
module micral_n (
    input logic clk,
    input logic rst_n,
    input logic cpu_enable,
    input logic substitute,
    input logic [7:0] switch_data,
    input logic [7:0] panel_input,
    input logic rom_protect,
    input logic [13:0] host_mem_addr,
    input logic [7:0] host_mem_data,
    input logic host_mem_write,
    output logic [7:0] host_mem_read,
    input logic [4:0] host_io_addr,
    output logic [7:0] host_io_read,
    output logic [13:0] pc,
    output logic [7:0] accumulator,
    output logic [3:0] flags,
    output logic halted,
    output logic retired,
    output logic [13:0] bus_addr,
    output logic [7:0] bus_data,
    output logic bus_mem_read,
    output logic bus_write,
    output logic bus_io_read,
    output logic bus_io_write,
    output logic [4:0] last_output_port,
    output logic [7:0] last_output_data,
    output logic [31:0] cycle_count,
    output logic [31:0] instruction_count
);
    logic [7:0] memory [0:16383];
    logic [7:0] output_latch [0:23];
    logic [13:0] mem_addr;
    logic mem_read, mem_write;
    logic [7:0] mem_data_i, mem_data_o;
    logic [4:0] io_port;
    logic io_read, io_write;
    logic [7:0] io_data_i, io_data_o;
    logic [31:0] instruction_counter;
    string image;
    integer i;

    initial begin
        for (i=0; i<16384; i=i+1) memory[i] = 8'd0;
        if ($value$plusargs("image=%s", image)) $readmemh(image, memory);
    end

    assign host_mem_read = memory[host_mem_addr];
    assign host_io_read = host_io_addr >= 5'd8 ? output_latch[host_io_addr - 5'd8] : 8'd0;
    assign mem_data_i = substitute ? switch_data : memory[mem_addr];
    assign io_data_i = io_port == 5'd5 ? panel_input : 8'd0;
    assign bus_addr = mem_addr;
    assign bus_data = mem_write ? mem_data_o : mem_data_i;
    assign bus_mem_read = mem_read;
    assign bus_write = mem_write;
    assign bus_io_read = io_read;
    assign bus_io_write = io_write;
    assign instruction_count = instruction_counter + {31'd0, retired};

    intel_8008 cpu (
        .clk, .rst_n, .ready(cpu_enable),
        .mem_addr, .mem_read, .mem_write, .mem_data_i, .mem_data_o,
        .io_port, .io_read, .io_write, .io_data_i, .io_data_o,
        .interrupt_i(1'b0), .interrupt_opcode(8'd0),
        .halted, .retire(retired), .pc_debug(pc), .a_debug(accumulator),
        .flags_debug(flags)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            last_output_port <= 5'd0;
            last_output_data <= 8'd0;
            cycle_count <= 32'd0;
            instruction_counter <= 32'd0;
            for (integer j=0; j<24; j=j+1) output_latch[j] <= 8'd0;
        end else begin
            if (host_mem_write) memory[host_mem_addr] <= host_mem_data;
            else if (cpu_enable && mem_write && (!rom_protect ||
                     (mem_addr >= 14'h0100 && mem_addr < 14'h3800)))
                memory[mem_addr] <= mem_data_o;
            if (cpu_enable) begin
                cycle_count <= cycle_count + 32'd1;
                if (io_write) begin
                    output_latch[io_port - 5'd8] <= io_data_o;
                    last_output_port <= io_port;
                    last_output_data <= io_data_o;
                end
            end
            if (retired) instruction_counter <= instruction_counter + 32'd1;
        end
    end
endmodule
