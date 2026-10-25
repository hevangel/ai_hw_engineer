`timescale 1ns/1ps
module tb_ttl_74x631;
    logic mode_n,single_err,double_err;
    logic [15:0] data_in,data_out;
    logic [5:0] check_in,check_out,expected_check;
    logic [15:0] words[32];logic [5:0] checks[32];

    ttl_74x631 dut(.*);
    initial begin
        words[0]=16'hcaf3;checks[0]=6'h3c;
        words[1]=16'hff60;checks[1]=6'h3c;
        words[2]=16'ha1d5;checks[2]=6'h0;
        words[3]=16'h6a4a;checks[3]=6'h31;
        words[4]=16'h1cbf;checks[4]=6'h24;
        words[5]=16'hc12c;checks[5]=6'h27;
        words[6]=16'h8b81;checks[6]=6'h28;
        words[7]=16'hbdf6;checks[7]=6'h0;
        words[8]=16'h666b;checks[8]=6'h26;
        words[9]=16'h28d8;checks[9]=6'h2b;
        words[10]=16'hdd4d;checks[10]=6'h9;
        words[11]=16'h87a2;checks[11]=6'h1a;
        words[12]=16'h4817;checks[12]=6'hc;
        words[13]=16'h7284;checks[13]=6'h11;
        words[14]=16'h24f9;checks[14]=6'h3c;
        words[15]=16'he96e;checks[15]=6'h2b;
        words[16]=16'h93c3;checks[16]=6'h5;
        words[17]=16'h4430;checks[17]=6'h18;
        words[18]=16'hea5;checks[18]=6'h13;
        words[19]=16'h331a;checks[19]=6'h29;
        words[20]=16'he58f;checks[20]=6'h1b;
        words[21]=16'haffc;checks[21]=6'h1e;
        words[22]=16'h5051;checks[22]=6'h7;
        words[23]=16'h1ac6;checks[23]=6'h29;
        words[24]=16'hcf3b;checks[24]=6'h3e;
        words[25]=16'hf1a8;checks[25]=6'hc;
        words[26]=16'hba1d;checks[26]=6'h20;
        words[27]=16'h6c72;checks[27]=6'h14;
        words[28]=16'h16e7;checks[28]=6'h3e;
        words[29]=16'hdb54;checks[29]=6'h25;
        words[30]=16'h8dc9;checks[30]=6'h5;
        words[31]=16'hb63e;checks[31]=6'h12;
        mode_n=0;data_in=0;check_in=0;
        for(int v=0;v<32;v++) begin
            mode_n=0;data_in=words[v];#1;
            if(check_out!==checks[v]) $fatal(1,"independent encoding literal");
            mode_n=1;check_in=checks[v];#1;
            if(single_err || double_err || data_out!==words[v]) $fatal(1,"clean word");
            for(int bit_index=0;bit_index<22;bit_index++) begin
                data_in=words[v];check_in=checks[v];
                if(bit_index<16) data_in[bit_index]=!data_in[bit_index];
                else check_in[bit_index-16]=!check_in[bit_index-16];
                #1;if(!single_err || double_err || data_out!==words[v]) $fatal(1,"single error bit %0d",bit_index);
            end
        end
        for(int first=0;first<22;first++) begin
            for(int second=first+1;second<22;second++) begin
                data_in=words[0];check_in=checks[0];
                if(first<16) data_in[first]=!data_in[first];else check_in[first-16]=!check_in[first-16];
                if(second<16) data_in[second]=!data_in[second];else check_in[second-16]=!check_in[second-16];
                #1;if(single_err || !double_err) $fatal(1,"double error detection");
            end
        end

        $display("PASS: tb_ttl_74x631");$finish;
    end
endmodule
