interface intel_8272_if(input logic clk);
    logic rst_n=0, us_tick=1, cs_n=1, rd_n=1, wr_n=1, dack_n=1, a0=0, tc=0;
    logic [7:0] db_in=0, db_out;
    logic db_oe, irq, drq;
    logic [3:0] ready=0, write_protect=0, track0=15, two_sided=15, fault=0;
    logic [3:0] step, direction;
    logic [1:0] unit;
    logic head, mfm, head_load, media_active, media_write, media_format;
    logic index_pulse=0, header_valid=0;
    logic [7:0] header_c=0, header_h=0, header_r=0, header_n=0;
    logic header_deleted=0, header_missing_data=0, header_crc_error=0;
    logic media_byte_valid=0;
    logic [7:0] media_byte=0;
    logic media_end=0, media_crc_error=0, write_slot=0;
    logic sector_begin, sector_end, tx_valid, sector_deleted;
    logic [7:0] tx_byte, sector_c, sector_h, sector_r, sector_n;
    integer checks=0;
    bit monitor_enable=0;
    task automatic tick(input integer count=1);
        repeat(count) begin @(posedge clk); @(negedge clk); end
    endtask
    task automatic check(input bit ok,input string message);
        checks++;
        if (!ok) $fatal(1,"%s at %0t",message,$time);
    endtask
    task automatic reset;
        rst_n=0; cs_n=1; rd_n=1; wr_n=1; dack_n=1; tc=0;
        ready=0; fault=0; write_protect=0; track0=15;
        header_valid=0; media_byte_valid=0; media_end=0; index_pulse=0; write_slot=0;
        tick(3); rst_n=1; tick(2);
    endtask
    task automatic wait_rqm(input bit read_direction);
        integer timeout;
        a0=0; cs_n=0; #1;
        timeout=0;
        while (!(db_out[7] && db_out[6]==read_direction)) begin
            tick(); timeout++;
            if (timeout>3000) $fatal(1,"RQM timeout msr=%02x",db_out);
        end
        cs_n=1;
    endtask
    task automatic cpu_put(input logic [7:0] value,input integer hold=1);
        wait_rqm(0); cs_n=0; a0=1; db_in=value; wr_n=0;
        tick(hold); wr_n=1; cs_n=1; tick();
    endtask
    task automatic cpu_get(output logic [7:0] value,input integer hold=1);
        wait_rqm(1); cs_n=0; a0=1; rd_n=0; #1; value=db_out;
        check(db_oe,"read drives data bus"); tick(hold); rd_n=1; cs_n=1; tick();
    endtask
    task automatic data_get(output logic [7:0] value,input bit non_dma,input bit terminal=0);
        integer timeout;
        timeout=0;
        if (non_dma) begin
            wait_rqm(1); check(irq,"ND byte interrupt"); cs_n=0; a0=1;
        end else begin
            while (!drq) begin tick(); timeout++; if (timeout>100)
                $fatal(1,"DRQ timeout byte=%02x irq=%b",db_out,irq); end
            cs_n=1; a0=0; dack_n=0; tick(2);
            check(!drq,"DACK drops DRQ without consuming byte");
        end
        tc=terminal; rd_n=0; #1; value=db_out; check(db_oe,"execution bus enable");
        tick(); rd_n=1; dack_n=1; cs_n=1; tc=0; tick();
    endtask
    task automatic data_put(input logic [7:0] value,input bit non_dma,input bit terminal=0);
        integer timeout;
        timeout=0;
        if (non_dma) begin wait_rqm(0); cs_n=0; a0=1; check(irq,"ND write interrupt"); end
        else begin
            while (!drq) begin tick(); timeout++; if (timeout>100) $fatal(1,"write DRQ timeout"); end
            cs_n=1; dack_n=0; tick(); check(!drq,"write DACK token");
        end
        db_in=value; tc=terminal; wr_n=0; tick();
        wr_n=1; dack_n=1; cs_n=1; tc=0; tick();
    endtask
    task automatic command9(input logic [7:0] op,input logic [7:0] cc=3,
        hh=0,rr=1,nn=0,last=1,tail=0);
        cpu_put(op); cpu_put({5'd0,hh[0],2'd0}); cpu_put(cc); cpu_put(hh);
        cpu_put(rr); cpu_put(nn); cpu_put(last); cpu_put(8'h1b); cpu_put(tail);
        tick(4);
    endtask
    task automatic header(input logic [7:0] cc=3,hh=0,rr=1,nn=0,
        input bit deleted=0,missing=0,bad_crc=0);
        header_c=cc; header_h=hh; header_r=rr; header_n=nn;
        header_deleted=deleted; header_missing_data=missing; header_crc_error=bad_crc;
        header_valid=1; tick(); header_valid=0; tick();
    endtask
    task automatic index_event;
        index_pulse=1; tick(); index_pulse=0; tick();
    endtask
    task automatic disk_byte(input logic [7:0] value);
        media_byte=value; media_byte_valid=1; tick(); media_byte_valid=0;
    endtask
    task automatic disk_end(input bit bad_crc=0);
        media_crc_error=bad_crc; media_end=1; tick(); media_end=0; media_crc_error=0; tick();
    endtask
    task automatic disk_write(output logic [7:0] value);
        write_slot=1; tick(); write_slot=0;
        check(tx_valid,"media write byte valid"); value=tx_byte; tick();
    endtask
    task automatic result7(output logic [55:0] values);
        logic [7:0] value;
        check(irq,"completion interrupt");
        for (integer k=0;k<7;k++) begin
            cpu_get(value); values[55-k*8 -:8]=value;
            if (k==0) check(!irq,"first result acknowledges IRQ");
        end
        tick(3);
    endtask
    task automatic startup(input bit non_dma=0);
        logic [7:0] value;
        reset(); ready=15; tick(1300);
        for (integer k=0;k<4;k++) begin
            cpu_put(8'h08); cpu_get(value); check(value==8'hc0+8'(k),"startup ready event unit");
            cpu_get(value); check(value==0,"startup PCN");
        end
        cpu_put(8'h03); cpu_put(8'hf1); cpu_put(non_dma ? 8'h01 : 8'h00); tick(4);
    endtask
endinterface
