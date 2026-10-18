// IBM/Xebec functional adapter. DCB authority: original IBM 1982 ROM,
// independently cross-checked with pinned PCjs hdc.js (reference manifest).
// ASSUMPTION XT2: decoded sector bytes replace MFM/ECC/mechanical timing.
module xt_fixed_disk (
    input logic clk,rst_n,selected,io_read,io_write,
    input logic [1:0] port,
    input logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic data_oe,irq,drq,
    input logic dma_read,dma_write,terminal_count,
    output logic [23:0] media_address,
    input logic [7:0] media_data,
    output logic media_write,
    output logic [7:0] media_wdata,
    output logic [31:0] command_count,read_count,write_count
);
    localparam logic [2:0] IDLE=0,COMMAND=1,ACCEPT=2,PARAM=3,EXECUTE=4,TRANSFER=5,RESULT=6,FORMAT=7;
    logic [2:0] state;
    logic [7:0] command[0:13],response[0:4];
    logic [3:0] received;
    logic [2:0] result_index,result_length;
    logic [1:0] mask;
    logic [7:0] error_q;
    logic irq_pending,writing;
    logic [16:0] remaining;
    logic [23:0] format_remaining;
    logic read_byte,write_byte;
    logic [9:0] cylinder;
    logic [23:0] start_address,track_address;
    logic [17:0] request_bytes;
    logic valid_address;
    assign cylinder={command[2][7:6],command[3]};
    assign start_address=(24'(cylinder)*24'd68+24'(command[1][4:0])*24'd17+24'(command[2][5:0]))*24'd512;
    assign track_address=(24'(cylinder)*24'd68+24'(command[1][4:0])*24'd17)*24'd512;
    assign request_bytes={(command[4]==0?9'd256:{1'b0,command[4]}),9'd0};
    assign valid_address=!command[1][5]&&cylinder<306&&command[1][4:0]<4&&command[2][5:0]<17&&
        {1'b0,start_address}+{7'd0,request_bytes}<=25'd10653696;
    assign irq=irq_pending&&mask[1];
    assign drq=state==TRANSFER&&mask[0];
    assign data_oe=selected&&io_read;
    assign read_byte=state==TRANSFER&&!writing&&(dma_read||(!mask[0]&&selected&&io_read&&port==0));
    assign write_byte=state==TRANSFER&&writing&&(dma_write||(!mask[0]&&selected&&io_write&&port==0));
    assign media_write=rst_n&&(write_byte||state==FORMAT);
    assign media_wdata=state==FORMAT?8'hf6:data_i;
    always_comb begin
        data_o=8'hff;
        case(port)
            0:if(state==RESULT) data_o=response[result_index];else if(state==TRANSFER&&!writing) data_o=media_data;
            1:case(state)
                IDLE:data_o=8'h01;
                COMMAND,PARAM:data_o=8'h0d;
                ACCEPT,EXECUTE:data_o=8'h0c;
                TRANSFER:data_o=mask[0]?8'h08:(writing?8'h09:8'h0b);
                RESULT:data_o={2'd0,irq_pending,1'b0,3'b111,received[0]};
                default:data_o=8'h08;
            endcase
            2:data_o=8'hff; // original type-3 drive switches: 306/4/17
            default:begin end
        endcase
    end
    task automatic finish(input logic [7:0] error_value);
        begin
            response[0]<={2'd0,command[1][5],3'd0,(error_value!=0),1'b0};
            result_index<=0;result_length<=1;state<=RESULT;irq_pending<=1;error_q<=error_value;received<=0;
        end
    endtask
    // Automatic finish task and this block are the same sequential driver;
    // tool version 5.052 counts their writes separately.
    /* verilator lint_off MULTIDRIVEN */
    always_ff @(posedge clk) begin
        if(!rst_n||(selected&&io_write&&port==1)) begin
            state<=IDLE;received<=0;result_index<=0;result_length<=0;mask<=0;
            error_q<=0;irq_pending<=0;writing<=0;remaining<=0;media_address<=0;format_remaining<=0;
            command_count<=0;read_count<=0;write_count<=0;
            for(integer k=0;k<14;k=k+1) command[k]<=0;
            for(integer k=0;k<5;k=k+1) response[k]<=0;
        end else begin
            if(selected&&io_write&&port==3) mask<=data_i[1:0];
            if(selected&&io_write&&port==2) begin state<=COMMAND;received<=0;irq_pending<=0; end
            if(selected&&io_write&&port==0&&(state==COMMAND||state==PARAM)) begin
                command[received]<=data_i;received<=received+1'b1;
                if(received==5) state<=ACCEPT;
                else if(received==13) state<=EXECUTE;
            end
            // ASSUMPTION XT2: expose the documented request-low phase until
            // the CPU samples status; this avoids dependence on EU clocks.
            if(state==ACCEPT&&selected&&io_read&&port==1)
                state<=command[0]==8'h0c ? PARAM:EXECUTE;
            if(state==EXECUTE) begin
                command_count<=command_count+1'b1;
                case(command[0])
                    8'h03:begin
                        response[0]<=error_q;response[1]<=command[1];response[2]<=command[2];response[3]<=command[3];
                        response[4]<={2'd0,command[1][5],5'd0};
                        result_index<=0;result_length<=5;state<=RESULT;irq_pending<=1;received<=0;
                    end
                    8'h0c,8'he0,8'he4:finish(0);
                    8'h00,8'h01,8'h0b,8'he3:finish(command[1][5]?8'h04:8'h00);
                    8'h05:finish(valid_address?8'h00:8'h21);
                    8'h0e,8'h0f:begin
                        // External 512-byte controller SRAM has its own
                        // decoded address window, beyond the fixed medium.
                        writing<=command[0]==8'h0f;media_address<=24'hfffe00;
                        remaining<=17'd512;state<=TRANSFER;
                    end
                    8'h08,8'h0a:begin
                        if(!valid_address) finish(command[1][5]?8'h04:8'h21);
                        else begin
                            writing<=command[0]==8'h0a;media_address<=start_address;
                            remaining<=request_bytes[16:0];state<=TRANSFER;
                        end
                    end
                    8'h04,8'h06:begin
                        if(command[1][5]||cylinder>=306||command[1][4:0]>=4) finish(8'h21);
                        else begin
                            media_address<=command[0]==4?24'd0:track_address;
                            format_remaining<=command[0]==4?24'd10653696:24'd8704;state<=FORMAT;
                        end
                    end
                    default:finish(8'h20);
                endcase
            end
            if(read_byte||write_byte) begin
                if(read_byte&&command[0]!=8'h0e) read_count<=read_count+1'b1;
                if(write_byte&&command[0]!=8'h0f) write_count<=write_count+1'b1;
                media_address<=media_address+1'b1;remaining<=remaining-1'b1;
                if(remaining==1||terminal_count) finish(0);
            end
            if(state==FORMAT) begin
                media_address<=media_address+1'b1;format_remaining<=format_remaining-1'b1;
                write_count<=write_count+1'b1;if(format_remaining==1) finish(0);
            end
            if(state==RESULT&&selected&&io_read&&port==0) begin
                irq_pending<=0;result_index<=result_index+1'b1;
                if(result_index+1'b1==result_length) begin state<=IDLE;received<=0; end
            end
            // Original ROM 0562h/0590h and the INIT parameter sender must
            // observe REQ low before the response becomes ready. This phase
            // also follows the final eighth drive-parameter byte.
            if(state==RESULT&&selected&&io_read&&port==1) received<=1;
        end
    end
    /* verilator lint_on MULTIDRIVEN */
`ifdef FORMAL
    logic past_valid=0;
    always_ff @(posedge clk) begin
        past_valid<=1;if(!past_valid) assume(!rst_n);
        if(past_valid&&rst_n&&$past(rst_n)) begin
            assert(!drq||state==TRANSFER);
            assert(!media_write||media_address<24'd10653696||
                (state==TRANSFER&&command[0]==8'h0f&&media_address>=24'hfffe00));
            if(state==TRANSFER) begin
                assert(writing==(command[0]==8'h0a||command[0]==8'h0f));
                if(command[0]==8'h0e||command[0]==8'h0f) begin
                    assert(remaining!=0&&remaining<=512);
                    assert(media_address>=24'hfffe00);
                    assert({1'b0,media_address}+{8'd0,remaining}<=25'd16777216);
                end else assert({1'b0,media_address}+{7'd0,(remaining==0?18'd131072:{1'b0,remaining})}<=25'd10653696);
            end
            if(state==FORMAT) begin
                assert(format_remaining!=0);
                assert({1'b0,media_address}+{1'b0,format_remaining}<=25'd10653696);
            end
            if($past(state==TRANSFER&&!read_byte&&!write_byte)&&state==TRANSFER)
                assert($stable(media_address));
            cover(state==RESULT&&command[0]==8'h08);
            cover(media_write&&state==TRANSFER);
        end
    end
`endif
endmodule
