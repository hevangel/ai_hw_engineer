`timescale 1ns/1ps
// Intel 8272A host/decoded-sector controller. See spec/spec.md for the media boundary.
module intel_8272 #(
    parameter integer RQM_DELAY_US = 12,
    parameter integer MS_US = 1000
) (
    input logic clk, rst_n, us_tick,
    input logic cs_n, rd_n, wr_n, dack_n, a0, tc,
    input logic [7:0] db_in,
    output logic [7:0] db_out,
    output logic db_oe, irq, drq,
    input logic [3:0] ready, write_protect, track0, two_sided, fault,
    output logic [3:0] step, direction,
    output logic [1:0] unit,
    output logic head, mfm, head_load, media_active, media_write, media_format,
    input logic index_pulse, header_valid,
    input logic [7:0] header_c, header_h, header_r, header_n,
    input logic header_deleted, header_missing_data, header_crc_error,
    input logic media_byte_valid,
    input logic [7:0] media_byte,
    input logic media_end, media_crc_error, write_slot,
    output logic sector_begin, sector_end, tx_valid,
    output logic [7:0] tx_byte, sector_c, sector_h, sector_r, sector_n,
    output logic sector_deleted
);
    typedef enum logic [3:0] {IDLE, COMMAND, LAUNCH, LOAD, INDEX_WAIT, SEARCH,
        READ_DATA, WRITE_DATA, SCAN_DATA, FORMAT_ID, FORMAT_DATA, SECTOR_DONE,
        FORMAT_END, RESULT} phase_t;
    phase_t phase;
    logic [7:0] command [0:8];
    logic [7:0] result [0:6];
    logic [3:0] command_index, command_length, result_index, result_length;
    logic [4:0] opcode;
    logic nd, mt, skip_deleted, deleted_command;
    logic [7:0] c, h, r, n, eot, dtl, st1, st2;
    logic [7:0] format_count, format_total, format_fill;
    logic [1:0] format_index;
    logic [13:0] byte_count, sector_size, host_limit;
    logic [7:0] data_latch;
    logic data_pending, dma_token, tc_seen, irq_result, irq_event, write_buffer_valid;
    logic rd_old, wr_old, dack_old;
    logic [19:0] delay_us, load_us, unload_us, service_us;
    logic [3:0] srt, hut;
    logic [6:0] hlt;
    logic [1:0] index_count;
    logic saw_header, scan_ok, scan_equal, cm_stop;
    logic [7:0] track_count;
    logic [3:0] seek_active, seek_busy, event_pending, recal;
    logic [7:0] pcn [0:3], target [0:3], event_st0 [0:3], event_pcn [0:3];
    logic [6:0] recal_steps [0:3];
    logic [19:0] seek_us [0:3];
    logic [3:0] ready_cached;
    logic [1:0] poll_unit, sis_unit;
    logic sis_event;
    logic [9:0] poll_us;
    logic read_edge, write_edge, cpu_read, cpu_write, data_read, data_write;
    logic execution, to_host, rqm, dio, serviced;
    integer i;

    function automatic logic [3:0] length_for(input logic [4:0] op);
        case (op)
            5'h02,5'h05,5'h06,5'h09,5'h0c,5'h11,5'h19,5'h1d: length_for=9;
            5'h03,5'h0f: length_for=3;
            5'h04,5'h07,5'h0a: length_for=2;
            5'h0d: length_for=6;
            default: length_for=1;
        endcase
    endfunction
    function automatic logic valid_opcode(input logic [7:0] op);
        case (op[4:0])
            5'h03,5'h04,5'h07,5'h08,5'h0f: valid_opcode=(op[7:5]==0);
            5'h02,5'h0a,5'h0d: valid_opcode=(!op[7] && !op[5]);
            5'h05,5'h09: valid_opcode=!op[5];
            5'h06,5'h0c,5'h11,5'h19,5'h1d: valid_opcode=1;
            default: valid_opcode=0;
        endcase
    endfunction
    function automatic logic [19:0] step_time(input logic [3:0] rate);
        step_time=20'((16-int'(rate))*MS_US);
    endfunction
    function automatic logic [19:0] unload_time(input logic [3:0] rate);
        // ASSUMPTION A4: zero HUT denotes 256 ms.
        unload_time=20'((rate==0 ? 256 : int'(rate)*16)*MS_US);
    endfunction
    function automatic logic [19:0] deadline(input logic writing, density);
        deadline=writing ? (density ? 20'd15 : 20'd31) :
                             (density ? 20'd13 : 20'd27);
    endfunction

    `define FDC_REQUEST_BYTE begin \
        data_pending<=1; \
        dma_token<=0; \
        service_us<=deadline(opcode==5'h05 || opcode==5'h09 || opcode==5'h0d,mfm); \
    end
    `define FDC_FINISH(status0,status1,status2,rc,rh,rr,rn) begin \
        result[0]<=status0; result[1]<=(status1) & 8'hb7; result[2]<=(status2) & 8'h7f; \
        result[3]<=rc; result[4]<=rh; result[5]<=rr; result[6]<=rn; \
        result_index<=0; result_length<=7; phase<=RESULT; \
        delay_us<=0; irq_result<=1; data_pending<=0; dma_token<=0; \
        unload_us<=unload_time(hut); \
    end
    `define FDC_INVALID_RESULT begin \
        result[0]<=8'h80; result_index<=0; result_length<=1; \
        phase<=RESULT; delay_us<=0; sis_event<=0; \
    end
    `define FDC_COMPLETED_ID(status1,status2) begin \
        if (r!=eot) `FDC_FINISH({5'b0,head,unit},status1,status2,c,h,r+8'd1,n) \
        else if (mt && h==0) `FDC_FINISH({5'b0,head,unit},status1,status2,c,8'd1,8'd1,n) \
        else `FDC_FINISH({5'b0,head,unit},status1,status2,c+8'd1,mt ? 8'd0 : h,8'd1,n) \
    end
    `define FDC_NEXT_SECTOR begin \
        byte_count<=0; index_count<=0; saw_header<=0; \
        scan_ok<=1; scan_equal<=1; tc_seen<=0; \
        if (r==eot) begin \
            if (mt && h==0) begin h<=1; head<=1; r<=1; phase<=SEARCH; end \
            else `FDC_FINISH({2'b01,3'b0,head,unit},st1|8'h80,st2,c,h,r,n) \
        end else begin \
            r<=r+((opcode==5'h11 || opcode==5'h19 || opcode==5'h1d) ? dtl : 8'd1); \
            phase<=SEARCH; \
        end \
    end

    always_comb begin
        read_edge=rd_old && !rd_n;
        write_edge=wr_old && !wr_n;
        cpu_read=read_edge && !cs_n;
        cpu_write=write_edge && !cs_n;
        execution=(phase>=LOAD && phase<=FORMAT_END);
        to_host=(phase==READ_DATA || (phase==SECTOR_DONE &&
            (opcode==5'h02 || opcode==5'h06 || opcode==5'h0c)));
        dio=(phase==RESULT) || to_host;
        drq=!nd && data_pending && !dma_token;
        rqm=(delay_us==0) && ((phase==IDLE || phase==COMMAND || phase==RESULT) ||
            (nd && data_pending && (phase==READ_DATA || phase==WRITE_DATA ||
             phase==SCAN_DATA || phase==FORMAT_ID || phase==SECTOR_DONE)));
        data_read=to_host && data_pending && read_edge &&
            ((nd && !cs_n && a0 && rqm) || (!nd && !dack_n &&
              (dma_token || drq) && !(!cs_n && !a0)));
        data_write=!to_host && data_pending && write_edge &&
            ((nd && !cs_n && a0 && rqm) || (!nd && !dack_n && (dma_token || drq)));
        serviced=data_read || data_write;
        db_out=(a0 || (!nd && !dack_n && to_host && cs_n)) ?
            (phase==RESULT ? result[result_index[2:0]] : data_latch) :
            {rqm,dio,(nd && execution),(phase!=IDLE),seek_busy};
        db_oe=!rd_n && (!cs_n || (!nd && !dack_n && to_host));
        irq=irq_result || irq_event || (nd && data_pending);
        media_active=execution && phase!=LOAD;
        media_write=phase==WRITE_DATA || phase==FORMAT_DATA;
        media_format=phase==FORMAT_ID || phase==FORMAT_DATA || phase==FORMAT_END;
        sector_c=c; sector_h=h; sector_r=r; sector_n=n;
        sector_deleted=deleted_command;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            phase<=IDLE; command_index<=0; command_length<=0; result_index<=0;
            result_length<=1; opcode<=0; nd<=0; mt<=0; skip_deleted<=0;
            deleted_command<=0; c<=0; h<=0; r<=0; n<=0; eot<=0; dtl<=0;
            st1<=0; st2<=0; byte_count<=0; sector_size<=128; host_limit<=128;
            format_count<=0; format_total<=0; format_fill<=0; format_index<=0;
            data_latch<=0; data_pending<=0; dma_token<=0; tc_seen<=0;
            irq_result<=0; irq_event<=0; write_buffer_valid<=0;
            rd_old<=1; wr_old<=1; dack_old<=1;
            delay_us<=0; load_us<=0; unload_us<=0; service_us<=0;
            srt<=0; hut<=0; hlt<=0; index_count<=0; saw_header<=0;
            scan_ok<=1; scan_equal<=1; cm_stop<=0; track_count<=0; unit<=0; head<=0;
            mfm<=0; head_load<=0; sector_begin<=0; sector_end<=0;
            tx_valid<=0; tx_byte<=0; step<=0; direction<=0;
            seek_active<=0; seek_busy<=0; event_pending<=0; recal<=0;
            ready_cached<=0; poll_unit<=0; poll_us<=220; sis_unit<=0; sis_event<=0;
            for (i=0;i<9;i=i+1) command[i]<=0;
            for (i=0;i<7;i=i+1) result[i]<=0;
            for (i=0;i<4;i=i+1) begin
                pcn[i]<=0; target[i]<=0; event_st0[i]<=0; event_pcn[i]<=0;
                recal_steps[i]<=0; seek_us[i]<=0;
            end
        end else begin
            rd_old<=rd_n; wr_old<=wr_n; dack_old<=dack_n;
            step<=0; sector_begin<=0; sector_end<=0; tx_valid<=0;
            if (us_tick) begin
                if (delay_us!=0) delay_us<=delay_us-1'b1;
                if (load_us!=0) load_us<=load_us-1'b1;
                if (!execution && unload_us!=0) begin
                    unload_us<=unload_us-1'b1;
                    if (unload_us==1) head_load<=0;
                end
                if (data_pending && service_us!=0) service_us<=service_us-1'b1;
            end
            if (!nd && data_pending && dack_old && !dack_n) dma_token<=1;
            if (serviced) begin data_pending<=0; dma_token<=0; end
            if (data_write && phase==WRITE_DATA) begin
                data_latch<=db_in; write_buffer_valid<=1;
            end
            if (data_write && (phase==SCAN_DATA || phase==SECTOR_DONE)) begin
                // ASSUMPTION A3: FF on either side masks this comparison.
                if (data_latch!=8'hff && db_in!=8'hff) begin
                    if (data_latch!=db_in) scan_equal<=0;
                    if ((opcode==5'h11 && data_latch!=db_in) ||
                        (opcode==5'h19 && data_latch>db_in) ||
                        (opcode==5'h1d && data_latch<db_in)) scan_ok<=0;
                end
                if (tc && phase==SCAN_DATA) phase<=SECTOR_DONE;
            end
            if (execution && tc) begin
                tc_seen<=1;
                if (!serviced) begin data_pending<=0; dma_token<=0; end
            end

            if (cpu_read && a0 && rqm && phase==RESULT) begin
                if (result_index==0) begin
                    irq_result<=0;
                    if (sis_event) begin seek_busy[sis_unit]<=0; sis_event<=0; end
                end
                delay_us<=20'(RQM_DELAY_US);
                if (result_index+1'b1==result_length) begin phase<=IDLE; result_index<=0; end
                else result_index<=result_index+1'b1;
            end
            if (cpu_write && a0 && rqm && (phase==IDLE || phase==COMMAND)) begin
                delay_us<=20'(RQM_DELAY_US);
                if (phase==IDLE) begin
                    command[0]<=db_in; command_index<=1; command_length<=length_for(db_in[4:0]);
                    sis_event<=0;
                    if (!valid_opcode(db_in) || (event_pending!=0 && db_in!=8'h08))
                        `FDC_INVALID_RESULT
                    else if (length_for(db_in[4:0])==1) phase<=LAUNCH;
                    else phase<=COMMAND;
                end else begin
                    command[command_index]<=db_in;
                    command_index<=command_index+1'b1;
                    if (command_index+1'b1==command_length) phase<=LAUNCH;
                end
            end

            if (phase==LAUNCH && delay_us==0) begin
                opcode<=command[0][4:0]; unit<=command[1][1:0]; head<=command[1][2];
                mfm<=command[0][6]; mt<=command[0][7]; skip_deleted<=command[0][5];
                deleted_command<=command[0][4:0]==5'h09 || command[0][4:0]==5'h0c;
                st1<=0; st2<=0; byte_count<=0; tc_seen<=0; index_count<=0; write_buffer_valid<=0;
                saw_header<=0; track_count<=0; scan_ok<=1; scan_equal<=1; cm_stop<=0;
                case (command[0][4:0])
                    5'h03: begin srt<=command[1][7:4]; hut<=command[1][3:0];
                        hlt<=command[2][7:1]; nd<=command[2][0]; phase<=IDLE; end
                    5'h04: begin
                        result[0]<={fault[command[1][1:0]],write_protect[command[1][1:0]],
                            ready[command[1][1:0]],track0[command[1][1:0]],
                            two_sided[command[1][1:0]],command[1][2:0]};
                        result_length<=1; result_index<=0; phase<=RESULT;
                    end
                    5'h08: begin
                        irq_event<=0; result_index<=0; phase<=RESULT;
                        if (event_pending==0) begin result[0]<=8'h80; result_length<=1; end
                        else begin
                            if (event_pending[0]) begin
                                sis_unit<=0; result[0]<=event_st0[0]; result[1]<=event_pcn[0];
                                event_pending[0]<=0;
                            end else if (event_pending[1]) begin
                                sis_unit<=1; result[0]<=event_st0[1]; result[1]<=event_pcn[1];
                                event_pending[1]<=0;
                            end else if (event_pending[2]) begin
                                sis_unit<=2; result[0]<=event_st0[2]; result[1]<=event_pcn[2];
                                event_pending[2]<=0;
                            end else begin
                                sis_unit<=3; result[0]<=event_st0[3]; result[1]<=event_pcn[3];
                                event_pending[3]<=0;
                            end
                            result_length<=2; sis_event<=1;
                        end
                    end
                    5'h07,5'h0f: begin
                        seek_active[command[1][1:0]]<=1; seek_busy[command[1][1:0]]<=1;
                        recal[command[1][1:0]]<=command[0][4:0]==5'h07;
                        target[command[1][1:0]]<=command[2];
                        recal_steps[command[1][1:0]]<=0;
                        seek_us[command[1][1:0]]<=step_time(srt);
                        direction[command[1][1:0]]<=command[0][4:0]==5'h0f &&
                            command[2]>pcn[command[1][1:0]];
                        if (command[0][4:0]==5'h07) pcn[command[1][1:0]]<=0;
                        phase<=IDLE;
                    end
                    default: begin
                        c<=command[2]; h<=command[3]; r<=command[4]; n<=command[5];
                        eot<=command[6]; dtl<=command[8];
                        if (command[0][4:0]==5'h0d) begin
                            n<=command[2]; format_total<=command[3];
                            format_fill<=command[5]; format_count<=0; format_index<=0;
                            sector_size<=14'd128 << command[2][2:0];
                        end else begin
                            sector_size<=14'd128 << command[5][2:0];
                            host_limit<=command[5]==0 && command[8]!=0 &&
                                (command[0][4:0]==5'h05 || command[0][4:0]==5'h06 ||
                                 command[0][4:0]==5'h09 || command[0][4:0]==5'h0c) ?
                                {6'b0,command[8]} : (14'd128 << command[5][2:0]);
                        end
                        // ASSUMPTION A4: HLT=0 starts the search immediately.
                        load_us<=head_load ? 20'd0 : 20'(int'(hlt)*2*MS_US);
                        head_load<=1; unload_us<=0; phase<=LOAD;
                    end
                endcase
            end

            if (execution) begin
                if (!ready[unit]) `FDC_FINISH({2'b01,1'b0,1'b0,1'b1,head,unit},st1,st2,c,h,r,n)
                else if (fault[unit]) `FDC_FINISH({2'b01,1'b0,1'b1,1'b0,head,unit},st1,st2,c,h,r,n)
                else if ((opcode==5'h05 || opcode==5'h09 || opcode==5'h0d) && write_protect[unit])
                    `FDC_FINISH({2'b01,3'b0,head,unit},8'h02,st2,c,h,r,n)
                else if (tc && (phase==LOAD || phase==INDEX_WAIT || phase==SEARCH ||
                    phase==FORMAT_ID || phase==FORMAT_END))
                    `FDC_FINISH({5'b0,head,unit},st1,st2,c,h,r,n)
                else if (data_pending && us_tick && service_us==1 && !serviced && !tc)
                    `FDC_FINISH({2'b01,3'b0,head,unit},st1|8'h10,st2,c,h,r,n)
                else case (phase)
                    LOAD: if (load_us==0) begin
                        if ((opcode==5'h0d ? command[2] : n)>6 && opcode!=5'h0a)
                            `FDC_FINISH({2'b01,3'b0,head,unit},8'h04,0,c,h,r,n)
                        else if ((opcode==5'h11 || opcode==5'h19 || opcode==5'h1d) &&
                            dtl!=1 && dtl!=2) `FDC_INVALID_RESULT
                        else phase<=(opcode==5'h02 || opcode==5'h0d) ? INDEX_WAIT : SEARCH;
                    end
                    INDEX_WAIT: if (index_pulse) begin
                        if (opcode==5'h0d) begin
                            if (format_total==0) phase<=FORMAT_END;
                            else begin phase<=FORMAT_ID; `FDC_REQUEST_BYTE end
                        end else phase<=SEARCH;
                    end
                    SEARCH: begin
                        if (index_pulse) begin
                            index_count<=index_count+1'b1;
                            if (index_count==1) `FDC_FINISH({2'b01,3'b0,head,unit},
                                st1 | (saw_header ? 8'h04 : 8'h05),st2,c,h,r,n)
                        end
                        if (header_valid) begin
                            saw_header<=1;
                            if (opcode==5'h0a) `FDC_FINISH(
                                {header_crc_error ? 2'b01 : 2'b00,3'b0,head,unit},
                                header_crc_error ? 8'h20 : 8'h00,0,
                                header_c,header_h,header_r,header_n)
                            else if (opcode==5'h02 || (header_h==h && header_r==r && header_n==n)) begin
                                if (opcode==5'h02) begin
                                    byte_count<=0;
                                    c<=header_c; h<=header_h; r<=header_r; n<=header_n;
                                    sector_size<=14'd128 << header_n[2:0];
                                    host_limit<=14'd128 << header_n[2:0];
                                end
                                if (header_n>6) `FDC_FINISH({2'b01,3'b0,head,unit},st1|8'h04,st2,
                                    header_c,header_h,header_r,header_n)
                                else if (opcode!=5'h02 && header_c!=c)
                                    `FDC_FINISH({2'b01,3'b0,head,unit},st1|8'h04,
                                        st2|8'h10|(header_c==8'hff ? 8'h02 : 8'h00),
                                        header_c,header_h,header_r,header_n)
                                else if (header_crc_error && opcode!=5'h02)
                                    `FDC_FINISH({2'b01,3'b0,head,unit},st1|8'h20,st2,c,h,r,n)
                                else if (header_missing_data)
                                    `FDC_FINISH({2'b01,3'b0,head,unit},st1|8'h01,st2|8'h01,c,h,r,n)
                                else if (opcode!=5'h05 && opcode!=5'h09 && opcode!=5'h02 &&
                                    header_deleted!=deleted_command && skip_deleted) begin
                                    if (opcode==5'h11 || opcode==5'h19 || opcode==5'h1d) st2<=st2|8'h40;
                                    `FDC_NEXT_SECTOR
                                end else begin
                                    if (header_crc_error) st1<=st1|8'h20;
                                    if (opcode!=5'h05 && opcode!=5'h09 && header_deleted!=deleted_command)
                                        st2<=st2|8'h40;
                                    cm_stop<=opcode!=5'h05 && opcode!=5'h09 && header_deleted!=deleted_command;
                                    byte_count<=0; scan_ok<=1; scan_equal<=1;
                                    if (opcode==5'h05 || opcode==5'h09) begin
                                        phase<=WRITE_DATA; sector_begin<=1; `FDC_REQUEST_BYTE
                                    end else if (opcode==5'h11 || opcode==5'h19 || opcode==5'h1d)
                                        phase<=SCAN_DATA;
                                    else phase<=READ_DATA;
                                end
                            end
                        end
                    end
                    READ_DATA,SCAN_DATA: begin
                        if (data_read) begin
                            if (tc) tc_seen<=1;
                        end
                        if (media_byte_valid && byte_count<sector_size) begin
                            byte_count<=byte_count+1'b1;
                            if (!tc_seen && !tc && byte_count<host_limit) begin
                                if (data_pending && !serviced)
                                    `FDC_FINISH({2'b01,3'b0,head,unit},st1|8'h10,st2,c,h,r,n)
                                else begin data_latch<=media_byte; `FDC_REQUEST_BYTE end
                            end
                        end
                        if (media_end) begin
                            if (media_crc_error) begin st1<=st1|8'h20; st2<=st2|8'h20; end
                            phase<=SECTOR_DONE;
                        end
                    end
                    WRITE_DATA: begin
                        if (write_slot && byte_count<sector_size) begin
                            if (!tc_seen && !tc && byte_count<host_limit && data_pending && !data_write)
                                `FDC_FINISH({2'b01,3'b0,head,unit},st1|8'h10,st2,c,h,r,n)
                            else begin
                                tx_valid<=1;
                                tx_byte<=((write_buffer_valid || data_write) && byte_count<host_limit) ?
                                    (data_write ? db_in : data_latch) : 8'd0;
                                write_buffer_valid<=0;
                                byte_count<=byte_count+1'b1;
                                if (byte_count+1'b1==sector_size) begin sector_end<=1; phase<=SECTOR_DONE; end
                                else if (!tc_seen && !tc && byte_count+1'b1<host_limit) `FDC_REQUEST_BYTE
                            end
                        end
                    end
                    FORMAT_ID: if (data_write) begin
                        case (format_index)
                            0: c<=db_in;
                            1: h<=db_in;
                            2: r<=db_in;
                            3: n<=db_in;
                        endcase
                        format_index<=format_index+1'b1;
                        if (format_index==3) begin
                            phase<=FORMAT_DATA; byte_count<=0; sector_begin<=1;
                        end else `FDC_REQUEST_BYTE
                    end
                    FORMAT_DATA: if (write_slot && byte_count<sector_size) begin
                        tx_valid<=1; tx_byte<=format_fill; byte_count<=byte_count+1'b1;
                        if (byte_count+1'b1==sector_size) begin
                            sector_end<=1; format_count<=format_count+1'b1;
                            if (format_count+1'b1==format_total || tc_seen || tc) phase<=FORMAT_END;
                            else begin phase<=FORMAT_ID; `FDC_REQUEST_BYTE end
                        end
                    end
                    FORMAT_END: if (index_pulse) `FDC_FINISH({5'b0,head,unit},st1,st2,c,h,r+8'd1,n)
                    SECTOR_DONE: if ((!data_pending || tc_seen || tc) && !data_write) begin
                        data_pending<=0; dma_token<=0;
                        if ((st1 & 8'h20)!=0 || cm_stop) begin
                            if (opcode==5'h02 && track_count+1'b1<eot) begin
                                track_count<=track_count+1'b1; index_count<=0; phase<=SEARCH;
                            end else `FDC_FINISH({2'b01,3'b0,head,unit},st1,st2,c,h,r,n)
                        end else if (opcode==5'h11 || opcode==5'h19 || opcode==5'h1d) begin
                            // ASSUMPTION A6: normal scan result IDs use the shared
                            // read/scan advancement convention; see the assumption ledger.
                            if (scan_ok || tc_seen || tc || (r==eot && !(mt && h==0))) `FDC_COMPLETED_ID(st1,
                                (st2 & 8'hf3) | (scan_ok ? (scan_equal ? 8'h08 : 8'h00) : 8'h04))
                            else begin st2<=(st2 & 8'hf7)|8'h04; `FDC_NEXT_SECTOR end
                        end else if (tc_seen || tc) `FDC_COMPLETED_ID(st1,st2)
                        else if (opcode==5'h02) begin
                            track_count<=track_count+1'b1;
                            if (track_count+1'b1==eot) `FDC_FINISH({5'b0,head,unit},st1,st2,c,h,r+8'd1,n)
                            else begin index_count<=0; phase<=SEARCH; end
                        end else `FDC_NEXT_SECTOR
                    end
                    default: begin end
                endcase
            end

            // ASSUMPTION A2: a per-drive latest-event latch, lowest-unit SIS priority.
            // Event generation follows acknowledgement so a simultaneous new event wins.
            if (us_tick && (phase==IDLE || phase==COMMAND || phase==LAUNCH)) begin
                if (poll_us>1) poll_us<=poll_us-1'b1;
                else begin
                    poll_unit<=poll_unit+1'b1;
                    poll_us<=poll_unit==2 ? 10'd440 : 10'd220;
                    ready_cached[poll_unit]<=ready[poll_unit];
                    if (ready_cached[poll_unit]!=ready[poll_unit]) begin
                        event_pending[poll_unit]<=1; irq_event<=1;
                        event_st0[poll_unit]<={2'b11,2'b00,!ready[poll_unit],1'b0,poll_unit};
                        event_pcn[poll_unit]<=pcn[poll_unit];
                    end
                end
            end
            for (i=0;i<4;i=i+1) begin
                if (seek_active[i]) begin
                    if (!ready[i] || (recal[i] ? track0[i] : pcn[i]==target[i])) begin
                        seek_active[i]<=0; event_pending[i]<=1; irq_event<=1;
                        event_st0[i]<={ready[i] ? 2'b00 : 2'b01,1'b1,1'b0,!ready[i],1'b0,2'(i)};
                        event_pcn[i]<=pcn[i];
                    end else if (us_tick) begin
                        if (seek_us[i]>1) seek_us[i]<=seek_us[i]-1'b1;
                        else begin
                            step[i]<=1; seek_us[i]<=step_time(srt);
                            if (recal[i]) begin
                                // ASSUMPTION A4: recalibration uses outward direction=0.
                                if (recal_steps[i]<77) recal_steps[i]<=recal_steps[i]+1'b1;
                                if (recal_steps[i]>=76) begin
                                    seek_active[i]<=0; event_pending[i]<=1; irq_event<=1;
                                    event_st0[i]<={2'b01,1'b1,1'b1,2'b00,2'(i)};
                                    event_pcn[i]<=0;
                                end
                            end else pcn[i]<=direction[i] ? pcn[i]+1'b1 : pcn[i]-1'b1;
                        end
                    end
                end
            end
        end
    end
`ifdef FORMAL
    `include "intel_8272_props.sv"
`endif
    `undef FDC_REQUEST_BYTE
    `undef FDC_FINISH
    `undef FDC_INVALID_RESULT
    `undef FDC_COMPLETED_ID
    `undef FDC_NEXT_SECTOR
endmodule
