// SCELBI 8B functional system board. Source: spec/spec.md.
//
// 16 KiB RAM behind the repository's Intel 8008 core, plus the console
// card: a software (bit-banger) serial interface to an ASR-33, following
// SIMH's SCELBI 8B model. Each character crosses the bus bit by bit —
// 9 INPs to receive (start + 8 data bits, LSB first, returned in bit 7)
// and 10 OUTs to transmit (start + 8 data + 2 stops, sent in bit 0) —
// with a flag port for ready/status. SIMH wires the two documented port
// variants: INP 2 and INP 5 for input, OUT 10 and OUT 14 for output
// (SCELBAL itself reads INP 5 and writes OUT 14); INP 4 reads the flag
// port (bit 0 printer ready, bit 4 key available).
//
// The paper-tape reader follows the port map SIMH documents for the SCELBI
// 8B in scelbi_io.c: INP 3 returns the byte under the read head and advances
// the tape, flag-port bit 1 reports "input available from tape-reader" and
// bit 2 reports "tape in tape-reader". SIMH itself leaves the PTR unit
// unimplemented (ptr_svc returns immediately), so this card is built from its
// documented interface rather than from a working reference model. See
// spec/spec.md, "Paper-tape reader".
module scelbi_8b (
    input logic clk,
    input logic rst_n,
    input logic cpu_enable,
    input logic tty_rx_push,
    input logic [7:0] tty_rx_data,
    output logic tty_rx_full,
    output logic [7:0] tty_tx_data,
    output logic tty_tx_strobe,
    input logic [13:0] host_mem_addr,
    input logic [7:0] host_mem_data,
    input logic host_mem_write,
    output logic [7:0] host_mem_read,
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
    output logic [31:0] instruction_count,
    // Paper-tape reader. The host streams the tape image one byte per push;
    // the card presents it at INP 3 and reports availability in flag bit 1.
    input logic ptr_push,
    input logic [7:0] ptr_data,
    output logic ptr_empty,
    output logic ptr_full,
    output logic [7:0] ptr_byte,
    output logic [31:0] ptr_read_count
);
    logic [7:0] memory [0:16383];
    logic [13:0] mem_addr;
    logic mem_read, mem_write;
    logic [7:0] mem_data_i, mem_data_o;
    logic [4:0] io_port;
    logic io_read, io_write;
    logic [7:0] io_data_i, io_data_o;
    logic [31:0] instruction_counter;
    logic cpu_ready;
    string image;
    integer i;

    initial begin
        for (i=0; i<16384; i=i+1) memory[i] = 8'd0;
        if ($value$plusargs("image=%s", image)) $readmemh(image, memory);
    end

    // Console receiver: byte FIFO from the host feeding the bit-banger.
    logic [7:0] rx_fifo [0:63];
    logic [6:0] rx_wr, rx_rd;
    logic rx_empty;
    logic [3:0] rx_bit;   // 0 = next INP is the start bit, 1..8 = data bits
    logic [7:0] rx_shift;
    logic rx_inp;         // a console data INP strobe (either port variant)

    // Paper-tape reader: a byte stream from the host. INP 3 pops the oldest
    // byte; flag bit 1 reports "a byte is available" and bit 2 reports "tape
    // is still loaded" (SIMH's scelbi_io.c names them the same way).
    logic [7:0] ptr_fifo [0:255];
    logic [8:0] ptr_wr, ptr_rd;
    logic ptr_full_r;
    logic ptr_inp;
    logic ptr_avail;         // a byte is available to read (FIFO non-empty)

    // Console transmitter: counts OUTs into a 10-bit frame and hands the
    // assembled byte to the host. Data bits arrive LSB first; capturing at
    // the eighth-data-bit edge leaves {d7..d0} in the byte register.
    logic [3:0] tx_bit;   // 0 = start, 1..8 = data, 9 = first stop
    logic [6:0] tx_shift;
    logic [7:0] tx_byte;
    logic tx_pending;
    logic tx_out;         // a console data OUT strobe (either port variant)

    assign cpu_ready = cpu_enable && !host_mem_write;
    assign host_mem_read = memory[host_mem_addr];
    assign mem_data_i = memory[mem_addr];
    assign rx_empty = rx_wr == rx_rd;
    assign tty_rx_full = rx_wr[6] != rx_rd[6] && rx_wr[5:0] == rx_rd[5:0];
    assign rx_inp = cpu_ready && io_read && (io_port == 5'd2 || io_port == 5'd5);
    assign ptr_inp = cpu_ready && io_read && (io_port == 5'd3);
    // `ptr_empty` mirrors "no tape left": the FIFO is drained and nothing is
    // in flight.
    assign ptr_empty = !ptr_avail;
    assign ptr_full = ptr_full_r;
    // INP 3 is combinational on the FIFO head so the byte is available in the
    // same cycle as the read strobe.
    assign ptr_byte = ptr_fifo[ptr_rd[7:0]];
    assign tx_out = cpu_ready && io_write && (io_port == 5'd10 || io_port == 5'd14);
    assign tty_tx_strobe = cpu_ready && tx_pending;
    assign tty_tx_data = tx_byte;
    // Serial line value this INP hands the CPU: idle or stop reads as mark
    // (0x80), the start bit reads 0, and data bits follow LSB first.
    logic rx_bit_value;
    assign rx_bit_value = rx_bit == 4'd0 ? !rx_empty ? 1'b0 : 1'b1 : rx_shift[0];
    // Flag port, per SIMH's scelbi_io.c: bit 0 printer ready (reset default),
    // bit 1 tape-reader data available, bit 2 tape in reader, bit 4 key
    // available. Bits 3, 5 and 7 read as 0; bit 6 (the reset key) is not
    // modelled by this board.
    assign io_data_i = io_port == 5'd4 ? {1'b0, 1'b0, ptr_avail,
                                           ptr_avail, 1'b0, !rx_empty,
                                           1'b0, 1'b1}
                     : io_port == 5'd3 ? ptr_fifo[ptr_rd[7:0]]
                     : rx_inp ? {rx_bit_value, 7'd0}
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
            rx_wr <= 7'd0;
            rx_rd <= 7'd0;
            rx_bit <= 4'd0;
            rx_shift <= 8'd0;
            tx_bit <= 4'd0;
            tx_shift <= 7'd0;
            tx_byte <= 8'd0;
            tx_pending <= 1'b0;
            ptr_wr <= 9'd0;
            ptr_rd <= 9'd0;
            ptr_full_r <= 1'b0;
            ptr_avail <= 1'b0;
            ptr_read_count <= 32'd0;
        end else begin
            if (host_mem_write) memory[host_mem_addr] <= host_mem_data;
            else if (cpu_ready && mem_write) memory[mem_addr] <= mem_data_o;
            if (tty_rx_push && !tty_rx_full) begin
                rx_fifo[rx_wr[5:0]] <= tty_rx_data;
                rx_wr <= rx_wr + 7'd1;
            end
            // The INP strobe itself advances the bit-banger, exactly like
            // SIMH's ttyin_d: the first read of a frame hands out the start
            // bit and latches the character, the next eight reads shift the
            // data bits out LSB first. The card sets bit 7 on every
            // received character (SCELBI's 7-bit console convention, which
            // SCELBAL's command parser relies on).
            if (rx_inp) begin
                if (rx_bit == 4'd0) begin
                    if (!rx_empty) begin
                        rx_shift <= rx_fifo[rx_rd[5:0]] | 8'h80;
                        rx_rd <= rx_rd + 7'd1;
                        rx_bit <= 4'd1;
                    end
                end else begin
                    rx_shift <= {1'b0, rx_shift[7:1]};
                    rx_bit <= rx_bit == 4'd8 ? 4'd0 : rx_bit + 4'd1;
                end
            end
            // Paper-tape reader. A pushed byte enters the FIFO; INP 3 pops
            // the oldest byte. Push and pop can land on the same cycle, so
            // availability is recomputed from the next pointer values.
            if (ptr_push && !ptr_full_r) begin
                ptr_fifo[ptr_wr[7:0]] <= ptr_data;
                ptr_wr <= ptr_wr + 9'd1;
            end
            if (ptr_inp && ptr_avail) begin
                ptr_read_count <= ptr_read_count + 32'd1;
                ptr_rd <= ptr_rd + 9'd1;
            end
            ptr_full_r <= (ptr_wr + (ptr_push && !ptr_full_r ? 9'd1 : 9'd0)
                           == ptr_rd + 9'd256 - 9'd1);
            ptr_avail <= (ptr_wr + (ptr_push && !ptr_full_r ? 9'd1 : 9'd0))
                       != (ptr_rd + (ptr_inp && ptr_avail ? 9'd1 : 9'd0));

            // Data bits assemble LSB first; the byte completes on the
            // eighth data bit's edge and pulses to the host one cycle later.
            if (tx_out) begin
                tx_shift <= {io_data_o[0], tx_shift[6:1]};
                if (tx_bit == 4'd8) begin
                    tx_byte <= {io_data_o[0], tx_shift};
                    tx_pending <= 1'b1;
                end else begin
                    tx_pending <= 1'b0;
                end
                tx_bit <= tx_bit == 4'd9 ? 4'd0 : tx_bit + 4'd1;
            end else begin
                tx_pending <= 1'b0;
            end
            if (cpu_ready) begin
                cycle_count <= cycle_count + 32'd1;
                if (io_write) begin
                    last_output_port <= io_port;
                    last_output_data <= io_data_o;
                end
            end
            if (retired) instruction_counter <= instruction_counter + 32'd1;
        end
    end
endmodule
