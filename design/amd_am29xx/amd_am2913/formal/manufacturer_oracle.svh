// Generated from manufacturer truth tables.
logic [2:0] gold_a; logic gold_eo, gold_enable;
always_comb begin gold_a=0;gold_eo=1;
casez({ei_n_i,request_n_i})
9'b1????????:begin gold_a=3'b000;gold_eo=1'b1;end
9'b011111111:begin gold_a=3'b000;gold_eo=1'b0;end
9'b00???????:begin gold_a=3'b111;gold_eo=1'b1;end
9'b010??????:begin gold_a=3'b110;gold_eo=1'b1;end
9'b0110?????:begin gold_a=3'b101;gold_eo=1'b1;end
9'b01110????:begin gold_a=3'b100;gold_eo=1'b1;end
9'b011110???:begin gold_a=3'b011;gold_eo=1'b1;end
9'b0111110??:begin gold_a=3'b010;gold_eo=1'b1;end
9'b01111110?:begin gold_a=3'b001;gold_eo=1'b1;end
9'b011111110:begin gold_a=3'b000;gold_eo=1'b1;end
endcase
gold_enable=0;
casez({g5_n_i,g4_n_i,g3_n_i,g2_i,g1_i})
5'b00011:gold_enable=1'b1;
5'b????0:gold_enable=1'b0;
5'b???0?:gold_enable=1'b0;
5'b??1??:gold_enable=1'b0;
5'b?1???:gold_enable=1'b0;
5'b1????:gold_enable=1'b0;
endcase
end
