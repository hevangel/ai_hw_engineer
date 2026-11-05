; PDP-1 Am29xx microcode source.
;
; Assembled by scripts/ucasm.py into src/microcode/pdp1_uc.sv (control store).
; Numeric convention: IR[17:13] opcode, IR[12] indirect/group bit,
; IR[11:0] address field; an 18-bit word has bit 17 = sign.
;
; Naming: dest=3 presents the ALU result on Y (visible to glue); dest=2
; presents the A-port value on Y and still writes F, which is what the shift
; network and the memory-write cycles use. src=DA means R=D, S=A.
;
; Every architectural write leaves guard bits 19:18 zero, except the
; intermediate add result whose bit 18 is the end-around carry consumed by
; ADD_FIX.

; Power-up vector: JZ clears the Am2910 stack and jumps to microaddress 0,
; where the reset sequence begins. The store is held at this vector while
; rst_n is low, so the first executed word after release is RESET1.
@org 0x0F8
JZ:         seq=JZ

@org 0x000
RESET1:     a=AC, b=AC, d=ZERO, src=DZ, fn=ADD, cn=0, dest=3, pc_load, imm=0, ov_clr, flag_we, flag_clr, flag_sel=7
RESET2:     a=IO, b=IO, d=ZERO, src=DZ, fn=ADD, cn=0, dest=3

; ---------------------------------------------------------------- fetch
; Fetch is three microinstructions (address, read, decode) and one core
; cycle. The trace pulse marks the instruction start for the oracle diff.
F0:         seq=CJP, cc=SBS_REQ, next=SBS0
F1:         ma_load, d=PC, src=DZ, dest=1
F2:         ir_load, pc_inc, mem=READ, core
F3:         seq=CJP, cc=IR_IND, next=IND0, trace
F4:         seq=JMAP, disp=OP

; -------------------------------------------------------- indirect loop
; Each indirect step is one extra core cycle; the loop repeats while the
; fetched word again has bit 5 set.
IND0:       ma_load, d=ADDR, src=DZ, dest=1, mem=READ, core
IND1:       ir_ind, mem=READ, core
IND2:       seq=CJP, cc=IR_IND, next=IND0
IND3:       seq=JMAP, disp=OP

; -------------------------------------------------------- sequence break
; One-channel break: M[0] <- AC, M[1] <- PC, PC <- 2.
SBS0:       ma_load, d=ZERO, src=DZ, dest=1, mem=WRITE, core
SBS1:       a=AC, b=AC, d=Y, src=ZA, fn=ADD, cn=0, dest=2, mem=WRITE, core
SBS2:       ma_load, d=ONE, src=DZ, dest=1, mem=WRITE, core
SBS3:       a=ZERO, b=TMP1, d=PC, src=DZ, fn=ADD, cn=0, dest=3, mem=WRITE, core
SBS4:       pc_load, d=IMM, imm=2, sbs_vec, src=DZ, dest=1, seq=JMAP, next=F1

; ------------------------------------- end-around-carry repair subroutine
; AC holds the un-repaired sum; bit 18 is the carry out of bit 17. Adding
; one can carry again only when the low 18 bits were all ones, so the loop
; runs at most twice.
ADD_FIX:    a=AC, b=AC, d=ONE, src=DA, fn=ADD, cn=0, dest=3
FIX_TEST:   seq=CJP, cc=EAC, next=ADD_FIX
            seq=CRTN, cc=TRUE

; ------------------------------------------------------------- helpers
SKIP_TAKEN: skip, src=DZ, dest=1, seq=JMAP, next=F0
CLR_OV:     ov_clr, src=DZ, dest=1, seq=CRTN, cc=TRUE
HALT_WAIT:  seq=CJP, cc=HALTED, next=HALT_WAIT
            seq=JMAP, next=F0
ILLEGAL:    illegal, src=DZ, dest=1
ILLEGAL_L:  seq=CJP, cc=TRUE, next=ILLEGAL_L

