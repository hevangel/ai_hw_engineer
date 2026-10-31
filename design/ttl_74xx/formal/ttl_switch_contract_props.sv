`ifdef FORMAL
module ttl_switch_contract(input logic clk);
    (* anyseq *) logic [2:0] control;
    (* anyseq *) logic [47:0] external_data,external_drive;
    logic [47:0] resolved,valid,conflict,weak_drive;
    ttl_74x16213 dut(.*);
    // Independent component labels from the native truth table.
    // Code 5 joins A1, A2 and B2; B1 remains isolated (unlike 16212).
    function automatic integer component(input logic [2:0] selection,input integer port_index);
        component=port_index;
        case(selection)
            1: if(port_index==2) component=0;
            2: if(port_index==3) component=0;
            3: if(port_index==2) component=1;
            4: if(port_index==3) component=1;
            5: if(port_index==1 || port_index==3) component=0;
            6: begin if(port_index==2) component=0;if(port_index==3) component=1;end
            7: begin if(port_index==3) component=0;if(port_index==2) component=1;end
            default: ;
        endcase
    endfunction
    for(genvar bit_index=0;bit_index<12;bit_index++) begin : g_bit
        for(genvar destination=0;destination<4;destination++) begin : g_port
            logic ones,zeros,expected_conflict,expected_valid;
            always_comb begin
                ones=0;zeros=0;
                for(integer source_port=0;source_port<4;source_port=source_port+1) begin
                    if(component(control,source_port)==component(control,destination) && external_drive[source_port*12+bit_index]) begin
                        if(external_data[source_port*12+bit_index]) ones=1;
                        else zeros=1;
                    end
                end
                expected_conflict=ones && zeros;
                expected_valid=(ones || zeros) && !expected_conflict;
                assert(conflict[destination*12+bit_index]==expected_conflict);
                assert(valid[destination*12+bit_index]==expected_valid);
                assert(resolved[destination*12+bit_index]==(expected_valid && ones));
                assert(!weak_drive[destination*12+bit_index]);
            end
        end
    end
    always_ff @(posedge clk) begin
        cover(control==5 && external_drive==48'h000000001000 && external_data==48'h000000001000 &&
              resolved[0] && resolved[12] && resolved[36] && !valid[24]);
        cover(control==5 && external_drive[0] && external_drive[36] &&
              external_data[0] && !external_data[36] && conflict[0] && conflict[12] && conflict[36]);
        cover(control==0 && valid=='1 && conflict==0);
    end
endmodule
`endif
