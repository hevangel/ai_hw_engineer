`timescale 1ns/1ps
// Demultiplex the native maximum-mode 8086 bus. RAM/ROM use both lanes;
// Byte-wide I/O/video words use T3/Tw with an inactive strobe interval between
// bytes, so peripherals that detect RD/WR edges see two distinct accesses.
module model30_bus (
    input logic clk,rst_n,
    input logic [2:0] phase,status,
    input logic [15:0] ad_out,
    input logic [3:0] address_high,
    input logic bhe_n,owned,dma_ready,
    input logic [15:0] dma_response,
    output logic ready,
    output logic [15:0] ad_in,
    output logic [19:0] address,
    output logic [1:0] lanes,
    output logic writing,io,intack,strobe,inta_active,
    output logic [7:0] byte_data,
    input logic [7:0] byte_read,
    input logic [15:0] memory_read
);
    logic [19:0] base;
    logic [1:0] byte_enable;
    logic [7:0] low_read;
    logic [1:0] paired_step;
    logic word_io,word_narrow,paired,upper,slow_io;
    assign slow_io=io && base[15:5]==0;
    assign word_io=io && !intack && byte_enable==3;
    assign word_narrow=!io && !intack && byte_enable==3 && base>=20'ha0000 && base<20'hf0000;
    assign paired=word_io || word_narrow;
    assign upper=paired ? paired_step==2 : byte_enable==2;
    assign address=base+{19'b0,paired && upper};
    assign lanes=word_narrow ? (upper ? 2'b10:2'b01):byte_enable;
    assign ready=slow_io ? phase==4 && dma_ready : !paired || phase==4 && paired_step==2;
    assign strobe=rst_n && owned && !slow_io && (phase==3 || paired && phase==4 && paired_step==2);
    assign inta_active=rst_n && owned && intack && (phase==2 || phase==3);
    assign byte_data=upper ? ad_out[15:8]:ad_out[7:0];
    assign ad_in=slow_io ? dma_response : io || intack ? (word_io ? {byte_read,low_read} :
        byte_enable==2 ? {byte_read,8'b0}:{8'b0,byte_read}) :
        word_narrow ? {memory_read[15:8],low_read}:memory_read;
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            base<=0;byte_enable<=0;low_read<=0;writing<=0;io<=0;intack<=0;paired_step<=0;
        end else begin
            if(phase==1 && owned) begin
                base<={address_high,ad_out};byte_enable<={!bhe_n,!ad_out[0]};
                writing<=status==2 || status==6;
                io<=status==1 || status==2;intack<=status==0;
                paired_step<=0;
            end
            if(strobe && paired && !upper) begin
                low_read<=io ? byte_read:memory_read[7:0];paired_step<=1;
            end
            if(phase==4 && paired_step==1) paired_step<=2;
        end
    end
`ifdef FORMAL
    logic past_valid=0;
    always_ff @(posedge clk) begin
        past_valid<=1;
        if(!past_valid) assume(!rst_n);
        // Environment contract: the independently verified native BIU owns
        // phase progression. This proof covers the planar conversion only.
        if(past_valid && rst_n && $past(rst_n)) begin
            assume(phase<=5);
            // RQ/GT relinquishes the bus between transactions. Ownership
            // cannot appear midway through T2/T3/Tw without a captured T1.
            if(phase>=2 && phase<=5) assume(owned==$past(owned));
            case($past(phase))
                0:assume(phase==0 || phase==1);
                1:assume(phase==2);
                2:assume(phase==3);
                3:assume(phase==4 || phase==5);
                4:assume(phase==4 || phase==5);
                5:assume(phase==0);
                default:begin end
            endcase
        end
        if(rst_n) begin
            assert(!strobe || owned);
            if(paired && phase==2) assert(!ready);
            if(paired && strobe && phase==4) assert(address==base+1);
            if(paired && phase==4 && paired_step==1) assert(!strobe && !ready);
            if(word_narrow && strobe) assert(lanes==(phase==4 ? 2:1));
        end
        cover(past_valid && strobe && word_io && phase==4);
        cover(past_valid && strobe && !io && lanes==3);
        cover(past_valid && strobe && word_narrow && phase==4);
        cover(past_valid && inta_active);
    end
`endif
endmodule
