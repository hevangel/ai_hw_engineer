`timescale 1ns/1ps
// Intel figure 8's quadrant corrections, represented as oversample strobes.
module intel_8273_dpll (
    input logic clk, rst_n, tick32, rxd,
    output logic sample_tick
);
    logic [5:0] phase_q, limit_q;
    logic prev_q;
    always_ff @(posedge clk) begin
        if (!rst_n) begin phase_q<=0; limit_q<=32; prev_q<=1; sample_tick<=0; end
        else begin
            sample_tick<=0;
            if (tick32) begin
                prev_q<=rxd;
                if (phase_q+6'd1>=limit_q) begin
                    // ASSUMPTION A5: retain the selected interval through
                    // transition-free runs, avoiding accumulated baud drift.
                    phase_q<=0; sample_tick<=1;
                end else begin
                    phase_q<=phase_q+1'b1;
                    if (rxd!=prev_q) begin
                        if (phase_q<8) limit_q<=30;
                        else if (phase_q<16) limit_q<=31;
                        else if (phase_q<24) limit_q<=33;
                        else limit_q<=34;
                    end
                end
            end
        end
    end
`ifdef FORMAL
    always_ff @(posedge clk) if (rst_n) begin
        assert(phase_q<34);
        assert(limit_q>=30 && limit_q<=34);
    end
`endif
endmodule
