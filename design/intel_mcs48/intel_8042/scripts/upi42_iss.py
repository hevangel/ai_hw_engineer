"""Instruction-set reference model of the Intel 8042 (UPI-42).

Independent oracle for the RTL. Every semantic rule below is taken from the
Intel UPI-41A User's Manual (order 9800504-02B, April 1980), chapter 2
(functional description) and chapter 3 (instruction set, Table 3-2 and the
alphabetic listing), or from the 8742 data sheet (order 290256-001, Nov 1991)
for the 2K/128-byte 8042 sizes. Where neither document states a behavior, the
rule is tagged ``ASSUMPTION Ux`` and listed in spec/spec.md; the RTL carries
the same tag. This file must never be updated by reading the RTL.

Granularity: one call to step() executes one instruction (or one interrupt
vector) and advances the timer by that instruction's machine cycles.
Host-bus accesses and pin changes are applied between instructions.
"""

from dataclasses import dataclass, field

ROM_SIZE = 2048          # 8742 data sheet: 2048 x 8
RAM_SIZE = 128           # 8742 data sheet: 128 x 8
PC_MASK = ROM_SIZE - 1


@dataclass
class Retire:
    """Architectural record of one executed instruction or interrupt."""
    pc: int
    opcode: int
    operand: int | None
    cycles: int
    kind: str            # 'insn', 'irq3', 'irq7'
    mnemonic: str
    illegal: bool = False


