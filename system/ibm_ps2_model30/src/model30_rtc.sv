`timescale 1ns/1ps
// MM58167 counter/RAM at E0-EF, control/status at B0-BF.
// Battery reset is separate from CPU reset: a warm reset retains configuration.
module model30_rtc (
    input logic clk,cold_rst_n,us_tick,selected,reading,writing,
    input logic [4:0] address,
    input logic [7:0] wdata,
    input logic nv_write,
    input logic [4:0] nv_address,
    input logic [7:0] nv_data,
    output logic [7:0] nv_read,
    output logic [7:0] rdata,
    output logic irq
);
    logic [7:0] registers[0:31];
    logic [9:0] microseconds;
    logic [7:0] events;
    logic alarm_match;
    function automatic logic [7:0] bcd_next(input logic [7:0] value);
        bcd_next=value[3:0]==9 ? value+8'h07:value+8'h01;
    endfunction
    function automatic logic [7:0] month_days(input logic [7:0] month,year);
        case(month)
            8'h04,8'h06,8'h09,8'h11:month_days=8'h30;
            8'h02:month_days=((year[3:0]+{2'b0,year[4],1'b0})&4'h3)==0 ? 8'h29:8'h28;
            default:month_days=8'h31;
        endcase
    endfunction
    assign irq=|(registers[16]&registers[17]);
    assign nv_read=registers[nv_address];
    always_comb begin
        rdata=registers[address];
        if(address==0 || address==8) rdata=registers[address]&8'hf0;
        if(address==5) rdata=registers[5]&8'h07;
        if(address==13) rdata=registers[13]&8'h0f;
        alarm_match=1;
        for(integer i=0;i<8;i=i+1) begin
            if(i!=0 && registers[i+8][3:2]!=3) alarm_match=alarm_match && registers[i][3:0]==registers[i+8][3:0];
            if(i!=5 && registers[i+8][7:6]!=3) alarm_match=alarm_match && registers[i][7:4]==registers[i+8][7:4];
        end
        events=0;
        if(registers[0]==8'h90 && registers[1][3:0]==9) begin
            events[1]=1;
            if(registers[1]==8'h99) begin
                events[2]=1;
                if(registers[2]==8'h59) begin
                    events[3]=1;
                    if(registers[3]==8'h59) begin
                        events[4]=1;
                        if(registers[4]==8'h23) begin
                            events[5]=1;events[6]=registers[5]==7;
                            events[7]=registers[6]==month_days(registers[7],registers[9]);
                        end
                    end
                end
            end
        end
        events[0]=alarm_match;
    end
    always_ff @(posedge clk) begin
        if(!cold_rst_n) begin
            microseconds<=0;
            for(integer i=0;i<32;i=i+1) registers[i]<=0;
            registers[5]<=1;registers[6]<=1;registers[7]<=1;
        end else begin
            if(us_tick) begin
                if(microseconds==999) begin
                    microseconds<=0;registers[20]<=1;
                    registers[16]<=registers[16]|(events&registers[17]);
                    if(registers[0]==8'h90) begin
                        registers[0]<=0;registers[1]<=bcd_next(registers[1]);
                        if(registers[1]==8'h99) begin
                            registers[1]<=0;registers[2]<=bcd_next(registers[2]);
                            if(registers[2]==8'h59) begin
                                registers[2]<=0;registers[3]<=bcd_next(registers[3]);
                                if(registers[3]==8'h59) begin
                                    registers[3]<=0;registers[4]<=bcd_next(registers[4]);
                                    if(registers[4]==8'h23) begin
                                        registers[4]<=0;registers[5]<=registers[5]==7 ? 8'd1:registers[5]+8'd1;
                                        registers[6]<=bcd_next(registers[6]);
                                        if(registers[6]==month_days(registers[7],registers[9])) begin
                                            registers[6]<=1;registers[7]<=registers[7]==8'h12 ? 8'd1:bcd_next(registers[7]);
                                        end
                                    end
                                end
                            end
                        end
                    end else registers[0]<=registers[0]+8'h10;
                end else microseconds<=microseconds+10'd1;
            end
            if(selected && reading && (address==16 || address==20)) registers[address]<=0;
            if(selected && writing) begin
                case(address)
                    5'd16,5'd20:begin end
                    5'd17:begin registers[17]<=wdata;registers[16]<=0;end
                    5'd18:if(wdata==8'hff) begin
                        microseconds<=0;
                        for(integer i=0;i<8;i=i+1) registers[i]<=0;
                        registers[5]<=1;registers[6]<=1;registers[7]<=1;
                    end
                    5'd19:if(wdata==8'hff) for(integer i=8;i<16;i=i+1) registers[i]<=0;
                    5'd21:begin registers[0]<=0;registers[1]<=0;registers[2]<=0;microseconds<=0;end
                    5'd0,5'd8:registers[address]<=wdata&8'hf0;
                    5'd2,5'd3:registers[address]<=wdata&8'h7f;
                    5'd4,5'd6:registers[address]<=wdata&8'h3f;
                    5'd5:registers[5]<=wdata&8'h07;
                    5'd7:registers[7]<=wdata&8'h1f;
                    5'd13:registers[13]<=wdata&8'h0f;
                    default:registers[address]<=wdata;
                endcase
            end
            // External battery-backed storage restore, permitted by the
            // planar only while the CPU is held in reset.
            if(nv_write) registers[nv_address]<=nv_data;
        end
    end
endmodule
