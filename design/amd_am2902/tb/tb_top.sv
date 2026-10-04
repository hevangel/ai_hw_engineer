`timescale 1ns/1ps
module tb_top;
  logic [3:0] p_n_i=0,g_n_i=0;
  logic cn_i=0;
  logic [2:0] carry_o;
  logic p_n_o,g_n_o;
  amd_am2902 dut (.*);
  logic [15:0] x=0,y=0,wide_f;
  logic [2:0] function_code=0;
  logic wide_cn=0;
  logic [3:0] alu_p,alu_g,alu_carry,alu_overflow,alu_sign,alu_zero;
  logic [2:0] predicted;
  logic group_p,group_g;
  logic [3:0] alu_cin;
  assign alu_cin={predicted,wide_cn};
  amd_am2902 word_carry (.p_n_i(alu_p),.g_n_i(alu_g),.cn_i(wide_cn),.carry_o(predicted),.p_n_o(group_p),.g_n_o(group_g));
  for (genvar nibble=0;nibble<4;nibble++) begin: word_alu
    amd_am2901_alu alu (.r_i(x[nibble*4+:4]),.s_i(y[nibble*4+:4]),.function_i(function_code),.cn_i(alu_cin[nibble]),
        .f_o(wide_f[nibble*4+:4]),.cn4_o(alu_carry[nibble]),.p_n_o(alu_p[nibble]),.g_n_o(alu_g[nibble]),
        .ovr_o(alu_overflow[nibble]),.f3_o(alu_sign[nibble]),.zero_o(alu_zero[nibble]));
  end
  logic [15:0] level_p=0,level_g=0;
  logic level_cn=0;
  logic [3:0] block_p,block_g,block_cin;
  logic [2:0] block_carries;
  logic top_p,top_g;
  logic [11:0] leaf_carries;
  logic [15:0] carries64;
  assign block_cin={block_carries,level_cn};
  amd_am2902 root (.p_n_i(block_p),.g_n_i(block_g),.cn_i(level_cn),.carry_o(block_carries),.p_n_o(top_p),.g_n_o(top_g));
  for (genvar block_index=0;block_index<4;block_index++) begin: leaves
    amd_am2902 leaf (.p_n_i(level_p[block_index*4+:4]),.g_n_i(level_g[block_index*4+:4]),.cn_i(block_cin[block_index]),
        .carry_o(leaf_carries[block_index*3+:3]),.p_n_o(block_p[block_index]),.g_n_o(block_g[block_index]));
    assign carries64[block_index*4+:4]={leaf_carries[block_index*3+:3],block_cin[block_index]};
  end
  integer pin_checks=0,word_checks=0,tree_checks=0;
  logic [31:0] rng=32'h29021975;
  function automatic logic [31:0] next_random(input logic [31:0] value);
    return value*32'd1664525+32'd1013904223;
  endfunction
  task automatic pins;
    logic [4:0] c,g;
    c[0]=cn_i;g[0]=0;
    for (int i=0;i<4;i++) begin c[i+1]=!g_n_i[i] || (!p_n_i[i] && c[i]);g[i+1]=!g_n_i[i] || (!p_n_i[i] && g[i]);end
    #1;
    if (carry_o!==c[3:1] || g_n_o!==!g[4] || p_n_o!==(|p_n_i)) $fatal(1,"physical carry/group mismatch");
    pin_checks++;
  endtask
  task automatic word_math;
    logic [15:0] xx,yy;
    logic [16:0] sum;
    logic ov;
    xx=function_code==1 ? ~x:x; yy=function_code==2 ? ~y:y;
    sum={1'b0,xx}+{1'b0,yy}+17'(wide_cn);
    ov=(xx[15]==yy[15]) && (sum[15]!=xx[15]);
    #1;
    if (wide_f!==sum[15:0] || alu_carry[3]!==sum[16] || alu_overflow[3]!==ov ||
        alu_carry[2:0]!==predicted || (!group_g || (!group_p && wide_cn))!==sum[16] ||
        alu_sign[3]!==sum[15] || (&alu_zero)!==(sum[15:0]==0)) $fatal(1,"actual Am2901/Am2902 arithmetic cascade mismatch");
    for (int i=0;i<4;i++) begin
      if (alu_sign[i]!==sum[i*4+3] || alu_zero[i]!==(sum[i*4+:4]==0) ||
          alu_overflow[i]!==((xx[i*4+3]==yy[i*4+3]) && (sum[i*4+3]!=xx[i*4+3])))
        $fatal(1,"individual real-slice status mismatch");
    end
    word_checks++;
  endtask
  task automatic tree;
    logic [16:0] reference_c;
    logic generated;
    reference_c[0]=level_cn;generated=0;
    for (int i=0;i<16;i++) begin
      reference_c[i+1]=!level_g[i] || (!level_p[i] && reference_c[i]);
      generated=!level_g[i] || (!level_p[i] && generated);
    end
    #1;
    if (carries64!==reference_c[15:0] || top_p!==(|level_p) || top_g!==!generated ||
        (!top_g || (!top_p && level_cn))!==reference_c[16]) $fatal(1,"two-level carry network mismatch");
    tree_checks++;
  endtask
  task automatic full_word(input logic [63:0] first,second);
    logic [64:0] expected;
    logic [63:0] actual;
    logic [4:0] nibble_sum;
    for (int i=0;i<16;i++) begin
      level_p[i]=!(&(first[i*4+:4]|second[i*4+:4]));
      nibble_sum={1'b0,first[i*4+:4]}+{1'b0,second[i*4+:4]};
      level_g[i]=!nibble_sum[4];
    end
    tree();
    for (int i=0;i<16;i++) begin
      nibble_sum={1'b0,first[i*4+:4]}+{1'b0,second[i*4+:4]}+5'(carries64[i]);
      actual[i*4+:4]=nibble_sum[3:0];
    end
    expected={1'b0,first}+{1'b0,second}+65'(level_cn);
    if (actual!==expected[63:0] || (!top_g || (!top_p && level_cn))!==expected[64]) $fatal(1,"64-bit arithmetic result mismatch");
  endtask
  initial begin
    for (int value=0;value<512;value++) begin p_n_i=4'(value);g_n_i=4'(value>>4);cn_i=1'(value>>8);pins();end
    for (int func=0;func<3;func++) begin
      function_code=3'(func);
      for (int bit_index=0;bit_index<16;bit_index++) for (int carry=0;carry<2;carry++) begin
        x=16'hffff;y=16'(1<<bit_index);wide_cn=1'(carry);word_math();
        x=16'(1<<bit_index);y=16'hffff;word_math();
      end
      for (int trial=0;trial<16384;trial++) begin
        rng=next_random(rng);x=rng[31:16];rng=next_random(rng);y=rng[31:16];wide_cn=1'(trial);word_math();
      end
    end
    for (int trial=0;trial<65536;trial++) begin
      level_cn=1'(trial);rng=next_random(rng);level_p=rng[31:16];rng=next_random(rng);level_g=rng[31:16];tree();
    end
    for (int carry=0;carry<2;carry++) begin
      level_cn=1'(carry);full_word(64'hffffffffffffffff,0);full_word(64'hffffffffffffffff,1);
      for (int bit_index=0;bit_index<64;bit_index++) full_word(64'hffffffffffffffff,64'b1<<bit_index);
    end
    for (int trial=0;trial<16384;trial++) begin
      logic [63:0] first,second;
      rng=next_random(rng);first[31:0]=rng;rng=next_random(rng);first[63:32]=rng;
      rng=next_random(rng);second[31:0]=rng;rng=next_random(rng);second[63:32]=rng;
      level_cn=1'(trial);full_word(first,second);
    end
    $display("TEST PASSED: %0d pin vectors, %0d actual-ALU 16-bit cases, %0d two-level carry/64-bit cases",pin_checks,word_checks,tree_checks);
    $finish;
  end
endmodule