; Operate-group subroutines.
SUB_CLA:    a=ZERO, b=AC, d=ZERO, src=DZ, fn=ADD, cn=0, dest=3, seq=CRTN, cc=TRUE
SUB_CLI:    a=ZERO, b=IO, d=ZERO, src=DZ, fn=ADD, cn=0, dest=3, seq=CRTN, cc=TRUE
SUB_CMA:    a=AC, b=AC, d=ONES, src=DA, fn=XOR, cn=0, dest=3, seq=CRTN, cc=TRUE
SUB_LAT:    a=AC, b=AC, d=TW, src=DA, fn=OR, cn=0, dest=3, seq=CRTN, cc=TRUE
SUB_FLAGS:  flag_we, flag_dyn, src=DZ, dest=1, seq=CRTN, cc=TRUE
SUB_HALT:   halt, src=DZ, dest=1, seq=JMAP, next=HALT_WAIT

; --------------------------------------------------------------- opcodes
; One eight-word slot per opcode at 0x100 + 8*opcode; the slot jumps to the
; handler in the 16-word block at 0x400 + 16*opcode. Keeping the blocks at a
; fixed stride leaves room for the longer handlers without address math in
; the RTL dispatch ROM.
@org 0x100
SLOT_00:    seq=JMAP, next=ILLEGAL
@org 0x108
SLOT_01:    seq=JMAP, next=H_AND
@org 0x110
SLOT_02:    seq=JMAP, next=H_IOR
@org 0x118
SLOT_03:    seq=JMAP, next=H_XOR
@org 0x120
SLOT_04:    seq=JMAP, next=H_XCT
@org 0x128
SLOT_05:    seq=JMAP, next=ILLEGAL
@org 0x130
SLOT_06:    seq=JMAP, next=ILLEGAL
@org 0x138
SLOT_07:    seq=JMAP, next=H_CAL
@org 0x140
SLOT_10:    seq=JMAP, next=H_LAC
@org 0x148
SLOT_11:    seq=JMAP, next=H_LIO
@org 0x150
SLOT_12:    seq=JMAP, next=H_DAC
@org 0x158
SLOT_13:    seq=JMAP, next=H_DAP
@org 0x160
SLOT_14:    seq=JMAP, next=H_DIP
@org 0x168
SLOT_15:    seq=JMAP, next=H_DIO
@org 0x170
SLOT_16:    seq=JMAP, next=H_DZM
@org 0x178
SLOT_17:    seq=JMAP, next=ILLEGAL
@org 0x180
SLOT_20:    seq=JMAP, next=H_ADD
@org 0x188
SLOT_21:    seq=JMAP, next=H_SUB
@org 0x190
SLOT_22:    seq=JMAP, next=H_IDX
@org 0x198
SLOT_23:    seq=JMAP, next=H_ISP
@org 0x1A0
SLOT_24:    seq=JMAP, next=H_SAD
@org 0x1A8
SLOT_25:    seq=JMAP, next=H_SAS
@org 0x1B0
SLOT_26:    seq=JMAP, next=H_MUS
@org 0x1B8
SLOT_27:    seq=JMAP, next=H_DIS
@org 0x1C0
SLOT_30:    seq=JMAP, next=H_JMP
@org 0x1C8
SLOT_31:    seq=JMAP, next=H_JSP
@org 0x1D0
SLOT_32:    seq=JMAP, next=H_SKP
@org 0x1D8
SLOT_33:    seq=JMAP, next=H_SFT
@org 0x1E0
SLOT_34:    seq=JMAP, next=H_LAW
@org 0x1E8
SLOT_35:    seq=JMAP, next=H_IOT
@org 0x1F0
SLOT_36:    seq=JMAP, next=ILLEGAL
@org 0x1F8
SLOT_37:    seq=JMAP, next=H_OPR

; ------------------------------------------------------ logical handlers
@org 0x401
H_AND:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
            a=AC, b=AC, d=MB, src=DA, fn=AND, cn=0, dest=3, seq=JMAP, next=F0

@org 0x411
H_IOR:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
            a=AC, b=AC, d=MB, src=DA, fn=OR, cn=0, dest=3, seq=JMAP, next=F0

