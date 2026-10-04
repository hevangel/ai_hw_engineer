`include "manufacturer_oracle.svh"
always_comb begin
  assert(a_o==gold_a);
  assert(eo_n_o==gold_eo);
  assert(a_oe_o==gold_enable);
  for(integer p=0;p<8;p=p+1)
    cover(a_oe_o && !ei_n_i && eo_n_o && a_o==3'(p));
  cover(a_oe_o && ei_n_i && a_o==0);
  cover(a_oe_o && !ei_n_i && !eo_n_o);
  cover(!g1_i && !a_oe_o && eo_n_o);
  cover(!g2_i && !a_oe_o && eo_n_o);
  cover(g3_n_i && !a_oe_o && eo_n_o);
  cover(g4_n_i && !a_oe_o && eo_n_o);
  cover(g5_n_i && !a_oe_o && eo_n_o);
end
