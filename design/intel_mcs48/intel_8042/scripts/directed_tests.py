#!/usr/bin/env python3
"""Directed tests of the reference model against statements and worked
examples in the Intel UPI-41A User's Manual (9800504-02B). Each test checks
exact program-counter values and results; none relies on padding to absorb
an unknown landing address. Each test also writes OUT_DIR/<name>.bin and
.txt so tb/lockstep_tb.cpp can run the same program on the RTL.

usage: directed_tests.py OUT_DIR
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from upi42_iss import UPI42   # noqa: E402

TESTS = []


def test(fn):
    TESTS.append(fn)
    return fn


class Prog:
    def __init__(self):
        self.rom = bytearray(2048)       # 00h = NOP
        self.script = []
        self.retires = 0

    def at(self, addr, *data):
        for i, b in enumerate(data):
            self.rom[addr + i] = b & 0xFF
        return addr + len(data)

    def machine(self):
        m = UPI42(bytes(self.rom))
        m.reset()
        return m


def run_to(m, pc, limit=10000):
    """Step until the next instruction to execute is at pc; return the
    retire records."""
    recs = []
    for _ in range(limit):
        if m.pc == pc and recs:
            return recs
        recs.append(m.step())
    raise AssertionError('pc %03X not reached' % pc)


def check(cond, msg):
    if not cond:
        raise AssertionError(msg)


def pcs(recs):
    return [r.pc for r in recs]


@test
def da_example(p):
    """p.3-10 example: A=9AH, C=0, AC=0. The manual's table shows 9AH+06H as
    A1H and the result as 01H; 9AH+06H is A0H, so the arithmetic it
    describes gives A0H+60H = 00H with C set. The manual's example has an
    arithmetic error; this test checks the stated rule, not the typo."""
    p.at(0, 0x23, 0x9A, 0x97, 0x57, 0x04, 0x05)   # MOV A,#9A; CLR C; DA A; JMP 5
    m = p.machine()
    recs = run_to(m, 5)
    check(pcs(recs) == [0, 2, 3, 4], 'path %s' % pcs(recs))
    check(m.a == 0x00 and m.cy == 1, 'DA 9A -> %02X C=%d' % (m.a, m.cy))
    p.retires = len(recs) + 1


@test
def bcd_add_carry(p):
    """ASSUMPTION U12: 99H + 99H (BCD) adjusts to 98H with C kept set."""
    p.at(0, 0x23, 0x99, 0x03, 0x99, 0x57, 0x04, 0x06)
    m = p.machine()
    recs = run_to(m, 6)
    check(pcs(recs) == [0, 2, 4, 5], 'path %s' % pcs(recs))
    check(m.a == 0x98 and m.cy == 1, 'BCD 99+99 -> %02X C=%d' % (m.a, m.cy))
    p.retires = len(recs) + 1


@test
def rotate_examples(p):
    """p.3-22/3-23: RL 10110001 -> 01100011; RR 10110001 -> 11011000;
    RRC with C=0, A=10110001 -> A=01011000, C=1; CPL A p.3-9."""
    a = p.at(0, 0x23, 0xB1, 0xE7, 0xA8)            # RL A; MOV R0,A
    a = p.at(a, 0x23, 0xB1, 0x77, 0xA9)            # RR A; MOV R1,A
    a = p.at(a, 0x97, 0x23, 0xB1, 0x67, 0xAA)      # CLR C; RRC A; MOV R2,A
    a = p.at(a, 0x23, 0x6A, 0x37, 0xAB)            # CPL A; MOV R3,A
    end = a
    p.at(end, 0x04 | ((end >> 8) << 5), end & 0xFF)
    m = p.machine()
    recs = run_to(m, end)
    check(m.ram[0] == 0x63, 'RL %02X' % m.ram[0])
    check(m.ram[1] == 0xD8, 'RR %02X' % m.ram[1])
    check(m.ram[2] == 0x58 and m.cy == 1, 'RRC %02X C=%d' % (m.ram[2], m.cy))
    check(m.ram[3] == 0x95, 'CPL %02X' % m.ram[3])
    p.retires = len(recs) + 1


@test
def add_aux_carry(p):
    """ADD sets AC from bit 3 (used by DA, p.3-10): 0FH + 01H."""
    p.at(0, 0x23, 0x0F, 0x03, 0x01, 0xC7, 0xA8, 0x04, 0x06)
    m = p.machine()
    recs = run_to(m, 6)
    check(m.ram[0] & 0x40 and not m.ram[0] & 0x80, 'PSW %02X' % m.ram[0])
    p.retires = len(recs) + 1


@test
def xchd_and_swap(p):
    """p.3-25/3-26: XCHD exchanges the low digits only; SWAP swaps nibbles."""
    p.at(0, 0xB8, 0x30, 0xB0, 0xAB,   # MOV R0,#30; MOV @R0,#AB
         0x23, 0x12, 0x30,           # MOV A,#12; XCHD A,@R0
         0x47, 0x04, 0x09)           # SWAP A; JMP 9
    m = p.machine()
    recs = run_to(m, 9)
    check(m.ram[0x30] == 0xA2 and m.a == 0xB1, '@30=%02X A=%02X' % (m.ram[0x30], m.a))
    p.retires = len(recs) + 1


@test
def stack_wraps(p):
    """p.2-7: nine nested CALLs overflow the 8-level stack; SP wraps 07h ->
    00h and the deepest entry (RAM 8-9) is overwritten. CALL saves PSW 4-7."""
    # 10 + 2k: CALL 10 + 2(k+1) for k = 0..8; target of the ninth call loops
    a = 0x10
    for k in range(9):
        a = p.at(a, 0x14, a + 2)
    p.at(a, 0x04, a)          # JMP self at 22h
    p.at(0, 0xD5, 0x04, 0x10)  # SEL RB1; JMP 10h
    m = p.machine()
    recs = run_to(m, a)
    check(pcs(recs)[:3] == [0, 1, 0x10], 'path %s' % pcs(recs)[:3])
    check(m.sp == 1, 'SP %d' % m.sp)
    # Ninth call came from 20h: return address 22h, PSW high nibble with BS=1
    check(m.ram[8] == 0x22 and m.ram[9] == 0x10, 'stack0 %02X %02X' % (m.ram[8], m.ram[9]))
    check(m.ram[22] == 0x20 and m.ram[23] == 0x10, 'stack7 %02X %02X' % (m.ram[22], m.ram[23]))
    p.retires = len(recs) + 1


@test
def djnz_at_page_end(p):
    """p.3-11 note: a DJNZ starting at location 255 jumps within the
    following page (ASSUMPTION U5 generalizes to the operand's page)."""
    p.at(0, 0xB9, 0x02, 0x04, 0xFF)          # MOV R1,#2; JMP FFh
    p.at(0xFF, 0xE9, 0x20)                   # DJNZ R1,(page 1)20h
    p.at(0x120, 0x24, 0x20)                  # JMP 120h (self)
    m = p.machine()
    recs = run_to(m, 0x120)
    check(pcs(recs) == [0, 2, 0xFF], 'path %s' % pcs(recs))
    check(m.ram[1] == 1, 'R1 %d' % m.ram[1])
    p.retires = len(recs) + 1


@test
def movp_at_page_end(p):
    """p.3-20 note: MOVP at location 255 addresses the following page.
    MOVP3 reads page 3 (ASSUMPTION U10) even from the upper 1K."""
    p.at(0, 0x23, 0x10, 0x04, 0xFF)          # MOV A,#10; JMP FFh
    p.at(0xFF, 0xA3)                         # MOVP A,@A  -> ROM[110h]
    p.at(0x100, 0xA8, 0x23, 0x11, 0xE4, 0x00)  # MOV R0,A; MOV A,#11; JMP 700h
    p.at(0x110, 0x5A)
    p.at(0x311, 0xC3)
    p.at(0x711, 0x77)
    p.at(0x700, 0xE3, 0xA9, 0xE4, 0x04)      # MOVP3; MOV R1,A; JMP 704h
    p.at(0x704, 0xE4, 0x04)
    m = p.machine()
    recs = run_to(m, 0x704)
    check(pcs(recs) == [0, 2, 0xFF, 0x100, 0x101, 0x103, 0x700, 0x701, 0x702],
          'path %s' % ['%03X' % x for x in pcs(recs)])
    check(m.ram[0] == 0x5A and m.ram[1] == 0xC3, 'R0=%02X R1=%02X' % (m.ram[0], m.ram[1]))
    p.retires = len(recs) + 1


@test
def jmpp_table(p):
    """p.3-14: JMPP @A loads PC(0-7) from the current page at A."""
    p.at(0x200, 0x23, 0x80, 0xB3)            # MOV A,#80; JMPP @A
    p.at(0x280, 0x40)                        # table entry -> 240h
    p.at(0x240, 0x44, 0x40)                  # JMP 240h (self)
    p.at(0, 0x44, 0x00)                      # JMP 200h
    m = p.machine()
    recs = run_to(m, 0x240)
    check(pcs(recs) == [0, 0x200, 0x202], 'path %s' % pcs(recs))
    p.retires = len(recs) + 1


@test
def host_interface(p):
    """p.2-14: host write sets IBF and F1=A0; IN A,DBB clears IBF; OUT DBB
    sets OBF; host data read clears OBF; MOV STS,A sets bits 4-7 only."""
    p.at(0, 0xD6, 0x00,                      # 0: JNIBF 0
         0x22, 0xA8,                         # IN A,DBB; MOV R0,A
         0x23, 0xFF, 0x90,                   # MOV A,#FF; MOV STS,A
         0x23, 0x5C, 0x02,                   # MOV A,#5C; OUT DBB,A
         0x86, 0x0A,                         # 0A: JOBF 0A
         0x04, 0x0C)                         # 0C: JMP 0C
    m = p.machine()
    for _ in range(3):
        m.step()
    check(m.pc == 0 and m.status() == 0, 'idle sts %02X' % m.status())
    m.host_write(1, 0x3C)
    check(m.status() == 0x0A, 'after write sts %02X' % m.status())
    recs = run_to(m, 0x0A)
    check(m.ram[0] == 0x3C and m.status() == 0xF9, 'R0=%02X sts=%02X' % (m.ram[0], m.status()))
    for _ in range(4):
        m.step()
    check(m.pc == 0x0A, 'JOBF loop pc %03X' % m.pc)
    check(m.host_read(0) == 0x5C and m.status() == 0xF8, 'read sts %02X' % m.status())
    recs = run_to(m, 0x0C)
    check(pcs(recs) == [0x0A], 'exit %s' % pcs(recs))
    p.script = ['3 write 1 3C', '12 read 1', '13 read 0']
    p.retires = 20


@test
def ibf_interrupt_and_retr(p):
    """p.2-11/2-12: EN I + host write forces CALL 3 saving PC and PSW 4-7;
    RETR restores them and re-enables interrupts; DIS I does not clear a
    pending request (p.3-10)."""
    p.at(0, 0x04, 0x10)                      # JMP 10h
    p.at(3, 0x22, 0xD5, 0x93)                # IBF handler: IN A,DBB; SEL RB1; RETR
    p.at(0x10, 0x15, 0x00, 0x00, 0x05,       # DIS I; NOP; NOP; EN I
         0x00, 0x04, 0x15)                   # NOP; JMP 15h
    m = p.machine()
    m.step()                                 # JMP 10
    m.step()                                 # DIS I
    m.host_write(0, 0x77)                    # request while disabled
    recs = [m.step(), m.step(), m.step()]    # NOP NOP EN I
    check(pcs(recs) == [0x11, 0x12, 0x13] and m.ibf_irq == 1, 'pending kept')
    r = m.step()
    check(r.kind == 'irq3' and r.pc == 0x14 and m.pc == 3, 'vector %s %03X' % (r.kind, m.pc))
    check(m.ram[8] == 0x14 and m.ram[9] == 0x00 and m.sp == 1, 'stack %02X %02X' % (m.ram[8], m.ram[9]))
    recs = [m.step(), m.step(), m.step()]
    check(pcs(recs) == [3, 4, 5] and m.pc == 0x14 and m.bs == 0 and m.in_irq == 0,
          'RETR pc %03X bs %d' % (m.pc, m.bs))
    check(m.a == 0x77 and m.ibf == 0, 'A %02X' % m.a)
    p.script = ['2 write 0 77']
    p.retires = 12


@test
def timer_overflow_priority(p):
    """p.2-10: the timer counts machine cycles / 32; overflow sets TF and,
    with EN TCNTI, calls location 7. If IBF and timer requests are both
    pending, IBF is served first and the timer request stays pending.
    JTF clears TF (p.3-15)."""
    p.at(0, 0x04, 0x10)
    p.at(3, 0x93)                            # IBF: RETR
    p.at(7, 0x18, 0x93)                      # timer: INC R0; RETR
    p.at(0x10, 0x23, 0xFF, 0x62, 0x25,       # MOV A,#FF; MOV T,A; EN TCNTI
         0x55,                               # 14: STRT T
         0x04, 0x15)                         # 15: JMP 15h (2 cycles)
    m = p.machine()
    recs = []
    while not (m.tf or len(recs) > 40):
        recs.append(m.step())
    # STRT T retires at cycle 7; 32 cycles later T overflows FF->00.
    check(m.tf == 1 and m.t == 0 and m.tirq == 1, 'tf %d t %02X' % (m.tf, m.t))
    check(m.cycles == 7 + 32, 'overflow at cycle %d' % m.cycles)
    m.host_write(0, 0x01)
    m.ie = 1                                 # as if EN I had executed
    r = m.step()
    check(r.kind == 'irq3' and m.tirq == 1, 'IBF first: %s' % r.kind)
    m.step()                                 # RETR
    r = m.step()
    check(r.kind == 'irq7' and m.tirq == 0, 'then timer: %s' % r.kind)
    m.step(); m.step()                       # INC R0; RETR
    check(m.ram[0] == 1 and m.pc == 0x15, 'R0 %d pc %03X' % (m.ram[0], m.pc))
    # The RTL lockstep version enables IBF interrupts by program instead
    p.at(0x10, 0x05, 0x23, 0xFF, 0x62, 0x25, 0x55, 0x04, 0x16)
    p.at(0x16, 0x16, 0x18, 0x04, 0x16)        # JTF 18h; JMP 16h
    p.at(0x18, 0x04, 0x18)
    p.script = ['30 fwrite 0 01']
    p.retires = 60


@test
def flags_on_port2(p):
    """p.2-12 / data sheet p.4: after EN FLAGS, P24 outputs OBF and P25
    outputs NOT IBF, each gated by its latch bit."""
    p.at(0, 0xF5, 0x02, 0x04, 0x03)          # EN FLAGS; OUT DBB,A; JMP 3
    p.at(3, 0x04, 0x03)
    m = p.machine()
    m.step()
    check(m.p2_out() == 0xEF, 'flags idle %02X' % m.p2_out())     # OBF=0
    m.step()
    check(m.p2_out() == 0xFF, 'OBF set %02X' % m.p2_out())
    m.host_write(0, 0)
    check(m.p2_out() == 0xDF, 'IBF set %02X' % m.p2_out())
    p.script = ['2 fwrite 0 00', '4 read 0']
    p.retires = 8


@test
def reset_state(p):
    """p.2-12/2-14: RESET clears PC, SP, BS, F0, F1, status flags, interrupt
    enables, timer mode and TF; ports are set high (input mode)."""
    p.at(0, 0xC7, 0xA8, 0x0A, 0xA9, 0x04, 0x05)
    m = p.machine()
    run_to(m, 5)
    check(m.ram[0] == 0x08, 'PSW after reset %02X' % m.ram[0])
    check(m.ram[1] == 0xFF and m.status() == 0, 'P2 %02X sts %02X' % (m.ram[1], m.status()))
    p.retires = 6


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    failed = 0
    for fn in TESTS:
        p = Prog()
        try:
            fn(p)
            status = 'PASS'
        except AssertionError as e:
            status = 'FAIL: %s' % e
            failed += 1
        print('%-26s %s' % (fn.__name__, status))
        (out / (fn.__name__ + '.bin')).write_bytes(bytes(p.rom))
        (out / (fn.__name__ + '.txt')).write_text(
            '\n'.join(['run %d' % max(p.retires, 1)] + p.script) + '\n')
    print('%d directed tests, %d failed' % (len(TESTS), failed))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