@org 0x421
H_XOR:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
            a=AC, b=AC, d=MB, src=DA, fn=XOR, cn=0, dest=3, seq=JMAP, next=F0

; ------------------------------------------------------------ execute
@org 0x431
H_XCT:      ma_load, d=ADDR, src=DZ, dest=1
            ir_load, mem=READ, core
            seq=CJP, cc=IR_IND, next=IND0
            seq=JMAP, disp=OP, src=DZ, dest=1

; ------------------------------------------------------------- cal/jda
@org 0x451
H_CAL:      seq=CJP, cc=IR_A12, next=H_JDA
            ma_load, imm=0o100, d=IMM, src=DZ, dest=1
            a=AC, b=AC, d=Y, src=ZA, fn=ADD, cn=0, dest=2, mem=WRITE, core
            a=ZERO, b=AC, d=PC, src=DZ, fn=ADD, cn=0, dest=3
            pc_load, d=IMM, imm=0o101, src=DZ, dest=1
            seq=JMAP, next=F0, src=DZ, dest=1
H_JDA:      ma_load, d=ADDR, src=DZ, dest=1
            a=AC, b=AC, d=Y, src=ZA, fn=ADD, cn=0, dest=2, mem=WRITE, core
            a=ZERO, b=AC, d=PC, src=DZ, fn=ADD, cn=0, dest=3
            pc_load, d=ADDR1, src=DZ, dest=1
            seq=JMAP, next=F0, src=DZ, dest=1

; ------------------------------------------------------- load/store
@org 0x481
H_LAC:      ma_load, d=ADDR, src=DZ, dest=1
            a=ZERO, b=AC, d=MEM, src=DZ, fn=ADD, cn=0, dest=3, mem=READ, core, seq=JMAP, next=F0

@org 0x491
H_LIO:      ma_load, d=ADDR, src=DZ, dest=1
            a=ZERO, b=IO, d=MEM, src=DZ, fn=ADD, cn=0, dest=3, mem=READ, core, seq=JMAP, next=F0

@org 0x4A1
H_DAC:      ma_load, d=ADDR, src=DZ, dest=1
            a=AC, b=AC, d=Y, src=ZA, fn=ADD, cn=0, dest=2, mem=WRITE, core
            seq=JMAP, next=F0, src=DZ, dest=1

; DAP: M[Y]<11:0> <- AC<11:0>, other bits of M[Y] unchanged.
@org 0x4B1
H_DAP:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
            a=ZERO, b=TMP1, d=MB, src=DZ, fn=ADD, cn=0, dest=3
            a=AC, b=TMP0, d=IMM, imm=0o7777, src=DA, fn=AND, cn=0, dest=3
            a=TMP1, b=TMP1, d=IMM, imm=0o777700, src=DA, fn=AND, cn=0, dest=3
            a=TMP0, b=TMP1, src=AB, fn=OR, cn=0, dest=3
            a=TMP1, b=TMP1, d=Y, src=ZA, fn=ADD, cn=0, dest=2, mem=WRITE, core
            seq=JMAP, next=F0, src=DZ, dest=1

; DIP: M[Y]<17:12> <- AC<17:12>, other bits unchanged.
@org 0x4C1
H_DIP:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
            a=ZERO, b=TMP1, d=MB, src=DZ, fn=ADD, cn=0, dest=3
            a=AC, b=TMP0, d=IMM, imm=0o777700, src=DA, fn=AND, cn=0, dest=3
            a=TMP1, b=TMP1, d=IMM, imm=0o7777, src=DA, fn=AND, cn=0, dest=3
            a=TMP0, b=TMP1, src=AB, fn=OR, cn=0, dest=3
            a=TMP1, b=TMP1, d=Y, src=ZA, fn=ADD, cn=0, dest=2, mem=WRITE, core
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x4D1
H_DIO:      ma_load, d=ADDR, src=DZ, dest=1
            a=IO, b=IO, d=Y, src=ZA, fn=ADD, cn=0, dest=2, mem=WRITE, core
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x4E1
H_DZM:      ma_load, d=ADDR, src=DZ, dest=1
            a=ZERO, b=TMP1, d=Y, src=ZA, fn=ADD, cn=0, dest=2, mem=WRITE, core
            seq=JMAP, next=F0, src=DZ, dest=1

