// ASSUMPTION: normalized extended-Hamming matrix; NOT the native manufacturer matrix.
// The complete bit-position contract is in spec/chips/ttl_74x632.md.
module ttl_74x632 (
    input logic mode_n,
    input logic [31:0] data_in,
    input logic [6:0] check_in,
    input logic [3:0] byte_we,
    input logic [31:0] orig_data,
    output logic [31:0] data_out,
    output logic [6:0] check_out,
    output logic single_err,double_err
);
    logic [31:0] code_data;
    logic [5:0] generated,syndrome;
    logic overall;
    always_comb begin
        code_data=data_in;
        for(integer b=0;b<4;b=b+1)
            if(!mode_n && byte_we[b]) code_data[b*8+:8]=orig_data[b*8+:8];
        generated='0;
        generated = generated ^ (code_data[0] ? 6'd3 : 6'd0);
        generated = generated ^ (code_data[1] ? 6'd5 : 6'd0);
        generated = generated ^ (code_data[2] ? 6'd6 : 6'd0);
        generated = generated ^ (code_data[3] ? 6'd7 : 6'd0);
        generated = generated ^ (code_data[4] ? 6'd9 : 6'd0);
        generated = generated ^ (code_data[5] ? 6'd10 : 6'd0);
        generated = generated ^ (code_data[6] ? 6'd11 : 6'd0);
        generated = generated ^ (code_data[7] ? 6'd12 : 6'd0);
        generated = generated ^ (code_data[8] ? 6'd13 : 6'd0);
        generated = generated ^ (code_data[9] ? 6'd14 : 6'd0);
        generated = generated ^ (code_data[10] ? 6'd15 : 6'd0);
        generated = generated ^ (code_data[11] ? 6'd17 : 6'd0);
        generated = generated ^ (code_data[12] ? 6'd18 : 6'd0);
        generated = generated ^ (code_data[13] ? 6'd19 : 6'd0);
        generated = generated ^ (code_data[14] ? 6'd20 : 6'd0);
        generated = generated ^ (code_data[15] ? 6'd21 : 6'd0);
        generated = generated ^ (code_data[16] ? 6'd22 : 6'd0);
        generated = generated ^ (code_data[17] ? 6'd23 : 6'd0);
        generated = generated ^ (code_data[18] ? 6'd24 : 6'd0);
        generated = generated ^ (code_data[19] ? 6'd25 : 6'd0);
        generated = generated ^ (code_data[20] ? 6'd26 : 6'd0);
        generated = generated ^ (code_data[21] ? 6'd27 : 6'd0);
        generated = generated ^ (code_data[22] ? 6'd28 : 6'd0);
        generated = generated ^ (code_data[23] ? 6'd29 : 6'd0);
        generated = generated ^ (code_data[24] ? 6'd30 : 6'd0);
        generated = generated ^ (code_data[25] ? 6'd31 : 6'd0);
        generated = generated ^ (code_data[26] ? 6'd33 : 6'd0);
        generated = generated ^ (code_data[27] ? 6'd34 : 6'd0);
        generated = generated ^ (code_data[28] ? 6'd35 : 6'd0);
        generated = generated ^ (code_data[29] ? 6'd36 : 6'd0);
        generated = generated ^ (code_data[30] ? 6'd37 : 6'd0);
        generated = generated ^ (code_data[31] ? 6'd38 : 6'd0);
        check_out={(^{code_data,generated}),generated};
        syndrome=generated^check_in[5:0];
        overall=^{code_data,check_in};
        data_out=data_in;single_err=0;double_err=0;
        if(mode_n) begin
            if(overall) begin
                single_err=1;
                if(syndrome==6'd3) data_out[0]=!data_in[0];
                if(syndrome==6'd5) data_out[1]=!data_in[1];
                if(syndrome==6'd6) data_out[2]=!data_in[2];
                if(syndrome==6'd7) data_out[3]=!data_in[3];
                if(syndrome==6'd9) data_out[4]=!data_in[4];
                if(syndrome==6'd10) data_out[5]=!data_in[5];
                if(syndrome==6'd11) data_out[6]=!data_in[6];
                if(syndrome==6'd12) data_out[7]=!data_in[7];
                if(syndrome==6'd13) data_out[8]=!data_in[8];
                if(syndrome==6'd14) data_out[9]=!data_in[9];
                if(syndrome==6'd15) data_out[10]=!data_in[10];
                if(syndrome==6'd17) data_out[11]=!data_in[11];
                if(syndrome==6'd18) data_out[12]=!data_in[12];
                if(syndrome==6'd19) data_out[13]=!data_in[13];
                if(syndrome==6'd20) data_out[14]=!data_in[14];
                if(syndrome==6'd21) data_out[15]=!data_in[15];
                if(syndrome==6'd22) data_out[16]=!data_in[16];
                if(syndrome==6'd23) data_out[17]=!data_in[17];
                if(syndrome==6'd24) data_out[18]=!data_in[18];
                if(syndrome==6'd25) data_out[19]=!data_in[19];
                if(syndrome==6'd26) data_out[20]=!data_in[20];
                if(syndrome==6'd27) data_out[21]=!data_in[21];
                if(syndrome==6'd28) data_out[22]=!data_in[22];
                if(syndrome==6'd29) data_out[23]=!data_in[23];
                if(syndrome==6'd30) data_out[24]=!data_in[24];
                if(syndrome==6'd31) data_out[25]=!data_in[25];
                if(syndrome==6'd33) data_out[26]=!data_in[26];
                if(syndrome==6'd34) data_out[27]=!data_in[27];
                if(syndrome==6'd35) data_out[28]=!data_in[28];
                if(syndrome==6'd36) data_out[29]=!data_in[29];
                if(syndrome==6'd37) data_out[30]=!data_in[30];
                if(syndrome==6'd38) data_out[31]=!data_in[31];
            end else if(syndrome!=0) double_err=1;
        end
    end
endmodule
