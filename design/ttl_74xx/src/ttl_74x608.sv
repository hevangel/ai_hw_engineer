// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x608.md.
// ttl_74x608 - memory cycle controller (DRAM access state machine).
module ttl_74x608 (
    input  logic clk, reset_n,
    input  logic mem_req,
    output logic ras_n, cas_n, addr_sel, dt_oe_n, busy
);
    typedef enum logic [2:0] {IDLE, ROW, ROW_HOLD, COL, COL_HOLD, PRECHARGE} state_t;
    state_t state;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state    <= IDLE;
            ras_n    <= 1;
            cas_n    <= 1;
            addr_sel <= 0;
            dt_oe_n  <= 1;
            busy     <= 0;
        end else begin
            unique case (state)
                IDLE: begin
                    busy <= 0; ras_n <= 1; cas_n <= 1; addr_sel <= 0; dt_oe_n <= 1;
                    if (mem_req) begin
                        ras_n <= 0; addr_sel <= 0; busy <= 1;
                        state <= ROW;
                    end
                end
                ROW:      begin addr_sel <= 1; state <= ROW_HOLD; end
                ROW_HOLD: begin cas_n   <= 0; state <= COL; end
                COL:      begin dt_oe_n <= 0; state <= COL_HOLD; end
                COL_HOLD: begin cas_n   <= 1; ras_n <= 1; dt_oe_n <= 1; state <= PRECHARGE; end
                PRECHARGE: begin state <= IDLE; end
                default:  state <= IDLE;
            endcase
        end
    end
endmodule
