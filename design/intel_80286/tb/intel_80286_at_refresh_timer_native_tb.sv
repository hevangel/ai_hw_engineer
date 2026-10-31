module intel_80286_at_refresh_timer_native_tb;
    logic clk, clk2x, reset, ready_n, dma_clk_n, permit, io_ready;
    logic [2:0] timer_clk, timer_out;
    logic [15:0] host_data, data_out, memory_word;
    logic data_oe, address_oe, status_oe, lock_n, lock_oe, bhe_n;
    logic cod_inta, m_io, s1, s0, hlda, cycle_active, protocol_error;
    logic halted, shutdown, fault, hold_req, refresh, refresh_n, detect, request;
    logic timer_selected, timer_valid, port_selected, port_valid;
    logic [7:0] port_data;
    logic [3:0] port_control;
    logic [23:0] address;
    logic [1:0] completed;
    logic [3:0] chain;
    logic [7:0] rom [0:63];
    logic last_refresh, initial_detect, last_timer_out, last_memr;
    logic [7:0] refresh_row;
    logic row_oe, memr_n, memr_oe;
    logic unused_observations;
    integer timer_writes, timer_write_stalls, timer_stalls_this_write;
    integer memory_writes, refresh_edges, refresh_cycles, timer_rises, memr_edges, port_reads, port_writes;
    logic seen_refresh_low, seen_refresh_high;
    integer cycles;
    assign unused_observations=^{timer_out,lock_n,lock_oe,bhe_n,cod_inta,m_io,s1,s0,
                                 hold_req,request,timer_valid,chain};

    intel_80286_at_refresh_timer_native dut (
        .clk_i(clk), .clk_2x_i(clk2x), .reset_i(reset), .ready_n_i(ready_n),
        .dma_clk_n_i(dma_clk_n), .hold_permit_i(permit), .io_ready_i(io_ready),
        .pck_i(1'b0), .iochck_i(1'b0),
        .timer_clk_i(timer_clk), .host_data_i(host_data), .data_o(data_out),
        .data_oe_o(data_oe), .address_oe_o(address_oe), .status_oe_o(status_oe),
        .lock_n_o(lock_n), .lock_oe_o(lock_oe), .address_o(address), .bhe_n_o(bhe_n),
        .cod_inta_o(cod_inta), .m_io_o(m_io), .s1_o(s1), .s0_o(s0),
        .hlda_o(hlda), .cycle_active_o(cycle_active), .protocol_error_o(protocol_error),
        .completed_bytes_o(completed), .halted_o(halted), .shutdown_o(shutdown),
        .fault_o(fault), .hold_o(hold_req), .refresh_o(refresh), .refresh_n_o(refresh_n),
        .detect_o(detect), .request_o(request), .clear_chain_o(chain),
        .timer_out_o(timer_out), .timer_selected_o(timer_selected),
        .timer_rdata_valid_o(timer_valid), .refresh_row_o(refresh_row),
        .refresh_row_oe_o(row_oe), .refresh_memr_n_o(memr_n), .refresh_memr_oe_o(memr_oe),
        .port61_selected_o(port_selected), .port61_rdata_valid_o(port_valid),
        .port61_rdata_o(port_data), .port61_control_o(port_control)
    );
    function automatic logic [7:0] read_byte(input logic [23:0] a);
        case (a)
            24'hfffff0: return 8'hea;
            24'hfffff1: return 8'h00;
            24'hfffff2: return 8'h01;
            24'hfffff3: return 8'h00;
            24'hfffff4: return 8'hf0;
            24'h000200: return memory_word[7:0];
            24'h000201: return memory_word[15:8];
            default: begin
                if (a>=24'h0f0100 && a<24'h0f0140) return rom[a[5:0]];
                return 8'h00;
            end
        endcase
    endfunction
    always_comb begin
        host_data={read_byte({address[23:1],1'b0}+24'd1),
                   read_byte({address[23:1],1'b0})};
    end
    task automatic processor_tick;
        for (int n=0;n<2;n++) begin
            clk2x=1; clk=(n==0); #1;
            clk2x=0; #1;
        end
    endtask
    initial begin
        for (int i=0;i<64;i++) rom[i]=8'h00;
        // MOV AL,74h; OUT 43h,AL; MOV AL,08h; OUT 41h,AL;
        // MOV AL,00h; OUT 41h,AL; MOV AL,01h; OUT 61h,AL;
        // MOV CX,32; INC word [0200h]; LOOP; poll port 61h bit 4 high,
        // then low; HLT. Each backward branch targets the exact IN opcode.
        rom[0]=8'hb0; rom[1]=8'h74; rom[2]=8'he6; rom[3]=8'h43;
        rom[4]=8'hb0; rom[5]=8'h08; rom[6]=8'he6; rom[7]=8'h41;
        rom[8]=8'hb0; rom[9]=8'h00; rom[10]=8'he6; rom[11]=8'h41;
        rom[12]=8'hb0; rom[13]=8'h01; rom[14]=8'he6; rom[15]=8'h61;
        rom[16]=8'hb9; rom[17]=8'h20; rom[18]=8'h00;
        rom[19]=8'hff; rom[20]=8'h06; rom[21]=8'h00; rom[22]=8'h02;
        rom[23]=8'he2; rom[24]=8'hfa;
        rom[25]=8'he4; rom[26]=8'h61; rom[27]=8'ha8; rom[28]=8'h10; rom[29]=8'h74; rom[30]=8'hfa;
        rom[31]=8'he4; rom[32]=8'h61; rom[33]=8'ha8; rom[34]=8'h10; rom[35]=8'h75; rom[36]=8'hfa;
        rom[37]=8'hf4;
        clk=0; clk2x=0; reset=1; ready_n=0; dma_clk_n=0;
        permit=1; io_ready=0; timer_clk=0; memory_word=0;
        timer_writes=0; timer_write_stalls=0; timer_stalls_this_write=0; memory_writes=0;
        refresh_edges=0; refresh_cycles=0; timer_rises=0; memr_edges=0;
        port_reads=0; port_writes=0; seen_refresh_low=0; seen_refresh_high=0;
        last_refresh=0; last_memr=0;
        repeat (16) processor_tick();
        reset=0;
        repeat (4) processor_tick();
        initial_detect=detect;
        last_timer_out=timer_out[1];
        for (cycles=0;cycles<12000 && !halted;cycles++) begin
            clk=0; clk2x=0;
            ready_n=(cycles%5!=4);
            dma_clk_n=cycles[0];
            timer_clk=cycles[3] ? 3'b111 : 3'b000;
            #1;
            // Force two wait clocks on each accepted timer write. The 8254
            // must not consume its byte phase until the CPU beat completes.
            if (timer_selected && data_oe) begin
                if (timer_stalls_this_write<2) begin
                    ready_n=1; timer_stalls_this_write++; timer_write_stalls++;
                end else ready_n=0;
            end
            #1;
            if (timer_out[1] && !last_timer_out) timer_rises++;
            last_timer_out=timer_out[1];
            if (refresh) begin
                if (!last_refresh) begin
                    assert(timer_writes==3 && timer_rises>refresh_edges)
                        else $fatal(1,"refresh did not follow a programmed timer OUT1 edge");
                    refresh_edges++; refresh_cycles=0;
                end
                refresh_cycles++;
                io_ready=(refresh_cycles>=3);
            end else io_ready=0;
            last_refresh=refresh;
            #1;
            assert(!protocol_error && !fault && !shutdown)
                else $fatal(1,"native CPU stopped or rejected a beat");
            if (hlda) assert(!address_oe && !data_oe && !status_oe && !cycle_active && !lock_oe)
                else $fatal(1,"CPU drove the bus during HLDA");
            if (refresh) assert(hlda && !refresh_n && hold_req && request)
                else $fatal(1,"timer refresh signal did not require HLDA");
            if (memr_oe && !memr_n) begin
                assert(row_oe && hlda && refresh)
                    else $fatal(1,"refresh memory strobe lacked row or bus grant");
                if (!last_memr) begin
                    assert(refresh_row==8'(memr_edges))
                        else $fatal(1,"refresh row sequence failed: %0d %02x",memr_edges,refresh_row);
                    memr_edges++;
                end
            end
            last_memr=memr_oe && !memr_n;
            if (completed!=0 && data_oe) begin
                if (timer_selected) begin
                    assert(!bhe_n && address[0]) else $fatal(1,"timer write used the wrong bus lane");
                    case (timer_writes)
                        0: assert(address==24'h43 && data_out[15:8]==8'h74)
                            else $fatal(1,"wrong channel-1 control write");
                        1: assert(address==24'h41 && data_out[15:8]==8'h08)
                            else $fatal(1,"wrong channel-1 low count");
                        2: assert(address==24'h41 && data_out[15:8]==8'h00)
                            else $fatal(1,"wrong channel-1 high count");
                        default: $fatal(1,"extra timer register write");
                    endcase
                    timer_writes++;
                    timer_stalls_this_write=0;
                end else if (port_selected) begin
                    assert(address==24'h61 && completed==1 && !bhe_n && data_out[15:8]==8'h01)
                        else $fatal(1,"wrong port B write or bus lane");
                    port_writes++;
                end else if (address==24'h000200 && completed==2) begin
                    assert(data_out==16'(memory_writes+1))
                        else $fatal(1,"loop wrote wrong intermediate value: %04x after %0d writes",
                                    data_out,memory_writes);
                    memory_word=data_out;
                    memory_writes++;
                end else $fatal(1,"unexpected CPU write at %06x",address);
            end else if (completed!=0 && !data_oe && port_selected) begin
                assert(address==24'h61 && completed==1 && !bhe_n && port_valid &&
                       port_data[7:6]==0 && port_data[5]==timer_out[2] &&
                       port_data[4]==detect && port_data[3:0]==4'h1 && port_control==4'h1)
                    else $fatal(1,"port B read mapping, latch or bus lane failed");
                if (port_data[4]) seen_refresh_high=1;
                else seen_refresh_low=1;
                port_reads++;
            end
            processor_tick();
        end
        assert(halted && !fault && !shutdown) else $fatal(1,"CPU did not reach HLT");
        assert(timer_writes==3 && timer_write_stalls==6 && port_writes==1 &&
               port_reads>=2 && seen_refresh_low && seen_refresh_high && memory_writes==32 && memory_word==16'd32)
            else $fatal(1,"programmed timer or exact loop writes failed: %0d %0d %04x",
                        timer_writes,memory_writes,memory_word);
        assert(refresh_edges>=2 && memr_edges==refresh_edges && detect===(initial_detect ^ refresh_edges[0]))
            else $fatal(1,"timer did not generate the expected refresh/detect edges: %0d",refresh_edges);
        $display("PASS: native 286 programs 8254, reads both port-61 refresh states and completes 32 exact writes (%0d refreshes, %0d port reads)",refresh_edges,port_reads);
        $finish;
    end
endmodule
