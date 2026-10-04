// Independent survivor checker compiled directly from manufacturer CSV.
function automatic [255:0] documented_stack(input logic [6:0] cmd,input logic [127:0] old_stack,input logic [31:0] result,input logic overflow_format);
 logic [127:0] value,mask;
 begin value=0;mask=0;case(cmd)
7'h00:begin value={old_stack[127:96],old_stack[95:64],old_stack[63:32],old_stack[31:0]};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'hffffffff};end
7'h01:begin value={result,old_stack[95:64],old_stack[63:32],32'd0};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'h00000000};end
7'h02:begin value={result,old_stack[95:64],32'd0,32'd0};mask={32'hffffffff,32'hffffffff,32'h00000000,32'h00000000};end
7'h03:begin value={result,old_stack[95:64],32'd0,32'd0};mask={32'hffffffff,32'hffffffff,32'h00000000,32'h00000000};end
7'h04:begin value={result,old_stack[95:64],32'd0,32'd0};mask={32'hffffffff,32'hffffffff,32'h00000000,32'h00000000};end
7'h05:begin value={result,32'd0,32'd0,32'd0};mask={32'hffffffff,32'h00000000,32'h00000000,32'h00000000};end
7'h06:begin value={result,32'd0,32'd0,32'd0};mask={32'hffffffff,32'h00000000,32'h00000000,32'h00000000};end
7'h07:begin value={result,old_stack[95:64],32'd0,32'd0};mask={32'hffffffff,32'hffffffff,32'h00000000,32'h00000000};end
7'h08:begin value={result,old_stack[95:64],32'd0,32'd0};mask={32'hffffffff,32'hffffffff,32'h00000000,32'h00000000};end
7'h09:begin value={result,old_stack[95:64],32'd0,32'd0};mask={32'hffffffff,32'hffffffff,32'h00000000,32'h00000000};end
7'h0a:begin value={result,old_stack[95:64],32'd0,32'd0};mask={32'hffffffff,32'hffffffff,32'h00000000,32'h00000000};end
7'h0b:begin value={result,old_stack[63:32],32'd0,32'd0};mask={32'hffffffff,32'hffffffff,32'h00000000,32'h00000000};end
7'h10:begin value={result,old_stack[63:32],old_stack[31:0],32'd0};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'h00000000};end
7'h11:begin value={result,old_stack[63:32],old_stack[31:0],32'd0};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'h00000000};end
7'h12:begin value={result,old_stack[63:32],old_stack[31:0],32'd0};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'h00000000};end
7'h13:begin value={result,old_stack[63:32],old_stack[31:0],32'd0};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'h00000000};end
7'h15:begin value={result,old_stack[95:64],old_stack[63:32],old_stack[31:0]};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'hffffffff};value[127:96]=old_stack[119]?old_stack[127:96]^32'h80000000:old_stack[127:96];end
7'h17:begin value={old_stack[127:96],old_stack[127:96],old_stack[95:64],old_stack[63:32]};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'hffffffff};end
7'h18:begin value={old_stack[95:64],old_stack[63:32],old_stack[31:0],old_stack[127:96]};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'hffffffff};end
7'h19:begin value={old_stack[95:64],old_stack[127:96],old_stack[63:32],old_stack[31:0]};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'hffffffff};end
7'h1a:begin value={32'h02c90fda,old_stack[127:96],old_stack[95:64],old_stack[63:32]};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'hffffffff};end
7'h1c:begin value={result,old_stack[95:64],old_stack[63:32],32'd0};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'h00000000};end
7'h1d:begin value={result[31:16],result[15:0],old_stack[111:96],old_stack[95:80],old_stack[79:64],old_stack[63:48],16'd0,16'd0};mask={16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'h0000,16'h0000};end
7'h1e:begin value={result,old_stack[95:64],old_stack[63:32],32'd0};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'h00000000};end
7'h1f:begin value={result[15:0],old_stack[95:80],old_stack[79:64],old_stack[63:48],old_stack[47:32],16'd0,16'd0,16'd0};mask={16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'h0000,16'h0000,16'h0000};if(overflow_format)begin value={old_stack[127:32],32'd0};mask={96'hffffffffffffffffffffffff,32'd0};end end
7'h2c:begin value={result,old_stack[63:32],old_stack[31:0],old_stack[127:96]};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'hffffffff};end
7'h2d:begin value={result,old_stack[63:32],old_stack[31:0],old_stack[127:96]};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'hffffffff};end
7'h2e:begin value={result,old_stack[63:32],old_stack[31:0],32'd0};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'h00000000};end
7'h2f:begin value={result,old_stack[63:32],old_stack[31:0],32'd0};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'h00000000};end
7'h34:begin value={result,old_stack[95:64],old_stack[63:32],old_stack[31:0]};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'hffffffff};end
7'h36:begin value={result,old_stack[63:32],old_stack[31:0],32'd0};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'h00000000};end
7'h37:begin value={old_stack[127:96],old_stack[127:96],old_stack[95:64],old_stack[63:32]};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'hffffffff};end
7'h38:begin value={old_stack[95:64],old_stack[63:32],old_stack[31:0],old_stack[127:96]};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'hffffffff};end
7'h39:begin value={old_stack[95:64],old_stack[127:96],old_stack[63:32],old_stack[31:0]};mask={32'hffffffff,32'hffffffff,32'hffffffff,32'hffffffff};end
7'h6c:begin value={result[15:0],old_stack[95:80],old_stack[79:64],old_stack[63:48],old_stack[47:32],old_stack[31:16],old_stack[15:0],old_stack[127:112]};mask={16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff};end
7'h6d:begin value={result[15:0],old_stack[95:80],old_stack[79:64],old_stack[63:48],old_stack[47:32],old_stack[31:16],old_stack[15:0],old_stack[127:112]};mask={16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff};end
7'h6e:begin value={result[15:0],old_stack[95:80],old_stack[79:64],old_stack[63:48],old_stack[47:32],old_stack[31:16],old_stack[15:0],16'd0};mask={16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'h0000};end
7'h6f:begin value={result[15:0],old_stack[95:80],old_stack[79:64],old_stack[63:48],old_stack[47:32],old_stack[31:16],old_stack[15:0],16'd0};mask={16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'h0000};end
7'h74:begin value={result[15:0],old_stack[111:96],old_stack[95:80],old_stack[79:64],old_stack[63:48],old_stack[47:32],old_stack[31:16],old_stack[15:0]};mask={16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff};end
7'h76:begin value={result[15:0],old_stack[95:80],old_stack[79:64],old_stack[63:48],old_stack[47:32],old_stack[31:16],old_stack[15:0],16'd0};mask={16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'h0000};end
7'h77:begin value={old_stack[127:112],old_stack[127:112],old_stack[111:96],old_stack[95:80],old_stack[79:64],old_stack[63:48],old_stack[47:32],old_stack[31:16]};mask={16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff};end
7'h78:begin value={old_stack[111:96],old_stack[95:80],old_stack[79:64],old_stack[63:48],old_stack[47:32],old_stack[31:16],old_stack[15:0],old_stack[127:112]};mask={16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff};end
7'h79:begin value={old_stack[111:96],old_stack[127:112],old_stack[95:80],old_stack[79:64],old_stack[63:48],old_stack[47:32],old_stack[31:16],old_stack[15:0]};mask={16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff,16'hffff};end
default:begin end
endcase documented_stack={mask,value};end
endfunction
function automatic [6:0] documented_flags(input logic [6:0] cmd);begin case(cmd)
7'h00:documented_flags=7'd127;
7'h01:documented_flags=7'd126;
7'h02:documented_flags=7'd96;
7'h03:documented_flags=7'd96;
7'h04:documented_flags=7'd126;
7'h05:documented_flags=7'd126;
7'h06:documented_flags=7'd126;
7'h07:documented_flags=7'd96;
7'h08:documented_flags=7'd126;
7'h09:documented_flags=7'd126;
7'h0a:documented_flags=7'd126;
7'h0b:documented_flags=7'd126;
7'h10:documented_flags=7'd126;
7'h11:documented_flags=7'd126;
7'h12:documented_flags=7'd126;
7'h13:documented_flags=7'd126;
7'h15:documented_flags=7'd96;
7'h17:documented_flags=7'd96;
7'h18:documented_flags=7'd96;
7'h19:documented_flags=7'd96;
7'h1a:documented_flags=7'd96;
7'h1c:documented_flags=7'd96;
7'h1d:documented_flags=7'd96;
7'h1e:documented_flags=7'd126;
7'h1f:documented_flags=7'd126;
7'h2c:documented_flags=7'd127;
7'h2d:documented_flags=7'd127;
7'h2e:documented_flags=7'd126;
7'h2f:documented_flags=7'd126;
7'h34:documented_flags=7'd126;
7'h36:documented_flags=7'd126;
7'h37:documented_flags=7'd96;
7'h38:documented_flags=7'd96;
7'h39:documented_flags=7'd96;
7'h6c:documented_flags=7'd127;
7'h6d:documented_flags=7'd127;
7'h6e:documented_flags=7'd126;
7'h6f:documented_flags=7'd126;
7'h74:documented_flags=7'd126;
7'h76:documented_flags=7'd126;
7'h77:documented_flags=7'd96;
7'h78:documented_flags=7'd96;
7'h79:documented_flags=7'd96;
default:documented_flags=0;endcase end endfunction
