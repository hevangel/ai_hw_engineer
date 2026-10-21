// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7807.md.
// ttl_74x7807 - 18432-bit FIFO memory (2048x9), clocked
// Synchronous FIFO, 2048-word x 9-bit.
module ttl_74x7807 (
    input  logic              clk,
    input  logic              clr_n,
    input  logic              we,
    input  logic              re,
    input  logic [8:0]      din,
    output logic [8:0]      dout,
    output logic              full,
    output logic              empty
);
    logic [8:0] mem [0:2047];
    logic [11:0] wr_ptr, rd_ptr;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            if (we && !full)  begin mem[wr_ptr[10:0]] <= din; wr_ptr <= wr_ptr + 1; end
            if (re && !empty) rd_ptr <= rd_ptr + 1;
        end
    end

    assign dout  = mem[rd_ptr[10:0]];
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr - rd_ptr) == 12'd2048;
endmodule
