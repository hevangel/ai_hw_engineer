// Native Am2910 digital behavior: AMD 1978 family book Table I/II.
module amd_am2910 (
  input logic cp_i,
  input logic [3:0] instruction_i,
  input logic [11:0] d_i,
  input logic cc_n_i, ccen_n_i, ci_i, rld_n_i, oe_n_i,
  output logic [11:0] y_o,
  output logic y_oe_o, full_n_o, pl_n_o, map_n_o, vect_n_o
);
  logic [11:0] upc, counter;
  logic [11:0] stack [0:4];
  logic [2:0] depth;
  logic pass_condition, push_stack, pop_stack, clear_stack;
  logic load_counter, decrement_counter;
  logic [2:0] top_slot, write_slot;
  logic [11:0] top_address;

  // ASSUMPTION: legal physical depth is 0..5; power-up state is unspecified.
  // ASSUMPTION: empty-stack data is unspecified; return stored bottom data.
  assign top_slot = depth==0 ? 3'd0 : depth-3'd1;
  assign write_slot = depth==5 ? 3'd4 : depth;
  assign top_address = stack[top_slot];
  assign pass_condition = ccen_n_i || !cc_n_i;
  assign y_oe_o = !oe_n_i;
  assign full_n_o = depth!=5;
  assign pl_n_o = instruction_i==2 || instruction_i==6;
  assign map_n_o = instruction_i!=2;
  assign vect_n_o = instruction_i!=6;

  always_comb begin
    y_o=upc;
    push_stack=0; pop_stack=0; clear_stack=0;
    load_counter=0; decrement_counter=0;
    case (instruction_i)
      4'h0: begin y_o=0; clear_stack=1; end
      4'h1: if (pass_condition) begin y_o=d_i; push_stack=1; end
      4'h2: y_o=d_i;
      4'h3: if (pass_condition) y_o=d_i;
      4'h4: begin push_stack=1; load_counter=pass_condition; end
      4'h5: begin y_o=pass_condition ? d_i:counter; push_stack=1; end
      4'h6: if (pass_condition) y_o=d_i;
      4'h7: y_o=pass_condition ? d_i:counter;
      4'h8: if (counter!=0) begin y_o=top_address; decrement_counter=1; end
             else pop_stack=1;
      4'h9: if (counter!=0) begin y_o=d_i; decrement_counter=1; end
      4'ha: if (pass_condition) begin y_o=top_address; pop_stack=1; end
      4'hb: if (pass_condition) begin y_o=d_i; pop_stack=1; end
      4'hc: load_counter=1;
      4'hd: if (pass_condition) pop_stack=1; else y_o=top_address;
      4'he: begin end
      4'hf: begin
        decrement_counter=counter!=0;
        if (pass_condition) pop_stack=1;
        else if (counter!=0) y_o=top_address;
        else begin y_o=d_i; pop_stack=1; end
      end
      default: begin end
    endcase
  end
  always_ff @(posedge cp_i) begin
    upc<=y_o+12'(ci_i);
    if (!rld_n_i || load_counter) counter<=d_i;
    else if (decrement_counter) counter<=counter-12'd1;
    if (clear_stack) depth<=0;
    else if (push_stack) begin
      stack[write_slot]<=upc;
      if (depth<5) depth<=depth+3'd1;
    end else if (pop_stack && depth!=0) depth<=depth-3'd1;
  end
`ifdef FORMAL
  `include "amd_am2910_props.sv"
`endif
endmodule
