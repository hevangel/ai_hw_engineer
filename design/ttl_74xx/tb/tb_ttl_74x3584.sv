`timescale 1ns/1ps
module tb_ttl_74x3584;
    localparam int WIDTH = 10;
    localparam int PORTS = 2;
    logic bea_n, beb_n;
    logic [PORTS*WIDTH-1:0] external_data;
    logic [PORTS*WIDTH-1:0] external_drive;
    logic [PORTS*WIDTH-1:0] resolved;
    logic [PORTS*WIDTH-1:0] valid;
    logic [PORTS*WIDTH-1:0] conflict;
    logic [PORTS*WIDTH-1:0] weak_drive;

    ttl_74x3584 dut(.*);

    function automatic logic reference_edge(input int mode, input int channel, input int left, input int right);
        reference_edge = 1'b0;
        case (mode)
            0: reference_edge = (left == 0 && right == 1);
            1: reference_edge = (channel < 5 && left == 0 && right == 1);
            2: reference_edge = (channel >= 5 && left == 0 && right == 1);
            default: reference_edge = 1'b0;
        endcase
    endfunction

    task automatic check_resolution(input int mode);
        int label[PORTS];
        int old_label;
        int new_label;
        logic one_seen;
        logic zero_seen;
        logic expected_conflict;
        logic expected_valid;
        logic expected_resolved;
        begin
            #1;
            for (int channel = 0; channel < WIDTH; channel++) begin
                for (int port_index = 0; port_index < PORTS; port_index++) label[port_index] = port_index;
                for (int left = 0; left < PORTS; left++) begin
                    for (int right = left + 1; right < PORTS; right++) begin
                        if (reference_edge(mode, channel, left, right)) begin
                            old_label = label[right];
                            new_label = label[left];
                            for (int port_index = 0; port_index < PORTS; port_index++)
                                if (label[port_index] == old_label) label[port_index] = new_label;
                        end
                    end
                end
                for (int destination = 0; destination < PORTS; destination++) begin
                    one_seen = 1'b0;
                    zero_seen = 1'b0;
                    for (int source_port = 0; source_port < PORTS; source_port++) begin
                        if (label[source_port] == label[destination] && external_drive[source_port*WIDTH+channel]) begin
                            if (external_data[source_port*WIDTH+channel]) one_seen = 1'b1;
                            else zero_seen = 1'b1;
                        end
                    end
                    expected_conflict = one_seen && zero_seen;
                    expected_valid = (one_seen || zero_seen) && !expected_conflict;
                    expected_resolved = expected_valid && one_seen;
                    if (conflict[destination*WIDTH+channel] !== expected_conflict ||
                        valid[destination*WIDTH+channel] !== expected_valid ||
                        resolved[destination*WIDTH+channel] !== expected_resolved ||
                        weak_drive[destination*WIDTH+channel] !== 1'b0)
                        $fatal(1, "resolution mode=%0d channel=%0d port=%0d", mode, channel, destination);
                end
            end
        end
    endtask

    initial begin
        external_data = '0;
        external_drive = '0;
        bea_n = 1'b0; beb_n = 1'b0;
        #1;
        for (int mode = 0; mode < 4; mode++) begin
                        bea_n = 1'(mode >> 1); beb_n = 1'(mode);
            external_data = '0;
            external_drive = '0;
            check_resolution(mode);

            for (int vector = 0; vector < 96; vector++) begin
                for (int port_index = 0; port_index < PORTS; port_index++) begin
                    for (int channel = 0; channel < WIDTH; channel++) begin
                        external_data[port_index*WIDTH+channel] = 1'(((vector >> ((port_index+channel)%7)) ^ (port_index*3+channel+mode)) & 1);
                        external_drive[port_index*WIDTH+channel] = 1'(((vector >> ((port_index+2*channel)%7)) ^ (channel+port_index+mode/2)) & 1);
                    end
                end
                check_resolution(mode);
            end

            for (int left = 0; left < PORTS; left++) begin
                for (int right = left + 1; right < PORTS; right++) begin
                    external_data = '0;
                    external_drive = '0;
                    for (int channel = 0; channel < WIDTH; channel++) begin
                        external_drive[left*WIDTH+channel] = 1'b1;
                        external_data[left*WIDTH+channel] = 1'b0;
                        external_drive[right*WIDTH+channel] = 1'b1;
                        external_data[right*WIDTH+channel] = 1'b1;
                    end
                    check_resolution(mode);
                end
            end

            for (int source_port = 0; source_port < PORTS; source_port++) begin
                for (int channel = 0; channel < WIDTH; channel++) begin
                    for (int value = 0; value < 2; value++) begin
                        external_data = '0;
                        external_drive = '0;
                        external_drive[source_port*WIDTH+channel] = 1'b1;
                        external_data[source_port*WIDTH+channel] = 1'(value);
                        check_resolution(mode);
                    end
                end
            end
        end
        $display("PASS: tb_ttl_74x3584");
        $finish;
    end
endmodule
