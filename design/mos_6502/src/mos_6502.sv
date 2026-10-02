// Authored documented-instruction NMOS core. Sources and assumptions: ../spec/spec.md.
module mos_6502 (
    input logic clk, rst_n, res_n, irq_n, nmi_n, rdy, so_n,
    output logic [15:0] bus_addr,
    input logic [7:0] bus_data_i,
    output logic [7:0] bus_data_o,
    output logic bus_we, fetch_o, fault_o,
    output logic [15:0] pc_o,
    output logic [7:0] status_o, a_o, x_o, y_o, sp_o
);
    typedef enum logic [5:0] {OP_BAD, OP_ADC, OP_AND, OP_ASL, OP_BCC, OP_BCS, OP_BEQ, OP_BIT, OP_BMI, OP_BNE, OP_BPL, OP_BRK, OP_BVC, OP_BVS, OP_CLC, OP_CLD, OP_CLI, OP_CLV, OP_CMP, OP_CPX, OP_CPY, OP_DEC, OP_DEX, OP_DEY, OP_EOR, OP_INC, OP_INX, OP_INY, OP_JMP, OP_JSR, OP_LDA, OP_LDX, OP_LDY, OP_LSR, OP_NOP, OP_ORA, OP_PHA, OP_PHP, OP_PLA, OP_PLP, OP_ROL, OP_ROR, OP_RTI, OP_RTS, OP_SBC, OP_SEC, OP_SED, OP_SEI, OP_STA, OP_STX, OP_STY, OP_TAX, OP_TAY, OP_TSX, OP_TXA, OP_TXS, OP_TYA} op_t;
    typedef enum logic [3:0] {M_IMP, M_ACC, M_IMM, M_ZP, M_ZX, M_ZY, M_ABS, M_AX, M_AY, M_IX, M_IY, M_IND, M_REL} mode_t;
    typedef enum logic [5:0] {
        FETCH, OPERAND, IMPLIED, ABS_HIGH, ZP_INDEX, PTR_LOW, PTR_HIGH,
        INDEX_DUMMY, MEM_READ, MEM_WRITE, RMW_OLD, RMW_NEW,
        BRANCH_DUMMY, BRANCH_FIX, JMP_LOW, JMP_HIGH,
        JSR_DUMMY, JSR_HIGH, JSR_LOW, JSR_FINISH,
        PUSH_WRITE, PULL_DUMMY, PULL_READ, RTS_LOW, RTS_HIGH, RTS_FINISH,
        RTI_STATUS, RTI_LOW, RTI_HIGH,
        INT_DUMMY, INT_HIGH, INT_LOW, INT_STATUS, VECTOR_LOW, VECTOR_HIGH,
        RESET_0, RESET_1, RESET_2, RESET_3, RESET_4, FAULT
    } state_t;
    state_t state;
    op_t op, decoded_op;
    mode_t mode, decoded_mode;
    logic [15:0] pc, target, wrong, vector_addr;
    logic [7:0] a, x, y, sp, p, lo, operand;
    logic interrupt_brk, irq_latched, nmi_latched;
    logic previous_nmi, previous_so, previous_irq, nmi_pending;
    logic is_store, is_rmw, branch_taken;
    logic [7:0] index_value, read_value, alu_a, alu_p, rmw_value, rmw_p;
    logic [8:0] indexed_sum;
    logic [15:0] indexed_address, branch_address;

    always_comb begin
        decoded_op=OP_BAD; decoded_mode=M_IMP;
        case(bus_data_i)
            8'h00: begin decoded_op=OP_BRK; decoded_mode=M_IMP; end
            8'h01: begin decoded_op=OP_ORA; decoded_mode=M_IX; end
            8'h05: begin decoded_op=OP_ORA; decoded_mode=M_ZP; end
            8'h06: begin decoded_op=OP_ASL; decoded_mode=M_ZP; end
            8'h08: begin decoded_op=OP_PHP; decoded_mode=M_IMP; end
            8'h09: begin decoded_op=OP_ORA; decoded_mode=M_IMM; end
            8'h0a: begin decoded_op=OP_ASL; decoded_mode=M_ACC; end
            8'h0d: begin decoded_op=OP_ORA; decoded_mode=M_ABS; end
            8'h0e: begin decoded_op=OP_ASL; decoded_mode=M_ABS; end
            8'h10: begin decoded_op=OP_BPL; decoded_mode=M_REL; end
            8'h11: begin decoded_op=OP_ORA; decoded_mode=M_IY; end
            8'h15: begin decoded_op=OP_ORA; decoded_mode=M_ZX; end
            8'h16: begin decoded_op=OP_ASL; decoded_mode=M_ZX; end
            8'h18: begin decoded_op=OP_CLC; decoded_mode=M_IMP; end
            8'h19: begin decoded_op=OP_ORA; decoded_mode=M_AY; end
            8'h1d: begin decoded_op=OP_ORA; decoded_mode=M_AX; end
            8'h1e: begin decoded_op=OP_ASL; decoded_mode=M_AX; end
            8'h20: begin decoded_op=OP_JSR; decoded_mode=M_ABS; end
            8'h21: begin decoded_op=OP_AND; decoded_mode=M_IX; end
            8'h24: begin decoded_op=OP_BIT; decoded_mode=M_ZP; end
            8'h25: begin decoded_op=OP_AND; decoded_mode=M_ZP; end
            8'h26: begin decoded_op=OP_ROL; decoded_mode=M_ZP; end
            8'h28: begin decoded_op=OP_PLP; decoded_mode=M_IMP; end
            8'h29: begin decoded_op=OP_AND; decoded_mode=M_IMM; end
            8'h2a: begin decoded_op=OP_ROL; decoded_mode=M_ACC; end
            8'h2c: begin decoded_op=OP_BIT; decoded_mode=M_ABS; end
            8'h2d: begin decoded_op=OP_AND; decoded_mode=M_ABS; end
            8'h2e: begin decoded_op=OP_ROL; decoded_mode=M_ABS; end
            8'h30: begin decoded_op=OP_BMI; decoded_mode=M_REL; end
            8'h31: begin decoded_op=OP_AND; decoded_mode=M_IY; end
            8'h35: begin decoded_op=OP_AND; decoded_mode=M_ZX; end
            8'h36: begin decoded_op=OP_ROL; decoded_mode=M_ZX; end
            8'h38: begin decoded_op=OP_SEC; decoded_mode=M_IMP; end
            8'h39: begin decoded_op=OP_AND; decoded_mode=M_AY; end
            8'h3d: begin decoded_op=OP_AND; decoded_mode=M_AX; end
            8'h3e: begin decoded_op=OP_ROL; decoded_mode=M_AX; end
            8'h40: begin decoded_op=OP_RTI; decoded_mode=M_IMP; end
            8'h41: begin decoded_op=OP_EOR; decoded_mode=M_IX; end
            8'h45: begin decoded_op=OP_EOR; decoded_mode=M_ZP; end
            8'h46: begin decoded_op=OP_LSR; decoded_mode=M_ZP; end
            8'h48: begin decoded_op=OP_PHA; decoded_mode=M_IMP; end
            8'h49: begin decoded_op=OP_EOR; decoded_mode=M_IMM; end
            8'h4a: begin decoded_op=OP_LSR; decoded_mode=M_ACC; end
            8'h4c: begin decoded_op=OP_JMP; decoded_mode=M_ABS; end
            8'h4d: begin decoded_op=OP_EOR; decoded_mode=M_ABS; end
            8'h4e: begin decoded_op=OP_LSR; decoded_mode=M_ABS; end
            8'h50: begin decoded_op=OP_BVC; decoded_mode=M_REL; end
            8'h51: begin decoded_op=OP_EOR; decoded_mode=M_IY; end
            8'h55: begin decoded_op=OP_EOR; decoded_mode=M_ZX; end
            8'h56: begin decoded_op=OP_LSR; decoded_mode=M_ZX; end
            8'h58: begin decoded_op=OP_CLI; decoded_mode=M_IMP; end
            8'h59: begin decoded_op=OP_EOR; decoded_mode=M_AY; end
            8'h5d: begin decoded_op=OP_EOR; decoded_mode=M_AX; end
            8'h5e: begin decoded_op=OP_LSR; decoded_mode=M_AX; end
            8'h60: begin decoded_op=OP_RTS; decoded_mode=M_IMP; end
            8'h61: begin decoded_op=OP_ADC; decoded_mode=M_IX; end
            8'h65: begin decoded_op=OP_ADC; decoded_mode=M_ZP; end
            8'h66: begin decoded_op=OP_ROR; decoded_mode=M_ZP; end
            8'h68: begin decoded_op=OP_PLA; decoded_mode=M_IMP; end
            8'h69: begin decoded_op=OP_ADC; decoded_mode=M_IMM; end
            8'h6a: begin decoded_op=OP_ROR; decoded_mode=M_ACC; end
            8'h6c: begin decoded_op=OP_JMP; decoded_mode=M_IND; end
            8'h6d: begin decoded_op=OP_ADC; decoded_mode=M_ABS; end
            8'h6e: begin decoded_op=OP_ROR; decoded_mode=M_ABS; end
            8'h70: begin decoded_op=OP_BVS; decoded_mode=M_REL; end
            8'h71: begin decoded_op=OP_ADC; decoded_mode=M_IY; end
            8'h75: begin decoded_op=OP_ADC; decoded_mode=M_ZX; end
            8'h76: begin decoded_op=OP_ROR; decoded_mode=M_ZX; end
            8'h78: begin decoded_op=OP_SEI; decoded_mode=M_IMP; end
            8'h79: begin decoded_op=OP_ADC; decoded_mode=M_AY; end
            8'h7d: begin decoded_op=OP_ADC; decoded_mode=M_AX; end
            8'h7e: begin decoded_op=OP_ROR; decoded_mode=M_AX; end
            8'h81: begin decoded_op=OP_STA; decoded_mode=M_IX; end
            8'h84: begin decoded_op=OP_STY; decoded_mode=M_ZP; end
            8'h85: begin decoded_op=OP_STA; decoded_mode=M_ZP; end
            8'h86: begin decoded_op=OP_STX; decoded_mode=M_ZP; end
            8'h88: begin decoded_op=OP_DEY; decoded_mode=M_IMP; end
            8'h8a: begin decoded_op=OP_TXA; decoded_mode=M_IMP; end
            8'h8c: begin decoded_op=OP_STY; decoded_mode=M_ABS; end
            8'h8d: begin decoded_op=OP_STA; decoded_mode=M_ABS; end
            8'h8e: begin decoded_op=OP_STX; decoded_mode=M_ABS; end
            8'h90: begin decoded_op=OP_BCC; decoded_mode=M_REL; end
            8'h91: begin decoded_op=OP_STA; decoded_mode=M_IY; end
            8'h94: begin decoded_op=OP_STY; decoded_mode=M_ZX; end
            8'h95: begin decoded_op=OP_STA; decoded_mode=M_ZX; end
            8'h96: begin decoded_op=OP_STX; decoded_mode=M_ZY; end
            8'h98: begin decoded_op=OP_TYA; decoded_mode=M_IMP; end
            8'h99: begin decoded_op=OP_STA; decoded_mode=M_AY; end
            8'h9a: begin decoded_op=OP_TXS; decoded_mode=M_IMP; end
            8'h9d: begin decoded_op=OP_STA; decoded_mode=M_AX; end
            8'ha0: begin decoded_op=OP_LDY; decoded_mode=M_IMM; end
            8'ha1: begin decoded_op=OP_LDA; decoded_mode=M_IX; end
            8'ha2: begin decoded_op=OP_LDX; decoded_mode=M_IMM; end
            8'ha4: begin decoded_op=OP_LDY; decoded_mode=M_ZP; end
            8'ha5: begin decoded_op=OP_LDA; decoded_mode=M_ZP; end
            8'ha6: begin decoded_op=OP_LDX; decoded_mode=M_ZP; end
            8'ha8: begin decoded_op=OP_TAY; decoded_mode=M_IMP; end
            8'ha9: begin decoded_op=OP_LDA; decoded_mode=M_IMM; end
            8'haa: begin decoded_op=OP_TAX; decoded_mode=M_IMP; end
            8'hac: begin decoded_op=OP_LDY; decoded_mode=M_ABS; end
            8'had: begin decoded_op=OP_LDA; decoded_mode=M_ABS; end
            8'hae: begin decoded_op=OP_LDX; decoded_mode=M_ABS; end
            8'hb0: begin decoded_op=OP_BCS; decoded_mode=M_REL; end
            8'hb1: begin decoded_op=OP_LDA; decoded_mode=M_IY; end
            8'hb4: begin decoded_op=OP_LDY; decoded_mode=M_ZX; end
            8'hb5: begin decoded_op=OP_LDA; decoded_mode=M_ZX; end
            8'hb6: begin decoded_op=OP_LDX; decoded_mode=M_ZY; end
            8'hb8: begin decoded_op=OP_CLV; decoded_mode=M_IMP; end
            8'hb9: begin decoded_op=OP_LDA; decoded_mode=M_AY; end
            8'hba: begin decoded_op=OP_TSX; decoded_mode=M_IMP; end
            8'hbc: begin decoded_op=OP_LDY; decoded_mode=M_AX; end
            8'hbd: begin decoded_op=OP_LDA; decoded_mode=M_AX; end
            8'hbe: begin decoded_op=OP_LDX; decoded_mode=M_AY; end
            8'hc0: begin decoded_op=OP_CPY; decoded_mode=M_IMM; end
            8'hc1: begin decoded_op=OP_CMP; decoded_mode=M_IX; end
            8'hc4: begin decoded_op=OP_CPY; decoded_mode=M_ZP; end
            8'hc5: begin decoded_op=OP_CMP; decoded_mode=M_ZP; end
            8'hc6: begin decoded_op=OP_DEC; decoded_mode=M_ZP; end
            8'hc8: begin decoded_op=OP_INY; decoded_mode=M_IMP; end
            8'hc9: begin decoded_op=OP_CMP; decoded_mode=M_IMM; end
            8'hca: begin decoded_op=OP_DEX; decoded_mode=M_IMP; end
            8'hcc: begin decoded_op=OP_CPY; decoded_mode=M_ABS; end
            8'hcd: begin decoded_op=OP_CMP; decoded_mode=M_ABS; end
            8'hce: begin decoded_op=OP_DEC; decoded_mode=M_ABS; end
            8'hd0: begin decoded_op=OP_BNE; decoded_mode=M_REL; end
            8'hd1: begin decoded_op=OP_CMP; decoded_mode=M_IY; end
            8'hd5: begin decoded_op=OP_CMP; decoded_mode=M_ZX; end
            8'hd6: begin decoded_op=OP_DEC; decoded_mode=M_ZX; end
            8'hd8: begin decoded_op=OP_CLD; decoded_mode=M_IMP; end
            8'hd9: begin decoded_op=OP_CMP; decoded_mode=M_AY; end
            8'hdd: begin decoded_op=OP_CMP; decoded_mode=M_AX; end
            8'hde: begin decoded_op=OP_DEC; decoded_mode=M_AX; end
            8'he0: begin decoded_op=OP_CPX; decoded_mode=M_IMM; end
            8'he1: begin decoded_op=OP_SBC; decoded_mode=M_IX; end
            8'he4: begin decoded_op=OP_CPX; decoded_mode=M_ZP; end
            8'he5: begin decoded_op=OP_SBC; decoded_mode=M_ZP; end
            8'he6: begin decoded_op=OP_INC; decoded_mode=M_ZP; end
            8'he8: begin decoded_op=OP_INX; decoded_mode=M_IMP; end
            8'he9: begin decoded_op=OP_SBC; decoded_mode=M_IMM; end
            8'hea: begin decoded_op=OP_NOP; decoded_mode=M_IMP; end
            8'hec: begin decoded_op=OP_CPX; decoded_mode=M_ABS; end
            8'hed: begin decoded_op=OP_SBC; decoded_mode=M_ABS; end
            8'hee: begin decoded_op=OP_INC; decoded_mode=M_ABS; end
            8'hf0: begin decoded_op=OP_BEQ; decoded_mode=M_REL; end
            8'hf1: begin decoded_op=OP_SBC; decoded_mode=M_IY; end
            8'hf5: begin decoded_op=OP_SBC; decoded_mode=M_ZX; end
            8'hf6: begin decoded_op=OP_INC; decoded_mode=M_ZX; end
            8'hf8: begin decoded_op=OP_SED; decoded_mode=M_IMP; end
            8'hf9: begin decoded_op=OP_SBC; decoded_mode=M_AY; end
            8'hfd: begin decoded_op=OP_SBC; decoded_mode=M_AX; end
            8'hfe: begin decoded_op=OP_INC; decoded_mode=M_AX; end
            default: begin end
        endcase
    end
    assign pc_o=pc; assign status_o=p; assign a_o=a;
    assign x_o=x; assign y_o=y; assign sp_o=sp;
    assign fetch_o=(state==FETCH); assign fault_o=(state==FAULT);
    assign is_store=(op==OP_STA || op==OP_STX || op==OP_STY);
    assign is_rmw=(op==OP_ASL || op==OP_ROL || op==OP_LSR || op==OP_ROR || op==OP_INC || op==OP_DEC);
    assign index_value=(mode==M_ZY || mode==M_AY || mode==M_IY) ? y : x;
    assign indexed_sum={1'b0,lo}+{1'b0,index_value};
    assign indexed_address={bus_data_i,lo}+{8'b0,index_value};
    assign branch_address=pc+16'd1+{{8{bus_data_i[7]}},bus_data_i};
    always_comb begin
        case(op)
            OP_BPL: branch_taken=!p[7]; OP_BMI: branch_taken=p[7];
            OP_BVC: branch_taken=!p[6]; OP_BVS: branch_taken=p[6];
            OP_BCC: branch_taken=!p[0]; OP_BCS: branch_taken=p[0];
            OP_BNE: branch_taken=!p[1]; OP_BEQ: branch_taken=p[1];
            default: branch_taken=0;
        endcase
    end

    always_comb begin
        bus_addr=pc; bus_data_o=a; bus_we=0;
        case(state)
            MEM_READ, MEM_WRITE, RMW_OLD, RMW_NEW, PTR_LOW, JMP_LOW: bus_addr=target;
            PTR_HIGH: bus_addr={8'b0,target[7:0]+8'd1};
            JMP_HIGH: bus_addr={target[15:8],target[7:0]+8'd1}; // NMOS page wrap
            INDEX_DUMMY, BRANCH_FIX: bus_addr=wrong;
            ZP_INDEX: bus_addr=target;
            JSR_DUMMY, JSR_HIGH, JSR_LOW, PUSH_WRITE, PULL_DUMMY,
            PULL_READ, RTS_LOW, RTS_HIGH, RTI_STATUS, RTI_LOW, RTI_HIGH,
            INT_HIGH, INT_LOW, INT_STATUS, RESET_2, RESET_3, RESET_4:
                bus_addr={8'h01,sp};
            VECTOR_LOW: bus_addr=vector_addr;
            VECTOR_HIGH: bus_addr=vector_addr+16'd1;
            default: begin end
        endcase
        case(state)
            MEM_WRITE: begin
                bus_we=1;
                if(op==OP_STX) bus_data_o=x;
                else if(op==OP_STY) bus_data_o=y;
            end
            RMW_OLD: begin bus_we=1; bus_data_o=operand; end
            RMW_NEW: begin bus_we=1; bus_data_o=rmw_value; end
            JSR_HIGH, INT_HIGH: begin bus_we=1; bus_data_o=pc[15:8]; end
            JSR_LOW, INT_LOW: begin bus_we=1; bus_data_o=pc[7:0]; end
            PUSH_WRITE: begin bus_we=1; bus_data_o=(op==OP_PHP) ? (p|8'h30) : a; end
            INT_STATUS: begin bus_we=1; bus_data_o=(p|8'h20)|(interrupt_brk ? 8'h10 : 8'h00); end
            default: begin end
        endcase
    end

    // NMOS decimal flags come from the pre-correction ALU paths, not the
    // final BCD accumulator. SingleStepTests/65x02 is the independent oracle.
    logic [8:0] binary_sum;
    logic [7:0] compare_value, binary_result;
    integer decimal_low, decimal_high;
    always_comb begin
        read_value=bus_data_i;
        if(state==IMPLIED && mode==M_ACC) read_value=a;
        alu_a=a; alu_p=p; compare_value=a;
        binary_sum=0; binary_result=0; decimal_low=0; decimal_high=0;
        case(op)
            OP_ORA: alu_a=a|read_value;
            OP_AND: alu_a=a&read_value;
            OP_EOR: alu_a=a^read_value;
            OP_LDA, OP_PLA: alu_a=read_value;
            OP_ADC: begin
                binary_sum={1'b0,a}+{1'b0,read_value}+{8'b0,p[0]};
                binary_result=binary_sum[7:0];
                alu_p[6]=(~(a[7]^read_value[7]))&(a[7]^binary_result[7]);
                alu_p[0]=binary_sum[8]; alu_a=binary_result;
                if(p[3]) begin
                    decimal_low=int'(a[3:0])+int'(read_value[3:0])+int'(p[0]);
                    if(decimal_low>=10) decimal_low=((decimal_low+6)&15)+16;
                    decimal_high=(int'(a[7:4])<<4)+(int'(read_value[7:4])<<4)+decimal_low;
                    alu_p[7]=decimal_high[7]; alu_p[1]=(binary_result==0);
                    alu_p[6]=(~(a[7]^read_value[7]))&(a[7]^decimal_high[7]);
                    if(decimal_high>=160) decimal_high=decimal_high+96;
                    alu_p[0]=(decimal_high>255); alu_a=decimal_high[7:0];
                end
            end
            OP_SBC: begin
                binary_sum={1'b0,a}+{1'b0,~read_value}+{8'b0,p[0]};
                binary_result=binary_sum[7:0];
                alu_p[6]=(a[7]^read_value[7])&(a[7]^binary_result[7]);
                alu_p[0]=binary_sum[8]; alu_a=binary_result;
                if(p[3]) begin
                    decimal_low=int'(a[3:0])-int'(read_value[3:0])-int'(!p[0]);
                    if(decimal_low<0) decimal_low=((decimal_low-6)&15)-16;
                    decimal_high=(int'(a[7:4])<<4)-(int'(read_value[7:4])<<4)+decimal_low;
                    if(decimal_high<0) decimal_high=decimal_high-96;
                    alu_a=decimal_high[7:0]; alu_p[7]=binary_result[7]; alu_p[1]=(binary_result==0);
                end
            end
            OP_CMP, OP_CPX, OP_CPY: begin
                if(op==OP_CPX) compare_value=x;
                if(op==OP_CPY) compare_value=y;
                binary_sum={1'b0,compare_value}+{1'b0,~read_value}+9'd1;
                alu_p[0]=binary_sum[8]; alu_p[7]=binary_sum[7]; alu_p[1]=(binary_sum[7:0]==0);
            end
            OP_BIT: begin alu_p[7:6]=read_value[7:6]; alu_p[1]=((a&read_value)==0); end
            OP_LDX, OP_LDY: begin alu_p[7]=read_value[7]; alu_p[1]=(read_value==0); end
            default: begin end
        endcase
        if(op==OP_ORA || op==OP_AND || op==OP_EOR || op==OP_LDA || op==OP_PLA ||
           ((op==OP_ADC || op==OP_SBC) && !p[3])) begin
            alu_p[7]=alu_a[7]; alu_p[1]=(alu_a==0);
        end
    end
    always_comb begin
        rmw_value=operand; rmw_p=p;
        if(mode==M_ACC) rmw_value=a;
        case(op)
            OP_ASL: begin rmw_p[0]=rmw_value[7]; rmw_value={rmw_value[6:0],1'b0}; end
            OP_ROL: begin rmw_p[0]=rmw_value[7]; rmw_value={rmw_value[6:0],p[0]}; end
            OP_LSR: begin rmw_p[0]=rmw_value[0]; rmw_value={1'b0,rmw_value[7:1]}; end
            OP_ROR: begin rmw_p[0]=rmw_value[0]; rmw_value={p[0],rmw_value[7:1]}; end
            OP_INC: rmw_value=rmw_value+8'd1;
            OP_DEC: rmw_value=rmw_value-8'd1;
            default: begin end
        endcase
        rmw_p[7]=rmw_value[7]; rmw_p[1]=(rmw_value==0);
    end
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            // ASSUMPTION: canonical project power-up state; res_n below is
            // the separate physical warm reset and does not clear A/X/Y/D.
            state<=RESET_0; pc<=0; a<=0; x<=0; y<=0; sp<=0; p<=8'h24;
            target<=0; wrong<=0; vector_addr<=16'hfffc; lo<=0; operand<=0;
            op<=OP_NOP; mode<=M_IMP; interrupt_brk<=0;
            irq_latched<=0; nmi_latched<=0; previous_nmi<=1; previous_so<=1; previous_irq<=1;
            nmi_pending<=0;
        end else begin
            previous_irq<=irq_n; previous_nmi<=nmi_n; previous_so<=so_n;
            if(previous_nmi && !nmi_n) nmi_pending<=1;
            if(!res_n) begin
                state<=RESET_0; irq_latched<=0; nmi_latched<=0; nmi_pending<=0;
                p[2]<=1; vector_addr<=16'hfffc;
            end else if(!rdy && (state==BRANCH_FIX || state==INDEX_DUMMY)) begin
                // The NMOS address-high latch corrects even while RDY holds
                // the branch/index page-correction cycle (perfect6502 oracle).
                wrong<=target;
            end else if(rdy || bus_we) begin
                case(state)
                    RESET_0: state<=RESET_1;
                    RESET_1: state<=RESET_2;
                    RESET_2: begin sp<=sp-8'd1; state<=RESET_3; end
                    RESET_3: begin sp<=sp-8'd1; state<=RESET_4; end
                    RESET_4: begin
                        sp<=sp-8'd1;
                        state<=VECTOR_LOW;
                    end
                    VECTOR_LOW: begin lo<=bus_data_i; state<=VECTOR_HIGH; end
                    VECTOR_HIGH: begin pc<={bus_data_i,lo}; state<=FETCH; irq_latched<=0; nmi_latched<=0; end
                    FETCH: begin
                        if(nmi_latched || irq_latched) begin
                            interrupt_brk<=0;
                            state<=INT_DUMMY;
                            vector_addr<=nmi_latched ? 16'hfffa : 16'hfffe;
                            if(nmi_latched) nmi_pending<=0;
                            irq_latched<=0; nmi_latched<=0;
                        end else begin
                            op<=decoded_op; mode<=decoded_mode; pc<=pc+16'd1;
                            if(decoded_op==OP_BAD) state<=FAULT;
                            else if(decoded_mode==M_IMP || decoded_mode==M_ACC) state<=IMPLIED;
                            else state<=OPERAND;
                        end
                    end
                    IMPLIED: begin
                        case(op)
                            OP_BRK: begin pc<=pc+16'd1; interrupt_brk<=1; vector_addr<=16'hfffe; state<=INT_HIGH; end
                            OP_PHA, OP_PHP: state<=PUSH_WRITE;
                            OP_PLA, OP_PLP, OP_RTS, OP_RTI: state<=PULL_DUMMY;
                            default: begin
                                begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end
                                if(mode==M_ACC) begin a<=rmw_value; p<=rmw_p; end
                                else case(op)
                                    OP_CLC: p[0]<=0; OP_SEC: p[0]<=1;
                                    OP_CLI: p[2]<=0; OP_SEI: p[2]<=1;
                                    OP_CLV: p[6]<=0; OP_CLD: p[3]<=0; OP_SED: p[3]<=1;
                                    OP_TAX: begin x<=a; p[7]<=(((a) & 8'h80)!=0); p[1]<=(a==0); end
                                    OP_TAY: begin y<=a; p[7]<=(((a) & 8'h80)!=0); p[1]<=(a==0); end
                                    OP_TXA: begin a<=x; p[7]<=(((x) & 8'h80)!=0); p[1]<=(x==0); end
                                    OP_TYA: begin a<=y; p[7]<=(((y) & 8'h80)!=0); p[1]<=(y==0); end
                                    OP_TSX: begin x<=sp; p[7]<=(((sp) & 8'h80)!=0); p[1]<=(sp==0); end
                                    OP_TXS: sp<=x;
                                    OP_INX: begin x<=x+8'd1; p[7]<=(((x+8'd1) & 8'h80)!=0); p[1]<=(x==8'hff); end
                                    OP_INY: begin y<=y+8'd1; p[7]<=(((y+8'd1) & 8'h80)!=0); p[1]<=(y==8'hff); end
                                    OP_DEX: begin x<=x-8'd1; p[7]<=(((x-8'd1) & 8'h80)!=0); p[1]<=(x==8'h01); end
                                    OP_DEY: begin y<=y-8'd1; p[7]<=(((y-8'd1) & 8'h80)!=0); p[1]<=(y==8'h01); end
                                    default: begin end
                                endcase
                            end
                        endcase
                    end
                    OPERAND: begin
                        pc<=pc+16'd1; lo<=bus_data_i;
                        case(mode)
                            M_IMM: begin p<=alu_p; if(op==OP_LDX) x<=read_value; else if(op==OP_LDY) y<=read_value; else a<=alu_a; begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end end
                            M_REL: begin
                                if(branch_taken) begin target<=branch_address; state<=BRANCH_DUMMY; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end
                                else begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end
                            end
                            M_ZP: begin target<={8'b0,bus_data_i}; state<=is_store ? MEM_WRITE : MEM_READ; end
                            M_ZX, M_ZY, M_IX: begin target<={8'b0,bus_data_i}; state<=ZP_INDEX; end
                            M_IY: begin target<={8'b0,bus_data_i}; state<=PTR_LOW; end
                            default: state<=(op==OP_JSR) ? JSR_DUMMY : ABS_HIGH;
                        endcase
                    end
                    ABS_HIGH: begin
                        pc<=pc+16'd1;
                        if(op==OP_JMP && mode==M_ABS) begin pc<={bus_data_i,lo}; begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end end
                        else if(mode==M_IND) begin target<={bus_data_i,lo}; state<=JMP_LOW; end
                        else if(mode==M_AX || mode==M_AY) begin
                            target<=indexed_address; wrong<={bus_data_i,indexed_sum[7:0]};
                            if(is_store || is_rmw || indexed_sum[8]) state<=INDEX_DUMMY;
                            else state<=MEM_READ;
                        end else begin target<={bus_data_i,lo}; state<=is_store ? MEM_WRITE : MEM_READ; end
                    end
                    ZP_INDEX: begin
                        target<={8'b0,target[7:0]+index_value};
                        if(mode==M_IX) state<=PTR_LOW; else state<=is_store ? MEM_WRITE : MEM_READ;
                    end
                    PTR_LOW: begin lo<=bus_data_i; state<=PTR_HIGH; end
                    PTR_HIGH: begin
                        if(mode==M_IY) begin
                            target<=indexed_address; wrong<={bus_data_i,indexed_sum[7:0]};
                            if(is_store || indexed_sum[8]) state<=INDEX_DUMMY; else state<=MEM_READ;
                        end else begin target<={bus_data_i,lo}; state<=is_store ? MEM_WRITE : MEM_READ; end
                    end
                    INDEX_DUMMY: state<=is_store ? MEM_WRITE : MEM_READ;
                    MEM_READ: begin
                        if(is_rmw) begin operand<=bus_data_i; state<=RMW_OLD; end
                        else begin p<=alu_p; if(op==OP_LDX) x<=read_value; else if(op==OP_LDY) y<=read_value; else a<=alu_a; begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end end
                    end
                    MEM_WRITE: begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end
                    RMW_OLD: state<=RMW_NEW;
                    RMW_NEW: begin p<=rmw_p; begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end end
                    BRANCH_DUMMY: begin
                        if(pc[15:8]==target[15:8]) begin pc<=target; state<=FETCH; end
                        else begin wrong<={pc[15:8],target[7:0]}; state<=BRANCH_FIX; end
                    end
                    BRANCH_FIX: begin pc<=target; state<=FETCH; irq_latched<=irq_latched || (!previous_irq && !p[2]); nmi_latched<=nmi_latched || nmi_pending; end
                    JMP_LOW: begin lo<=bus_data_i; state<=JMP_HIGH; end
                    JMP_HIGH: begin pc<={bus_data_i,lo}; begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end end
                    JSR_DUMMY: state<=JSR_HIGH;
                    JSR_HIGH: begin sp<=sp-8'd1; state<=JSR_LOW; end
                    JSR_LOW: begin sp<=sp-8'd1; state<=JSR_FINISH; end
                    JSR_FINISH: begin pc<={bus_data_i,lo}; begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end end
                    PUSH_WRITE: begin sp<=sp-8'd1; begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end end
                    PULL_DUMMY: begin
                        sp<=sp+8'd1;
                        if(op==OP_RTS) state<=RTS_LOW;
                        else if(op==OP_RTI) state<=RTI_STATUS;
                        else state<=PULL_READ;
                    end
                    PULL_READ: begin
                        if(op==OP_PLP) begin p<=(bus_data_i&8'hef)|8'h20; begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end end
                        else begin p<=alu_p; if(op==OP_LDX) x<=read_value; else if(op==OP_LDY) y<=read_value; else a<=alu_a; begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end end
                    end
                    RTS_LOW: begin lo<=bus_data_i; sp<=sp+8'd1; state<=RTS_HIGH; end
                    RTS_HIGH: begin pc<={bus_data_i,lo}; state<=RTS_FINISH; end
                    RTS_FINISH: begin pc<=pc+16'd1; begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end end
                    RTI_STATUS: begin p<=(bus_data_i&8'hef)|8'h20; sp<=sp+8'd1; state<=RTI_LOW; end
                    RTI_LOW: begin lo<=bus_data_i; sp<=sp+8'd1; state<=RTI_HIGH; end
                    RTI_HIGH: begin pc<={bus_data_i,lo}; begin state<=FETCH; irq_latched<=!previous_irq && !p[2]; nmi_latched<=nmi_pending; end end
                    INT_DUMMY: state<=INT_HIGH;
                    INT_HIGH: begin sp<=sp-8'd1; state<=INT_LOW; end
                    INT_LOW: begin sp<=sp-8'd1; state<=INT_STATUS; end
                    INT_STATUS: begin
                        sp<=sp-8'd1; p[2]<=1;
                        if(nmi_pending) begin vector_addr<=16'hfffa; nmi_pending<=0; end
                        state<=VECTOR_LOW;
                    end
                    FAULT: state<=FAULT;
                    default: state<=FAULT;
                endcase
            end
            if(previous_so && !so_n) p[6]<=1;
        end
    end
`ifdef FORMAL
    logic f_past_valid=0;
    logic [3:0] f_steps=0, f_remaining;
    // A structural rank strengthens the progress bound for induction. Even
    // impossible opcode/mode combinations must decrease along this graph.
    always_comb begin
        case(state)
            OPERAND: f_remaining=8;
            ZP_INDEX, RESET_0: f_remaining=7;
            PTR_LOW, IMPLIED, INT_DUMMY, RESET_1: f_remaining=6;
            PTR_HIGH, ABS_HIGH, INT_HIGH, RESET_2: f_remaining=5;
            INDEX_DUMMY, JSR_DUMMY, PULL_DUMMY, INT_LOW, RESET_3: f_remaining=4;
            MEM_READ, JSR_HIGH, RTS_LOW, RTI_STATUS, INT_STATUS, RESET_4: f_remaining=3;
            RMW_OLD, BRANCH_DUMMY, JMP_LOW, JSR_LOW, RTS_HIGH, RTI_LOW, VECTOR_LOW: f_remaining=2;
            MEM_WRITE, RMW_NEW, BRANCH_FIX, JMP_HIGH, JSR_FINISH, PUSH_WRITE,
            PULL_READ, RTS_FINISH, RTI_HIGH, VECTOR_HIGH: f_remaining=1;
            default: f_remaining=0;
        endcase
    end
    always_ff @(posedge clk) begin
        f_past_valid<=1;
        if(!rst_n || !res_n || fetch_o || fault_o) f_steps<=0;
        else if(rdy || bus_we) f_steps<=f_steps+4'd1;
        if(f_past_valid && rst_n && $past(rst_n)) begin
            assert({1'b0,f_steps}+{1'b0,f_remaining}<=5'd8);
            assert(f_steps<=8);
            assert(state<=FAULT);
            assert(p[5:4]==2'b10);
            assert(!(fetch_o && bus_we));
            if($past(!rdy && !bus_we && res_n)) assert(state==$past(state));
            cover(fetch_o && pc==16'h8000);
            cover(bus_we && state==RMW_NEW);
            cover(state==INT_STATUS && !interrupt_brk);
        end
    end
`endif
endmodule
