`timescale 1ns/1ps
// IBM DBA integrated fixed disk, original Model 30 type 26.
// Authority: Model 30 TR pp.1-106/107 and unchanged ROM F4FC..F57D;
// DBA block definitions: IBM PS/1 Drives pp.8-5..8-23. See spec/hard_disk.md.
module model30_fixed_disk #(
    parameter integer CYLINDERS=612, HEADS=4, SECTORS=17,
    parameter integer DRIVE_TYPE=26, PARK_CYLINDER=670,
    parameter integer COMMAND_CYCLES=800, SECTOR_CYCLES=2000
) (
    input logic clk,rst_n,cold_rst_n,present,selected,reading,writing,
    input logic [2:0] address,
    input logic [7:0] wdata,
    output logic [7:0] rdata,
    input logic dma_dack_n,dma_ior_n,dma_iow_n,terminal_count,
    input logic [7:0] dma_wdata,
    output logic [7:0] dma_rdata,
    output logic drq,irq,busy,
    output logic [16:0] media_sector,
    output logic [9:0] media_address,
    input logic [7:0] media_rdata,
    input logic media_check_valid,
    output logic media_read,media_write,
    output logic [7:0] media_wdata
);
    typedef enum logic [4:0] {
        IDLE,RECV_CCB,RECV_CSB,SEND_SSB,DELAY_COMMAND,EXECUTE,START,
        SCAN_ID,TEST_ID,LOAD_DATA,LOAD_CHECK,TEST_CHECK,RECV_DATA,SEND_DATA,
        COMMIT_DATA,COMMIT_CHECK,ADVANCE,RECV_FCB,FORMAT_ERASE,FORMAT_DATA,
        FORMAT_ID,FORMAT_CHECK,ECC_SCAN,ECC_DECIDE,ECC_REPAIR,RECALCULATE,
        ECC_RESULT,RESET_DELAY
    } state_t;
    state_t state;
    logic [7:0] block_buffer[0:85];
    logic [7:0] sector_buffer[0:517];
    logic [7:0] id_buffer[0:4];
    logic [7:0] intstat,status0,status1,syndrome;
    logic [2:0] control;
    logic [3:0] status2;
    logic [7:0] remaining,sector,last_sector,last_size,corrections,retries;
    logic [9:0] cylinder,target_cylinder,last_cylinder;
    logic [3:0] head,last_head,command,retry_limit;
    logic [4:0] slot,format_entry,format_count;
    logic [9:0] byte_index,stream_length;
    logic [2:0] field_index;
    logic [15:0] delay_count;
    logic irq_pending,data_ready,ecc_mode,no_data,format_all,buffer_valid;
    logic recovery_enabled,verify_after_write,recalc_for_write,last_defective,saw_ff;
    logic old_dma_read,old_dma_write,old_tc,tc_pending;
    logic dma_read_edge,dma_write_edge,stream_read,stream_write,stream_tx,stream_rx;
    logic [7:0] stream_value,input_value;
    logic [47:0] crc48,expected_check,stored_check;
    logic [15:0] crc16;
    logic [47:0] ecc_syndrome,ecc_power;
    logic [31:0] ecc_pattern;
    logic [12:0] ecc_position,repair_position;
    logic [15:0] repair_pattern;
    logic [1:0] match_count;
    logic [4:0] repair_bit;
    logic [13:0] repair_exponent;
    logic [12:0] repair_stream_bit;
    logic [47:0] ecc_candidate;
    logic ecc_span_valid;
    logic [3:0] requested_command;
    logic [9:0] requested_cylinder;
    logic [3:0] requested_head;

    // ASSUMPTION A9: polynomial/framing state pinned to the independent DBA
    // implementation; external known vectors and burst tests are required.
    localparam logic [47:0] ECC_POLY=48'h102100011021, ECC_INITIAL=48'h752f00008ad0;
    function automatic logic [47:0] times_x(input logic [47:0] value);
        times_x={value[46:0],1'b0}^(value[47] ? ECC_POLY:48'b0);
    endfunction
    function automatic logic [47:0] next_ecc(input logic [47:0] value,input logic [7:0] data);
        logic [47:0] v;
        v=value^{data,40'b0};
        for(integer i=0;i<8;i=i+1) v=times_x(v);
        next_ecc=v;
    endfunction
    function automatic logic [15:0] next_crc(input logic [15:0] value,input logic [7:0] data);
        logic [15:0] v;
        v=value^{data,8'b0};
        for(integer i=0;i<8;i=i+1) v={v[14:0],1'b0}^(v[15] ? 16'h1021:16'b0);
        next_crc=v;
    endfunction
    function automatic logic [47:0] polynomial_product(input logic [47:0] basis,input logic [15:0] pattern);
        logic [47:0] p,v;
        p=0;v=basis;
        for(integer i=0;i<16;i=i+1) begin
            if(pattern[i]) p=p^v;
            v=times_x(v);
        end
        polynomial_product=p;
    endfunction
    function automatic logic [7:0] sense_byte(input logic [9:0] index);
        case(index)
            0:sense_byte=status0|{!present,6'b0,cylinder==0};
            1:sense_byte=status1;
            2:sense_byte={status2,head};
            3:sense_byte=last_cylinder[7:0];
            4:sense_byte={last_defective,last_cylinder[9:8],1'b0,last_head};
            5:sense_byte=last_sector;
            6:sense_byte=last_size;
            7:sense_byte={head,2'b0,cylinder[9:8]};
            8:sense_byte=cylinder[7:0];
            9:sense_byte=corrections;
            10:sense_byte=retries;
            11:sense_byte=syndrome;
            12:sense_byte=8'(DRIVE_TYPE);
            default:sense_byte=0;
        endcase
    endfunction
    // Completion expands inside this single sequential process, including
    // when public signal visibility is enabled for waveform inspection.
`define FINISH(error) begin state<=IDLE;irq_pending<=1;intstat<=intstat|(error); \
        data_ready<=0;syndrome<={syndrome[7:4]|4'b0001,4'h4};tc_pending<=0;end



    assign requested_command=block_buffer[0][7:4];
    assign requested_cylinder={block_buffer[1][1:0],block_buffer[2]};
    assign requested_head=block_buffer[1][7:4];
    assign stream_rx=state==RECV_CCB || state==RECV_CSB || state==RECV_DATA || state==RECV_FCB;
    assign stream_tx=state==SEND_SSB || state==SEND_DATA;
    assign busy=state!=IDLE && state!=RECV_CCB && state!=RECV_CSB && state!=SEND_SSB;
    assign irq=present && irq_pending && control[1];
    assign drq=present && control[0] && !control[2] && (stream_rx || stream_tx) &&
        (state==RECV_DATA || state==SEND_DATA || state==RECV_FCB || data_ready);
    assign dma_read_edge=present && !dma_dack_n && !dma_ior_n && !old_dma_read;
    assign dma_write_edge=present && !dma_dack_n && !dma_iow_n && !old_dma_write;
    assign stream_read=(selected && reading && address==0) || dma_read_edge;
    assign stream_write=(selected && writing && address==0) || dma_write_edge;
    assign input_value=dma_write_edge ? dma_wdata:wdata;
    assign stream_value=state==SEND_SSB ? sense_byte(byte_index):
        byte_index<518 ? sector_buffer[byte_index]:8'hff;
    assign expected_check=ecc_mode ? crc48:{next_crc(next_crc(crc16,0),0),32'b0};
    assign stored_check={sector_buffer[512],sector_buffer[513],sector_buffer[514],
        sector_buffer[515],sector_buffer[516],sector_buffer[517]};
    assign media_sector=(17'(cylinder)*17'(HEADS)+{13'b0,head})*17'(SECTORS)+{12'b0,slot};
    assign ecc_candidate=state==ECC_SCAN ? polynomial_product(ecc_power,ecc_pattern[15:0]):48'b0;
    assign repair_exponent={1'b0,repair_position}+{9'b0,repair_bit};
    assign repair_stream_bit=13'(14'd4143-repair_exponent);
    always_comb begin
        ecc_span_valid=1;
        for(integer i=0;i<16;i=i+1)
            if(state==ECC_SCAN && ecc_pattern[i] && {1'b0,ecc_position}+14'(i)>4143) ecc_span_valid=0;
        stream_length=512;
        if(state==RECV_CCB) stream_length=6;
        else if(state==RECV_CSB || state==SEND_SSB) stream_length=14;
        else if(state==RECV_FCB) stream_length=10'(format_count)*10'd5+{9'b0,format_count[0]};
        else if(command==3 || command==11) stream_length=518;
        rdata=8'hff;
        case(address)
            0:if(stream_tx) rdata=stream_value;
            2:rdata={3'b0,(stream_rx || stream_tx),stream_tx,busy,irq_pending,(stream_rx || stream_tx)};
            4:rdata=intstat;
            default:begin end
        endcase
        media_read=present && (state==SCAN_ID || state==LOAD_DATA || state==LOAD_CHECK);
        media_write=present && (state==COMMIT_DATA || state==COMMIT_CHECK || state==FORMAT_ERASE ||
            state==FORMAT_DATA || state==FORMAT_ID || state==FORMAT_CHECK);
        media_address=byte_index;
        media_wdata=byte_index<518 ? sector_buffer[byte_index]:8'hff;
        case(state)
            SCAN_ID,FORMAT_ERASE,FORMAT_ID:media_address=10'd512+{7'b0,field_index};
            LOAD_CHECK,COMMIT_CHECK,FORMAT_CHECK:media_address=10'd517+{7'b0,field_index};
            default:begin end
        endcase
        if(state==COMMIT_CHECK) media_wdata=command==11 ?
            sector_buffer[10'd512+{7'b0,field_index}]:8'(expected_check>>(40-8*field_index));
        if(state==FORMAT_ERASE) media_wdata=8'hff;
        if(state==FORMAT_DATA) media_wdata=block_buffer[7'(format_entry)*7'd5+7'd4];
        if(state==FORMAT_CHECK) media_wdata=8'(expected_check>>(40-8*field_index));
        if(state==FORMAT_ID) begin
            media_wdata=block_buffer[7'(format_entry)*7'd5+{4'b0,field_index}];
            if(format_all && field_index==0)
                media_wdata={head,block_buffer[7'(format_entry)*7'd5][3:2],cylinder[9:8]};
            if(format_all && field_index==1) media_wdata=cylinder[7:0];
        end
    end
    always_ff @(posedge clk) begin
        old_dma_read<=!dma_dack_n && !dma_ior_n;
        old_dma_write<=!dma_dack_n && !dma_iow_n;
        old_tc<=terminal_count;
        if(!rst_n) begin
            state<=IDLE;control<=0;intstat<=0;status0<=0;status1<=0;status2<=0;syndrome<=0;
            if(!cold_rst_n) cylinder<=0;
            target_cylinder<=0;last_cylinder<=0;head<=0;last_head<=0;sector<=1;slot<=0;
            last_sector<=1;last_size<=2;last_defective<=0;command<=0;remaining<=0;
            byte_index<=0;field_index<=0;delay_count<=0;format_entry<=0;format_count<=0;
            irq_pending<=0;data_ready<=0;no_data<=0;ecc_mode<=1;format_all<=0;
            recovery_enabled<=1;retry_limit<=15;buffer_valid<=0;verify_after_write<=0;
            recalc_for_write<=0;saw_ff<=0;tc_pending<=0;old_tc<=0;
            old_dma_read<=0;old_dma_write<=0;dma_rdata<=0;corrections<=0;retries<=0;
            crc48<=ECC_INITIAL;crc16<=16'hffff;ecc_syndrome<=0;ecc_power<=1;
            ecc_pattern<=0;ecc_position<=0;repair_position<=0;repair_pattern<=0;
            match_count<=0;repair_bit<=0;
        end else begin
            if(terminal_count && !old_tc && busy) tc_pending<=1;
            if(selected && reading && address==4) begin intstat<=0;irq_pending<=0;end
            // ASSUMPTION A8: ASR acknowledgement follows IBM's register
            // description; ISR read also clears the interrupt request.
            if(selected && reading && address==2) irq_pending<=0;
            if(dma_read_edge) dma_rdata<=stream_tx ? stream_value:8'hff;
            if(stream_rx && stream_write && byte_index<stream_length) begin
                if(state==RECV_DATA) begin
                    sector_buffer[byte_index]<=input_value;
                    if(byte_index<512) begin
                        crc48<=next_ecc(crc48,input_value);crc16<=next_crc(crc16,input_value);
                    end
                end else block_buffer[byte_index[6:0]]<=input_value;
                if(byte_index+10'd1==stream_length) begin
                    byte_index<=0;
                    case(state)
                        RECV_CCB:begin state<=DELAY_COMMAND;delay_count<=16'(SECTOR_CYCLES);irq_pending<=1;syndrome<=1;end
                        RECV_CSB:begin recovery_enabled<=block_buffer[0][7];retry_limit<=block_buffer[0][3:0];state<=IDLE;irq_pending<=1;end
                        RECV_FCB:begin slot<=0;format_entry<=0;field_index<=0;state<=FORMAT_ERASE;end
                        default:begin buffer_valid<=1;state<=COMMIT_DATA;syndrome<=syndrome|8'h80;end
                    endcase
                end else byte_index<=byte_index+10'd1;
            end
            if(stream_tx && stream_read && byte_index<stream_length) begin
                if(byte_index+10'd1==stream_length) begin
                    byte_index<=0;
                    if(state==SEND_SSB) begin state<=IDLE;irq_pending<=1;data_ready<=0;end
                    else begin state<=ADVANCE;syndrome<=syndrome|8'h80;end
                end else byte_index<=byte_index+10'd1;
            end
            case(state)
                RESET_DELAY:if(delay_count!=0) delay_count<=delay_count-16'd1;
                    else begin state<=IDLE;intstat<=0;irq_pending<=1;syndrome<=0;end
                DELAY_COMMAND:if(delay_count!=0) delay_count<=delay_count-16'd1;else state<=EXECUTE;
                EXECUTE:begin
                    command<=requested_command;target_cylinder<=requested_cylinder;
                    head<=requested_head;sector<=block_buffer[3];slot<=0;field_index<=0;
                    remaining<=requested_command==2 ? block_buffer[5] :
                        (block_buffer[0][3] || requested_command==3 || requested_command==11) ? 8'd1:block_buffer[5];
                    ecc_mode<=block_buffer[0][0];no_data<=block_buffer[0][3] || requested_command==2 || requested_command==5;
                    format_all<=requested_command==13;format_count<=block_buffer[5][4:0];
                    verify_after_write<=0;recalc_for_write<=0;saw_ff<=0;tc_pending<=0;
                    status0<=0;status1<=0;status2<=0;corrections<=0;retries<=0;syndrome<=2;
                    if(!present) begin status0<=8'h80;`FINISH(8'h80) end
                    else if(block_buffer[0][1] || block_buffer[1][3:2]!=0) `FINISH(8'h40)
                    else case(requested_command)
                        8:begin cylinder<=0;head<=0;sector<=1;status0<=8'h40;`FINISH(0) end
                        14:begin
                            if(block_buffer[0][0]) begin cylinder<=10'(PARK_CYLINDER);status0<=8'h40;`FINISH(0) end
                            else if(requested_cylinder>=10'(CYLINDERS)) begin status0<=8'h08;`FINISH(8'h80) end
                            else begin cylinder<=requested_cylinder;status0<=8'h40;`FINISH(0) end
                        end
                        1,2,3,5,9,10,11,13,15:begin
                            if(requested_head>=4'(HEADS) || (block_buffer[0][2] && requested_cylinder>=10'(CYLINDERS))) begin
                                status0<=8'h08;`FINISH(8'h80)
                            end else if(requested_command!=5 && (block_buffer[4]!=2 || block_buffer[5]==0 ||
                                ((requested_command==13 || requested_command==15) && block_buffer[5]>8'(SECTORS))))
                                `FINISH(8'h40)
                            else begin
                                if(block_buffer[0][2]) cylinder<=requested_cylinder;
                                if(requested_command==13) begin cylinder<=0;head<=0;target_cylinder<=0;end
                                state<=START;
                            end
                        end
                        default:`FINISH(8'h40)
                    endcase
                end
                START:if(data_ready || no_data) begin
                    byte_index<=0;field_index<=0;slot<=0;saw_ff<=0;
                    if(cylinder>=10'(CYLINDERS)) begin status0<=8'h08;`FINISH(8'h80) end
                    else if(command==13 || command==15) state<=RECV_FCB;
                    else state<=SCAN_ID;
                end
                SCAN_ID:begin
                    id_buffer[field_index]<=media_rdata;
                    if(field_index==4) begin field_index<=0;state<=TEST_ID;end
                    else field_index<=field_index+3'd1;
                end
                TEST_ID:begin
                    last_cylinder<={id_buffer[0][1:0],id_buffer[1]};last_head<=id_buffer[0][7:4];
                    last_defective<=id_buffer[0][2];last_sector<=id_buffer[2];last_size<=id_buffer[3];
                    if(&{id_buffer[0],id_buffer[1],id_buffer[2],id_buffer[3]}) saw_ff<=1;
                    if(command==5) begin
                        if(&{id_buffer[0],id_buffer[1],id_buffer[2],id_buffer[3]}) begin status1<=8'h10;`FINISH(8'h80) end
                        else begin status0<=8'h40;`FINISH(0) end
                    end else if(id_buffer[2]==sector) begin
                        if({id_buffer[0][1:0],id_buffer[1]}!=target_cylinder) begin status1<=8'h08;`FINISH(8'h80) end
                        else if(id_buffer[0][7:4]!=head || id_buffer[3]!=2) begin status1<=8'h01;`FINISH(8'h80) end
                        else if(id_buffer[0][2]) begin status2<=4'h1;`FINISH(8'h80) end
                        else begin
                            byte_index<=0;field_index<=0;crc48<=ECC_INITIAL;crc16<=16'hffff;
                            status0<=8'h40;syndrome<=syndrome|8'h03;
                            if((command==9 || command==10 || command==11) && !verify_after_write) begin
                                if(no_data) begin
                                    // ASSUMPTION A11: power-up sector-buffer bytes
                                    // are unspecified; ND writes need a valid buffer.
                                    if(!buffer_valid) `FINISH(8'h20)
                                    else begin recalc_for_write<=1;state<=RECALCULATE;end
                                end else state<=RECV_DATA;
                            end else state<=LOAD_DATA;
                        end
                    end else if(slot==5'(SECTORS-1)) begin status1<=saw_ff ? 8'h11:8'h01;`FINISH(8'h80) end
                    else begin slot<=slot+5'd1;field_index<=0;state<=SCAN_ID;end
                end
                LOAD_DATA:begin
                    sector_buffer[byte_index]<=media_rdata;crc48<=next_ecc(crc48,media_rdata);crc16<=next_crc(crc16,media_rdata);
                    if(byte_index==511) begin byte_index<=0;field_index<=0;state<=LOAD_CHECK;buffer_valid<=1;syndrome<=syndrome|8'h40;end
                    else byte_index<=byte_index+10'd1;
                end
                LOAD_CHECK:begin
                    // A raw image has canonical, error-free ECC fields.
                    sector_buffer[10'd512+{7'b0,field_index}]<=media_check_valid ? media_rdata:8'(crc48>>(40-8*field_index));
                    if(field_index==5) begin field_index<=0;state<=TEST_CHECK;end
                    else field_index<=field_index+3'd1;
                end
                TEST_CHECK:begin
                    if(command==3) begin byte_index<=0;state<=SEND_DATA;end
                    else if(ecc_mode ? stored_check==expected_check:stored_check[47:32]==expected_check[47:32]) begin
                        if(no_data || verify_after_write) state<=ADVANCE;
                        else begin byte_index<=0;state<=SEND_DATA;end
                    end else if(ecc_mode && recovery_enabled) begin
                        ecc_syndrome<=stored_check^expected_check;ecc_power<=1;
                        ecc_pattern<=(stored_check[31:0]^expected_check[31:0])^{16'b0,stored_check[47:32]^expected_check[47:32]};
                        ecc_position<=0;match_count<=0;intstat<=intstat|8'h02;state<=ECC_SCAN;
                    end else begin
        intstat<=intstat|8'h02;
        if(retries<{4'b0,retry_limit}) begin
            retries<=retries+8'd1;slot<=0;field_index<=0;saw_ff<=0;state<=SCAN_ID;
        end else begin status1<=status1|8'h40;`FINISH(8'h82) end
                    end
                end
                ECC_SCAN:begin
                    // The Fire-code factor x^32+1 gives the burst modulo 32.
                    // Search all 4,144 codeword positions with one polynomial
                    // basis per clock; accept a unique burst of at most 16 bits.
                    if(ecc_pattern[31:16]==0 && ecc_pattern[0] && ecc_span_valid && ecc_candidate==ecc_syndrome) begin
                        if(match_count==0) begin repair_position<=ecc_position;repair_pattern<=ecc_pattern[15:0];end
                        if(match_count<2) match_count<=match_count+2'd1;
                    end
                    ecc_power<=times_x(ecc_power);ecc_pattern<={ecc_pattern[0],ecc_pattern[31:1]};
                    if(ecc_position==4143) state<=ECC_DECIDE;else ecc_position<=ecc_position+13'd1;
                end
                ECC_DECIDE:if(match_count==1) begin repair_bit<=0;state<=ECC_REPAIR;end else begin
        intstat<=intstat|8'h02;
        if(retries<{4'b0,retry_limit}) begin
            retries<=retries+8'd1;slot<=0;field_index<=0;saw_ff<=0;state<=SCAN_ID;
        end else begin status1<=status1|8'h40;`FINISH(8'h82) end
                    end
                ECC_REPAIR:begin
                    if(repair_pattern[repair_bit[3:0]] && repair_exponent<=4143)
                        sector_buffer[repair_stream_bit[12:3]]<=sector_buffer[repair_stream_bit[12:3]]^(8'h80>>repair_stream_bit[2:0]);
                    if(repair_bit==15) begin byte_index<=0;crc48<=ECC_INITIAL;crc16<=16'hffff;recalc_for_write<=0;state<=RECALCULATE;end
                    else repair_bit<=repair_bit+5'd1;
                end
                RECALCULATE:begin
                    crc48<=next_ecc(crc48,sector_buffer[byte_index]);crc16<=next_crc(crc16,sector_buffer[byte_index]);
                    if(byte_index==511) begin byte_index<=0;state<=recalc_for_write ? COMMIT_DATA:ECC_RESULT;end
                    else byte_index<=byte_index+10'd1;
                end
                ECC_RESULT:if(stored_check==crc48) begin
                    corrections<=corrections+8'd1;syndrome<=syndrome|8'h20;
                    if(no_data || verify_after_write) state<=ADVANCE;
                    else begin byte_index<=0;state<=SEND_DATA;end
                end else begin
        intstat<=intstat|8'h02;
        if(retries<{4'b0,retry_limit}) begin
            retries<=retries+8'd1;slot<=0;field_index<=0;saw_ff<=0;state<=SCAN_ID;
        end else begin status1<=status1|8'h40;`FINISH(8'h82) end
                    end
                COMMIT_DATA:if(byte_index==511) begin byte_index<=0;field_index<=0;state<=COMMIT_CHECK;syndrome<=syndrome|8'h40;end
                    else byte_index<=byte_index+10'd1;
                COMMIT_CHECK:if(field_index==5) begin
                    field_index<=0;byte_index<=0;
                    if(command==10) begin verify_after_write<=1;crc48<=ECC_INITIAL;crc16<=16'hffff;state<=LOAD_DATA;end
                    else state<=ADVANCE;
                end else field_index<=field_index+3'd1;
                ADVANCE:begin
                    if(tc_pending && remaining>1) `FINISH(8'h80)
                    else if(remaining<=1) `FINISH(0)
                    else if(sector==8'(SECTORS) && head==4'(HEADS-1) && cylinder==10'(CYLINDERS-1)) begin status0<=8'h08;`FINISH(8'h80) end
                    else begin
                        remaining<=remaining-8'd1;retries<=0;verify_after_write<=0;state<=START;
                        if(sector==8'(SECTORS)) begin
                            sector<=1;
                            if(head==4'(HEADS-1)) begin head<=0;cylinder<=cylinder+10'd1;target_cylinder<=target_cylinder+10'd1;end
                            else head<=head+4'd1;
                        end else sector<=sector+8'd1;
                    end
                end
                FORMAT_ERASE:if(field_index==4) begin
                    field_index<=0;
                    if(slot==5'(SECTORS-1)) begin slot<=0;byte_index<=0;crc48<=ECC_INITIAL;crc16<=16'hffff;state<=FORMAT_DATA;end
                    else slot<=slot+5'd1;
                end else field_index<=field_index+3'd1;
                FORMAT_DATA:begin
                    crc48<=next_ecc(crc48,media_wdata);crc16<=next_crc(crc16,media_wdata);
                    if(byte_index==511) begin byte_index<=0;field_index<=0;state<=FORMAT_ID;end
                    else byte_index<=byte_index+10'd1;
                end
                FORMAT_ID:if(field_index==4) begin field_index<=0;state<=FORMAT_CHECK;end
                    else field_index<=field_index+3'd1;
                FORMAT_CHECK:if(field_index==5) begin
                    field_index<=0;byte_index<=0;syndrome<=syndrome|8'hc0;
                    if(format_entry+5'd1<format_count) begin
                        format_entry<=format_entry+5'd1;slot<=slot+5'd1;crc48<=ECC_INITIAL;crc16<=16'hffff;state<=FORMAT_DATA;
                    end else if(format_all && !(cylinder==10'(CYLINDERS-1) && head==4'(HEADS-1))) begin
                        slot<=0;format_entry<=0;state<=FORMAT_ERASE;
                        if(head==4'(HEADS-1)) begin head<=0;cylinder<=cylinder+10'd1;end else head<=head+4'd1;
                    end else `FINISH(0)
                end else field_index<=field_index+3'd1;
                default:begin end
            endcase
            // A short DMA count must terminate with an error, not leave DRQ
            // asserted after the 8237 has masked its channel at terminal count.
            if(terminal_count && !old_tc && (state==SEND_DATA || state==RECV_DATA || state==RECV_FCB) &&
                !(byte_index+10'd1==stream_length && (stream_read || stream_write)))
                `FINISH(8'h80)
            if(selected && writing && address==4) begin
                irq_pending<=0;data_ready<=wdata[4];
                if(wdata[0]) `FINISH(0)
                else if(|wdata[3:1] || ({1'b0,wdata[7]}+{1'b0,wdata[6]}+{1'b0,wdata[5]})>1) `FINISH(8'h40)
                else if(|wdata[7:5]) begin
                    if(busy) `FINISH(8'h20)
                    else begin
                        byte_index<=0;intstat<=0;tc_pending<=0;
                        if(wdata[7]) begin state<=RECV_CCB;status0<=0;status1<=0;status2<=0;syndrome<=0;end
                        else if(wdata[6]) state<=RECV_CSB;
                        else state<=SEND_SSB;
                    end
                end
            end
            if(selected && writing && address==2) begin
                control<={wdata[7],wdata[1:0]};
                if(wdata[1]) irq_pending<=0;
                if(wdata[7]) begin
                    state<=RESET_DELAY;delay_count<=16'(COMMAND_CYCLES);irq_pending<=0;intstat<=0;
                    status0<=0;status1<=0;status2<=0;syndrome<=0;data_ready<=0;tc_pending<=0;
                    recovery_enabled<=1;retry_limit<=15;corrections<=0;retries<=0;buffer_valid<=0;
                end
            end
        end
    end
`ifdef FORMAL
    logic past_valid=0;
    always_ff @(posedge clk) begin
        past_valid<=1;
        if(!past_valid) assume(!rst_n && !cold_rst_n);
        if(rst_n) begin
            assert(!drq || present && control[0] && !control[2]);
            assert(!media_write || media_sector<17'(CYLINDERS*HEADS*SECTORS));
            assert(!media_write || media_address<=522);
            assert(byte_index<518);
            assert(field_index<=5);
            assert(!irq || present && control[1]);
        end
        // Bounded formal non-vacuity covers the host block handshakes.
        // Full data/ECC/format transitions are exercised by native tests.
        cover(past_valid && rst_n && state==RECV_CCB);
        cover(past_valid && rst_n && state==RECV_CSB);
        cover(past_valid && rst_n && state==SEND_SSB);
        cover(past_valid && rst_n && state==RESET_DELAY);
        cover(past_valid && rst_n && intstat[6]);
    end
`endif
`undef FINISH
endmodule
