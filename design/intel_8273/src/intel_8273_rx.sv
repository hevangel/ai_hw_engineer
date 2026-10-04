`timescale 1ns/1ps
// Eight raw-bit look-behind excludes complete flags before zero deletion.
// Two decoded-byte tail registers exclude the FCS from host transfers.
module intel_8273_rx (
    input logic clk, rst_n, tick, enable, restart, rxd,
    input logic nrzi, hdlc, buffered, selective, eop_mode,
    input logic [7:0] match1, match2,
    output logic data_valid,
    output logic [7:0] data,
    output logic frame_done,
    output logic [7:0] result, address, control,
    output logic [15:0] length,
    output logic flag_seen, eop_seen, idle_seen
);
    logic [7:0] raw_q, raw_n, byte_q, byte_n, tail0_q, tail0_n, tail1_q, tail1_n;
    logic [7:0] address_q,address_n,control_q,control_n;
    logic [15:0] crc_q,crc_n;
    // Include A/C and FCS without overflowing a 65535-byte information frame.
    logic [16:0] count_q,count_n;
    logic [3:0] raw_len_q,raw_len_n,run_q,run_n;
    logic [2:0] bit_q,bit_n,ones_q,ones_n;
    logic prev_q,prev_n,in_frame_q,in_frame_n,accepted_q,accepted_n;
    logic second_q,second_n,had_frame_q,had_frame_n,had_flag_q,had_flag_n;
    logic decoded, candidate, ending, aborting;
    logic data_valid_n,frame_done_n,flag_n,eop_n,idle_n;
    logic [7:0] data_n,result_n;
    logic [15:0] length_n;
    function automatic [15:0] crc_bit(input logic [15:0] crc,input logic b);
        crc_bit=(crc>>1)^((crc[0]^b)?16'h8408:16'h0000);
    endfunction
    always_comb begin
        raw_n=raw_q; byte_n=byte_q; tail0_n=tail0_q; tail1_n=tail1_q;
        address_n=address_q; control_n=control_q; crc_n=crc_q; count_n=count_q;
        raw_len_n=raw_len_q; run_n=run_q; bit_n=bit_q; ones_n=ones_q;
        prev_n=prev_q; in_frame_n=in_frame_q; accepted_n=accepted_q;
        second_n=second_q; had_frame_n=had_frame_q; had_flag_n=had_flag_q;
        data_valid_n=0; frame_done_n=0; flag_n=0; eop_n=0; idle_n=0;
        data_n=data; result_n=result; length_n=length;
        decoded=nrzi ? (rxd==prev_q) : rxd;
        candidate=raw_q[0]; ending=0; aborting=0;
        if (!enable || restart) begin
            raw_len_n=0; run_n=0; in_frame_n=0; count_n=0; bit_n=0;
            crc_n=16'hffff; ones_n=0; had_frame_n=0; had_flag_n=0;
            accepted_n=!selective; second_n=0; byte_n=0;
            // Track physical line history even while waiting for a command.
            if (tick) prev_n=rxd;
        end else if (tick) begin
            prev_n=rxd; raw_n={decoded,raw_q[7:1]};
            if (raw_len_q<8) raw_len_n=raw_len_q+1'b1;
            if (decoded) begin if (run_q!=15) run_n=run_q+1'b1; end
            else run_n=0;
            ending=raw_len_q>=7 && raw_n==8'h7e;
            aborting=decoded && run_n==(hdlc ? 4'd7 : 4'd8);
            // Detect idle only after some frame activity, not startup mark fill.
            if (decoded && run_q==14 && had_frame_q) begin
                idle_n=1; frame_done_n=1; result_n=8'he5; length_n=0;
                in_frame_n=0; had_frame_n=0;
            end else if (aborting || (eop_mode && decoded && run_n==7)) begin
                if (eop_mode && run_n==7) begin
                    frame_done_n=1; result_n=8'he6; length_n=0;
                end else if ((in_frame_q && (count_q!=0 || bit_q!=0)) || !had_flag_q) begin
                    frame_done_n=1; result_n=8'he4;
                    length_n=buffered ? (count_q>4 ? 16'(count_q-17'd4) : 16'd0) :
                                         (count_q>2 ? 16'(count_q-17'd2) : 16'd0);
                end
                in_frame_n=0; raw_len_n=0; count_n=0; bit_n=0; ones_n=0;
                crc_n=16'hffff;
            end else begin
                if (in_frame_q && raw_len_q==8) begin
                    if (!candidate && ones_q==5) ones_n=0;
                    else begin
                        ones_n=candidate ? ones_q+1'b1 : 3'd0;
                        byte_n={candidate,byte_q[7:1]}; bit_n=bit_q+1'b1;
                        crc_n=crc_bit(crc_q,candidate);
                        if (bit_q==7) begin
                            bit_n=0;
                            if (count_q!=17'h1ffff) count_n=count_q+1'b1;
                            if (count_q==0) begin
                                address_n=byte_n;
                                accepted_n=!selective || byte_n==match1 || byte_n==match2;
                                second_n=selective && byte_n!=match1 && byte_n==match2;
                            end
                            if (count_q==1) control_n=byte_n;
                            if (count_q>=2 && (!buffered || count_q>=4) && accepted_q) begin
                                data_valid_n=1; data_n=tail0_q;
                            end
                            tail0_n=tail1_q; tail1_n=byte_n;
                        end
                    end
                end
                if (ending) begin
                    flag_n=1; had_flag_n=1;
                    if (in_frame_q && (count_n!=0 || bit_n!=0)) begin
                        had_frame_n=1;
                        if (accepted_n && (count_n>=4 || !buffered)) begin
                            frame_done_n=1;
                            length_n=buffered ? (count_n>=4 ? 16'(count_n-17'd4) : 16'd0) :
                                                (count_n>=2 ? 16'(count_n-17'd2) : 16'd0);
                            result_n=(bit_n==0 ? 8'he0 : {bit_n-3'd1,5'b0}) |
                                (count_n<4 ? 8'h07 : (crc_n!=16'hf0b8 || bit_n!=0) ?
                                 8'h03 : second_n ? 8'h01 : 8'h00);
                        end
                    end
                    raw_len_n=0; in_frame_n=1; crc_n=16'hffff; count_n=0;
                    bit_n=0; ones_n=0; byte_n=0;
                    accepted_n=!selective; second_n=0;
                end
            end
            // Intel's GA/EOP character is 01111111: seven ones following zero.
            // SDLC abort is eight ones; HDLC uses seven as an abort instead.
            if (decoded && run_n==7) eop_n=1;
        end
    end
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            raw_q<=0; byte_q<=0; tail0_q<=0; tail1_q<=0;
            address_q<=0; control_q<=0; crc_q<=16'hffff; count_q<=0;
            raw_len_q<=0; run_q<=0; bit_q<=0; ones_q<=0; prev_q<=1;
            in_frame_q<=0; accepted_q<=0; second_q<=0; had_frame_q<=0; had_flag_q<=0;
            data_valid<=0; data<=0; frame_done<=0; result<=0; length<=0;
            address<=0; control<=0; flag_seen<=0; eop_seen<=0; idle_seen<=0;
        end else begin
            raw_q<=raw_n; byte_q<=byte_n; tail0_q<=tail0_n; tail1_q<=tail1_n;
            address_q<=address_n; control_q<=control_n; crc_q<=crc_n; count_q<=count_n;
            raw_len_q<=raw_len_n; run_q<=run_n; bit_q<=bit_n; ones_q<=ones_n;
            prev_q<=prev_n; in_frame_q<=in_frame_n; accepted_q<=accepted_n;
            second_q<=second_n; had_frame_q<=had_frame_n; had_flag_q<=had_flag_n;
            data_valid<=data_valid_n; data<=data_n; frame_done<=frame_done_n;
            result<=result_n; length<=length_n; address<=address_n; control<=control_n;
            flag_seen<=flag_n; eop_seen<=eop_n; idle_seen<=idle_n;
        end
    end
`ifdef FORMAL
    logic rx_formal_past_valid=0;
    always_ff @(posedge clk) rx_formal_past_valid<=1;
    always_ff @(posedge clk) if (rst_n) begin
        assert(raw_len_q<=8);
        // Flags/restarts flush the delayed data and its stuffing history.
        if (raw_len_q<8) assert(ones_q==0);
        if (rx_formal_past_valid && data_valid) assert($past(enable && tick && !restart));
    end
`endif
endmodule
