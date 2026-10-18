`timescale 1ns/1ps
// ASSUMPTION A4/A5: completed-byte external keyboard/mouse boundary.
// Gate-array semantics: IBM Model 25 TR and independent 86Box kbc_ps2_m25.c;
// Model 30 ROM still performs all initialization and scan-code translation.
module model30_keyboard (
    input logic clk,rst_n,read_strobe,write_strobe,
    input logic [7:0] address,wdata,icw1,icw2,
    output logic [7:0] rdata,diagnostic_irqs,
    output logic irq,nmi,
    input logic key_valid,
    input logic [7:0] key_code,
    output logic key_ready,
    output logic [1:0] scan_set,
    input logic mouse_valid,
    input logic [7:0] mouse_code,
    output logic mouse_ready,
    input logic rtc_irq
);
    logic [7:0] latch60,control66,control69,diagnostic;
    logic [7:0] receive[0:1];
    logic [1:0] full,tx_ready,enabled,parameter_pending;
    logic [7:0] parameter_cmd[0:1];
    logic [7:0] replies[0:1][0:3];
    logic [2:0] reply_count[0:1];
    logic [1:0] reply_head[0:1];
    logic [15:0] delay_count[0:1];
    logic nmi_enabled;
    assign irq=|full;
    assign key_ready=enabled[1] && !full[1] && reply_count[1]==0 && delay_count[1]==0;
    assign mouse_ready=enabled[0] && !full[0] && reply_count[0]==0 && delay_count[0]==0;
    always_comb begin
        rdata=8'hff;
        case(address)
            8'h60:rdata=latch60;
            8'h63:rdata=control69[6] ? icw1:icw2;
            8'h66:rdata=control66|8'h04;
            8'h67:rdata=receive[0];
            8'h68:rdata=receive[1];
            8'h69:rdata=control69;
            // ASSUMPTION A12: stock 720K drive identification reads high.
            // Original 02/05/87 ROM F000:0F0E tests bit 0 before marking
            // a drive as 1.44M; Jan-1987 TR specifies 720K/type 3 only.
            8'h6a:rdata={2'b0,full[0],2'b0,full[1],2'b01};
            8'ha0:rdata={4'b0,full[1],full[0],1'b0,rtc_irq};
            default:rdata=8'hff;
        endcase
    end
    always_ff @(posedge clk) begin
        nmi<=0;
        if(!rst_n) begin
            latch60<=0;control66<=0;control69<=0;diagnostic<=0;
            diagnostic_irqs<=0;full<=0;tx_ready<=0;enabled<=0;
            parameter_pending<=0;nmi_enabled<=1;scan_set<=1;
            for(integer p=0;p<2;p=p+1) begin
                receive[p]<=0;reply_count[p]<=0;reply_head[p]<=0;delay_count[p]<=0;
                parameter_cmd[p]<=0;
                for(integer j=0;j<4;j=j+1) replies[p][j]<=0;
            end
        end else begin
            for(integer p=0;p<2;p=p+1) begin
                if(delay_count[p]!=0) delay_count[p]<=delay_count[p]-16'd1;
                else if(!full[p] && reply_count[p]!=0) begin
                    receive[p]<=replies[p][reply_head[p]];full[p]<=1;
                    reply_head[p]<=reply_head[p]+2'd1;reply_count[p]<=reply_count[p]-3'd1;
                    delay_count[p]<=800;
                end
            end
            if(key_valid && key_ready) begin receive[1]<=key_code;full[1]<=1;end
            if(mouse_valid && mouse_ready) begin receive[0]<=mouse_code;full[0]<=1;end
            if(write_strobe) begin
                case(address)
                    8'h60:latch60<=wdata;
                    8'h63:begin
                        if(control69[7]) begin
                            diagnostic_irqs<=wdata&8'hfc;
                            if(control69[2] && !diagnostic[0] && wdata[0] && nmi_enabled) nmi<=1;
                        end
                        diagnostic<=wdata;
                    end
                    8'h66:begin
                        if(!control66[4] && wdata[4]) full[0]<=0;
                        if(!control66[6] && wdata[6]) full[1]<=0;
                        control66<=wdata&8'hfb;
                    end
                    8'h69:begin
                        if(!control69[3] && wdata[3]) tx_ready[0]<=1;
                        if(!control69[4] && wdata[4]) tx_ready[1]<=1;
                        if(!wdata[7]) diagnostic_irqs<=0;
                        control69<=wdata;
                    end
                    8'ha0:nmi_enabled<=wdata[7];
                    8'h67,8'h68:begin
                        for(integer p=0;p<2;p=p+1) if(address==(p==0 ? 8'h67:8'h68) && tx_ready[p]) begin
                            tx_ready[p]<=0;full[p]<=0;reply_head[p]<=0;reply_count[p]<=1;
                            replies[p][0]<=8'hfa;delay_count[p]<=8000;
                            if(parameter_pending[p]) begin
                                parameter_pending[p]<=0;
                                if(parameter_cmd[p]==8'hf0 && wdata==0) begin
                                    reply_count[p]<=2;replies[p][1]<={6'b0,scan_set};
                                end else if(p==1 && parameter_cmd[p]==8'hf0 && wdata<=3) scan_set<=wdata[1:0];
                            end else case(wdata)
                                8'hff:begin
                                    enabled[p]<=p==1;replies[p][1]<=8'haa;reply_count[p]<=p==0 ? 3:2;
                                    replies[p][2]<=0;
                                    if(p==1) scan_set<=1;
                                end
                                8'hf2:begin
                                    reply_count[p]<=p==0 ? 2:3;
                                    replies[p][1]<=p==0 ? 8'h00:8'hab;replies[p][2]<=8'h83;
                                end
                                8'hf4:enabled[p]<=1;
                                // ASSUMPTION A7: Model 30 has no 8042 translator.
                                // TR p.4-4 defines POR set 1; original ROM E294
                                // and independent kbc_ps2_m25.c require F5/F6
                                // to preserve the selected scan set.
                                8'hf5:enabled[p]<=0;
                                8'hf6:enabled[p]<=1;
                                8'hee:replies[p][0]<=8'hee;
                                8'hed,8'hf0,8'hf3:begin parameter_pending[p]<=1;parameter_cmd[p]<=wdata;end
                                default:begin end
                            endcase
                        end
                    end
                    default:begin end
                endcase
            end
        end
    end
    logic unused_read;
    assign unused_read=read_strobe;
endmodule
