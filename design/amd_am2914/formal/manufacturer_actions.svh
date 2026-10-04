// Generated solely from original instruction effects.
function automatic [17:0] manufacturer_actions(input logic [3:0] op,input logic disabled);
begin manufacturer_actions=0; if(!disabled)begin case(op)
4'h0:manufacturer_actions=18'd70825;
4'h1:manufacturer_actions=18'd4224;
4'h2:manufacturer_actions=18'd256;
4'h3:manufacturer_actions=18'd16768;
4'h4:manufacturer_actions=18'd4608;
4'h5:manufacturer_actions=18'd139384;
4'h6:manufacturer_actions=18'd32768;
4'h7:manufacturer_actions=18'd16384;
4'h8:manufacturer_actions=18'd2;
4'h9:manufacturer_actions=18'd65616;
4'ha:manufacturer_actions=18'd3;
4'hb:manufacturer_actions=18'd4;
4'hc:manufacturer_actions=18'd1;
4'hd:manufacturer_actions=18'd2048;
4'he:manufacturer_actions=18'd5;
4'hf:manufacturer_actions=18'd1024;
endcase end end endfunction
