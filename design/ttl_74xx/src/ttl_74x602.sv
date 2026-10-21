// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x602.md.
// ttl_74x602 - dynamic memory refresh controller, cycle-steal + burst modes.
// Cycle-steal: hold ras low for 2 clocks then release.
module ttl_74x602 #(
    parameter int ROW_BITS = 8
) (
    input  logic clk, reset_n, refresh_req, burst,
    output logic                ras_n,
    output logic [ROW_BITS-1:0] row_addr,
    output logic                refresh_done
);
    typedef enum logic [2:0] {IDLE, STEAL_LOW, STEAL_HIGH, BURST_RUN} state_t;
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
                        row_addr <= count;
                        ras_n    <= 0;
                        state    <= burst ? BURST_RUN : STEAL_LOW;
                    end
                end
                STEAL_LOW: begin
                    ras_n <= 1;
                    state <= STEAL_HIGH;
                end
                STEAL_HIGH: begin
                    count <= count + 1;
                    state <= IDLE;
                    refresh_done <= 1;
                end
                BURST_RUN: begin
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
