// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x502.md.
// ttl_74x502 - 8-bit successive approximation register.
// On each clock, shift the SAR pointer down and update the result based on cmp.
module ttl_74x502 (
    input  logic       clk, start, cmp,
    output logic [7:0] q,
    output logic       done
);
    logic [3:0] state;
    always_ff @(posedge clk) begin
        if (start) begin
            state <= 8;
            q     <= 8'h80;
            done  <= 0;
        end else if (!done) begin
            if (cmp) q[state-1] <= 1'b1;
            else     q[state-1] <= 1'b0;
            if (state == 1) done <= 1;
            else begin
                state <= state - 1;
                q[state-2] <= 1'b1;
            end
        end
    end
endmodule
