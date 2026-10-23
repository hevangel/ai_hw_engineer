// Source-reviewed passive topology; external_drive contains only external strong drivers.
// ASSUMPTION: valid powered digital levels and settled controls; see part specification.
module ttl_74x16209 (
    input logic [2:0] control,
    input logic [35:0] external_data,external_drive,
    output logic [35:0] resolved,valid,conflict,weak_drive
);
    logic [2:0] selected;
    assign selected=control;
    logic [143:0] topology;
    logic [35:0] weak_mask;
    always_comb begin
        topology='0;weak_mask='0;
        case(selected)
            3'd0: begin topology=144'h842184218421842184218421842184218421; weak_mask=36'h0; end
            3'd1: begin topology=144'h852585258525852585258525852585258525; weak_mask=36'h0; end
            3'd2: begin topology=144'h942994299429942994299429942994299429; weak_mask=36'h0; end
            3'd3: begin topology=144'h866186618661866186618661866186618661; weak_mask=36'h0; end
            3'd4: begin topology=144'ha4a1a4a1a4a1a4a1a4a1a4a1a4a1a4a1a4a1; weak_mask=36'h0; end
            3'd5: begin topology=144'h842184218421842184218421842184218421; weak_mask=36'h0; end
            3'd6: begin topology=144'ha5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5; weak_mask=36'h0; end
            3'd7: begin topology=144'h966996699669966996699669966996699669; weak_mask=36'h0; end
            default: begin topology='x;weak_mask='x;end
        endcase
    end
    for(genvar bit_index=0;bit_index<9;bit_index++) begin : g_line
        for(genvar destination=0;destination<4;destination++) begin : g_port
            logic strong_one,strong_zero,weak_one,weak_zero,strong_present,weak_present;
            always_comb begin
                strong_one=0;strong_zero=0;weak_one=0;weak_zero=0;
                for(integer source_port=0;source_port<4;source_port=source_port+1) begin
                    if(topology[bit_index*16+destination*4+source_port]) begin
                        if(external_drive[source_port*9+bit_index]) begin
                            if(external_data[source_port*9+bit_index]) strong_one=1;
                            else strong_zero=1;
                        end
                        if(weak_mask[source_port*9+bit_index]) begin
                            if(1'b0) weak_one=1;
                            else weak_zero=1;
                        end
                    end
                end
                strong_present=strong_one || strong_zero;
                weak_present=weak_one || weak_zero;
                conflict[destination*9+bit_index]=strong_present?(strong_one && strong_zero):(weak_one && weak_zero);
                valid[destination*9+bit_index]=(strong_present || weak_present) && !conflict[destination*9+bit_index];
                resolved[destination*9+bit_index]=valid[destination*9+bit_index] && (strong_present?strong_one:weak_one);
                weak_drive[destination*9+bit_index]=!strong_present && weak_present;
            end
        end
    end
endmodule
