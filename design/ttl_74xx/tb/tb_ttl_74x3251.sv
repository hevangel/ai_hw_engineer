`timescale 1ns/1ps
module tb_ttl_74x3251;
    localparam int WIDTH=1,PORTS=9,MODE_BITS=4;
    logic [MODE_BITS-1:0] control;
    logic [WIDTH*PORTS-1:0] external_data,external_drive,resolved,valid,conflict,weak_drive;
    logic [31:0] rng,pattern_bits;
    int held_mode;

    ttl_74x3251 dut(.*);
    function automatic logic reference_edge(input int mode,channel,left,right);
        reference_edge=0;
        case(mode)
            0: reference_edge=(channel>=0 && channel<1 && (((left==0 && right==1) || (left==1 && right==0))));
            1: reference_edge=(channel>=0 && channel<1 && (((left==0 && right==2) || (left==2 && right==0))));
            2: reference_edge=(channel>=0 && channel<1 && (((left==0 && right==3) || (left==3 && right==0))));
            3: reference_edge=(channel>=0 && channel<1 && (((left==0 && right==4) || (left==4 && right==0))));
            4: reference_edge=(channel>=0 && channel<1 && (((left==0 && right==5) || (left==5 && right==0))));
            5: reference_edge=(channel>=0 && channel<1 && (((left==0 && right==6) || (left==6 && right==0))));
            6: reference_edge=(channel>=0 && channel<1 && (((left==0 && right==7) || (left==7 && right==0))));
            7: reference_edge=(channel>=0 && channel<1 && (((left==0 && right==8) || (left==8 && right==0))));
            8: reference_edge=(channel>=0 && channel<1 && (1'b0));
            9: reference_edge=(channel>=0 && channel<1 && (1'b0));
            10: reference_edge=(channel>=0 && channel<1 && (1'b0));
            11: reference_edge=(channel>=0 && channel<1 && (1'b0));
            12: reference_edge=(channel>=0 && channel<1 && (1'b0));
            13: reference_edge=(channel>=0 && channel<1 && (1'b0));
            14: reference_edge=(channel>=0 && channel<1 && (1'b0));
            15: reference_edge=(channel>=0 && channel<1 && (1'b0));
            default:reference_edge=0;
        endcase
    endfunction
    function automatic logic [WIDTH*PORTS-1:0] reference_weak(input int mode);
        reference_weak='0;
        case(mode)
            0: reference_weak=9'h0;
            1: reference_weak=9'h0;
            2: reference_weak=9'h0;
            3: reference_weak=9'h0;
            4: reference_weak=9'h0;
            5: reference_weak=9'h0;
            6: reference_weak=9'h0;
            7: reference_weak=9'h0;
            8: reference_weak=9'h0;
            9: reference_weak=9'h0;
            10: reference_weak=9'h0;
            11: reference_weak=9'h0;
            12: reference_weak=9'h0;
            13: reference_weak=9'h0;
            14: reference_weak=9'h0;
            15: reference_weak=9'h0;
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
        #1;
        for(int mode=0;mode<(1<<MODE_BITS);mode++) begin
            control=MODE_BITS'(mode);#1;held_mode=mode;

            for(int v=0;v<512;v++) begin
                rng=(rng<<1)^(rng[31]?32'h04c11db7:0);pattern_bits=rng;
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
        $display("PASS: tb_ttl_74x3251");$finish;
    end
endmodule