@dataclass
class UPI42:
    rom: bytes
    ram: list = field(default_factory=lambda: [0] * RAM_SIZE)
    a: int = 0
    pc: int = 0
    # PSW (manual Figure 2-8): CY AC F0 BS 1 S2 S1 S0
    cy: int = 0
    ac: int = 0
    f0: int = 0
    bs: int = 0
    sp: int = 0
    # Status register (manual p.2-14): ST7-4 F1 F0 IBF OBF
    f1: int = 0
    ibf: int = 0
    obf: int = 0
    st_hi: int = 0       # ST7..ST4 in bits 7..4
    dbbin: int = 0
    dbbout: int = 0
    # Ports: output latches; pins are latch AND external pull-down
    p1: int = 0xFF
    p2: int = 0xFF
    p1_ext: int = 0xFF   # external drive (1 = released, 0 = pulled low)
    p2_ext: int = 0xFF
    t0: int = 1
    t1: int = 1
    t1_prev: int = 1
    # Timer/counter (manual p.2-9/2-10)
    t: int = 0
    prescale: int = 0
    tmode: str = 'stop'  # 'stop', 'timer', 'counter'
    tf: int = 0
    tie: int = 0         # EN TCNTI
    tirq: int = 0        # latched timer interrupt request
    ie: int = 0          # EN I
    ibf_irq: int = 0     # latched IBF interrupt request
    in_irq: int = 0      # interrupt in progress (single level)
    flags_en: int = 0    # EN FLAGS
    dma_en: int = 0      # EN DMA
    cycles: int = 0
    illegal_count: int = 0

    def __post_init__(self):
        if len(self.rom) != ROM_SIZE:
            raise ValueError('8042 ROM must be 2048 bytes')

    # ----------------------------------------------------------- reset
    def reset(self):
        """Manual p.2-12: PC=0, SP=0, bank 0, ports input mode, interrupts
        disabled, timer stopped, TF clear, F0/F1 clear; status flags clear
        (p.2-14). A, RAM and the timer count are not changed (p.2-9 says the
        counter is not cleared by RESET). ASSUMPTION U1: EN FLAGS / EN DMA
        are cancelled only by RESET (p.2-12), so RESET clears them; CY/AC
        are cleared with the rest of the PSW."""
        self.pc = 0
        self.sp = 0
        self.bs = 0
        self.cy = self.ac = self.f0 = 0
        self.f1 = self.ibf = self.obf = 0
        self.st_hi = 0
        self.p1 = self.p2 = 0xFF
        self.ie = self.tie = 0
        self.tirq = self.ibf_irq = self.in_irq = 0
        self.tmode = 'stop'
        self.tf = 0
        self.prescale = 0
        self.flags_en = self.dma_en = 0

    # ------------------------------------------------------- host side
    def status(self):
        return (self.st_hi & 0xF0) | (self.f1 << 3) | (self.f0 << 2) | \
            (self.ibf << 1) | self.obf

    def host_write(self, a0, data):
        """WR with CS: data to DBBIN, IBF=1, F1=A0, IBF interrupt request
        latched regardless of EN I (manual p.2-11, 2-14)."""
        self.dbbin = data & 0xFF
        self.ibf = 1
        self.f1 = a0 & 1
        self.ibf_irq = 1

    def host_read(self, a0):
        """RD with CS: A0=1 status, A0=0 DBBOUT and clear OBF."""
        if a0:
            return self.status()
        self.obf = 0
        return self.dbbout

    # ----------------------------------------------------------- pins
    def p1_pins(self):
        return self.p1 & self.p1_ext

    def p2_out(self):
        """Port 2 as driven by the chip. EN FLAGS routes OBF to P24 and
        inverted IBF to P25, each gated by its latch bit (data sheet p.4,
        manual p.2-12)."""
        v = self.p2
        if self.flags_en:
            v = (v & ~0x30) | ((self.p2 & 0x10) & (self.obf << 4)) | \
                ((self.p2 & 0x20) & ((self.ibf ^ 1) << 5))
        return v & 0xFF

    def p2_pins(self):
        return self.p2_out() & self.p2_ext

    # -------------------------------------------------------- helpers
    def psw(self):
        # ASSUMPTION U2: PSW bit 3 ("not used", manual p.2-7) reads as 1.
        return (self.cy << 7) | (self.ac << 6) | (self.f0 << 5) | \
            (self.bs << 4) | 0x08 | self.sp

    def set_psw(self, v):
        self.cy = (v >> 7) & 1
        self.ac = (v >> 6) & 1
        self.f0 = (v >> 5) & 1
        self.bs = (v >> 4) & 1
        self.sp = v & 7

    def reg_addr(self, r):
        return (24 if self.bs else 0) + r

    def get_r(self, r):
        return self.ram[self.reg_addr(r)]

    def set_r(self, r, v):
        self.ram[self.reg_addr(r)] = v & 0xFF

    def ind_addr(self, r):
        # ASSUMPTION U3: @Rr uses bits 0-6 for the 8042's 128-byte RAM
        # (the 41A manual says bits 0-5 for its 64 bytes).
        return self.get_r(r) & (RAM_SIZE - 1)

    def fetch(self):
        b = self.rom[self.pc]
        # ASSUMPTION U4: the 11-bit PC wraps from 7FFh to 000h.
        self.pc = (self.pc + 1) & PC_MASK
        return b

    def push(self):
        """Manual Figure 2-7: low byte PC(0-7) at 8+2*SP, high byte
        PSW(4-7):PC(8-10) at 9+2*SP; SP increments modulo 8."""
        base = 8 + 2 * self.sp
        self.ram[base] = self.pc & 0xFF
        self.ram[base + 1] = (self.psw() & 0xF0) | ((self.pc >> 8) & 0x0F)
        self.sp = (self.sp + 1) & 7

    def pop(self, restore_psw):
        self.sp = (self.sp - 1) & 7
        base = 8 + 2 * self.sp
        lo = self.ram[base]
        hi = self.ram[base + 1]
        self.pc = ((hi & 0x07) << 8) | lo
        if restore_psw:
            self.cy = (hi >> 7) & 1
            self.ac = (hi >> 6) & 1
            self.f0 = (hi >> 5) & 1
            self.bs = (hi >> 4) & 1

    def add(self, v, carry_in):
        s = self.a + v + carry_in
        self.ac = 1 if ((self.a & 0x0F) + (v & 0x0F) + carry_in) > 0x0F else 0
        self.cy = 1 if s > 0xFF else 0
        self.a = s & 0xFF

    def page_jump(self, operand_addr, target):
        """Conditional jumps replace PC(0-7). ASSUMPTION U5: the page is the
        page of the operand byte (manual p.3-11 note: a DJNZ starting at
        location 255 jumps within the following page)."""
        self.pc = (operand_addr & 0x700) | target

    def tick(self, n):
        """Advance the timer/counter by n machine cycles. Manual p.2-9: the
        timer input is machine cycle / 32; overflow FFh->00h sets TF and,
        when EN TCNTI, latches a timer interrupt request (DIS TCNTI p.3-11:
        overflow does not initiate the interrupt when disabled).
        ASSUMPTION U6: the cycles of an instruction tick with the mode in
        effect before that instruction; the instruction's own effects
        (MOV T,A, STRT, STOP) apply after its cycles.
        ASSUMPTION U7: in counter mode one count per T1 high-to-low
        transition observed between instructions (the model samples T1 at
        instruction boundaries)."""
        for _ in range(n):
            self.cycles += 1
            if self.tmode == 'timer':
                self.prescale += 1
                if self.prescale == 32:
                    self.prescale = 0
                    self._inc_t()

    def counter_edge(self):
        if self.tmode == 'counter' and self.t1_prev == 1 and self.t1 == 0:
            self._inc_t()
        self.t1_prev = self.t1

    def _inc_t(self):
        self.t = (self.t + 1) & 0xFF
        if self.t == 0:
            self.tf = 1
            if self.tie:
                self.tirq = 1

    # ------------------------------------------------------------ step
    def step(self):
        self.counter_edge()
        # Interrupt recognition between instructions (manual p.2-11/2-12):
        # single level, IBF has priority over timer.
        if not self.in_irq:
            if self.ie and self.ibf_irq:
                return self._vector(3)
            if self.tie and self.tirq:
                return self._vector(7)
        start = self.pc
        op = self.fetch()
        rec = self._execute(start, op)
        return rec

    def _vector(self, addr):
        start = self.pc
        if addr == 3:
            self.ibf_irq = 0      # cleared on entering the service routine
        else:
            self.tirq = 0         # reset by initiating the timer routine
        self.in_irq = 1
        self.push()
        self.pc = addr
        # ASSUMPTION U8: the forced CALL costs 2 machine cycles, like CALL.
        self.tick(2)
        return Retire(start, -1, None, 2, 'irq%d' % addr, 'IRQ $%04X' % addr)

    def _execute(self, start, op):
        hi, lo = op >> 4, op & 0x0F
        r = op & 7
        ri = op & 1
        operand = None
        mn = None
        cyc = 1
        illegal = False
        pending = []          # effects applied after the timer ticks

        def imm():
            nonlocal operand, cyc
            operand_addr = self.pc
            operand = self.fetch()
            cyc = 2
            return operand, operand_addr

        a = self.a
        # ---- accumulator group, register forms (x8-xF) and @R (x0/x1)
        if lo >= 8 and hi in (0x6, 0x7, 0x5, 0x4, 0xD):
            v = self.get_r(r)
            name = {0x6: 'ADD', 0x7: 'ADDC', 0x5: 'ANL', 0x4: 'ORL', 0xD: 'XRL'}[hi]
            mn = '%s A,R%d' % (name, r)
            pending.append(lambda: self._alu(hi, v))
        elif lo in (0, 1) and hi in (0x6, 0x7, 0x5, 0x4, 0xD):
            v = self.ram[self.ind_addr(ri)]
            name = {0x6: 'ADD', 0x7: 'ADDC', 0x5: 'ANL', 0x4: 'ORL', 0xD: 'XRL'}[hi]
            mn = '%s A,@R%d' % (name, ri)
            pending.append(lambda: self._alu(hi, v))
        elif op in (0x03, 0x13, 0x53, 0x43, 0xD3):
            d, _ = imm()
            k = {0x03: 0x6, 0x13: 0x7, 0x53: 0x5, 0x43: 0x4, 0xD3: 0xD}[op]
            name = {0x6: 'ADD', 0x7: 'ADDC', 0x5: 'ANL', 0x4: 'ORL', 0xD: 'XRL'}[k]
            mn = '%s A,#$%02X' % (name, d)
            pending.append(lambda: self._alu(k, d))
        elif op == 0x17:
            mn = 'INC A'; pending.append(lambda: setattr(self, 'a', (a + 1) & 0xFF))
        elif op == 0x07:
            mn = 'DEC A'; pending.append(lambda: setattr(self, 'a', (a - 1) & 0xFF))
        elif op == 0x27:
            mn = 'CLR A'; pending.append(lambda: setattr(self, 'a', 0))
        elif op == 0x37:
            mn = 'CPL A'; pending.append(lambda: setattr(self, 'a', a ^ 0xFF))
        elif op == 0x57:
            mn = 'DA A'; pending.append(self._da)
        elif op == 0x47:
            mn = 'SWAP A'; pending.append(lambda: setattr(self, 'a', ((a << 4) | (a >> 4)) & 0xFF))
        elif op == 0xE7:
            mn = 'RL A'; pending.append(lambda: setattr(self, 'a', ((a << 1) | (a >> 7)) & 0xFF))
        elif op == 0xF7:
            mn = 'RLC A'
            def rlc():
                c = self.cy
                self.cy = a >> 7
                self.a = ((a << 1) | c) & 0xFF
            pending.append(rlc)
        elif op == 0x77:
            mn = 'RR A'; pending.append(lambda: setattr(self, 'a', ((a >> 1) | (a << 7)) & 0xFF))
        elif op == 0x67:
            mn = 'RRC A'
            def rrc():
                c = self.cy
                self.cy = a & 1
                self.a = (a >> 1) | (c << 7)
            pending.append(rrc)
        # ---- input/output
        elif op in (0x09, 0x0A):
            p = op & 3; mn = 'IN A,P%d' % p; cyc = 2
            v = self.p1_pins() if p == 1 else self.p2_pins()
            pending.append(lambda: setattr(self, 'a', v))
        elif op in (0x39, 0x3A):
            p = op & 3; mn = 'OUTL P%d,A' % p; cyc = 2
            pending.append(lambda: self._port_w(p, a))
        elif op in (0x99, 0x9A, 0x89, 0x8A):
            p = op & 3; d, _ = imm()
            name = 'ANL' if op & 0x10 else 'ORL'
            mn = '%s P%d,#$%02X' % (name, p, d)
            # ASSUMPTION U9: ANL/ORL Pp,#data operate on the output latch.
            def logic_port(p=p, d=d, name=name):
                cur = self.p1 if p == 1 else self.p2
                self._port_w(p, cur & d if name == 'ANL' else cur | d)
            pending.append(logic_port)
        elif op == 0x22:
            mn = 'IN A,DBB'
            def in_dbb():
                self.a = self.dbbin
                self.ibf = 0
            pending.append(in_dbb)
        elif op == 0x02:
            mn = 'OUT DBB,A'
            def out_dbb():
                self.dbbout = a
                self.obf = 1
            pending.append(out_dbb)
        elif op == 0x90:
            mn = 'MOV STS,A'; pending.append(lambda: setattr(self, 'st_hi', a & 0xF0))
        elif op in (0x0C, 0x0D, 0x0E, 0x0F, 0x3C, 0x3D, 0x3E, 0x3F,
                    0x9C, 0x9D, 0x9E, 0x9F, 0x8C, 0x8D, 0x8E, 0x8F):
            # 8243 expander instructions; not modeled (no 8243 / PROG).
            p = (op & 3) + 4
            mn = {0x0: 'MOVD A,P%d', 0x3: 'MOVD P%d,A', 0x9: 'ANLD P%d,A',
                  0x8: 'ORLD P%d,A'}[hi] % p
            cyc = 2
            illegal = True
        # ---- data moves
        elif hi == 0xF and lo >= 8:
            v = self.get_r(r); mn = 'MOV A,R%d' % r
            pending.append(lambda: setattr(self, 'a', v))
        elif op in (0xF0, 0xF1):
            v = self.ram[self.ind_addr(ri)]; mn = 'MOV A,@R%d' % ri
            pending.append(lambda: setattr(self, 'a', v))
        elif op == 0x23:
            d, _ = imm(); mn = 'MOV A,#$%02X' % d
            pending.append(lambda: setattr(self, 'a', d))
        elif hi == 0xA and lo >= 8:
            mn = 'MOV R%d,A' % r; pending.append(lambda: self.set_r(r, a))
        elif op in (0xA0, 0xA1):
            addr = self.ind_addr(ri); mn = 'MOV @R%d,A' % ri
            pending.append(lambda: self.ram.__setitem__(addr, a))
        elif hi == 0xB and lo >= 8:
            d, _ = imm(); mn = 'MOV R%d,#$%02X' % (r, d)
            pending.append(lambda: self.set_r(r, d))
        elif op in (0xB0, 0xB1):
            addr = self.ind_addr(ri); d, _ = imm(); mn = 'MOV @R%d,#$%02X' % (ri, d)
            pending.append(lambda: self.ram.__setitem__(addr, d))
        elif op == 0xC7:
            mn = 'MOV A,PSW'; v = self.psw()
            pending.append(lambda: setattr(self, 'a', v))
        elif op == 0xD7:
            mn = 'MOV PSW,A'; pending.append(lambda: self.set_psw(a))
        elif hi == 0x2 and lo >= 8:
            mn = 'XCH A,R%d' % r
            def xch_r():
                v = self.get_r(r); self.set_r(r, a); self.a = v
            pending.append(xch_r)
        elif op in (0x20, 0x21):
            mn = 'XCH A,@R%d' % ri; addr = self.ind_addr(ri)
            def xch_m():
                v = self.ram[addr]; self.ram[addr] = a; self.a = v
            pending.append(xch_m)
        elif op in (0x30, 0x31):
            mn = 'XCHD A,@R%d' % ri; addr = self.ind_addr(ri)
            def xchd():
                v = self.ram[addr]
                self.ram[addr] = (v & 0xF0) | (a & 0x0F)
                self.a = (a & 0xF0) | (v & 0x0F)
            pending.append(xchd)
        elif op == 0xA3:
            # MOVP: page of the incremented PC (manual p.3-20 note).
            mn = 'MOVP A,@A'; cyc = 2
            v = self.rom[(self.pc & 0x700) | a]
            pending.append(lambda: setattr(self, 'a', v))
        elif op == 0xE3:
            # ASSUMPTION U10: MOVP3 reads absolute 300h-3FFh from either 1K
            # half; the IBM 1503033 checksum (775h) relies on it.
            mn = 'MOVP3 A,@A'; cyc = 2
            v = self.rom[0x300 | a]
            pending.append(lambda: setattr(self, 'a', v))
        # ---- timer/counter
        elif op == 0x42:
            mn = 'MOV A,T'; pending.append(lambda: setattr(self, 'a', self.t))
        elif op == 0x62:
            mn = 'MOV T,A'; pending.append(lambda: setattr(self, 't', a))
        elif op == 0x55:
            mn = 'STRT T'
            def strt_t():
                self.tmode = 'timer'; self.prescale = 0   # p.3-25
            pending.append(strt_t)
        elif op == 0x45:
            mn = 'STRT CNT'; pending.append(lambda: setattr(self, 'tmode', 'counter'))
        elif op == 0x65:
            mn = 'STOP TCNT'; pending.append(lambda: setattr(self, 'tmode', 'stop'))
        elif op == 0x25:
            mn = 'EN TCNTI'; pending.append(lambda: setattr(self, 'tie', 1))
        elif op == 0x35:
            mn = 'DIS TCNTI'
            def dis_tcnti():
                self.tie = 0; self.tirq = 0                 # p.3-11
            pending.append(dis_tcnti)
        # ---- control
        elif op == 0xE5:
            mn = 'EN DMA'; pending.append(lambda: setattr(self, 'dma_en', 1))
        elif op == 0x05:
            mn = 'EN I'; pending.append(lambda: setattr(self, 'ie', 1))
        elif op == 0x15:
            mn = 'DIS I'; pending.append(lambda: setattr(self, 'ie', 0))
        elif op == 0xF5:
            mn = 'EN FLAGS'; pending.append(lambda: setattr(self, 'flags_en', 1))
        elif op == 0xC5:
            mn = 'SEL RB0'; pending.append(lambda: setattr(self, 'bs', 0))
        elif op == 0xD5:
            mn = 'SEL RB1'; pending.append(lambda: setattr(self, 'bs', 1))
        elif op == 0x00:
            mn = 'NOP'
        # ---- registers
        elif hi == 0x1 and lo >= 8:
            mn = 'INC R%d' % r; pending.append(lambda: self.set_r(r, self.get_r(r) + 1))
        elif op in (0x10, 0x11):
            mn = 'INC @R%d' % ri; addr = self.ind_addr(ri)
            pending.append(lambda: self.ram.__setitem__(addr, (self.ram[addr] + 1) & 0xFF))
        elif hi == 0xC and lo >= 8:
            mn = 'DEC R%d' % r; pending.append(lambda: self.set_r(r, self.get_r(r) - 1))
        # ---- subroutine
        elif lo == 4:
            d, _ = imm()
            target = ((hi >> 1) << 8) | d
            if hi & 1:
                mn = 'CALL $%04X' % target
                def call():
                    self.push(); self.pc = target
                pending.append(call)
            else:
                mn = 'JMP $%04X' % target
                pending.append(lambda: setattr(self, 'pc', target))
        elif op == 0x83:
            mn = 'RET'; cyc = 2; pending.append(lambda: self.pop(False))
        elif op == 0x93:
            mn = 'RETR'; cyc = 2
            def retr():
                self.pop(True); self.in_irq = 0             # p.2-12
            pending.append(retr)
        # ---- flags
        elif op == 0x97:
            mn = 'CLR C'; pending.append(lambda: setattr(self, 'cy', 0))
        elif op == 0xA7:
            mn = 'CPL C'; pending.append(lambda: setattr(self, 'cy', self.cy ^ 1))
        elif op == 0x85:
            mn = 'CLR F0'; pending.append(lambda: setattr(self, 'f0', 0))
        elif op == 0x95:
            mn = 'CPL F0'; pending.append(lambda: setattr(self, 'f0', self.f0 ^ 1))
        elif op == 0xA5:
            mn = 'CLR F1'; pending.append(lambda: setattr(self, 'f1', 0))
        elif op == 0xB5:
            mn = 'CPL F1'; pending.append(lambda: setattr(self, 'f1', self.f1 ^ 1))
        # ---- branch
        elif op == 0xB3:
            # JMPP: PC(0-7) <- ROM[page of incremented PC | A] (p.3-14).
            mn = 'JMPP @A'; cyc = 2
            tgt = self.rom[(self.pc & 0x700) | a]
            page = self.pc & 0x700
            pending.append(lambda: setattr(self, 'pc', page | tgt))
        elif hi == 0xE and lo >= 8:
            d, oa = imm(); mn = 'DJNZ R%d,$%04X' % (r, (oa & 0x700) | d)
            def djnz():
                v = (self.get_r(r) - 1) & 0xFF
                self.set_r(r, v)
                if v:
                    self.page_jump(oa, d)
            pending.append(djnz)
        elif lo == 2 and hi & 1:
            # JBb: b2 b1 b0 1 0 0 1 0 (p.3-13)
            b = hi >> 1
            d, oa = imm(); mn = 'JB%d $%04X' % (b, (oa & 0x700) | d)
            if (a >> b) & 1:
                pending.append(lambda: self.page_jump(oa, d))
        elif op in _COND:
            name = _COND[op]
            d, oa = imm(); mn = '%s $%04X' % (name, (oa & 0x700) | d)
            take = self._cond(name)
            if name == 'JTF':
                pending.append(lambda: setattr(self, 'tf', 0))  # p.3-15
            if take:
                pending.append(lambda: self.page_jump(oa, d))
        else:
            # ASSUMPTION U11: an opcode absent from Table 3-2 executes as a
            # one-cycle no-operation and is reported as illegal.
            mn = 'DB $%02X' % op
            illegal = True

        self.tick(cyc)
        for f in pending:
            f()
        if illegal:
            self.illegal_count += 1
        return Retire(start, op, operand, cyc, 'insn', mn, illegal)

    def _cond(self, name):
        # Branch conditions are evaluated before the instruction's cycles
        # tick; T0/T1 are the values presented between instructions.
        return {
            'JC': self.cy == 1, 'JNC': self.cy == 0,
            'JZ': self.a == 0, 'JNZ': self.a != 0,
            'JT0': self.t0 == 1, 'JNT0': self.t0 == 0,
            'JT1': self.t1 == 1, 'JNT1': self.t1 == 0,
            'JF0': self.f0 == 1, 'JF1': self.f1 == 1,
            'JTF': self.tf == 1,
            'JNIBF': self.ibf == 0, 'JOBF': self.obf == 1,
        }[name]

    def _alu(self, k, v):
        if k == 0x6:
            self.add(v, 0)
        elif k == 0x7:
            self.add(v, self.cy)
        elif k == 0x5:
            self.a &= v
        elif k == 0x4:
            self.a |= v
        else:
            self.a ^= v

    def _da(self):
        """Manual p.3-10: if A(0-3) > 9 or AC, add 6; then if A(4-7) > 9 or
        C, add 60h. 'If an overflow occurs, C is set to one; otherwise, it
        is cleared to zero.' ASSUMPTION U12: read literally, that sentence
        would clear a BCD carry (99h+99h = 32h, C=1, AC=1 would adjust to
        98h with C=0). C is instead set by a carry out of bit 7 from either
        addition and otherwise keeps its input value, which is correct BCD
        and matches MAME's mcs48 core."""
        a = self.a
        c = self.cy
        over = c
        if (a & 0x0F) > 9 or self.ac:
            a += 0x06
            if a > 0xFF:
                over = 1
            a &= 0xFF
        if ((a >> 4) & 0x0F) > 9 or c:
            a += 0x60
            if a > 0xFF:
                over = 1
            a &= 0xFF
        self.a = a
        self.cy = over

    def _port_w(self, p, v):
        if p == 1:
            self.p1 = v & 0xFF
        elif p == 2:
            self.p2 = v & 0xFF


_COND = {
    0xF6: 'JC', 0xE6: 'JNC', 0xC6: 'JZ', 0x96: 'JNZ',
    0x36: 'JT0', 0x26: 'JNT0', 0x56: 'JT1', 0x46: 'JNT1',
    0xB6: 'JF0', 0x76: 'JF1', 0x16: 'JTF', 0xD6: 'JNIBF', 0x86: 'JOBF',
}


def disassemble(rom, pc):
    """Decode one instruction at pc without side effects."""
    m = UPI42(bytes(rom))
    m.pc = pc
    rec = m._execute(pc, m.fetch())
    return rec.mnemonic, (2 if rec.operand is not None else 1)
