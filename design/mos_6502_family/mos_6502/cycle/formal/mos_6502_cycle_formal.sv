module mos_6502_cycle_formal(input logic clk);
    (* anyseq *) logic rst_n, res_n, irq_n, nmi_n, rdy, so_n;
    (* anyseq *) logic [7:0] bus_data_i;
    logic [15:0] bus_addr,pc_o;
    logic [7:0] bus_data_o,status_o,a_o,x_o,y_o,sp_o;
    logic bus_we, fetch_o, fault_o;
    mos_6502_cycle dut(.*);
    always_ff @(posedge clk) begin
        if($initstate) assume(!rst_n);
        else assume(rst_n);
        cover(rst_n && fetch_o && pc_o==16'h8000);
        cover(rst_n && bus_we);
    end

    // Instruction-class coverage at the opcode fetch. Bus data is
    // unconstrained, so each cover asks whether the decoder and sequencer can
    // reach that path at all, not whether a scripted trace took it.
    localparam logic [7:0] FETCH_ADC_IMM = 8'h69, FETCH_LDA_ABS = 8'had,
        FETCH_LDA_ABX = 8'hbd, FETCH_STA_ABS = 8'h8d, FETCH_ASL_ABS = 8'h0e,
        FETCH_INC_ABS = 8'hee, FETCH_JMP_ABS = 8'h4c, FETCH_JSR = 8'h20,
        FETCH_RTS = 8'h60, FETCH_RTI = 8'h40, FETCH_BRK = 8'h00,
        FETCH_BEQ = 8'hf0, FETCH_PHA = 8'h48, FETCH_PLA = 8'h68;
    always_ff @(posedge clk) if (rst_n && fetch_o) begin
        cover(bus_data_i == FETCH_ADC_IMM);
        cover(bus_data_i == FETCH_LDA_ABS);
        cover(bus_data_i == FETCH_LDA_ABX);
        cover(bus_data_i == FETCH_STA_ABS);
        cover(bus_data_i == FETCH_ASL_ABS);
        cover(bus_data_i == FETCH_INC_ABS);
        cover(bus_data_i == FETCH_JMP_ABS);
        cover(bus_data_i == FETCH_JSR);
        cover(bus_data_i == FETCH_RTS);
        cover(bus_data_i == FETCH_RTI);
        cover(bus_data_i == FETCH_BRK);
        cover(bus_data_i == FETCH_BEQ);
        cover(bus_data_i == FETCH_PHA);
        cover(bus_data_i == FETCH_PLA);
    end
endmodule
