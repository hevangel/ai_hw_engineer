// Source-backed 74F779 digital function. See spec/chips/ttl_74x779.md.
module ttl_74x779 (
    input  logic       clk,
    input  logic       s1,
    input  logic       s0,
    input  logic       cet_n,
    input  logic       oe_n,
    input  logic [7:0] external_io_data,
    input  logic [7:0] external_io_drive,
    output logic [7:0] io_data,
    output logic [7:0] io_drive,
    output logic [7:0] io_bus_resolved,
    output logic [7:0] io_bus_valid,
    output logic [7:0] io_bus_conflict,
    output logic       tc_n
);
    logic [7:0] count;

    assign io_data = count;
    assign io_drive = {8{!oe_n}};
    assign tc_n = !((!cet_n && s1 && !s0 && (&count)) ||
                    (!cet_n && !s1 && s0 && (count == 8'h00)));

    always_ff @(posedge clk) begin
        if (!s1 && !s0 && oe_n) begin
            count <= external_io_data;
        end else if (!cet_n && s1 && !s0) begin
            count <= count + 8'd1;
        end else if (!cet_n && !s1 && s0) begin
            count <= count - 8'd1;
        end
    end

    always_comb begin
        for (int bit_index = 0; bit_index < 8; bit_index++) begin
            io_bus_conflict[bit_index] = !oe_n && external_io_drive[bit_index] &&
                                         (count[bit_index] != external_io_data[bit_index]);
            io_bus_valid[bit_index] = (!oe_n || external_io_drive[bit_index]) &&
                                      !io_bus_conflict[bit_index];
            if (io_bus_valid[bit_index]) begin
                io_bus_resolved[bit_index] = !oe_n ? count[bit_index] :
                                                      external_io_data[bit_index];
            end else begin
                io_bus_resolved[bit_index] = 1'b0;
            end
        end
    end
endmodule
