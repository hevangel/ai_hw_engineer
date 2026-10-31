`timescale 1ns/1ps
module tb_top;
    logic clk=0, rst_n=0, rdy_i=1, irq_n=1, nmi_n=1, aec_i=1;
    logic [15:0] bus_addr, pc_o;
    logic [7:0] bus_data_i, bus_data_o, ddr_o, latch_o, status_o, a_o, x_o, y_o, s_o;
    logic bus_we, bus_addr_oe, bus_rw_oe, bus_data_oe, fetch_o, fault_o, jammed_o;
    logic [5:0] port_i=6'h3f, port_o, port_oe;
    logic [7:0] rom [0:31], low_ram [0:1], result_ram [0:3];
    int checks=0;
    mos_6510 #(.PORT_FALLOFF_CYCLES(4)) dut (.*);
    always_comb begin
        bus_data_i=8'hea;
        if (bus_addr >= 16'h8000 && bus_addr < 16'h8020) bus_data_i=rom[bus_addr[4:0]];
        else if (bus_addr <= 1) bus_data_i=low_ram[bus_addr[0]];
        else if (bus_addr >= 16'h2000 && bus_addr <= 16'h2003) bus_data_i=result_ram[bus_addr[1:0]];
        else if (bus_addr == 16'hfffc) bus_data_i=0;
        else if (bus_addr == 16'hfffd) bus_data_i=8'h80;
    end
    // A board bus resolver supplies FF while no chip drives the data bus.
    // RAM still sees R/W low on a CPU-port write, but not the internal data.
    always_ff @(posedge clk) if (rst_n && bus_we && bus_addr_oe && bus_rw_oe) begin
        if (bus_addr <= 1) low_ram[bus_addr[0]] <= bus_data_oe ? bus_data_o : 8'hff;
        else if (bus_addr >= 16'h2000 && bus_addr <= 16'h2003) result_ram[bus_addr[1:0]] <= bus_data_o;
        else $fatal(1,"Unexpected external write");
    end
    task automatic tick;
        #1; clk=1; #1; clk=0; #1;
    endtask
    task automatic transfer(input logic [15:0] address,
                            input logic write_cycle=0,
                            input logic [7:0] value=0,
                            input logic opcode_fetch=0);
        #1;
        if (bus_addr !== address || bus_we !== write_cycle || fetch_o !== opcode_fetch || fault_o || jammed_o ||
            bus_addr_oe !== aec_i || bus_rw_oe !== aec_i || bus_data_oe !== (aec_i && write_cycle && address>1))
            $fatal(1,"6510 bus expected=%04x/%b/%b actual=%04x/%b/%b P=%02x A=%02x X=%02x Y=%02x S=%02x",
                   address,write_cycle,opcode_fetch,bus_addr,bus_we,fetch_o,status_o,a_o,x_o,y_o,s_o);
        if (opcode_fetch && (pc_o !== address || bus_data_i !== value)) $fatal(1,"6510 exact PC/opcode");
        if (write_cycle && bus_data_o !== value) $fatal(1,"6510 internal write value");
        checks++; tick();
    endtask
    initial begin
        foreach (rom[i]) rom[i]=8'hea; foreach (low_ram[i]) low_ram[i]=0; foreach (result_ram[i]) result_ram[i]=0;

        rom['h00]=8'ha9; rom['h01]=8'h2f;
        rom['h02]=8'h85; rom['h03]=0;
        rom['h04]=8'ha9; rom['h05]=8'h37;
        rom['h06]=8'h85; rom['h07]=1;
        rom['h08]=8'ha5; rom['h09]=0;
        rom['h0a]=8'h8d; rom['h0b]=0; rom['h0c]=8'h20;
        rom['h0d]=8'ha5; rom['h0e]=1;
        rom['h0f]=8'h8d; rom['h10]=1; rom['h11]=8'h20;
        rom['h12]=8'he6; rom['h13]=1;
        rom['h14]=8'ha5; rom['h15]=1;
        rom['h16]=8'h8d; rom['h17]=2; rom['h18]=8'h20;
        rom['h19]=8'hea; rom['h1a]=8'h4c; rom['h1b]=8'h19; rom['h1c]=8'h80;
        tick(); tick(); rst_n=1; repeat(5) tick();
        transfer(16'hfffc); transfer(16'hfffd);
        transfer(16'h8000,0,8'ha9,1); transfer(16'h8001);
        transfer(16'h8002,0,8'h85,1); transfer(16'h8003);
        rdy_i=0; transfer(0,1,8'h2f); rdy_i=1;
        if (ddr_o !== 8'h2f || port_oe !== 6'h2f) $fatal(1,"6510 CPU DDR write");
        transfer(16'h8004,0,8'ha9,1); transfer(16'h8005);
        transfer(16'h8006,0,8'h85,1); transfer(16'h8007); transfer(1,1,8'h37);
        transfer(16'h8008,0,8'ha5,1); transfer(16'h8009); transfer(0);
        transfer(16'h800a,0,8'h8d,1); transfer(16'h800b); transfer(16'h800c); transfer(16'h2000,1,8'h2f);
        transfer(16'h800d,0,8'ha5,1); transfer(16'h800e); transfer(1);
        transfer(16'h800f,0,8'h8d,1); transfer(16'h8010); transfer(16'h8011); transfer(16'h2001,1,8'h37);
        transfer(16'h8012,0,8'he6,1); transfer(16'h8013); transfer(1);
        rdy_i=0; transfer(1,1,8'h37); transfer(1,1,8'h38); rdy_i=1;
        if (latch_o !== 8'h38 || port_o !== 6'h38) $fatal(1,"6510 actual CPU RMW port writes");
        transfer(16'h8014,0,8'ha5,1); transfer(16'h8015); transfer(1);
        transfer(16'h8016,0,8'h8d,1); transfer(16'h8017); transfer(16'h8018); transfer(16'h2002,1,8'h38);
        if (low_ram[0] !== 8'hff || low_ram[1] !== 8'hff || result_ram[0] !== 8'h2f ||
            result_ram[1] !== 8'h37 || result_ram[2] !== 8'h38) $fatal(1,"6510 internal/external data separation");
        aec_i=0; rdy_i=0;
        repeat(3) transfer(16'h8019,0,8'hea,1);
        rdy_i=1; transfer(16'h8019,0,8'hea,1);
        // AEC gates drivers only; the sequencer advanced with RDY high.
        if (pc_o !== 16'h801a || fetch_o) $fatal(1,"6510 AEC spuriously stalled CPU");
        aec_i=1; transfer(16'h801a);
        transfer(16'h801a,0,8'h4c,1); transfer(16'h801b); transfer(16'h801c);
        if (!fetch_o || pc_o !== 16'h8019 || ddr_o !== 8'h2f || latch_o !== 8'h38)
            $fatal(1,"6510 final exact next instruction/port");
        $display("MOS 6510 CPU PASS: %0d exact bus checks; port/RMW/RDY/AEC/external RAM",checks);
        $finish;
    end
endmodule
