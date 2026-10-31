// Independent reference derived from 86Box x86_ops_bcd.h, revision
// 1db9ae4cc910b0b7e6e9b49995910b0cc19747a0; see spec/decimal_execution.md.
// Uses the artifact's sequential byte adjustments and flag reconstruction.
module intel_80286_decimal_props (
    input logic [2:0] operation,
    input logic [15:0] ax, flags,
    input logic [7:0] base
);
    logic [15:0] result, result_flags, expected, expected_flags;
    integer unsigned low_byte, whole, old_byte;
    logic adjust_low, old_carry, carry, auxiliary;
    intel_80286_decimal dut(.operation_i(operation),.ax_i(ax),.flags_i(flags),.base_i(base),
                            .ax_o(result),.flags_o(result_flags));
    always_comb begin
        expected=ax; expected_flags=flags;
        old_byte={24'h0,ax[7:0]}; low_byte=old_byte; whole={16'h0,ax};
        old_carry=flags[0]; carry=0; auxiliary=flags[4];
        adjust_low=(old_byte%16)>9 || auxiliary;
        case(operation)
            0,1: begin
                if (adjust_low) begin
                    if (operation==0) low_byte=(low_byte+6)%256;
                    else begin carry=old_carry || low_byte<6; low_byte=(low_byte+256-6)%256; end
                    auxiliary=1;
                end else auxiliary=0;
                if (old_byte>153 || old_carry) begin
                    low_byte=operation==0 ? (low_byte+96)%256 : (low_byte+256-96)%256;
                    carry=1;
                end else if (operation==0) carry=0;
                expected={ax[15:8],8'(low_byte)};
                expected_flags[0]=carry; expected_flags[4]=auxiliary;
            end
            2,3: begin
                if (adjust_low) begin
                    whole=operation==2 ? (whole+6+256)%65536 : (whole+65536-6-256)%65536;
                    expected_flags[0]=1; expected_flags[4]=1;
                end else begin expected_flags[0]=0; expected_flags[4]=0; end
                expected=16'(whole & 32'hff0f);
            end
            4: begin
                low_byte=(old_byte+({24'h0,ax[15:8]}*{24'h0,base}))%256;
                expected=16'(low_byte);
            end
            default: begin end
        endcase
        if (operation==0 || operation==1 || operation==4) begin
            expected_flags[7]=low_byte>=128; expected_flags[6]=low_byte==0;
            expected_flags[2]=~^(8'(low_byte));
        end
        assert(result==expected);
        // Undefined bits follow project A3, so preservation is checked too.
        assert(result_flags==expected_flags);
        cover(operation==2 && ax==16'hfffa && result==16'h0100);
        cover(operation==3 && ax==0 && flags[4] && result==16'hfe0a);
        cover(operation==1 && ax[7:0]==0 && flags[4] && !flags[0] && result_flags[0]);
        cover(operation==4 && base==0 && result[15:8]==0);
    end
endmodule
