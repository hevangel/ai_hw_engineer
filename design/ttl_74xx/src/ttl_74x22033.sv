// ASSUMPTION: native setup/hold windows are not modeled; storage powers up
// unspecified. The B port is open-drain GTLP: b_drive masks indicate which
// pins are actively sunk low (bus level is the inverted element output). The
// LOOPBACK path feeds the A-to-B logic-element output P into the B-to-A path
// input per the source LOOPBACK table. ERC analog edge-rate control and the
// VREF/BIAS VCC references are omitted.
module ttl_74x22033 (
    input  logic [7:0] ai,
    input  logic [7:0] bi,
    input  logic       oeab,
    input  logic       oeab_n,
    input  logic       oeba,
    input  logic [1:0] omode,
    input  logic [1:0] imode,
    input  logic       clkab_leab,
    input  logic       clkba_leba,
    input  logic       loopback,
    output logic [7:0] ao,
    output logic [7:0] ao_drive,
    output logic [7:0] b_drive
);
    logic [7:0] p_src;
    logic [7:0] q_src;
    logic [7:0] p_elem;
    logic [7:0] q_elem;
    logic [7:0] p_ff;
    logic [7:0] q_ff;
    logic [7:0] p_latch;
    logic [7:0] q_latch;
    logic b_enable;

    assign p_src = ai;
    assign q_src = loopback ? p_elem : bi;
    assign b_enable = oeab && !oeab_n;

    always_ff @(posedge clkab_leab)
        p_ff <= p_src;
    always_ff @(posedge clkba_leba)
        q_ff <= q_src;

    always_latch begin
        if (clkab_leab)
            p_latch = p_src;
    end
    always_latch begin
        if (clkba_leba)
            q_latch = q_src;
    end

    always_comb begin
        case (omode[1])
            1'b0: p_elem = omode[0] ? p_ff : p_src;
            default: p_elem = p_latch;
        endcase
        case (imode[1])
            1'b0: q_elem = imode[0] ? q_ff : q_src;
            default: q_elem = q_latch;
        endcase
    end

    always_comb begin
        ao = '0;
        ao_drive = '0;
        b_drive = '0;
        if (oeba) begin
            ao_drive = '1;
            ao = ~q_elem;
        end
        if (b_enable)
            b_drive = p_elem;
    end
endmodule
