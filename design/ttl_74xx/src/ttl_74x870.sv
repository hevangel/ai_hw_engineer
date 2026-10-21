// ASSUMPTION: address/select meet the native asynchronous write-pulse timing.
module ttl_74x870 (
    input logic [3:0] address_1,address_2,select,a_in,b_in,
    input logic [1:0] write_n,
    output logic [3:0] a_out,b_out,
    output logic a_drive,b_drive
);
    logic [3:0] file_1[0:15],file_2[0:15];
    logic write_1,write_2;
    logic [3:0] data_1,data_2;
    assign write_1=!write_n[0] && ((select[2] && !select[0]) || (select[3] && !select[1]));
    assign write_2=!write_n[1] && ((select[2] && select[0]) || (select[3] && select[1]));
    assign data_1=(select[3] && !select[1])?b_in:a_in;
    assign data_2=(select[3] && select[1])?b_in:a_in;
    for(genvar word_index=0;word_index<16;word_index++) begin : g_word
        always_latch begin
            if(write_1 && address_1==4'(word_index)) file_1[word_index]=data_1;
        end
        always_latch begin
            if(write_2 && address_2==4'(word_index)) file_2[word_index]=data_2;
        end
    end
    assign a_drive=!select[2];
    assign b_drive=!select[3];
    assign a_out=a_drive?(select[0]?file_2[address_2]:file_1[address_1]):4'd0;
    assign b_out=b_drive?(select[1]?file_2[address_2]:file_1[address_1]):4'd0;
endmodule
