// ASSUMPTION: This FIFO uses normalized synchronous we/re transactions on clk. The original asynchronous request/ready handshake and its propagation timing are not native pins here.
// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x222 - FIFO
// Synchronous FIFO, 16-word x 4-bit.
module ttl_74x222 (
    input  logic              clk,
    input  logic              clr_n,
    input  logic              we,
    input  logic              re,
    input  logic [3:0]      din,
    output logic [3:0]      dout,
    output logic              full,
    output logic              empty
);
    logic [3:0] mem [0:15];
    logic [4:0] wr_ptr, rd_ptr;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            if (we && !full)  begin mem[wr_ptr[3:0]] <= din; wr_ptr <= wr_ptr + 1; end
            if (re && !empty) rd_ptr <= rd_ptr + 1;
        end
    end

    assign dout  = mem[rd_ptr[3:0]];
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr - rd_ptr) == 16;
endmodule
