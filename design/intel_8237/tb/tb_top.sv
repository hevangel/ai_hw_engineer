`timescale 1ns/1ps
module tb_top;
    logic clk = 0;
    logic rst_n = 0, cs_n = 1, ior_n = 1, iow_n = 1;
    logic [3:0] reg_addr = 0, dreq = 0;
    logic [7:0] data_i, data_o, cpu_data = 0;
    logic data_oe, hrq, hlda = 0, ready = 1, eop_n = 1, eop_out_n;
    logic [3:0] dack;
    logic [15:0] dma_addr;
    logic addr_oe, adstb, aen, memr_n, memw_n, dma_ior_n, dma_iow_n;
    logic transfer_valid;
    logic [1:0] transfer_channel;
    intel_8237 dut (.*);
    always #5 clk = ~clk;

    logic [7:0] memory [0:65535];
    logic [7:0] io_byte [0:3];
    logic [7:0] command_shadow = 0;
    typedef struct packed {
        logic [1:0] channel;
        logic [15:0] address;
        logic [3:0] strobes;
        logic [7:0] payload;
        logic terminal;
    } event_t;
    event_t events[$];
    int checks = 0, transfers = 0, strobes = 0;
    int large_count = 0;
    bit large_run = 0;
    logic [15:0] large_address = 0;
    int seed = 1;
    logic [31:0] random_state;

    always_comb begin
        data_i = cpu_data;
        if (aen && !memr_n) data_i = memory[dma_addr];
        else if (aen && !dma_ior_n) data_i = io_byte[transfer_channel];
    end

    task automatic check(input bit condition, input string label_text);
        checks++;
        if (!condition) $fatal(1, "8237A check failed: %s at %0t", label_text, $time);
    endtask

    always @(posedge clk) begin : external_bfm
        event_t ev;
        logic [3:0] active_ack;
        if (rst_n) begin
            active_ack = command_shadow[7] ? dack : ~dack;
            check($onehot0(active_ack), "one DACK maximum");
            if (!memr_n || !memw_n || !dma_ior_n || !dma_iow_n)
                check(aen && addr_oe && hrq && hlda, "strobes require ownership");
            if (adstb) begin
                check(data_oe && data_o == dma_addr[15:8], "high address multiplexing");
                strobes++;
            end
            if (transfer_valid) begin
                check(hrq && hlda && aen, "commit ownership");
                ev.channel = transfer_channel;
                ev.address = dma_addr;
                ev.strobes = {memr_n, memw_n, dma_ior_n, dma_iow_n};
                ev.payload = (!memw_n && data_oe) ? data_o : data_i;
                ev.terminal = !eop_out_n;
                if (!memw_n) memory[dma_addr] = ev.payload;
                if (!dma_iow_n) check(data_i == memory[dma_addr], "memory to peripheral payload");
                if (!dma_ior_n) io_byte[transfer_channel]++;
                transfers++;
                if (large_run) begin
                    check(ev.address == large_address && ev.channel == 3 && ev.strobes == 4'b1111,
                          "65536-transfer exact verify sequence");
                    large_address++;
                    large_count++;
                end else events.push_back(ev);
            end
        end
    end

    task automatic tick(input int n = 1);
        repeat (n) begin @(posedge clk); #1; end
    endtask
    task automatic reset_chip;
        @(negedge clk);
        rst_n = 0; cs_n = 1; ior_n = 1; iow_n = 1;
        dreq = 0; hlda = 0; ready = 1; eop_n = 1; command_shadow = 0;
        tick(2);
        @(negedge clk); rst_n = 1;
        events.delete(); strobes = 0;
        tick();
    endtask
    task automatic wr(input logic [3:0] offset, input logic [7:0] value);
        @(negedge clk);
        check(!hlda && !hrq, "CPU has bus for write");
        reg_addr = offset; cpu_data = value; cs_n = 0; iow_n = 0; ior_n = 1;
        tick();
        if (offset == 8) command_shadow = value;
        if (offset == 13) command_shadow = 0;
        @(negedge clk); cs_n = 1; iow_n = 1;
    endtask
    task automatic rd(input logic [3:0] offset, input logic [7:0] expected);
        @(negedge clk);
        check(!hlda && !hrq, "CPU has bus for read");
        reg_addr = offset; cs_n = 0; ior_n = 0; iow_n = 1;
        #1; check(data_oe && data_o == expected,
                  $sformatf("register %h expected %h actual %h", offset, expected, data_o));
        tick();
        @(negedge clk); cs_n = 1; ior_n = 1;
    endtask
    task automatic word_write(input logic [3:0] offset, input logic [15:0] value);
        wr(12, 0); wr(offset, value[7:0]); wr(offset, value[15:8]);
    endtask
    task automatic word_read(input logic [3:0] offset, input logic [15:0] expected);
        wr(12, 0); rd(offset, expected[7:0]); rd(offset, expected[15:8]);
    endtask
    task automatic program_channel(input int ch, input logic [15:0] address,
                                   input logic [15:0] count, input logic [7:0] mode);
        word_write(4'(2*ch), address); word_write(4'(2*ch+1), count);
        wr(11, (mode & 8'hfc) | 8'(ch));
    endtask
    task automatic unmask(input int ch);
        wr(10, 8'(ch));
    endtask
    task automatic request(input logic [3:0] bits_req);
        @(negedge clk); dreq = bits_req;
    endtask
    task automatic grant_bus;
        int timeout_count;
        timeout_count = 0;
        while (!hrq && timeout_count < 40) begin tick(); timeout_count++; end
        check(hrq, "HRQ raised");
        tick(3); check(!aen && !transfer_valid, "no transfer before delayed grant");
        @(negedge clk); hlda = 1;
    endtask
    task automatic wait_events(input int n);
        int timeout_count;
        timeout_count = 0;
        while (events.size() < n && timeout_count < 20000) begin tick(); timeout_count++; end
        check(events.size() == n, $sformatf("exact observed transfers expected %0d actual %0d", n, events.size()));
    endtask
    task automatic release_bus;
        int timeout_count;
        timeout_count = 0;
        while (hrq && timeout_count < 50) begin tick(); timeout_count++; end
        check(!hrq, "HRQ released");
        @(negedge clk); hlda = 0;
        tick();
    endtask
    task automatic expect_event(input int n, input int ch, input logic [15:0] address,
                               input logic [3:0] pins);
        event_t ev;
        check(events.size() > n, "event exists");
        ev = events[n];
        check(ev.channel == 2'(ch) && ev.address == address && ev.strobes == pins,
              $sformatf("event %0d ch/address/strobes actual %h", n, ev));
    endtask
    function automatic logic [31:0] random_next();
        random_state = random_state ^ (random_state << 13);
        random_state = random_state ^ (random_state >> 17);
        random_state = random_state ^ (random_state << 5);
        return random_state;
    endfunction

    initial begin : regression
        int ch, len, snapshot_count;
        logic [15:0] address, final_address;
        logic [7:0] mode, command;
        logic [31:0] random_value;
        bit decrement, auto_reload, direction;
        event_t ev;
        if ($value$plusargs("seed=%d", seed)) begin end
        random_state = 32'(seed) | 32'h1;
        for (int i = 0; i < 65536; i++) memory[i] = 8'(i ^ (i >> 8) ^ 8'ha5);
        for (int i = 0; i < 4; i++) io_byte[i] = 8'(32 + i*16);
        reset_chip();

        $display("8237A register and reset tests");
        word_read(0, 0); rd(8, 0); rd(13, 0);
        word_write(0, 16'h1234); word_write(3, 16'habcd);
        wr(12, 0); rd(0, 8'h34); rd(3, 8'hab); // global read byte phase
        wr(12, 0); wr(0, 8'h56); wr(2, 8'h78); // shared write phase
        word_read(0, 16'h1256); word_read(2, 16'h7800);
        wr(13, 0); word_read(0, 16'h1256); word_read(3, 16'habcd);
        // Undefined read offsets leave the bus undriven.
        for (int offset = 9; offset < 16; offset++) begin
            if (offset != 13) begin
                @(negedge clk); reg_addr = 4'(offset); cs_n = 0; ior_n = 0;
                #1; check(!data_oe && data_o == 0, "undefined NMOS read offset");
                tick(); @(negedge clk); cs_n = 1; ior_n = 1;
            end
        end
        @(negedge clk); cs_n = 0; ior_n = 0; iow_n = 0; reg_addr = 0; cpu_data = 8'hff;
        tick(); @(negedge clk); cs_n = 1; ior_n = 1; iow_n = 1;
        word_read(0, 16'h1256);
        request(15); tick(8); check(!hrq, "reset masks hardware requests"); request(0);
        program_channel(0, 16'h100, 0, 8'h88); unmask(0); wr(8, 4);
        request(1); tick(8); check(!hrq, "controller disable"); request(0);
        wr(8, 0); wr(15, 15); request(1); tick(8); check(!hrq, "write all masks"); request(0);
        wr(14, 0); request(1); grant_bus(); wait_events(1); request(0); release_bus();
        expect_event(0, 0, 16'h100, 4'b0110);

        $display("8237A block directions, address boundary, wait and timing tests");
        for (int timing = 0; timing < 3; timing++) begin
            for (int dir = 0; dir < 3; dir++) begin
                for (int dec = 0; dec < 2; dec++) begin
                    reset_chip(); ch = (timing + dir + dec) % 4;
                    address = dec != 0 ? 16'h0000 : 16'hfffe;
                    mode = 8'h80 | (8'(dir) << 2) | (dec != 0 ? 8'h20 : 0);
                    program_channel(ch, address, 3, mode); unmask(ch);
                    command = timing == 1 ? 8'h08 : (timing == 2 ? 8'h20 : 0);
                    wr(8, command); ready = 0;
                    request(4'(1 << ch)); grant_bus(); tick(7);
                    if (dir == 0) begin
                        wait_events(4); check(!ready, "verify ignores READY");
                    end
                    else begin
                        check(events.size() == 0, "READY stalls data transfers");
                        check(aen && dma_addr == address, "wait holds address");
                        check((dir == 1 ? !memw_n : !dma_iow_n) == (timing != 0),
                              "normal/extended/compressed write-strobe timing in wait");
                    end
                    ready = 1; request(0); wait_events(4); release_bus();
                    for (int i = 0; i < 4; i++) begin
                        expect_event(i, ch, address + (dec != 0 ? -16'(i) : 16'(i)),
                                     dir == 0 ? 4'b1111 : (dir == 1 ? 4'b1001 : 4'b0110));
                        ev = events[i]; check(ev.terminal == (i == 3), "TC only final transfer");
                    end
                    check(strobes == 2, "S1 only initial and high-byte boundary");
                    final_address = address + (dec != 0 ? -16'd4 : 16'd4);
                    word_read(4'(2*ch), final_address); word_read(4'(2*ch+1), 16'hffff);
                    rd(8, 8'(1 << ch)); rd(8, 0);
                    request(4'(1 << ch)); tick(5); check(!hrq, "TC masks nonauto channel"); request(0);
                end
            end
        end

        $display("8237A single service and ownership release");
        reset_chip(); program_channel(2, 16'h8000, 2, 8'h48); unmask(2);
        request(4); grant_bus(); wait_events(1); tick(); check(!hrq, "single releases after byte");
        tick(5); check(!hrq && events.size() == 1, "HLDA-low interlock");
        release_bus(); grant_bus(); wait_events(2); release_bus();
        grant_bus(); wait_events(3); request(0); release_bus();
        for (int i = 0; i < 3; i++) expect_event(i, 2, 16'h8000+16'(i), 4'b0110);

        $display("8237A demand pause and resume");
        reset_chip(); program_channel(1, 16'h200, 2, 8'h04); unmask(1);
        request(2); grant_bus(); wait_events(1); request(0); wait_events(2); release_bus();
        word_read(2, 16'h202); word_read(3, 0); rd(8, 0);
        request(2); grant_bus(); wait_events(3); request(0); release_bus(); rd(8, 2);

        $display("8237A fixed and rotating contention");
        for (int rotate = 0; rotate < 2; rotate++) begin
            reset_chip();
            for (int i = 0; i < 4; i++) program_channel(i, 16'(i*256), 1, 8'h50);
            wr(14, 0); wr(8, rotate != 0 ? 8'h10 : 0); request(15);
            for (int i = 0; i < 8; i++) begin
                grant_bus(); wait_events(i+1); release_bus();
                expect_event(i, rotate != 0 ? i%4 : 0,
                             rotate != 0 ? 16'((i%4)*256 + (i/4)%2) : 16'(i%2), 4'b1111);
            end
            request(0); tick(3);
        end

        $display("8237A software requests bypass mask only in block mode");
        for (int sw_channel = 0; sw_channel < 4; sw_channel++) begin
            reset_chip(); program_channel(sw_channel, 16'h5000, 1, 8'h88);
            wr(9, 8'(4+sw_channel)); grant_bus(); wait_events(2); release_bus();
            rd(8, 8'(1<<sw_channel));
        end
        reset_chip(); program_channel(3, 16'h5000, 1, 8'h48);
        wr(9, 7); tick(5); check(!hrq, "software request excluded outside block");
        rd(8, 8'h80); wr(9, 3); rd(8, 0);

        $display("8237A auto reload, external termination and polarity");
        reset_chip(); program_channel(0, 16'hab00, 7, 8'h98); unmask(0);
        request(1); grant_bus(); wait_events(1);
        @(negedge clk); eop_n = 0; request(0); wait_events(2); release_bus(); eop_n = 1;
        word_read(0, 16'hab00); word_read(1, 7); rd(8, 1);
        request(1); grant_bus(); wait_events(10); request(0); release_bus();
        for (int i = 2; i < 10; i++) expect_event(i, 0, 16'hab00+16'(i-2), 4'b0110);
        reset_chip(); program_channel(1, 16'h6800, 9, 8'h84); unmask(1);
        request(2); grant_bus(); wait_events(1);
        @(negedge clk); eop_n = 0; request(0); wait_events(2); release_bus(); eop_n = 1;
        word_read(2, 16'h6802); word_read(3, 7); rd(8, 2);
        ev = events[1]; check(!ev.terminal, "external EOP does not drive internal TC output");
        request(2); tick(5); check(!hrq, "external EOP masks nonauto channel"); request(0);
        reset_chip(); program_channel(2, 16'h900, 0, 8'h88); unmask(2);
        wr(8, 8'hc0); dreq = 15; tick(4); check(!hrq && dack == 0, "active-low request idle");
        request(11); grant_bus(); tick(2); check(dack == 4, "active-high acknowledgment");
        wait_events(1); request(15); release_bus(); rd(8, 4);

        $display("8237A cascade and illegal transfer type");
        reset_chip(); program_channel(1, 16'h7777, 16'h8888, 8'hcc); unmask(1);
        ready = 0; request(2); grant_bus(); tick(8);
        check(dack == 4'b1101 && !aen && !addr_oe && !adstb && !transfer_valid,
              "cascade ack without bus drive");
        check(memr_n && memw_n && dma_ior_n && dma_iow_n, "cascade no strobes");
        request(0); release_bus(); ready = 1;
        word_read(2, 16'h7777); word_read(3, 16'h8888); rd(8, 0);
        program_channel(1, 0, 0, 8'h8c); request(2); tick(6); check(!hrq, "illegal transfer ignored"); request(0);

        $display("8237A memory copy/fill, unequal counts and phase EOP");
        for (int variant = 0; variant < 5; variant++) begin
            reset_chip();
            program_channel(0, 16'h12fe, variant == 2 ? 1 : 3, 8'h98);
            program_channel(1, 16'h3400, 3, 8'h94);
            wr(8, variant == 1 ? 3 : 1);
            wr(9, 4); grant_bus(); tick(2);
            check(dack == 15, "memory copy no DACK");
            // Stall source before its first commit.
            ready = 0; snapshot_count = events.size(); tick(4);
            check(events.size() == snapshot_count, "copy source wait");
            ready = 1; wait_events(1);
            ready = 0; tick(5); check(events.size() == 1, "copy destination wait");
            if (variant == 3) eop_n = 0; // destination EOP reloads destination only
            ready = 1; wait_events(2);
            if (variant == 4) begin
                // Pulse EOP during the following source half.
                @(negedge clk); eop_n = 0; tick();
                @(negedge clk); eop_n = 1;
            end
            wait_events(variant == 3 ? 2 : (variant == 4 ? 4 : 8));
            release_bus(); eop_n = 1;
            len = variant == 3 ? 1 : (variant == 4 ? 2 : 4);
            for (int i = 0; i < len; i++) begin
                address = 16'h12fe + (variant == 1 ? 16'd0 :
                          (variant == 2 ? 16'(i%2) : 16'(i)));
                expect_event(2*i, 0, address, 4'b0111);
                expect_event(2*i+1, 1, 16'h3400+16'(i), 4'b1011);
                check(memory[16'h3400+16'(i)] == memory[address], "copy/fill payload");
            end
            word_read(0, variant == 3 ? 16'h12ff : 16'h12fe);
            word_read(1, variant == 3 ? 2 : (variant == 2 ? 1 : 3));
            word_read(2, 16'h3400); word_read(3, 3); rd(8, 2);
            ev = events[2*len-2]; rd(13, ev.payload);
        end

        $display("8237A randomized blocks seed=%0d", seed);
        for (int trial = 0; trial < 80; trial++) begin
            reset_chip(); random_value = random_next();
            ch = int'(random_value[1:0]); len = 1+int'(random_value[6:2]);
            decrement = random_value[7]; auto_reload = random_value[8]; direction = random_value[9];
            address = random_value[31:16];
            mode = 8'h80 | (direction ? 8'h08 : 8'h04) |
                   (decrement ? 8'h20 : 0) | (auto_reload ? 8'h10 : 0);
            program_channel(ch, address, 16'(len-1), mode); unmask(ch);
            wr(8, trial%3 == 0 ? 8'h08 : (trial%3 == 1 ? 8'h20 : 0));
            request(4'(1<<ch)); grant_bus(); request(0);
            for (int cycle = 0; events.size() < len && cycle < 2000; cycle++) begin
                @(negedge clk); random_value = random_next(); ready = random_value[0] || random_value[1]; tick();
            end
            ready = 1; wait_events(len); release_bus();
            for (int i = 0; i < len; i++)
                expect_event(i, ch, address + (decrement ? -16'(i) : 16'(i)),
                             direction ? 4'b0110 : 4'b1001);
            final_address = auto_reload ? address : address + (decrement ? -16'(len) : 16'(len));
            word_read(4'(2*ch), final_address);
            word_read(4'(2*ch+1), auto_reload ? 16'(len-1) : 16'hffff);
            rd(8, 8'(1<<ch));
        end

        $display("8237A full 65536-transfer count range");
        reset_chip(); program_channel(3, 16'hfedc, 16'hffff, 8'h80); unmask(3);
        large_run = 1; large_count = 0; large_address = 16'hfedc;
        request(8); grant_bus(); request(0);
        for (int cycle = 0; large_count < 65536 && cycle < 210000; cycle++) tick();
        check(large_count == 65536, "maximum count completes exactly 65536 transfers");
        release_bus(); large_run = 0;
        word_read(6, 16'hfedc); word_read(7, 16'hffff); rd(8, 8);
        $display("8237A TEST PASSED checks=%0d transfers=%0d seed=%0d", checks, transfers, seed);
        $finish;
    end
    initial begin
        #5000000;
        $fatal(1, "8237A regression timeout");
    end
endmodule
