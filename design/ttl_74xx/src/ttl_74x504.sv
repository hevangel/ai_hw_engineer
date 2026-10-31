// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x504.md.
// ttl_74x504 - 12-bit SAR with expansion control.
module ttl_74x504 (
    input  logic        clk, start_n, cmp, cs_n,
    output logic [11:0] q,
    output logic        done, cco_n
);
    logic [4:0] state;
    always_ff @(posedge clk) begin
        if (!start_n) begin
            state <= 12;
            q     <= 12'h800;
            done  <= 0;
            cco_n <= 1;
        end else if (!cs_n && !done) begin
            if (cmp) q[state-1] <= 1'b1;
            else     q[state-1] <= 1'b0;
            if (state == 1) begin
                done  <= 1;
                cco_n <= 0;
            end else begin
                state <= state - 1;
                q[state-2] <= 1'b1;
            end
        end
    end
endmodule
