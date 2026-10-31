// Source: Philips 74HCT1284 product specification, pp. 2-3.
// HD low is represented as low-or-Z on the B and Y output groups.
module ttl_74x1284 (
    input  logic       dir,
    input  logic       hd,
    input  logic [3:0] a_bus_in,
    input  logic [3:0] b_bus_in,
    input  logic [2:0] a_aux_in,
    output logic [3:0] a_bus_out,
    output logic [3:0] b_bus_out,
    output logic [2:0] y_aux_out,
    output logic [3:0] a_bus_drive,
    output logic [3:0] b_bus_drive,
    output logic [2:0] y_aux_drive
);
    assign a_bus_drive = {4{~dir}};
    assign a_bus_out = dir ? 4'b0000 : b_bus_in;

    assign b_bus_drive = dir ? (hd ? 4'b1111 : ~a_bus_in) : 4'b0000;
    assign b_bus_out = (dir && hd) ? a_bus_in : 4'b0000;

    assign y_aux_drive = hd ? 3'b111 : ~a_aux_in;
    assign y_aux_out = hd ? a_aux_in : 3'b000;
endmodule
