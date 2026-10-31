// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7804.md.
// ttl_74x7804 - 9216-bit FIFO memory (512x18)
// Synchronous FIFO, 512-word x 18-bit.
module ttl_74x7804 (
    input  logic              clk,
    input  logic              clr_n,
    input  logic              we,
    input  logic              re,
    input  logic [17:0]      din,
    output logic [17:0]      dout,
    output logic              full,
    output logic              empty
);
    logic [17:0] mem [0:511];
    logic [9:0] wr_ptr, rd_ptr;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            if (we && !full)  begin mem[wr_ptr[8:0]] <= din; wr_ptr <= wr_ptr + 1; end
            if (re && !empty) rd_ptr <= rd_ptr + 1;
        end
    end

    assign dout  = mem[rd_ptr[8:0]];
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr - rd_ptr) == 10'd512;
endmodule
