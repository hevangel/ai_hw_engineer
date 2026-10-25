// ASSUMPTION: supply_good classifies the native analog voltage monitor.
module ttl_74x2414 (
    input logic [1:0] address_1,address_2,
    input logic supply_good,sd_n,g_n,g1_n,g2,
    output logic [3:0] y1_n,y2_n,
    output logic vs,vs_drive_low
);
    logic common_enable;
    assign common_enable=supply_good && sd_n && !g_n;
    assign vs_drive_low=supply_good;
    assign vs=!vs_drive_low;
    for(genvar n=0;n<4;n++) begin : g_decode
        assign y1_n[n]=!(common_enable && !g1_n && address_1==2'(n));
        assign y2_n[n]=!(common_enable && g2 && address_2==2'(n));
    end
endmodule
