// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x601.md.
// ttl_74x601 - dynamic memory refresh controller (transparent + burst).
module ttl_74x601 #(
    parameter int ROW_BITS = 8
) (
    input  logic clk, reset_n, refresh_req, burst,
    output logic                ras_n,
    output logic [ROW_BITS-1:0] row_addr,
    output logic                refresh_done
);
    typedef enum logic [1:0] {IDLE, REFRESH, BURST_REFRESH} state_t;
    state_t state;
    logic [ROW_BITS-1:0] count;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state    <= IDLE;
            count    <= 0;
            ras_n    <= 1;
            row_addr <= 0;
            refresh_done <= 0;
        end else begin
            refresh_done <= 0;
            unique case (state)
                IDLE: begin
                    ras_n <= 1;
                    if (refresh_req) begin
                        state    <= burst ? BURST_REFRESH : REFRESH;
                        row_addr <= count;
                        ras_n    <= 0;
                    end
                end
                REFRESH: begin
                    ras_n <= 1;
                    count <= count + 1;
                    state <= IDLE;
                    refresh_done <= 1;
                end
                BURST_REFRESH: begin
                    count    <= count + 1;
                    row_addr <= count + 1;
                    if (count == {ROW_BITS{1'b1}}) begin
                        state        <= IDLE;
                        ras_n        <= 1;
                        refresh_done <= 1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
