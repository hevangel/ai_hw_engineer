// IBM 5170 type 1 system-board schematic, sheet 21: U118 is an ALS74.
// Q-bar feeds D and +REFRESH clocks it. Sheet 3 supplies the PULL UP net
// connected to PRE# through R19 to +5 V; CLR# is also tied high. Expose PRE#
// to test the device itself; the board connection must hold it high.
// This circuit does not generate refresh or bus grants.
module intel_80286_at_refresh_detect (
    input  logic refresh_i,
    input  logic preset_n_i,
    output logic detect_o
);
    always_ff @(posedge refresh_i or negedge preset_n_i) begin
        if (!preset_n_i) detect_o <= 1'b1;
        else detect_o <= !detect_o;
    end
endmodule
