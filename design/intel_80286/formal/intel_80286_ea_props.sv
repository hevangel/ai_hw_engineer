`ifdef FORMAL
// Intel table B-1: offsets are modular sums and BP selects the default SS.
module intel_80286_ea_props (
    input logic [4:0] mode,
    input logic [15:0] bx,bp,si,di,displacement
);
    logic [15:0] offset;
    logic stack;
    logic [1:0] bytes_count;
    logic [31:0] expected_base;
    intel_80286_ea dut(.address_mode_i(mode),.bx_i(bx),.bp_i(bp),.si_i(si),.di_i(di),
        .displacement_i(displacement),.offset_o(offset),.stack_o(stack),.displacement_bytes_o(bytes_count));
    always_comb begin
        expected_base=0;
        case (mode[2:0])
            0: expected_base={16'h0,bx}+{16'h0,si};
            1: expected_base={16'h0,bx}+{16'h0,di};
            2: expected_base={16'h0,bp}+{16'h0,si};
            3: expected_base={16'h0,bp}+{16'h0,di};
            4: expected_base={16'h0,si};
            5: expected_base={16'h0,di};
            6: expected_base=mode[4:3]==0 ? 0 : {16'h0,bp};
            7: expected_base={16'h0,bx};
        endcase
        if (mode[4:3]!=3) begin
            assert(offset == ((expected_base+{16'h0,displacement}) % 65536));
            assert(stack == (mode[2:0]==2 || mode[2:0]==3 || (mode[2:0]==6 && mode[4:3]!=0)));
            assert(bytes_count == (mode[4:3]==2 || (mode[4:3]==0 && mode[2:0]==6) ? 2 : mode[4:3]==1 ? 1 : 0));
        end
        cover(mode==0 && bx==16'hffff && si==1 && displacement==0 && offset==0);
        cover(mode==6 && displacement==16'hffff && offset==16'hffff && !stack);
        cover(mode==14 && bp==16'h8000 && displacement==16'hff80 && offset==16'h7f80 && stack);
    end
endmodule
`endif
