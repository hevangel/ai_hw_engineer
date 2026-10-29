`include "table_oracle.svh"
  (* anyconst *) logic [2:0] watched_slot;
  logic past_valid=0;
  logic [6:0] reference_actions;
  logic [11:0] reference_y;
  assign reference_actions=manufacturer_table(instruction_i,counter!=0,ccen_n_i || !cc_n_i);
  always_comb begin
    case(reference_actions[2:0])
      0: reference_y=upc;
      1: reference_y=d_i;
      2: reference_y=counter;
      3: reference_y=stack[depth==0 ? 3'd0:depth-3'd1];
      default: reference_y=0;
    endcase
  end
  always_ff @(posedge cp_i) begin
    if (!past_valid) begin assume(depth<=5); assume(watched_slot<5); end
    past_valid<=1;
    assert(depth<=5);
    assert(y_o==reference_y);
    assert(y_oe_o==!oe_n_i);
    assert(full_n_o==(depth!=5));
    assert({pl_n_o,map_n_o,vect_n_o}==(instruction_i==2 ? 3'b101:instruction_i==6 ? 3'b110:3'b011));
    if(past_valid) begin
      assert(upc==$past(reference_y)+12'($past(ci_i)));
      if (!$past(rld_n_i) || $past(reference_actions[5])) assert(counter==$past(d_i));
      else if ($past(reference_actions[6])) assert(counter==$past(counter)-12'd1);
      else assert(counter==$past(counter));
      case ($past(reference_actions[4:3]))
        0: assert(depth==$past(depth));
        1: assert(depth==($past(depth)<5 ? $past(depth)+3'd1:3'd5));
        2: assert(depth==($past(depth)>0 ? $past(depth)-3'd1:3'd0));
        3: assert(depth==0);
      endcase
      if ($past(reference_actions[4:3])==1 && watched_slot==($past(depth)==5 ? 3'd4:$past(depth)))
        assert(stack[watched_slot]==$past(upc));
      else assert(stack[watched_slot]==$past(stack[watched_slot]));
    end
    for (int op=0;op<16;op++) cover(past_valid && instruction_i==4'(op) && depth>0 && counter!=0);
    cover(past_valid && depth==5 && reference_actions[4:3]==1);
    cover(past_valid && depth==0 && reference_actions[4:3]==2);
    cover(past_valid && instruction_i==15 && counter!=0 && !pass_condition);
    cover(past_valid && instruction_i==15 && counter==0 && !pass_condition);
    cover(past_valid && instruction_i==15 && counter!=0 && pass_condition);
    cover(past_valid && reference_actions[6] && !rld_n_i && counter!=d_i);
    cover(past_valid && y_o==12'hfff && ci_i && oe_n_i);
  end