; ---------------------------------------------------------- arithmetic
@org 0x501
H_ADD:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
            a=AC, b=AC, d=MB, src=DA, fn=ADD, cn=0, dest=3, ov_upd, seq=CJS, cc=EAC, next=ADD_FIX
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x511
H_SUB:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
            a=AC, b=AC, d=MB, src=DA, fn=SUB, cn=0, dest=3, ov_upd, seq=CJS, cc=EAC, next=ADD_FIX
            seq=JMAP, next=F0, src=DZ, dest=1

; IDX: M[Y] <- M[Y]+1, AC <- M[Y]+1. No overflow indication.
@org 0x521
H_IDX:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
            a=ZERO, b=AC, d=MB, src=DA, fn=ADD, cn=1, dest=3, seq=CJS, cc=EAC, next=ADD_FIX
            a=AC, b=AC, d=Y, src=ZA, fn=ADD, cn=0, dest=2, mem=WRITE, core
            seq=JMAP, next=F0, src=DZ, dest=1

; ISP: same, plus skip when the result is non-negative.
@org 0x531
H_ISP:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
            a=ZERO, b=AC, d=MB, src=DA, fn=ADD, cn=1, dest=3, seq=CJS, cc=EAC, next=ADD_FIX
            a=AC, b=AC, d=Y, src=ZA, fn=ADD, cn=0, dest=2, mem=WRITE, core, seq=CJP, cc=AC_SIGN, cc_inv, next=SKIP_TAKEN
            seq=JMAP, next=F0, src=DZ, dest=1

; SAD / SAS compare with XOR; the ALU zero flag is the equality test.
@org 0x541
H_SAD:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
            a=AC, b=TMP1, d=MB, src=DA, fn=XOR, cn=0, dest=1, seq=CJP, cc=RESULT_ZERO, cc_inv, next=SKIP_TAKEN
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x551
H_SAS:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
            a=AC, b=TMP1, d=MB, src=DA, fn=XOR, cn=0, dest=1, seq=CJP, cc=RESULT_ZERO, next=SKIP_TAKEN
            seq=JMAP, next=F0, src=DZ, dest=1

; MUS: if IO<17> (numeric bit 0) then AC <- AC + M[Y]; then AC'IO >> 1 with
; AC's sign cleared. One place per microcode iteration.
@org 0x561
H_MUS:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
            seq=CJP, cc=IO_LSB, next=MUS_ADD
            seq=JMAP, next=MUS_SHIFT
MUS_ADD:    a=AC, b=AC, d=MB, src=DA, fn=ADD, cn=0, dest=3, ov_upd, seq=CJS, cc=EAC, next=ADD_FIX
            seq=JMAP, next=MUS_SHIFT
MUS_SHIFT:  a=AC, b=AC, d=Y, src=ZA, fn=ADD, cn=0, dest=2, shf=RIGHT, cap=A
            a=IO, b=IO, d=SHF, shf=RIGHT, fill=EXT_A, src=DZ, fn=ADD, cn=0, dest=2
            a=AC, b=AC, d=SHF, shf=RIGHT, fill=ZERO, src=DZ, fn=ADD, cn=0, dest=2
            seq=JMAP, next=F0

; DIS: rotate AC'IO left one; IO<17> <- ~AC<0>; then subtract or add M[Y]+1.
@org 0x571
H_DIS:      ma_load, d=ADDR, src=DZ, dest=1
            mb_load, mem=READ, core
