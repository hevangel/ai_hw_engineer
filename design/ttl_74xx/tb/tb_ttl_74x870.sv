`timescale 1ns/1ps
module tb_ttl_74x870;
    logic [3:0] address_1,address_2,select,a_in,b_in,a_out,b_out;
    logic [1:0] write_n;
    logic a_drive,b_drive;
    logic [3:0] reference_1[0:15],reference_2[0:15];
    ttl_74x870 dut(.*);
    // Source-table write routes: 0 holds, 1 selects A, 2 selects B.
    task automatic update_reference;
        int route_1,route_2;
        route_1=0;route_2=0;
        case(select)
            4,6: route_1=1;
            5,7: route_2=1;
            8,9,12: route_1=2;
            10,11,15: route_2=2;
            13: begin route_1=2;route_2=1;end
            14: begin route_1=1;route_2=2;end
            default: begin end
        endcase
        if(!write_n[0] && route_1!=0) reference_1[address_1]=(route_1==1)?a_in:b_in;
        if(!write_n[1] && route_2!=0) reference_2[address_2]=(route_2==1)?a_in:b_in;
    endtask
    task automatic check;
        logic [3:0] ea,eb;
        #1;
        case(select[1:0])
            0: begin ea=reference_1[address_1];eb=reference_1[address_1];end
            1: begin ea=reference_2[address_2];eb=reference_1[address_1];end
            2: begin ea=reference_1[address_1];eb=reference_2[address_2];end
            3: begin ea=reference_2[address_2];eb=reference_2[address_2];end
            default: begin ea='x;eb='x;end
        endcase
        if(a_drive!==!select[2] || b_drive!==!select[3] ||
           a_out!==(select[2]?4'd0:ea) || b_out!==(select[3]?4'd0:eb))
            $fatal(1,"native file routing/read/drive or B-priority write");
    endtask
    initial begin
        write_n=3;address_1=0;address_2=0;select=12;a_in=0;b_in=0;
        // Initialize all 32 words through the prioritized native B input route.
        for(int bank=0;bank<2;bank++) begin
            select=bank==0?4'd12:4'd15;
            for(int address=0;address<16;address++) begin
                address_1=4'(address);address_2=4'(address);b_in=4'(address*3+bank*5);
                #1;write_n=bank==0?2'b10:2'b01;update_reference;#1;write_n=3;#1;
            end
        end
        for(int mode=0;mode<16;mode++) begin
            for(int first=0;first<16;first++) begin
                for(int second=0;second<16;second++) begin
                    write_n=3;select=4'(mode);address_1=4'(first);address_2=4'(second);
                    a_in=4'(first*3+second+mode);b_in=4'(first+second*5+mode*3);check;
                    for(int enables=0;enables<4;enables++) begin
                        write_n=~2'(enables);update_reference;check;
                        // Stable addresses/selects, changing data while the write window is open.
                        a_in=~a_in;b_in=4'(int'(b_in)+7);update_reference;check;
                        write_n=3;#1;a_in=~a_in;b_in=~b_in;check;
                    end
                end
            end
        end
        // Read both files back after all route/write combinations.
        for(int address=0;address<16;address++) begin
            select=2;address_1=4'(address);address_2=4'(address);check;
        end
        $display("PASS: tb_ttl_74x870");$finish;
    end
endmodule
