`timescale 1ns/1ps
module tb_ttl_74x16232;
    localparam int WIDTH=16,PORTS=3,MODE_BITS=2;
    logic [MODE_BITS-1:0] control;
    logic [WIDTH*PORTS-1:0] external_data,external_drive,resolved,valid,conflict,weak_drive;
    logic [31:0] rng,pattern_bits;
    int held_mode;
    logic clk,clken_n;

    ttl_74x16232 dut(.*);
    function automatic logic reference_edge(input int mode,channel,left,right);
        reference_edge=0;
        case(mode)
            0: reference_edge=(channel>=0 && channel<16 && (1'b0));
            1: reference_edge=(channel>=0 && channel<16 && (((left==0 && right==1) || (left==1 && right==0)) || ((left==0 && right==2) || (left==2 && right==0))));
            2: reference_edge=(channel>=0 && channel<16 && (((left==0 && right==1) || (left==1 && right==0))));
            3: reference_edge=(channel>=0 && channel<16 && (((left==0 && right==2) || (left==2 && right==0))));
            default:reference_edge=0;
        endcase
    endfunction
    function automatic logic [WIDTH*PORTS-1:0] reference_weak(input int mode);
        reference_weak='0;
        case(mode)
            0: reference_weak=48'h0;
            1: reference_weak=48'h0;
            2: reference_weak=48'h0;
            3: reference_weak=48'h0;
            default:reference_weak='0;
        endcase
    endfunction
    task automatic check_topology(input int mode);
        int label[PORTS];int old_label,new_label;
        logic one_seen,zero_seen,strong_seen,weak_seen,weak_value;
        logic expected_conflict,expected_valid,expected_resolved;
        logic [WIDTH*PORTS-1:0] pull_mask;
        #1;pull_mask=reference_weak(mode);
        for(int channel=0;channel<WIDTH;channel++) begin
            for(int port_index=0;port_index<PORTS;port_index++) label[port_index]=port_index;
            for(int left=0;left<PORTS;left++) begin
                for(int right=left+1;right<PORTS;right++) begin
                    if(reference_edge(mode,channel,left,right)) begin
                        old_label=label[right];new_label=label[left];
                        for(int port_index=0;port_index<PORTS;port_index++) if(label[port_index]==old_label) label[port_index]=new_label;
                    end
                end
            end
            for(int destination=0;destination<PORTS;destination++) begin
                one_seen=0;zero_seen=0;strong_seen=0;weak_seen=0;weak_value=1'b0;
                for(int port_index=0;port_index<PORTS;port_index++) begin
                    if(label[port_index]==label[destination]) begin
                        if(external_drive[port_index*WIDTH+channel]) begin
                            strong_seen=1;
                            if(external_data[port_index*WIDTH+channel]) one_seen=1;else zero_seen=1;
                        end
                        if(pull_mask[port_index*WIDTH+channel]) weak_seen=1;
                    end
                end
                expected_conflict=one_seen && zero_seen;
                expected_valid=(strong_seen || weak_seen) && !expected_conflict;
                expected_resolved=expected_valid && (strong_seen?one_seen:weak_value);
                if(conflict[destination*WIDTH+channel]!==expected_conflict ||
                   valid[destination*WIDTH+channel]!==expected_valid ||
                   resolved[destination*WIDTH+channel]!==expected_resolved ||
                   weak_drive[destination*WIDTH+channel]!==(!strong_seen && weak_seen))
                    $fatal(1,"topology/resolution mode=%0d channel=%0d port=%0d",mode,channel,destination);
            end
        end
    endtask
    initial begin
        control=0;external_data=0;external_drive=0;rng=32'hac971243;held_mode=0;
        clk=0;clken_n=0;
#1;clk=1;#1;clk=0;#1;
        for(int mode=0;mode<(1<<MODE_BITS);mode++) begin

            clken_n=1;control='0;#1;clk=0;#1;clk=1;#1;check_topology(held_mode);
            control=MODE_BITS'(mode);#1;clk=0;#1;clken_n=0;#1;clk=1;#1;held_mode=mode;

            for(int v=0;v<64;v++) begin
                rng=(rng<<1)^(rng[31]?32'h04c11db7:0);pattern_bits=32'(v);
                for(int port_index=0;port_index<PORTS;port_index++) begin
                    for(int channel=0;channel<WIDTH;channel++) begin
                        external_data[port_index*WIDTH+channel]=pattern_bits[port_index] ^ 1'(channel%2);
                        external_drive[port_index*WIDTH+channel]=pattern_bits[PORTS+port_index] ^ 1'((channel/3)%2);
                    end
                end
                check_topology(held_mode);

            end
            // A strong driver at each port must reach every connected peer in either direction.
            for(int source_port=0;source_port<PORTS;source_port++) begin
                external_drive='0;external_data='1;
                external_drive[source_port*WIDTH+:WIDTH]='1;check_topology(held_mode);
                external_data='0;check_topology(held_mode);
            end
        end
        $display("PASS: tb_ttl_74x16232");$finish;
    end
endmodule
