module intel_80286_at_page_map_tb;
    logic refresh_n, dack0_n, dack2_n, dack3_n, dack4_n, dack6_n, dack7_n;
    logic hlda, master_n, aen1_n, high_oe, xa16, xa16_valid;
    logic [7:0] data, io_wdata, read_data;
    logic clk, rst_n, io_req, io_ready, io_write, io_selected, io_valid;
    logic [15:0] io_address;
    logic [6:0] high_address;
    logic [3:0] index;
    intel_80286_at_page_map dut (
        .refresh_n_i(refresh_n), .dack0_n_i(dack0_n), .dack2_n_i(dack2_n),
        .dack3_n_i(dack3_n), .dack4_n_i(dack4_n), .dack6_n_i(dack6_n), .dack7_n_i(dack7_n),
        .hlda_i(hlda), .master_n_i(master_n), .aen1_n_i(aen1_n), .map_data_i(data),
        .map_index_o(index), .a23_a17_o(high_address), .a23_a17_oe_o(high_oe),
        .xa16_o(xa16), .xa16_valid_o(xa16_valid)
    );
    intel_80286_at_page page (
        .clk(clk), .rst_n(rst_n), .io_req_i(io_req), .io_ready_i(io_ready),
        .io_write_i(io_write), .io_addr_i(io_address), .io_wdata_i(io_wdata),
        .map_index_i(index), .selected_o(io_selected), .rdata_valid_o(io_valid),
        .rdata_o(read_data), .map_data_o(data)
    );
    task automatic tick;
        clk=0; #1; clk=1; #1; clk=0; #1;
    endtask
    task automatic expected(input logic [3:0] value);
        #1;
        assert(index==value) else $fatal(1,"page index was %x, expected %x",index,value);
    endtask
    initial begin
        refresh_n=1; dack0_n=1; dack2_n=1; dack3_n=1;
        dack4_n=1; dack6_n=1; dack7_n=1;
        hlda=0; master_n=1; aen1_n=1;
        clk=0; rst_n=0; io_req=0; io_ready=0; io_write=0; io_address=0; io_wdata=0;
        tick(); rst_n=1;
        io_req=1; io_ready=1; io_write=1; io_address=16'h008f; io_wdata=8'ha5; tick();
        io_req=0; io_ready=0; io_write=0;
        expected(4'hb); // all DACKs inactive; index itself does not imply a valid output
        assert(!high_oe && !xa16_valid);
        hlda=1; refresh_n=0; expected(4'hf);
        assert(high_oe && !xa16_valid && high_address==7'h52 && xa16);
        // Stall cannot change the selected refresh page, then accept a new
        // nonzero value and verify the actual mapper output follows it.
        io_req=1; io_ready=0; io_write=1; io_address=16'h008f; io_wdata=8'h5a; tick();
        assert(io_selected && high_address==7'h52 && xa16);
        io_ready=1; tick();
        assert(high_address==7'h2d && !xa16);
        io_req=0; io_ready=0; io_write=0;
        io_req=1; io_ready=1; io_write=0; #1;
        assert(io_selected && io_valid && read_data==8'h5a);
        io_req=0; io_ready=0;
        aen1_n=0; #1; assert(high_oe && xa16_valid);
        master_n=0; #1; assert(!high_oe && !xa16_valid);
        master_n=1; aen1_n=1;
        refresh_n=0; expected(4'hf);
        refresh_n=1; dack4_n=0; dack0_n=0; expected(4'h7);
        dack0_n=1; expected(4'h3); // cascade, channel 1
        dack2_n=0; expected(4'h1);
        dack2_n=1; dack3_n=0; expected(4'h2);
        dack3_n=1; dack4_n=1; expected(4'hb); // channel 5, schematic logic
        dack6_n=0; expected(4'h9);
        dack6_n=1; dack7_n=0; expected(4'ha);
        // Simultaneous request inputs follow the drawn gates, not priority logic.
        refresh_n=0; dack4_n=0; dack2_n=0; dack7_n=0; expected(4'h4);
        $display("PASS: AT page-map gate indices, refresh slot and separate output enables");
        $finish;
    end
endmodule
