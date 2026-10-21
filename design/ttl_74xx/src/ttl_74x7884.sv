// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7884.md.
// ttl_74x7884 - 73728-bit FIFO memory (4096x18), clocked
// Synchronous FIFO, 4096-word x 18-bit.
module ttl_74x7884 (
    input  logic              clk,
    input  logic              clr_n,
    input  logic              we,
    input  logic              re,
    input  logic [17:0]      din,
    output logic [17:0]      dout,
    output logic              full,
    output logic              empty
);
    logic [17:0] mem [0:4095];
    logic [12:0] wr_ptr, rd_ptr;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            if (we && !full)  begin mem[wr_ptr[11:0]] <= din; wr_ptr <= wr_ptr + 1; end
            if (re && !empty) rd_ptr <= rd_ptr + 1;
        end
    end

    assign dout  = mem[rd_ptr[11:0]];
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr - rd_ptr) == 13'd4096;
endmodule
