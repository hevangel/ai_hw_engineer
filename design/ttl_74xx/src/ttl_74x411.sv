// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x411.md.
// ttl_74x411 - FIFO RAM controller. Simplified pointer manager.
module ttl_74x411 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       inc_wr,
    input  logic       inc_rd,
    output logic [3:0] wr_ptr,
    output logic [3:0] rd_ptr,
    output logic       empty,
    output logic       full
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            wr_ptr <= 4'h0;
            rd_ptr <= 4'h0;
        end else begin
            if (inc_wr) wr_ptr <= wr_ptr + 4'h1;
            if (inc_rd) rd_ptr <= rd_ptr + 4'h1;
        end
    end
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr + 4'h1 == rd_ptr);
endmodule