DIS_INIT:   a=AC, b=AC, d=Y, src=ZA, fn=ADD, cn=0, dest=2, shf=LEFT, cap=A
DIS_INIT_B: a=IO, b=IO, d=Y, src=ZA, fn=ADD, cn=0, dest=2, shf=LEFT, cap=B
            a=IO, b=IO, d=SHF, shf=LEFT, fill=EXT_A, src=DZ, fn=ADD, cn=0, dest=2
            a=AC, b=AC, d=SHF, shf=LEFT, fill=EXT_B, src=DZ, fn=ADD, cn=0, dest=2
            a=IO, b=IO, d=ONE, src=DA, fn=XOR, cn=0, dest=3
            seq=CJP, cc=IO_LSB, next=DIS_SUB
            a=AC, b=AC, d=MB, src=DA, fn=ADD, cn=1, dest=3, ov_upd, seq=CJS, cc=EAC, next=ADD_FIX
            seq=JMAP, next=F0, src=DZ, dest=1
DIS_SUB:    a=AC, b=AC, d=MB, src=DA, fn=SUB, cn=0, dest=3, ov_upd, seq=CJS, cc=EAC, next=ADD_FIX
            seq=JMAP, next=F0, src=DZ, dest=1

; ---------------------------------------------------------------- jumps
@org 0x581
H_JMP:      pc_load, d=ADDR, src=DZ, dest=1, seq=JMAP, next=F0

@org 0x591
H_JSP:      a=ZERO, b=AC, d=PC, src=DZ, fn=ADD, cn=0, dest=3
            pc_load, d=ADDR, src=DZ, dest=1, seq=JMAP, next=F0

; ---------------------------------------------------------- skip group
@org 0x5A1
H_SKP:      seq=CJS, cc=IR_A9, next=CLR_OV
            seq=CJP, cc=SKIP_ANY, next=SKIP_TAKEN
            seq=JMAP, next=F0, src=DZ, dest=1

; -------------------------------------------------------- shift / rotate
@org 0x5B1
H_SFT:      nfc_load, src=DZ, dest=1
            seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, disp=OPX, src=DZ, dest=1

; ---------------------------------------------------------------- law
@org 0x5C1
H_LAW:      seq=CJP, cc=IR_IND, next=LAW_NEG
            a=ZERO, b=AC, d=ADDR, src=DZ, fn=ADD, cn=0, dest=3, seq=JMAP, next=F0
LAW_NEG:    a=ZERO, b=AC, d=ADDR, d_inv, src=DZ, fn=ADD, cn=0, dest=3, seq=JMAP, next=F0

; ----------------------------------------------------------------- iot
; The device field selects a four-word handler in the 0x200 block.
@org 0x5D1
H_IOT:      seq=JMAP, disp=DEV, src=DZ, dest=1

; ------------------------------------------------------------- operate
; Order follows the handbook example (cla + lat + cma = 3200): clear the
; accumulator, load the test word, then complement.
@org 0x5E1
H_OPR:      seq=CJS, cc=IR_A7, next=SUB_CLA
            seq=CJS, cc=IR_A10, next=SUB_LAT
            seq=CJS, cc=IR_A9, next=SUB_CMA
            seq=CJS, cc=IR_A11, next=SUB_CLI
            seq=CJS, cc=IR_A3, next=SUB_FLAGS
            seq=CJS, cc=IR_A8, next=SUB_HALT
            seq=JMAP, next=F0, src=DZ, dest=1

; ------------------------------------------------------ shift subcode block
; 8 words per subcode at 0x300 + 8*subcode. The counter is decremented by
; its own microinstruction and tested by the next one, so a step is never
; repeated when the count reaches zero.
@org 0x300
            illegal, src=DZ, dest=1                 ; subcode 0 (invalid)
            seq=JMAP, next=ILLEGAL

@org 0x308
; RAL: rotate AC left
SFT_RAL:    a=AC, b=AC, d=SHF, shf=LEFT, fill=ROT, src=DZ, fn=ADD, cn=0, dest=2, nfc_dec
SFT_RAL_T:  seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, next=SFT_RAL, src=DZ, dest=1

@org 0x310
; RIL: rotate IO left
SFT_RIL:    a=IO, b=IO, d=SHF, shf=LEFT, fill=ROT, src=DZ, fn=ADD, cn=0, dest=2, nfc_dec
SFT_RIL_T:  seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, next=SFT_RIL, src=DZ, dest=1

