; PDP-8 / Am29xx microcode.
;
; One microinstruction per clock.  Fields are decoded by pdp8_cpu.sv; see
; scripts/gen_microcode.py for the encoding.  The Am2910 selects the next
; microinstruction; `jmp` is an unconditional CJP, `cjs`/`rtn` use the
; five-entry return stack.
;
; Register map in the three Am2901 slices: ac = R0, tmp = R1, tmp2 = R2.
; PC, MA, MB, IR, L and the switch register are external 12-bit registers.
;
; Every instruction ends by jumping to HALTLOOP, which re-tests the run
; request and the interrupt request at the instruction boundary.

; ---------------------------------------------------------------- boundary
HALTLOOP:   cjp clr, CLR
            cjp go, FETCH
SPIN:       jmp HALTLOOP

FETCH:      cjp irq, IRQ  retire ra=ac dest=none alf=or src=a
; Re-test the run request after the boundary so STOP and single-step take
; effect at the instruction just completed, not one instruction later.
F_CHK:      cjp go, F_MA
            jmp HALTLOOP
F_MA:       ma_ld dsel=pc src=d alf=add pg_ld mem_rd rdsel=y
F_INC:      pc_ld dsel=pc cin=1 src=d ir_ld
            cjp ir11, D1XX
            cjp ir10, D01X
            cjp ir9, TAD

; ------------------------------------------------------- memory reference
AND:        cjs FEA
            ra=ac rb=ac dest=rb dsel=mb src=da alf=and
            jmp HALTLOOP

TAD:        cjs FEA
            ; 13-bit TAD: the link is bit 12 of the sum, so the carry into the
            ; accumulator is zero and the link is exclusive-ored with the carry out.
            ra=ac rb=ac dest=rb dsel=mb src=da alf=add lop=xor
            jmp HALTLOOP

D01X:       cjp ir9, DCA
ISZ:        cjs FEA
            dest=none dsel=mb src=d alf=add cin=1 mem_wr cjp zero, ISZ_SKIP
            jmp HALTLOOP
ISZ_SKIP:   pc_ld dsel=pc cin=1 src=d
            jmp HALTLOOP

DCA:        cjs FEA
            ra=ac dest=none alf=or src=a mem_wr
            ra=ac rb=ac dest=rb dsel=zero src=d alf=add
            jmp HALTLOOP

D1XX:       cjp ir10, D11X
            cjp ir9, JMP
JMS:        cjs FEAA
            dsel=pc src=d alf=add mem_wr
            pc_ld dsel=ma cin=1 src=d
            jmp HALTLOOP
JMP:        cjs FEAA
            pc_ld dsel=ma src=d
            jmp HALTLOOP

; --------------------------------------------------------------- I/O transfer
D11X:       cjp ir9, OPR
IOT:        ra=ac dest=none alf=or src=a iot_ph=strobe
IOT_D:      iot_ph=data cjp iskip, IOT_SKIP
            jmp HALTLOOP
IOT_SKIP:   pc_ld dsel=pc cin=1 src=d
            jmp HALTLOOP

; ------------------------------------------------------------ operate group 1
OPR:        cjp ir8, G23
G1_CLA:     ra=ac rb=ac dest=rb dsel=zero src=d alf=add acmask=ir8 lop=clr lmask=ir6
G1_CMA:     ra=ac rb=ac dest=rb alf=xnor src=a acmask=ir5 lop=cml lmask=ir4
G1_IAC:     ra=ac rb=ac dest=rb alf=add src=a cin=1 acmask=ir0 lop=xor lmask=ir0
G1_SH:      ra=ac rb=ac dest=shr sh_ir src=a alf=or acmask=rot lop=shift lmask=rot
            cjp ir1, G1_SH2
            jmp HALTLOOP
G1_SH2:     ra=ac rb=ac dest=shr sh_ir src=a alf=or acmask=rot lop=shift lmask=rot
            jmp HALTLOOP

; ------------------------------------------------------------ operate group 2
G23:        cjp ir0, G3
G2_TST:     ra=ac dest=none alf=or src=a cjp g2, G2_SKIP
            jmp G2_CLA
G2_SKIP:    pc_ld dsel=pc cin=1 src=d
G2_CLA:     ra=ac rb=ac dest=rb dsel=zero src=d alf=add acmask=ir8
G2_OSR:     ra=ac rb=ac dest=rb dsel=sr alf=or src=da acmask=ir2
G2_HLT:     halt
            jmp HALTLOOP

; --------------------------------------------- operate group 3 (EAE absent)
G3:         jmp HALTLOOP

; ------------------------------------------------------------- subroutines
; Effective address and operand fetch for AND/TAD/ISZ/DCA.
; Returns with MA = effective address and MB = operand.
FEA:        ma_ld ma_sel=1 mem_rd rdsel=ea
            cjp ir8, FEA_IND
            mb_ld
            rtn al
FEA_IND:    mb_ld
            cjp ai, FEA_AI
            ma_ld dsel=mb src=d mem_rd rdsel=y
            jmp FEA_RD2
FEA_AI:     ma_ld dsel=mb src=d cin=1 alf=add mem_wr mem_rd rdsel=y
FEA_RD2:    mb_ld
            rtn al

; Effective address only, for JMS/JMP.  Returns with MA = the target and
; MB = the final indirect word (auto-indexed when applicable).
FEAA:       ma_ld ma_sel=1 mem_rd rdsel=ea
            cjp ir8, FEAA_IND
            mb_ld
            rtn al
FEAA_IND:   mb_ld
            cjp ai, FEAA_AI
            ma_ld dsel=mb src=d
            rtn al
FEAA_AI:    ma_ld dsel=mb src=d cin=1 alf=add mem_wr
            rtn al

; --------------------------------------------------------------- interrupt
; Vector through location zero, clearing the interrupt enable.
IRQ:        ma_ld dsel=zero src=d alf=add
IRQ_W:      dsel=pc src=d alf=add mem_wr
IRQ_PC:     pc_ld dsel=one src=d iof
            jmp HALTLOOP

; ------------------------------------------------------------ master clear
; START loads the accumulator, link and interrupt enable with zero, as the
; front-panel master clear does on the original machine.
CLR:        ra=ac rb=ac dest=rb dsel=zero src=d alf=add acmask=al lop=clr lmask=al iof clr_ack
            jmp HALTLOOP
