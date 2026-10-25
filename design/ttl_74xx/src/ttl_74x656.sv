// ASSUMPTION: ideal digital levels; three-state outputs use drive flags; see spec/chips/ttl_74x656.md.
// Fairchild 74F656: all three active-low OEs participate in one shared enable.
module ttl_74x656 (
    input  logic [7:0] d_in,
    input  logic       parity_in,
    input  logic [2:0] oe_n,       // [0]=OE1_N, [1]=OE2_N, [2]=OE3_N
    output logic [7:0] q_out,
    output logic       q_drive,
    output logic       po,         // Odd parity output (native PO, pin 22)
    output logic       po_n,       // Even parity output (native PO-bar, pin 21)
    output logic       parity_drive
);
    logic odd_sum;

    assign odd_sum = ^{d_in, parity_in};

    always_comb begin
        q_drive = ~|oe_n;
        parity_drive = q_drive;
        q_out = q_drive ? d_in : 8'h00;
        po = q_drive ? odd_sum : 1'b0;
        po_n = q_drive ? ~odd_sum : 1'b0;
    end
endmodule
