// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7823.md.
// ttl_74x7823 - 36864-bit FIFO memory (1024x36), clocked
// Synchronous FIFO, 1024-word x 36-bit.
module ttl_74x7823 (
    input  logic              clk,
    input  logic              clr_n,
    input  logic              we,
    input  logic              re,
    input  logic [35:0]      din,
    output logic [35:0]      dout,
    output logic              full,
    output logic              empty
);
    logic [35:0] mem [0:1023];
    logic [10:0] wr_ptr, rd_ptr;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            if (we && !full)  begin mem[wr_ptr[9:0]] <= din; wr_ptr <= wr_ptr + 1; end
            if (re && !empty) rd_ptr <= rd_ptr + 1;
        end
    end

    assign dout  = mem[rd_ptr[9:0]];
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr - rd_ptr) == 11'd1024;
endmodule
