// ASSUMPTION: normalized extended-Hamming matrix; NOT the native manufacturer matrix.
// The complete bit-position contract is in spec/chips/ttl_74x637.md.
module ttl_74x637 (
    input logic mode_n,
    input logic [7:0] data_in,
    input logic [4:0] check_in,
    output logic [7:0] data_out,
    output logic [4:0] check_out,
    output logic single_err,double_err
);
    logic [7:0] code_data;
    logic [3:0] generated,syndrome;
    logic overall;
    always_comb begin
        code_data=data_in;
        generated='0;
        generated = generated ^ (code_data[0] ? 4'd3 : 4'd0);
        generated = generated ^ (code_data[1] ? 4'd5 : 4'd0);
        generated = generated ^ (code_data[2] ? 4'd6 : 4'd0);
        generated = generated ^ (code_data[3] ? 4'd7 : 4'd0);
        generated = generated ^ (code_data[4] ? 4'd9 : 4'd0);
        generated = generated ^ (code_data[5] ? 4'd10 : 4'd0);
        generated = generated ^ (code_data[6] ? 4'd11 : 4'd0);
        generated = generated ^ (code_data[7] ? 4'd12 : 4'd0);
        check_out={(^{code_data,generated}),generated};
        syndrome=generated^check_in[3:0];
        overall=^{code_data,check_in};
        data_out=data_in;single_err=0;double_err=0;
        if(mode_n) begin
            if(overall) begin
                single_err=1;
                if(syndrome==4'd3) data_out[0]=!data_in[0];
                if(syndrome==4'd5) data_out[1]=!data_in[1];
                if(syndrome==4'd6) data_out[2]=!data_in[2];
                if(syndrome==4'd7) data_out[3]=!data_in[3];
                if(syndrome==4'd9) data_out[4]=!data_in[4];
                if(syndrome==4'd10) data_out[5]=!data_in[5];
                if(syndrome==4'd11) data_out[6]=!data_in[6];
                if(syndrome==4'd12) data_out[7]=!data_in[7];
            end else if(syndrome!=0) double_err=1;
        end
    end
endmodule
