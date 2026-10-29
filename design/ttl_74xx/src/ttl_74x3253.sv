// Source-reviewed passive topology; external_drive contains only external strong drivers.
// ASSUMPTION: valid powered digital levels and settled controls; see part specification.
module ttl_74x3253 (
    input logic [3:0] control,
    input logic [9:0] external_data,external_drive,
    output logic [9:0] resolved,valid,conflict,weak_drive
);
    logic [3:0] selected;
    assign selected=control;
    logic [49:0] topology;
    logic [9:0] weak_mask;
    always_comb begin
        topology='0;weak_mask='0;
        case(selected)
            4'd0: begin topology=50'h20820c7041063; weak_mask=10'h0; end
            4'd1: begin topology=50'h208288b041445; weak_mask=10'h0; end
            4'd2: begin topology=50'h2092093049049; weak_mask=10'h0; end
            4'd3: begin topology=50'h22820a3141051; weak_mask=10'h0; end
            4'd4: begin topology=50'h2082083041041; weak_mask=10'h0; end
            4'd5: begin topology=50'h2082083041041; weak_mask=10'h0; end
            4'd6: begin topology=50'h2082083041041; weak_mask=10'h0; end
            4'd7: begin topology=50'h2082083041041; weak_mask=10'h0; end
            4'd8: begin topology=50'h2082083041041; weak_mask=10'h0; end
            4'd9: begin topology=50'h2082083041041; weak_mask=10'h0; end
            4'd10: begin topology=50'h2082083041041; weak_mask=10'h0; end
            4'd11: begin topology=50'h2082083041041; weak_mask=10'h0; end
            4'd12: begin topology=50'h2082083041041; weak_mask=10'h0; end
            4'd13: begin topology=50'h2082083041041; weak_mask=10'h0; end
            4'd14: begin topology=50'h2082083041041; weak_mask=10'h0; end
            4'd15: begin topology=50'h2082083041041; weak_mask=10'h0; end
            default: begin topology='x;weak_mask='x;end
        endcase
    end
    for(genvar bit_index=0;bit_index<2;bit_index++) begin : g_line
        for(genvar destination=0;destination<5;destination++) begin : g_port
            logic strong_one,strong_zero,weak_one,weak_zero,strong_present,weak_present;
            always_comb begin
                strong_one=0;strong_zero=0;weak_one=0;weak_zero=0;
                for(integer source_port=0;source_port<5;source_port=source_port+1) begin
                    if(topology[bit_index*25+destination*5+source_port]) begin
                        if(external_drive[source_port*2+bit_index]) begin
                            if(external_data[source_port*2+bit_index]) strong_one=1;
                            else strong_zero=1;
                        end
                        if(weak_mask[source_port*2+bit_index]) begin
                            if(1'b0) weak_one=1;
                            else weak_zero=1;
                        end
                    end
                end
                strong_present=strong_one || strong_zero;
                weak_present=weak_one || weak_zero;
                conflict[destination*2+bit_index]=strong_present?(strong_one && strong_zero):(weak_one && weak_zero);
                valid[destination*2+bit_index]=(strong_present || weak_present) && !conflict[destination*2+bit_index];
                resolved[destination*2+bit_index]=valid[destination*2+bit_index] && (strong_present?strong_one:weak_one);
                weak_drive[destination*2+bit_index]=!strong_present && weak_present;
            end
        end
    end
endmodule
