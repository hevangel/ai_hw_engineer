// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x488.md.
// ttl_74x488 - IEEE-488 bus interface (digital pass-through).
// Implements the data and handshake lines; bus protocol is application-level.
module ttl_74x488 (
    input  logic       talk_n,
    input  logic       dir,
    input  logic [7:0] cpu_data,
    input  logic [7:0] bus_data_in,
    output logic [7:0] cpu_data_out,
    output logic [7:0] bus_data_out
);
    assign bus_data_out = (dir && !talk_n) ? cpu_data    : 8'h00;
    assign cpu_data_out = (!dir && !talk_n) ? bus_data_in : 8'h00;
endmodule
