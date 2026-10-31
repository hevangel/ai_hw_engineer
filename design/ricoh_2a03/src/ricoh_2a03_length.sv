// APU length counter shared by pulse, triangle and noise channels.
module ricoh_2a03_length (
    input  logic clk, rst_n,
    input  logic enable_i,       // $4015 channel enable bit
    input  logic halt_i,         // length-counter halt flag
    input  logic load_i,         // write to the channel's length register
    input  logic [4:0] index_i,
    input  logic half_i,         // half-frame clock
    output logic active_o        // counter non-zero
);
    function automatic logic [7:0] length_lookup(input logic [4:0] index);
        case (index)
            5'd0:  length_lookup = 8'd10;  5'd1:  length_lookup = 8'd254;
            5'd2:  length_lookup = 8'd20;  5'd3:  length_lookup = 8'd2;
            5'd4:  length_lookup = 8'd40;  5'd5:  length_lookup = 8'd4;
            5'd6:  length_lookup = 8'd80;  5'd7:  length_lookup = 8'd6;
            5'd8:  length_lookup = 8'd160; 5'd9:  length_lookup = 8'd8;
            5'd10: length_lookup = 8'd60;  5'd11: length_lookup = 8'd10;
            5'd12: length_lookup = 8'd14;  5'd13: length_lookup = 8'd12;
            5'd14: length_lookup = 8'd26;  5'd15: length_lookup = 8'd14;
            5'd16: length_lookup = 8'd12;  5'd17: length_lookup = 8'd16;
            5'd18: length_lookup = 8'd24;  5'd19: length_lookup = 8'd18;
            5'd20: length_lookup = 8'd48;  5'd21: length_lookup = 8'd20;
            5'd22: length_lookup = 8'd96;  5'd23: length_lookup = 8'd22;
            5'd24: length_lookup = 8'd192; 5'd25: length_lookup = 8'd24;
            5'd26: length_lookup = 8'd72;  5'd27: length_lookup = 8'd26;
            5'd28: length_lookup = 8'd16;  5'd29: length_lookup = 8'd28;
            5'd30: length_lookup = 8'd32;  default: length_lookup = 8'd30;
        endcase
    endfunction
    logic [7:0] count;
    assign active_o = count != 0;
    always_ff @(posedge clk) begin
        if (!rst_n || !enable_i) count <= '0;
        // A reload written while a non-zero counter is being clocked is
        // ignored (blargg apu 11.len_reload_timing).
        else if (half_i && !halt_i && count != 0) count <= count - 8'd1;
        else if (load_i) count <= length_lookup(index_i);
    end
`ifdef FORMAL
    // The counter only ever holds a table entry or a decremented one.
    logic f_valid = 0;
    always_ff @(posedge clk) begin
        f_valid <= 1;
        if (f_valid) assert(count <= 8'd254);
    end
`endif
endmodule
