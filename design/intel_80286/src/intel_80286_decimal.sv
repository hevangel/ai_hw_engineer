// Intel 210498-005 Appendix B; 286 edge details: see spec/decimal_execution.md.
module intel_80286_decimal (
    input logic [2:0] operation_i,
    input logic [15:0] ax_i, flags_i,
    input logic [7:0] base_i,
    output logic [15:0] ax_o, flags_o
);
    logic low_adjust, high_adjust;
    logic [7:0] adjusted;
    always_comb begin
        ax_o=ax_i; flags_o=flags_i;
        low_adjust=ax_i[3:0]>9 || flags_i[4];
        high_adjust=ax_i[7:0]>8'h99 || flags_i[0];
        adjusted=ax_i[7:0];
        case (operation_i)
            0,1: begin
                if (operation_i==0)
                    adjusted=ax_i[7:0]+(low_adjust ? 8'h06 : 8'h00)+(high_adjust ? 8'h60 : 8'h00);
                else adjusted=ax_i[7:0]-(low_adjust ? 8'h06 : 8'h00)-(high_adjust ? 8'h60 : 8'h00);
                ax_o[7:0]=adjusted;
                flags_o[4]=low_adjust;
                flags_o[0]=high_adjust || (operation_i==1 && low_adjust && ax_i[7:0]<6);
                flags_o[7]=adjusted[7]; flags_o[6]=adjusted==0; flags_o[2]=~^adjusted;
            end
            2,3: begin
                // ASSUMPTION: A7. Pinned 286 emulator resolves whole-AX edge propagation; primary prose is ambiguous.
                if (low_adjust) ax_o=operation_i==2 ? ax_i+16'h0106 : ax_i-16'h0106;
                ax_o[7:4]=0;
                flags_o[4]=low_adjust; flags_o[0]=low_adjust;
            end
            4: begin
                // ASSUMPTION: A7. Nondecimal bases follow the pinned independent Intel-CPU implementation.
                adjusted=8'(ax_i[7:0]+(ax_i[15:8]*base_i));
                ax_o={8'h0,adjusted};
                flags_o[7]=adjusted[7]; flags_o[6]=adjusted==0; flags_o[2]=~^adjusted;
            end
            default: begin end
        endcase
        // ASSUMPTION: A3. Preserve manufacturer-undefined adjustment flags.
    end
endmodule
