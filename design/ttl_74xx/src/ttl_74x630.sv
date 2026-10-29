// ASSUMPTION: normalized extended-Hamming matrix; NOT the native manufacturer matrix.
// The complete bit-position contract is in spec/chips/ttl_74x630.md.
module ttl_74x630 (
    input logic mode_n,
    input logic [15:0] data_in,
    input logic [5:0] check_in,
    output logic [15:0] data_out,
    output logic [5:0] check_out,
    output logic single_err,double_err
);
    logic [15:0] code_data;
    logic [4:0] generated,syndrome;
    logic overall;
    always_comb begin
        code_data=data_in;
        generated='0;
        generated = generated ^ (code_data[0] ? 5'd3 : 5'd0);
        generated = generated ^ (code_data[1] ? 5'd5 : 5'd0);
        generated = generated ^ (code_data[2] ? 5'd6 : 5'd0);
        generated = generated ^ (code_data[3] ? 5'd7 : 5'd0);
        generated = generated ^ (code_data[4] ? 5'd9 : 5'd0);
        generated = generated ^ (code_data[5] ? 5'd10 : 5'd0);
        generated = generated ^ (code_data[6] ? 5'd11 : 5'd0);
        generated = generated ^ (code_data[7] ? 5'd12 : 5'd0);
        generated = generated ^ (code_data[8] ? 5'd13 : 5'd0);
        generated = generated ^ (code_data[9] ? 5'd14 : 5'd0);
        generated = generated ^ (code_data[10] ? 5'd15 : 5'd0);
        generated = generated ^ (code_data[11] ? 5'd17 : 5'd0);
        generated = generated ^ (code_data[12] ? 5'd18 : 5'd0);
        generated = generated ^ (code_data[13] ? 5'd19 : 5'd0);
        generated = generated ^ (code_data[14] ? 5'd20 : 5'd0);
        generated = generated ^ (code_data[15] ? 5'd21 : 5'd0);
        check_out={(^{code_data,generated}),generated};
        syndrome=generated^check_in[4:0];
        overall=^{code_data,check_in};
        data_out=data_in;single_err=0;double_err=0;
        if(mode_n) begin
            if(overall) begin
                single_err=1;
                if(syndrome==5'd3) data_out[0]=!data_in[0];
                if(syndrome==5'd5) data_out[1]=!data_in[1];
                if(syndrome==5'd6) data_out[2]=!data_in[2];
                if(syndrome==5'd7) data_out[3]=!data_in[3];
                if(syndrome==5'd9) data_out[4]=!data_in[4];
                if(syndrome==5'd10) data_out[5]=!data_in[5];
                if(syndrome==5'd11) data_out[6]=!data_in[6];
                if(syndrome==5'd12) data_out[7]=!data_in[7];
                if(syndrome==5'd13) data_out[8]=!data_in[8];
                if(syndrome==5'd14) data_out[9]=!data_in[9];
                if(syndrome==5'd15) data_out[10]=!data_in[10];
                if(syndrome==5'd17) data_out[11]=!data_in[11];
                if(syndrome==5'd18) data_out[12]=!data_in[12];
                if(syndrome==5'd19) data_out[13]=!data_in[13];
                if(syndrome==5'd20) data_out[14]=!data_in[14];
                if(syndrome==5'd21) data_out[15]=!data_in[15];
            end else if(syndrome!=0) double_err=1;
        end
    end
endmodule
