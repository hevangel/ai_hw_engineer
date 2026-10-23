// Source-reviewed passive topology; external_drive contains only external strong drivers.
// ASSUMPTION: powered valid Boolean levels and settled controls; see the part specification.
module ttl_74x3390 (
    input logic aen_n,
    input logic ben_n,
    input logic [24-1:0] external_data,
    input logic [24-1:0] external_drive,
    output logic [24-1:0] resolved,
    output logic [24-1:0] valid,
    output logic [24-1:0] conflict,
    output logic [24-1:0] weak_drive
);
    localparam integer WIDTH = 8;
    localparam integer PORTS = 3;
    logic [PORTS*PORTS-1:0] reach;
    integer bit_index;
    integer first_port;
    integer second_port;
    integer pivot;
    integer destination;
    integer source_port;
    logic strong_one;
    logic strong_zero;

    always_comb begin
        resolved = '0;
        valid = '0;
        conflict = '0;
        weak_drive = '0;
        reach = '0;
        strong_one = 1'b0;
        strong_zero = 1'b0;
        for (bit_index = 0; bit_index < WIDTH; bit_index = bit_index + 1) begin
            reach = '0;
            for (first_port = 0; first_port < PORTS; first_port = first_port + 1)
                reach[first_port*PORTS+first_port] = 1'b1;
            if (!aen_n) begin reach[0*PORTS+2] = 1'b1; reach[2*PORTS+0] = 1'b1; end
            if (!ben_n) begin reach[1*PORTS+2] = 1'b1; reach[2*PORTS+1] = 1'b1; end
            for (pivot = 0; pivot < PORTS; pivot = pivot + 1)
                for (first_port = 0; first_port < PORTS; first_port = first_port + 1)
                    for (second_port = 0; second_port < PORTS; second_port = second_port + 1)
                        reach[first_port*PORTS+second_port] = reach[first_port*PORTS+second_port] |
                            (reach[first_port*PORTS+pivot] & reach[pivot*PORTS+second_port]);
            for (destination = 0; destination < PORTS; destination = destination + 1) begin
                strong_one = 1'b0;
                strong_zero = 1'b0;
                for (source_port = 0; source_port < PORTS; source_port = source_port + 1) begin
                    if (reach[destination*PORTS+source_port] && external_drive[source_port*WIDTH+bit_index]) begin
                        if (external_data[source_port*WIDTH+bit_index]) strong_one = 1'b1;
                        else strong_zero = 1'b1;
                    end
                end
                conflict[destination*WIDTH+bit_index] = strong_one && strong_zero;
                valid[destination*WIDTH+bit_index] = (strong_one || strong_zero) && !conflict[destination*WIDTH+bit_index];
                resolved[destination*WIDTH+bit_index] = valid[destination*WIDTH+bit_index] && strong_one;
                weak_drive[destination*WIDTH+bit_index] = 1'b0;
            end
        end
    end
endmodule