@org 0x318
; RCL: rotate AC'IO left. IO phase first, then AC, each consuming the edge
; captured from the other register.
SFT_RCL:    a=AC, b=AC, d=Y, src=ZA, fn=ADD, cn=0, dest=2, shf=LEFT, cap=A
SFT_RCL_B:  a=IO, b=IO, d=Y, src=ZA, fn=ADD, cn=0, dest=2, shf=LEFT, cap=B
SFT_RCL_IO: a=IO, b=IO, d=SHF, shf=LEFT, fill=EXT_A, src=DZ, fn=ADD, cn=0, dest=2
SFT_RCL_AC: a=AC, b=AC, d=SHF, shf=LEFT, fill=EXT_B, src=DZ, fn=ADD, cn=0, dest=2, nfc_dec
SFT_RCL_T:  seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, next=SFT_RCL, src=DZ, dest=1

@org 0x328
; SAL: shift AC left, sign preserved
SFT_SAL:    a=AC, b=AC, d=SHF, shf=LEFT, fill=SIGN, shf_sign, src=DZ, fn=ADD, cn=0, dest=2, nfc_dec
SFT_SAL_T:  seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, next=SFT_SAL, src=DZ, dest=1

@org 0x330
; SIL: shift IO left, sign preserved
SFT_SIL:    a=IO, b=IO, d=SHF, shf=LEFT, fill=SIGN, shf_sign, src=DZ, fn=ADD, cn=0, dest=2, nfc_dec
SFT_SIL_T:  seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, next=SFT_SIL, src=DZ, dest=1

@org 0x338
; SCL: arithmetic shift AC'IO left
SFT_SCL:    a=AC, b=AC, d=Y, src=ZA, fn=ADD, cn=0, dest=2, shf=LEFT, cap=A
SFT_SCL_B:  a=IO, b=IO, d=Y, src=ZA, fn=ADD, cn=0, dest=2, shf=LEFT, cap=B
SFT_SCL_IO: a=IO, b=IO, d=SHF, shf=LEFT, fill=EXT_A, src=DZ, fn=ADD, cn=0, dest=2
SFT_SCL_AC: a=AC, b=AC, d=SHF, shf=LEFT, fill=EXT_B, shf_sign, src=DZ, fn=ADD, cn=0, dest=2, nfc_dec
SFT_SCL_T:  seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, next=SFT_SCL, src=DZ, dest=1

@org 0x348
; RAR: rotate AC right
SFT_RAR:    a=AC, b=AC, d=SHF, shf=RIGHT, fill=ROT, src=DZ, fn=ADD, cn=0, dest=2, nfc_dec
SFT_RAR_T:  seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, next=SFT_RAR, src=DZ, dest=1

@org 0x350
; RIR: rotate IO right
SFT_RIR:    a=IO, b=IO, d=SHF, shf=RIGHT, fill=ROT, src=DZ, fn=ADD, cn=0, dest=2, nfc_dec
SFT_RIR_T:  seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, next=SFT_RIR, src=DZ, dest=1

@org 0x358
; RCR: rotate AC'IO right
SFT_RCR:    a=AC, b=AC, d=Y, src=ZA, fn=ADD, cn=0, dest=2, shf=RIGHT, cap=A
SFT_RCR_B:  a=IO, b=IO, d=Y, src=ZA, fn=ADD, cn=0, dest=2, shf=RIGHT, cap=B
SFT_RCR_IO: a=IO, b=IO, d=SHF, shf=RIGHT, fill=EXT_A, src=DZ, fn=ADD, cn=0, dest=2
SFT_RCR_AC: a=AC, b=AC, d=SHF, shf=RIGHT, fill=EXT_B, src=DZ, fn=ADD, cn=0, dest=2, nfc_dec
SFT_RCR_T:  seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, next=SFT_RCR, src=DZ, dest=1

