`timescale 1ns/1ps
module tb_ttl_74x636;
    logic mode_n,single_err,double_err;
    logic [7:0] data_in,data_out;
    logic [4:0] check_in,check_out,expected_check;
    logic [7:0] words[32];logic [4:0] checks[32];

    ttl_74x636 dut(.*);
    initial begin
        words[0]=8'hf3;checks[0]=5'h12;
        words[1]=8'h60;checks[1]=5'h11;
        words[2]=8'hd5;checks[2]=5'hb;
        words[3]=8'h4a;checks[3]=5'h19;
        words[4]=8'hbf;checks[4]=5'h8;
        words[5]=8'h2c;checks[5]=5'hb;
        words[6]=8'h81;checks[6]=5'hf;
        words[7]=8'hf6;checks[7]=5'h17;
        words[8]=8'h6b;checks[8]=5'h10;
        words[9]=8'hd8;checks[9]=5'h9;
        words[10]=8'h4d;checks[10]=5'h9;
        words[11]=8'ha2;checks[11]=5'h13;
        words[12]=8'h17;checks[12]=5'h9;
        words[13]=8'h84;checks[13]=5'ha;
        words[14]=8'hf9;checks[14]=5'h0;
        words[15]=8'h6e;checks[15]=5'h15;
        words[16]=8'hc3;checks[16]=5'h11;
        words[17]=8'h30;checks[17]=5'h3;
        words[18]=8'ha5;checks[18]=5'h3;
        words[19]=8'h1a;checks[19]=5'hb;
        words[20]=8'h8f;checks[20]=5'hb;
        words[21]=8'hfc;checks[21]=5'h5;
        words[22]=8'h51;checks[22]=5'h1;
        words[23]=8'hc6;checks[23]=5'h14;
        words[24]=8'h3b;checks[24]=5'h2;
        words[25]=8'ha8;checks[25]=5'h1;
        words[26]=8'h1d;checks[26]=5'h1b;
        words[27]=8'h72;checks[27]=5'h1d;
        words[28]=8'he7;checks[28]=5'h1d;
        words[29]=8'h54;checks[29]=5'h4;
        words[30]=8'hc9;checks[30]=5'h3;
        words[31]=8'h3e;checks[31]=5'h7;
        mode_n=0;data_in=0;check_in=0;
        for(int v=0;v<32;v++) begin
            mode_n=0;data_in=words[v];#1;
            if(check_out!==checks[v]) $fatal(1,"independent encoding literal");
            mode_n=1;check_in=checks[v];#1;
            if(single_err || double_err || data_out!==words[v]) $fatal(1,"clean word");
            for(int bit_index=0;bit_index<13;bit_index++) begin
                data_in=words[v];check_in=checks[v];
                if(bit_index<8) data_in[bit_index]=!data_in[bit_index];
                else check_in[bit_index-8]=!check_in[bit_index-8];
                #1;if(!single_err || double_err || data_out!==words[v]) $fatal(1,"single error bit %0d",bit_index);
            end
        end
        for(int first=0;first<13;first++) begin
            for(int second=first+1;second<13;second++) begin
                data_in=words[0];check_in=checks[0];
                if(first<8) data_in[first]=!data_in[first];else check_in[first-8]=!check_in[first-8];
                if(second<8) data_in[second]=!data_in[second];else check_in[second-8]=!check_in[second-8];
                #1;if(single_err || !double_err) $fatal(1,"double error detection");
            end
        end

        $display("PASS: tb_ttl_74x636");$finish;
    end
endmodule
