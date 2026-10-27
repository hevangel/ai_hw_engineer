// Sony S-SMP: the SPC700 core plus its on-chip I/O ($00F0-$00FF), three
// timers, the 64-byte IPL ROM at $FFC0 and the four CPU communication ports.
// Audio RAM and the DSP registers are reached through the S-DSP. One SPC700
// bus cycle per `ce` (1.024 MHz). See spec/spec.md.
module sony_s_smp (
    input  logic clk,
    input  logic rst_n,
    input  logic ce,                   // end of the current SPC700 bus cycle
    // 5A22 side, $2140-$2143 (mirrored up to $217F by the board)
    input  logic [1:0] cpu_addr,
    input  logic cpu_wr,               // one-clock strobe
    input  logic [7:0] cpu_wdata,
    output logic [7:0] cpu_rdata,
    // S-DSP register window
    output logic [6:0] dsp_addr,
    output logic dsp_wr,
    output logic [7:0] dsp_wdata,
    input  logic [7:0] dsp_rdata,
    // audio RAM through the S-DSP
    output logic [15:0] mem_addr,
    output logic mem_wr,
    output logic [7:0] mem_wdata,
    input  logic [7:0] mem_rdata,
    // IPL ROM image load (Sony mask ROM, supplied by the host)
    input  logic ipl_we,
    input  logic [5:0] ipl_addr,
    input  logic [7:0] ipl_data,
    // debug
    output logic [15:0] pc_o,
    output logic fetch_o
);
    logic [15:0] addr;
    logic [7:0] dout, psw;
    // The core samples din at ce only; its address does not depend on din.
    /* verilator lint_off UNOPTFLAT */
    logic [7:0] din;
    /* verilator lint_on UNOPTFLAT */
    logic rd, we;

    sony_spc700 core (
        .clk, .ce, .rst_n,
        .addr_o(addr), .data_i(din), .data_o(dout), .rd_o(rd), .we_o(we),
        .fetch_o, .halted_o(), .pc_o,
        .a_o(), .x_o(), .y_o(), .sp_o(), .psw_o(psw)
    );

    logic [7:0] ipl [64];
    always_ff @(posedge clk) if (ipl_we) ipl[ipl_addr] <= ipl_data;

    // TEST ($F0) fields
    logic timers_disable, ram_writable, ram_disable, timers_enable;
    logic [3:0] wait_cfg;              // wait-state fields: stored, not modelled
    // CONTROL ($F1) fields
    logic [2:0] t_en;
    logic ipl_en;
    logic [7:0] dspa, aux4, aux5;
    logic [7:0] to_smp [4];            // written by the 5A22, read at $F4-$F7
    logic [7:0] to_cpu [4];            // written at $F4-$F7, read by the 5A22
    // timers: stage 1 divider, stage 2 counter, stage 3 4-bit output
    logic [6:0] div;
    logic [2:0] line;
    logic [7:0] target [3], stage2 [3];
    logic [3:0] stage3 [3];

    wire io = addr[15:4] == 12'h00f;
    wire [3:0] reg_n = addr[3:0];
    wire [1:0] tsel = 2'(reg_n - 4'hd);
    wire [1:0] tgt = 2'(reg_n - 4'ha);
    assign cpu_rdata = to_cpu[cpu_addr];
    assign mem_addr = addr;
    assign mem_wdata = dout;
    assign mem_wr = ce && we && ram_writable && !ram_disable;  // I/O writes reach RAM too
    assign dsp_addr = dspa[6:0];
    assign dsp_wdata = dout;
    assign dsp_wr = ce && we && io && reg_n == 4'h3 && !dspa[7];

    always_comb begin
        if (addr >= 16'hffc0 && ipl_en) din = ipl[addr[5:0]];
        else if (ram_disable) din = 8'h5a;
        else din = mem_rdata;
        if (io) begin
            case (reg_n)
                4'h2: din = dspa;
                4'h3: din = dsp_rdata;
                4'h4, 4'h5, 4'h6, 4'h7: din = to_smp[reg_n[1:0]];
                4'h8: din = aux4;
                4'h9: din = aux5;
                4'hd, 4'he, 4'hf: din = {4'h0, stage3[tsel]};
                default: din = 8'h00;   // $F0, $F1, $FA-$FC are write-only
            endcase
        end
    end

    // Timer stage-1 level after this cycle; TEST gates it, and a 1->0 edge of
    // the gated level clocks stage 2 (so a TEST write can produce a tick).
    logic [6:0] div_n;
    logic n_dis, n_en;
    logic [2:0] level;
    always_comb begin
        div_n = div + 7'd1;
        n_dis = timers_disable;
        n_en = timers_enable;
        if (we && io && reg_n == 4'h0 && !psw[5]) begin
            n_dis = dout[0];
            n_en = dout[3];
        end
        // T0/T1: stage 1 is high for cycles 64-127 of each 128; T2 for 8-15 of 16.
        level[0] = div_n[6] && n_en && !n_dis;
        level[1] = level[0];
        level[2] = div_n[3] && n_en && !n_dis;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            timers_disable <= 1'b0;
            ram_writable <= 1'b1;
            ram_disable <= 1'b0;
            timers_enable <= 1'b1;
            wait_cfg <= 4'h0;
            t_en <= 3'b000;
            ipl_en <= 1'b1;
            dspa <= 8'h00;
            aux4 <= 8'h00;
            aux5 <= 8'h00;
            div <= 7'd0;
            line <= 3'b000;
            for (int i = 0; i < 4; i++) begin
                to_smp[i] <= 8'h00;
                to_cpu[i] <= 8'h00;
            end
            for (int i = 0; i < 3; i++) begin
                target[i] <= 8'h00;
                stage2[i] <= 8'h00;
                stage3[i] <= 4'h0;
            end
        end else begin
            if (cpu_wr) to_smp[cpu_addr] <= cpu_wdata;
            if (ce) begin
                div <= div_n;
                line <= level;
                for (int i = 0; i < 3; i++) begin
                    if (line[i] && !level[i] && t_en[i]) begin
                        if (stage2[i] + 8'd1 == target[i]) begin
                            stage2[i] <= 8'h00;
                            stage3[i] <= stage3[i] + 4'd1;
                        end else begin
                            stage2[i] <= stage2[i] + 8'd1;
                        end
                    end
                end
                if (rd && io && reg_n >= 4'hd) stage3[tsel] <= 4'h0;
                if (we && io) begin
                    case (reg_n)
                        4'h0: if (!psw[5]) begin
                            timers_disable <= dout[0];
                            ram_writable <= dout[1];
                            ram_disable <= dout[2];
                            timers_enable <= dout[3];
                            wait_cfg <= dout[7:4];
                        end
                        4'h1: begin
                            for (int i = 0; i < 3; i++) begin
                                if (dout[i] && !t_en[i]) begin
                                    stage2[i] <= 8'h00;
                                    stage3[i] <= 4'h0;
                                end
                            end
                            t_en <= dout[2:0];
                            if (dout[4]) begin
                                to_smp[0] <= 8'h00;
                                to_smp[1] <= 8'h00;
                            end
                            if (dout[5]) begin
                                to_smp[2] <= 8'h00;
                                to_smp[3] <= 8'h00;
                            end
                            ipl_en <= dout[7];
                        end
                        4'h2: dspa <= dout;
                        4'h4, 4'h5, 4'h6, 4'h7: to_cpu[reg_n[1:0]] <= dout;
                        4'h8: aux4 <= dout;
                        4'h9: aux5 <= dout;
                        4'ha, 4'hb, 4'hc: target[tgt] <= dout;
                        default: ;
                    endcase
                end
            end
        end
    end
endmodule
