`timescale 1ns/1ps
module tb_ttl_74x632;
    logic mode_n,single_err,double_err;
    logic [31:0] data_in,data_out;
    logic [6:0] check_in,check_out,expected_check;
    logic [31:0] words[32];logic [6:0] checks[32];
    logic [3:0] byte_we;logic [31:0] orig_data;

    ttl_74x632 dut(.*);
    initial begin
        words[0]=32'h5a96caf3;checks[0]=7'h6f;
        words[1]=32'h4111ff60;checks[1]=7'h2b;
        words[2]=32'h6d98a1d5;checks[2]=7'h42;
        words[3]=32'h8036a4a;checks[3]=7'h72;
        words[4]=32'h348a1cbf;checks[4]=7'h71;
        words[5]=32'hd332c12c;checks[5]=7'h30;
        words[6]=32'hffbd8b81;checks[6]=7'h5;
        words[7]=32'h9a24bdf6;checks[7]=7'h7b;
        words[8]=32'h86af666b;checks[8]=7'h18;
        words[9]=32'had5628d8;checks[9]=7'h5d;
        words[10]=32'h49dedd4d;checks[10]=7'h5d;
        words[11]=32'h745987a2;checks[11]=7'h10;
        words[12]=32'h10c04817;checks[12]=7'h6e;
        words[13]=32'h3f4b7284;checks[13]=7'h50;
        words[14]=32'hdbf224f9;checks[14]=7'h8;
        words[15]=32'hc67ae96e;checks[15]=7'h25;
        words[16]=32'he2e593c3;checks[16]=7'h29;
        words[17]=32'h896c4430;checks[17]=7'h4;
        words[18]=32'hb5170ea5;checks[18]=7'h4e;
        words[19]=32'h519e331a;checks[19]=7'h40;
        words[20]=32'h7c06e58f;checks[20]=7'h75;
        words[21]=32'h1881affc;checks[21]=7'h14;
        words[22]=32'h7085051;checks[22]=7'h3e;
        words[23]=32'h23b31ac6;checks[23]=7'h31;
        words[24]=32'hce3bcf3b;checks[24]=7'h58;
        words[25]=32'heaa2f1a8;checks[25]=7'h47;
        words[26]=32'h912dba1d;checks[26]=7'h17;
        words[27]=32'hbdd46c72;checks[27]=7'h2b;
        words[28]=32'h585f16e7;checks[28]=7'h3c;
        words[29]=32'h44c7db54;checks[29]=7'h59;
        words[30]=32'h634e8dc9;checks[30]=7'hf;
        words[31]=32'hfc9b63e;checks[31]=7'h1e;
        mode_n=0;data_in=0;check_in=0;byte_we=0;orig_data=0;
        for(int v=0;v<32;v++) begin
            mode_n=0;data_in=words[v];#1;
            if(check_out!==checks[v]) $fatal(1,"independent encoding literal");
            mode_n=1;check_in=checks[v];#1;
            if(single_err || double_err || data_out!==words[v]) $fatal(1,"clean word");
            for(int bit_index=0;bit_index<39;bit_index++) begin
                data_in=words[v];check_in=checks[v];
                if(bit_index<32) data_in[bit_index]=!data_in[bit_index];
                else check_in[bit_index-32]=!check_in[bit_index-32];
                #1;if(!single_err || double_err || data_out!==words[v]) $fatal(1,"single error bit %0d",bit_index);
            end
        end
        for(int first=0;first<39;first++) begin
            for(int second=first+1;second<39;second++) begin
                data_in=words[0];check_in=checks[0];
                if(first<32) data_in[first]=!data_in[first];else check_in[first-32]=!check_in[first-32];
                if(second<32) data_in[second]=!data_in[second];else check_in[second-32]=!check_in[second-32];
                #1;if(single_err || !double_err) $fatal(1,"double error detection");
            end
        end

        mode_n=0;data_in=32'h55aa9966;orig_data=32'hc3f00f3c;
        for(int mask=0;mask<16;mask++) begin
            byte_we=4'(mask);
            case(mask)
                0:expected_check=7'h28;
                1:expected_check=7'h28;
                2:expected_check=7'h2e;
                3:expected_check=7'h2e;
                4:expected_check=7'h60;
                5:expected_check=7'h60;
                6:expected_check=7'h66;
                7:expected_check=7'h66;
                8:expected_check=7'h53;
                9:expected_check=7'h53;
                10:expected_check=7'h55;
                11:expected_check=7'h55;
                12:expected_check=7'h1b;
                13:expected_check=7'h1b;
                14:expected_check=7'h1d;
                15:expected_check=7'h1d;
            endcase
            #1;if(check_out!==expected_check) $fatal(1,"byte merge");
        end

        $display("PASS: tb_ttl_74x632");$finish;
    end
endmodule
