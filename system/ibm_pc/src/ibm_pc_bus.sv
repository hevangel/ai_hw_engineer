`timescale 1ns/1ps
// 8088-facing byte bus and four-byte prefetch queue around the shared EU.
// ASSUMPTION A1: bus phases are digital; EU instruction clock counts differ.
module ibm_pc_bus (
    input logic clk, rst_n,
    input logic eu_req, eu_write, eu_fetch, eu_intack,
    input logic [19:0] eu_addr,
    input logic [1:0] eu_be,
    input logic [15:0] eu_wdata,
    input logic eu_io, flush, suspend_fetch, inhibit_grant, locked,
    input logic [15:0] cs, ip,
    output logic eu_ready,
    output logic [15:0] eu_rdata,
    input logic hold_req,
    output logic hlda,
    output logic strobe, writing, io, intack, inta_active, fetching,
    output logic [19:0] address,
    output logic [7:0] wdata,
    input logic [7:0] rdata,
    output logic [2:0] queue_count
);
    typedef enum logic [2:0] {IDLE,T1,T2,T3,T4,RESPONSE} phase_t;
    phase_t phase;
    logic [7:0] queue [0:3];
    logic [1:0] head, tail;
    logic [2:0] count;
    logic [15:0] queue_cs, head_ip, fetch_ip;
    logic prefetch, discard, word_pair, second, high_lane;
    logic [7:0] write_high;
    logic [15:0] response;
    logic pop, fill;
    function automatic logic [19:0] physical(input logic [15:0] s,o);
        physical={s,4'b0}+{4'b0,o};
    endfunction
    assign pop=eu_req && eu_fetch && count!=0 && !flush &&
        eu_addr==(physical(queue_cs,head_ip)&20'hffffe) && eu_be==(head_ip[0] ? 2:1);
    assign fill=phase==T4 && prefetch && !discard && !flush;
    assign eu_ready=rst_n && (pop || phase==RESPONSE && eu_req && !eu_fetch);
    assign eu_rdata=eu_fetch ? (eu_be==2 ? {queue[head],8'b0}:{8'b0,queue[head]}) : response;
    assign queue_count=count;
    assign strobe=rst_n && !hlda && phase==T3;
    assign inta_active=rst_n && !hlda && intack && (phase==T2 || phase==T3);
    assign fetching=prefetch;
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            phase<=IDLE; head<=0; tail<=0; count<=0; queue_cs<=16'hffff;
            head_ip<=0; fetch_ip<=0; prefetch<=0; discard<=0; word_pair<=0;
            second<=0; high_lane<=0; write_high<=0; response<=0;
            address<=0; wdata<=0; writing<=0; io<=0; intack<=0; hlda<=0;
            for(integer i=0;i<4;i=i+1) queue[i]<=0;
        end else begin
            if(hlda && !hold_req) hlda<=0;
            if(flush) begin
                head<=0; tail<=0; count<=0; queue_cs<=cs;
                head_ip<=ip; fetch_ip<=ip; discard<=1;
            end else begin
                if(pop) begin head<=head+2'd1; head_ip<=head_ip+16'd1; end
                if(fill) begin queue[tail]<=response[7:0]; tail<=tail+2'd1; fetch_ip<=fetch_ip+16'd1; end
                if(pop || fill) count<=count+{2'b0,fill}-{2'b0,pop};
            end
            case(phase)
                IDLE: if(!hlda) begin
                    if(hold_req && !locked && !inhibit_grant) hlda<=1;
                    else if(!flush) begin
                        second<=0;
                        if(eu_req && !eu_fetch) begin
                            prefetch<=0; writing<=eu_write; io<=eu_io; intack<=eu_intack;
                            address<=eu_addr+{19'b0,eu_be==2};
                            wdata<=eu_be==2 ? eu_wdata[15:8]:eu_wdata[7:0];
                            write_high<=eu_wdata[15:8]; word_pair<=eu_be==3 && !eu_intack;
                            high_lane<=eu_be==2; phase<=T1;
                        end else if(count<4 && !suspend_fetch && !inhibit_grant) begin
                            prefetch<=1; discard<=0; writing<=0; io<=0; intack<=0;
                            address<=physical(queue_cs,fetch_ip); word_pair<=0; high_lane<=0;
                            wdata<=0; phase<=T1;
                        end
                    end
                end
                T1: phase<=T2;
                T2: phase<=T3;
                T3: begin
                    if(second || high_lane) response[15:8]<=rdata;
                    else response<={8'b0,rdata};
                    phase<=T4;
                end
                T4: begin
                    if(prefetch) phase<=IDLE;
                    else if(word_pair && !second) begin
                        second<=1; address<=address+20'd1; wdata<=write_high; phase<=T1;
                    end else phase<=RESPONSE;
                end
                RESPONSE: phase<=IDLE;
                default: phase<=IDLE;
            endcase
        end
    end
`ifdef FORMAL
    logic past_valid=0;
    always_ff @(posedge clk) begin
        past_valid<=1;
        if(!past_valid) assume(!rst_n);
        if(past_valid && rst_n && $past(rst_n)) begin
            assert(count<=4);
            assert(!(hlda && strobe));
            if(eu_ready && eu_fetch) assert(count!=0 && !flush);
            if($past(inhibit_grant && !hlda)) assert(!hlda);
        end
        cover(past_valid && count==4);
        cover(past_valid && pop && fill);
        cover(past_valid && hlda);
    end
`endif
endmodule