@org 0x368
; SAR: shift AC right, sign fill
SFT_SAR:    a=AC, b=AC, d=SHF, shf=RIGHT, fill=SIGN, src=DZ, fn=ADD, cn=0, dest=2, nfc_dec
SFT_SAR_T:  seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, next=SFT_SAR, src=DZ, dest=1

@org 0x370
; SIR: shift IO right, sign fill
SFT_SIR:    a=IO, b=IO, d=SHF, shf=RIGHT, fill=SIGN, src=DZ, fn=ADD, cn=0, dest=2, nfc_dec
SFT_SIR_T:  seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, next=SFT_SIR, src=DZ, dest=1

@org 0x378
; SCR: arithmetic shift AC'IO right
SFT_SCR:    a=AC, b=AC, d=Y, src=ZA, fn=ADD, cn=0, dest=2, shf=RIGHT, cap=A
SFT_SCR_B:  a=IO, b=IO, d=Y, src=ZA, fn=ADD, cn=0, dest=2, shf=RIGHT, cap=B
SFT_SCR_IO: a=IO, b=IO, d=SHF, shf=RIGHT, fill=EXT_A, src=DZ, fn=ADD, cn=0, dest=2
SFT_SCR_AC: a=AC, b=AC, d=SHF, shf=RIGHT, fill=SIGN, src=DZ, fn=ADD, cn=0, dest=2, nfc_dec
SFT_SCR_T:  seq=CJP, cc=NFC_ZERO, next=F0
            seq=JMAP, next=SFT_SCR, src=DZ, dest=1

; --------------------------------------------------------- I/O devices
; Four words per device at 0x200 + 4*device. Input handlers wait for the
; host bridge; every handler ends by returning to fetch.
@org 0x200
IO_WAIT:    seq=JMAP, next=F0, src=DZ, dest=1                 ; device 00

@org 0x204
IO_RDR:     seq=CJP, cc=IO_READY, cc_inv, next=IO_RDR         ; device 01
            io_strobe, src=DZ, dest=1
            a=ZERO, b=IO, d=DEVDATA, src=DZ, fn=ADD, cn=0, dest=3
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x208
IO_RDR2:    seq=CJP, cc=IO_READY, cc_inv, next=IO_RDR2        ; device 02
            io_strobe, src=DZ, dest=1
            a=ZERO, b=IO, d=DEVDATA, src=DZ, fn=ADD, cn=0, dest=3
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x20C
IO_TTO:     io_strobe, src=DZ, dest=1                         ; device 03
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x210
IO_TTI:     seq=CJP, cc=IO_READY, cc_inv, next=IO_TTI         ; device 04
            io_strobe, src=DZ, dest=1
            a=ZERO, b=IO, d=DEVDATA, src=DZ, fn=ADD, cn=0, dest=3
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x214
IO_PTP:     io_strobe, src=DZ, dest=1                         ; device 05
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x218
IO_PTP2:    io_strobe, src=DZ, dest=1                         ; device 06
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x21C
IO_DPY:     io_strobe, src=DZ, dest=1                         ; device 07
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x224
IO_CTL:     io_strobe, src=DZ, dest=1                         ; device 011
            a=ZERO, b=IO, d=DEVDATA, src=DZ, fn=ADD, cn=0, dest=3
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x260
IO_RRB:     seq=CJP, cc=IO_READY, cc_inv, next=IO_RRB         ; device 030
            io_strobe, src=DZ, dest=1
            a=ZERO, b=IO, d=DEVDATA, src=DZ, fn=ADD, cn=0, dest=3
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x26C
IO_STA:     io_strobe, src=DZ, dest=1                         ; device 033
            a=ZERO, b=IO, d=DEVDATA, src=DZ, fn=ADD, cn=0, dest=3
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x2B0
IO_LSM:     io_strobe, src=DZ, dest=1                         ; device 054
            seq=JMAP, next=F0, src=DZ, dest=1

@org 0x2B4
IO_ESM:     io_strobe, src=DZ, dest=1                         ; device 055
            seq=JMAP, next=F0, src=DZ, dest=1
