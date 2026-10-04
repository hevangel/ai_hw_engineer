`timescale 1ns/1ps
module tb_top;
  logic [3:0] x_i = 0;
  logic x_prev_i = 0;
  logic x_sign_i = 0;
  logic [1:0] y_i = 0;
  logic y_prev_i = 0;
  logic [3:0] k_i = 0;
  logic cn_i = 0;
  logic polarity_i = 0;
  logic [5:0] s_o;
  logic cn4_o;
  logic [7:0] array_x = 0;
  logic [3:0] array_y = 0;
  logic [7:0] array_k = 0;
  logic [11:0] array_product;
  integer slice_checks = 0;
  integer sign_checks = 0;
  integer array_checks = 0;
  logic [7:0] seen_booth = 0;
  logic [1:0] seen_polarity = 0;
  integer expected_array, ax_signed, ay_signed, addend;
  logic [6:0] expected_slice;
  amd_am2505 dut (.*);
  amd_am2505_array8x4 array_dut (
      .x_i(array_x), .y_i(array_y), .k_i(array_k),
      .polarity_i(polarity_i), .product_o(array_product)
  );

  // Math oracle from manufacturer's Booth table, separate from RTL gate decode.
  function automatic logic [6:0] reference_slice (
      input logic [3:0] xp, kp,
      input logic xmp,
      input logic [1:0] yp,
      input logic ymp, cp, pol
  );
    logic [3:0] xv, kv;
    logic [1:0] yv;
    logic xm, ym, cv;
    integer xsigned, ksigned, digit, result_value, operand_value, carry_sum;
    xv = xp ^ {4{pol}};
    kv = kp ^ {4{pol}};
    yv = yp ^ {2{pol}};
    xm = xmp ^ pol;
    ym = ymp ^ pol;
    cv = cp ^ pol;
    xsigned = int'($signed(xv));
    ksigned = int'($signed(kv));
    digit = int'(ym) + int'(yv[0]) - 2*int'(yv[1]);
    result_value = digit*xsigned + ksigned + int'(cv) - int'(yv[1]);
    if (digit == 2) result_value += int'(xm);
    if (digit == -2) result_value -= int'(xm);
    case ({yv[1],yv[0],ym})
      3'b000,3'b111: operand_value = 0;
      3'b001,3'b010,3'b101,3'b110: operand_value = int'(xv);
      3'b011,3'b100: operand_value = (2*int'(xv)+int'(xm)) & 15;
      default: operand_value = 0;
    endcase
    if (yv[1]) operand_value = 15 - operand_value;
    carry_sum = operand_value + int'(kv) + int'(cv);
    return {carry_sum >= 16, result_value[5:0]};
  endfunction

  initial begin
    for (integer pol_value = 0; pol_value < 2; pol_value++) begin
      polarity_i = 1'(pol_value);
      for (integer x_value = 0; x_value < 64; x_value++) begin
        {x_sign_i,x_prev_i,x_i} = 6'(x_value);
        for (integer y_value = 0; y_value < 8; y_value++) begin
          {y_prev_i,y_i} = 3'(y_value);
          for (integer k_value = 0; k_value < 16; k_value++) begin
            k_i = 4'(k_value);
            for (integer carry_value = 0; carry_value < 2; carry_value++) begin
              cn_i = 1'(carry_value);
              #1;
              expected_slice = reference_slice(x_i,k_i,x_prev_i,y_i,y_prev_i,cn_i,polarity_i);
              if ((s_o[3:0] ^ {4{polarity_i}}) !== expected_slice[3:0] ||
                  (cn4_o ^ polarity_i) !== expected_slice[6])
                $fatal(1,"slice low/carry mismatch P=%b X=%h Y=%h K=%h Cn=%b got=%h/%b expected=%h",
                       polarity_i,x_value,y_value,k_i,cn_i,s_o,cn4_o,expected_slice);
              slice_checks++;
              if (x_sign_i == x_i[3]) begin
                if ((s_o ^ {6{polarity_i}}) !== expected_slice[5:0])
                  $fatal(1,"signed extension mismatch got=%h expected=%h",s_o,expected_slice);
                sign_checks++;
              end
              seen_booth[{y_i[1]^polarity_i,y_i[0]^polarity_i,y_prev_i^polarity_i}] = 1;
              seen_polarity[pol_value] = 1;
            end
          end
        end
      end
      for (integer x_value = 0; x_value < 256; x_value++) begin
        array_x = 8'(x_value) ^ {8{polarity_i}};
        ax_signed = (x_value < 128) ? x_value : x_value - 256;
        for (integer y_value = 0; y_value < 16; y_value++) begin
          array_y = 4'(y_value) ^ {4{polarity_i}};
          ay_signed = (y_value < 8) ? y_value : y_value - 16;
          for (integer k_case = 0; k_case < 5; k_case++) begin
            case (k_case)
              0: addend = -128;
              1: addend = -1;
              2: addend = 0;
              3: addend = 1;
              4: addend = 127;
              default: addend = 0;
            endcase
            array_k = 8'(addend) ^ {8{polarity_i}};
            expected_array = ax_signed*ay_signed + addend;
            #1;
            if (int'($signed(array_product ^ {12{polarity_i}})) !== expected_array)
              $fatal(1,"AMD Fig.8 array X=%0d Y=%0d K=%0d P=%0d got=%h expected=%0d",
                     ax_signed,ay_signed,addend,pol_value,array_product,expected_array);
            array_checks++;
          end
        end
      end
    end
    if (slice_checks != 32768 || sign_checks != 16384 || array_checks != 40960 ||
        seen_booth != 8'hff || seen_polarity != 2'b11)
      $fatal(1,"incomplete functional coverage");
    $display("TEST PASSED: %0d exhaustive slices, %0d signed extensions, %0d wired-array cases; 0 failures",
             slice_checks,sign_checks,array_checks);
    $finish;
  end

  initial begin
    #90000;
    $fatal(1,"test watchdog expired");
  end
endmodule
