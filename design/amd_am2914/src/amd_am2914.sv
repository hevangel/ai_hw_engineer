module amd_am2914 (
  input logic cp_i,
  input logic [7:0] p_n_i, m_i,
  input logic [2:0] s_i,
  input logic [3:0] instruction_i,
  input logic ie_n_i, lb_i, ge_n_i, gar_n_i, id_n_i,
  output logic [7:0] m_o,
  output logic [2:0] s_o, v_o,
  output logic m_oe_o, s_oe_o, v_oe_o,
  output logic irq_pull_low_o, gs_n_o, gas_n_o, rd_n_o, pd_o, sv_n_o
);
  logic [7:0] pulse, edge_data, pending, mask, unmasked, clear_bits;
  logic [2:0] status, held_vector, vector_code;
  logic group_n, request_enabled, vector_clear_enabled, overflow_n;
  logic detected, eligible;
  always_comb begin
    unmasked=pending & ~mask;
    detected=|unmasked;
    vector_code=0;
    for(integer bit_index=0;bit_index<8;bit_index=bit_index+1)
      if(unmasked[bit_index])vector_code=3'(bit_index);
    eligible=id_n_i && detected && vector_code>=status;
    pd_o=!group_n || (detected && vector_code>=status);
    rd_n_o=id_n_i && !pd_o;
    irq_pull_low_o=eligible && request_enabled;
    gs_n_o=group_n;
    sv_n_o=overflow_n;
    m_o=mask;
    s_o=status;
    v_o=vector_code;
    m_oe_o=!ie_n_i && (instruction_i==3 || instruction_i==7);
    s_oe_o=!ie_n_i && instruction_i==6 && !group_n;
    v_oe_o=!ie_n_i && instruction_i==5 && eligible;
    gas_n_o=!(v_oe_o && vector_code==7);
    clear_bits=0;
    if(!ie_n_i) begin
      case(instruction_i)
        4'd0,4'd1:clear_bits=8'hff;
        4'd2:clear_bits=m_i;
        4'd3:clear_bits=mask;
        4'd4:if(vector_clear_enabled)clear_bits=8'b1<<held_vector;
        default:begin end
      endcase
    end
  end
  for(genvar b=0;b<8;b=b+1) begin : pulse_input
    // Figure1: a live LOW has set priority; clears operate while CP LOW.
    always_latch begin
      if(!p_n_i[b])pulse[b]=1;
      else if(lb_i || (!cp_i && clear_bits[b]))pulse[b]=0;
    end
  end
  // ASSUMPTION: settled native setup/hold. This LOW-phase capture represents
  // D immediately before CP rises; eight bits adapt zero-delay event ordering
  // when the physical clock-gated clear pulse ends. Not extra silicon state.
  always_latch if(!cp_i)edge_data=pulse & ~clear_bits;
  always_ff @(posedge cp_i) begin
    pending<=edge_data;
    if(!ie_n_i) begin
      case(instruction_i)
        4'd0:begin
          mask<=0;status<=0;group_n<=gar_n_i;request_enabled<=1;
          held_vector<=0;vector_clear_enabled<=0;overflow_n<=1;
        end
        4'd1,4'd4:begin held_vector<=0;vector_clear_enabled<=0; end
        4'd5:begin
          status<=eligible ? vector_code+3'd1 : 3'd0;
          held_vector<=vector_code;
          vector_clear_enabled<=eligible;
          // ASSUMPTION: use explicit PDF187 functional description rather
          // than the ambiguous DET overbar in the scanned Figure7.
          group_n<=(gar_n_i && !detected) || !gas_n_o || !id_n_i;
          // ASSUMPTION: explicit original application/1987 SV pin rule:
          // overflow remains asserted until MCLR/LDSTA, including idle RDVC.
          if(!gas_n_o)overflow_n<=0;
        end
        4'd8:mask<=8'hff;
        4'd9:begin status<=ge_n_i ? 3'd0:s_i;group_n<=ge_n_i;overflow_n<=1;end
        4'd10:mask<=mask & ~m_i;
        4'd11:mask<=mask | m_i;
        4'd12:mask<=0;
        4'd13:request_enabled<=0;
        4'd14:mask<=m_i;
        4'd15:request_enabled<=1;
        default:begin end
      endcase
    end
  end
`ifdef FORMAL
  `include "amd_am2914_props.sv"
`endif
endmodule
