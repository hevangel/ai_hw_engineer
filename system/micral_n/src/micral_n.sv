// Micral N functional system board. Source: spec/spec.md.
//
// Board devices: ASR-33 teletype on the 11100/SC async card (input group 0:
// byte 0 data, byte 1 status; OUT 8 data), front-panel switches on input
// group 0 byte... group 5 byte 0, and 24 output latches. Input groups follow
// R2E section II.2.5.2: the accumulator precharges the byte index, so INP G
// returns byte ACC[2:0] of group G.
module micral_n (
    input logic clk,
    input logic rst_n,
    input logic cpu_enable,
    input logic substitute,
    input logic [7:0] switch_data,
    input logic [7:0] panel_input,
    input logic rom_protect,
    input logic tty_rx_push,
    input logic [7:0] tty_rx_data,
    output logic tty_rx_full,
    output logic [7:0] tty_tx_data,
    output logic tty_tx_strobe,
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
    // The CPU stalls while the host drives a memory write, so a POKE can
    // never swallow an in-flight CPU store (review M2).
    logic cpu_ready;
    // ASR-33 receiver: small FIFO between the host and the AY-5-1012-style
    // data port; transmitter reports ready whenever the CPU looks.
    logic [7:0] rx_fifo [0:15];
    logic [4:0] rx_wr, rx_rd;
    logic rx_empty, rx_pop;
    // Pile card: hardware byte LIFO used by the monitor and boot as
    // subroutine state (OUT 30 pushes A, INP group 6 pops). Empty reads
    // return zero.
    logic [7:0] pile [0:63];
    logic [6:0] pile_sp;
    logic pile_push, pile_pop;
    string image;
    integer i;

    initial begin
        for (i=0; i<16384; i=i+1) memory[i] = 8'd0;
        if ($value$plusargs("image=%s", image)) $readmemh(image, memory);
    end

    assign cpu_ready = cpu_enable && !host_mem_write;
    assign host_mem_read = memory[host_mem_addr];
    assign host_io_read = host_io_addr >= 5'd8 ? output_latch[host_io_addr - 5'd8] : 8'd0;
    assign mem_data_i = substitute ? switch_data : memory[mem_addr];
    assign rx_empty = rx_wr == rx_rd;
    assign tty_rx_full = rx_wr[4] != rx_rd[4] && rx_wr[3:0] == rx_rd[3:0];
    assign tty_tx_strobe = cpu_ready && io_write && io_port == 5'd8;
    assign tty_tx_data = io_data_o;
    // Reading teletype data (group 0, index 0) pops the receiver.
    assign rx_pop = cpu_ready && io_read && io_port == 5'd0 && accumulator[2:0] == 3'd0;
    assign pile_push = cpu_ready && io_write && io_port == 5'd30;
    assign pile_pop = cpu_ready && io_read && io_port == 5'd6;
    // R2E II.2.5.2: the accumulator precharges the input byte index.
    assign io_data_i = io_port == 5'd0 ? (accumulator[2:0] == 3'd0 ? (rx_empty ? 8'd0 : rx_fifo[rx_rd[3:0]])
                                  : accumulator[2:0] == 3'd1 ? {1'b1, 3'b000, 3'b000, !rx_empty}
                                  : 8'd0)
                                 : io_port == 5'd5 ? (accumulator[2:0] == 3'd0 ? panel_input : 8'd0)
                                 : io_port == 5'd6 ? (pile_sp == 7'd0 ? 8'd0 : pile[pile_sp[5:0] - 6'd1])
                                 : 8'd0;
    assign bus_addr = mem_addr;
    assign bus_data = mem_write ? mem_data_o : mem_data_i;
    assign bus_mem_read = mem_read;
    assign bus_write = mem_write;
    assign bus_io_read = io_read;
    assign bus_io_write = io_write;
    assign instruction_count = instruction_counter + {31'd0, retired};

    intel_8008 cpu (
        .clk, .rst_n, .ready(cpu_ready),
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
            rx_wr <= 5'd0;
            rx_rd <= 5'd0;
            pile_sp <= 7'd0;
            for (integer j=0; j<24; j=j+1) output_latch[j] <= 8'd0;
        end else begin
            if (host_mem_write) memory[host_mem_addr] <= host_mem_data;
            else if (cpu_ready && mem_write && (!rom_protect ||
                     (mem_addr >= 14'h0100 && mem_addr < 14'h3800)))
                memory[mem_addr] <= mem_data_o;
            if (tty_rx_push && !tty_rx_full) begin
                rx_fifo[rx_wr[3:0]] <= tty_rx_data;
                rx_wr <= rx_wr + 5'd1;
            end
            if (rx_pop && !rx_empty) rx_rd <= rx_rd + 5'd1;
            if (pile_push && pile_sp < 7'd64) begin
                pile[pile_sp[5:0]] <= io_data_o;
                pile_sp <= pile_sp + 7'd1;
            end else if (pile_pop && pile_sp != 7'd0) begin
                pile_sp <= pile_sp - 7'd1;
            end
            if (cpu_ready) begin
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
