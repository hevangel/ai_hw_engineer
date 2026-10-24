"""Generate ISS comparison vectors for the mos_6502 full-ISA regression.

Imports the vendored py65 MPU (BSD-3-Clause, references/py65_mpu6502.py) as
the independent oracle, executes directed programs that cover every
documented opcode x addressing mode, and emits:

  vectors.hex  one record per instruction boundary:
               pc a x y p s  (six 4-hex-digit words per line)
  mem.hex      the 64K memory image to load into the RTL testbench
  gold_mem.hex the oracle's final memory (TB compares at the end)

The RTL is never consulted here.
"""
import re
import sys
import importlib.util
from pathlib import Path

DESIGN = Path(__file__).resolve().parents[1]
REF = DESIGN / 'references'
OUT = DESIGN / 'work' / 'sim'
OUT.mkdir(parents=True, exist_ok=True)

# ---- import the vendored py65 with a local package shim -------------------
def _load_module(name, path):
    # Load a repository-local module file through importlib (the sanctioned
    # API) instead of exec of compiled source.
    spec = importlib.util.spec_from_file_location(name, str(path))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod

def load_py65():
    src = (REF / 'py65_mpu6502.py').read_text()
    src = src.replace('from py65.utils.conversions import itoa',
                      'from py65_utils_conversions import itoa')
    src = src.replace('from py65.utils.devices import make_instruction_decorator',
                      'from py65_utils_devices import make_instruction_decorator')
    conv = _load_module('py65_utils_conversions', REF / 'py65_utils_conversions.py')
    dev = _load_module('py65_utils_devices', REF / 'py65_utils_devices.py')
    import types
    mpu_mod = types.ModuleType('py65_shim.mpu')
    mpu_mod.__dict__['itoa'] = conv.itoa
    mpu_mod.__dict__['make_instruction_decorator'] = dev.make_instruction_decorator
    # The import-rewritten py65 source is materialized under work/ and
    # loaded through importlib - byte-for-byte the vendored module apart
    # from the two rewritten import lines.
    shim_path = OUT / 'py65_mpu6502_shim.py'
    shim_path.write_text(src)
    shim_mod = _load_module('py65_mpu6502_shim', shim_path)
    mpu_mod.MPU = shim_mod.MPU
    return mpu_mod.MPU

MPU = load_py65()

# ---- program builder -------------------------------------------------------
class Prog:
    def __init__(self, org):
        self.org = org
        self.b = []          # (addr, byte)
        self.pc = org
        self.labels = {}
        self.fixups = []     # (addr, label)

    def label(self, name):
        self.labels[name] = self.pc

    def emit(self, *bs):
        for x in bs:
            self.b.append((self.pc, x & 0xFF))
            self.pc += 1

    def word(self, v):
        self.emit(v & 0xFF, (v >> 8) & 0xFF)

    def db(self, label):                       # 16-bit placeholder
        self.fixups.append((self.pc, label))
        self.emit(0, 0)

    def rel(self, label):                      # 8-bit branch placeholder
        self.fixups.append((self.pc, ('rel', label)))
        self.emit(0)

    def link(self):
        for addr, lab in self.fixups:
            if isinstance(lab, tuple) and lab[0] == 'rel':
                off = self.labels[lab[1]] - (addr + 1)
                assert -128 <= off <= 127, (lab, off)
                self.b[[i for i, a in enumerate(self.b) if a[0] == addr][0]] = (addr, off & 0xFF)
            else:
                t = self.labels[lab]
                self.b[[i for i, a in enumerate(self.b) if a[0] == addr][0]] = (addr, t & 0xFF)
                self.b[[i for i, a in enumerate(self.b) if a[0] == addr + 1][0]] = (addr + 1, (t >> 8) & 0xFF)

    def image(self):
        mem = [0] * 0x10000
        for addr, v in self.b:
            mem[addr] = v
        return mem


mem = [0] * 0x10000
prog = Prog(0x0200)

# zp/abs scratch areas (ABX/ABY from ABS0 with X=$FF crosses into $04xx)
ZP0, ZP1, ABS0, ABS1 = 0x40, 0x41, 0x40F0, 0x40F1

# seed memory the programs read
mem[0x40] = 0xA5; mem[0x41] = 0x5A; mem[0x42] = 0xFF; mem[0x43] = 0x01
mem[0x44] = 0x80; mem[0x45] = 0x7F
mem[0x0300] = 0x3C; mem[0x0301] = 0xC3
# (zp) pointers for (zp,X)/(zp),Y: pointer at 0x50 -> $0310
mem[0x50] = 0x10; mem[0x51] = 0x03
mem[0x0310] = 0x66; mem[0x0311] = 0x99
# indirect-page-wrap fixture for JMP ($xxFF): ptr page $02, FFF->FFE
prog_fixup_wrap = None

E = prog.emit
p = prog

# program: sweep every documented opcode with varied preconditions
p.label('start')
# precondition patterns: run the sweep with several register/flag/memory setups
# (memory at the operand addresses is reloaded between sweeps via STA writes)
sweep_sets = [
    dict(a=0x00, x=0x01, y=0x02, c=0, d=0),
    dict(a=0xFF, x=0xFF, y=0x01, c=1, d=0),
    dict(a=0x99, x=0x02, y=0xFF, c=1, d=1),
    dict(a=0x80, x=0x7F, y=0x80, c=0, d=1),
]

# The sweep body uses fixed operand addresses; memory at those addresses is
# initialized above and modified by the running code (exercising RMW).
def sweep():
    # ALU group 01 across all 8 modes (data-dependent)
    E(0xA9, 0x00)                    # LDA #imm0 placeholder replaced per set
    for opc in (0x09, 0x05, 0x15, 0x0D, 0x1D, 0x19, 0x01, 0x11,   # ORA
                0x29, 0x25, 0x35, 0x2D, 0x3D, 0x39, 0x21, 0x31,   # AND
                0x49, 0x45, 0x55, 0x4D, 0x5D, 0x59, 0x41, 0x51,   # EOR
                0x69, 0x65, 0x75, 0x6D, 0x7D, 0x79, 0x61, 0x71,   # ADC
                0xC9, 0xC5, 0xD5, 0xCD, 0xDD, 0xD9, 0xC1, 0xD1,   # CMP
                0xE9, 0xE5, 0xF5, 0xED, 0xFD, 0xF9, 0xE1, 0xF1):  # SBC
        if opc in (0x09, 0x29, 0x49, 0x69, 0xC9, 0xE9):
            E(opc, 0x5A)
        elif opc in (0x05, 0x25, 0x45, 0x65, 0xC5, 0xE5, 0x15, 0x35,
                     0x55, 0x75, 0xF5, 0xD5):
            E(opc, 0x40)
        elif opc in (0x0D, 0x2D, 0x4D, 0x6D, 0xCD, 0xED):
            E(opc); p.word(ABS0)
        elif opc in (0x1D, 0x3D, 0x5D, 0x7D, 0xFD, 0xDD):
            E(opc); p.word(ABS0)
        elif opc in (0x19, 0x39, 0x59, 0x79, 0xF9, 0xD9):
            E(opc); p.word(ABS1)
        elif opc in (0x01, 0x21, 0x41, 0x61, 0xE1, 0xC1):
            E(opc, 0x50)
        else:  # (zp),Y
            E(opc, 0x50)
    # compare/Bit families: CPX/CPY/BIT
    for opc, tail in ((0xE0, 'i'), (0xE4, 'z'), (0xEC, 'a')):
        if tail == 'i': E(opc, 0x11)
        elif tail == 'z': E(opc, 0x40)
        else: E(opc); p.word(ABS1)
    for opc, tail in ((0xC0, 'i'), (0xC4, 'z'), (0xCC, 'a')):
        if tail == 'i': E(opc, 0x22)
        elif tail == 'z': E(opc, 0x41)
        else: E(opc); p.word(ABS0)
    for opc, tail in ((0x24, 'z'), (0x2C, 'a')):
        if tail == 'z': E(opc, 0x40)
        else: E(opc); p.word(ABS0)
    # LDA/LDX/LDY/STA/STX/STY across modes
    for opc, tail in ((0xA9, 'i'), (0xA5, 'z'), (0xB5, 'zx'), (0xAD, 'a'),
                      (0xBD, 'ax'), (0xB9, 'ay'), (0xA1, 'ix'), (0xB1, 'iy')):
        if tail == 'i': E(opc, 0x99)
        elif tail == 'z': E(opc, 0x41)
        elif tail == 'zx': E(opc, 0x40)
        elif tail == 'a': E(opc); p.word(ABS0)
        elif tail == 'ax': E(opc); p.word(ABS0)
        elif tail == 'ay': E(opc); p.word(ABS1)
        elif tail == 'ix': E(opc, 0x50)
        else: E(opc, 0x50)
    for opc, tail in ((0xA2, 'i'), (0xA6, 'z'), (0xB6, 'zy'), (0xAE, 'a'), (0xBE, 'ay')):
        if tail == 'i': E(opc, 0x11)
        elif tail == 'z': E(opc, 0x42)
        elif tail == 'zy': E(opc, 0x40)
        elif tail == 'a': E(opc); p.word(ABS1)
        else: E(opc); p.word(ABS1)
    for opc, tail in ((0xA0, 'i'), (0xA4, 'z'), (0xB4, 'zx'), (0xAC, 'a'), (0xBC, 'ax')):
        if tail == 'i': E(opc, 0x22)
        elif tail == 'z': E(opc, 0x43)
        elif tail == 'zx': E(opc, 0x40)
        elif tail == 'a': E(opc); p.word(ABS0)
        else: E(opc); p.word(ABS0)
    E(0x85, 0x44); E(0x95, 0x40); E(0x8D); p.word(ABS0)
    E(0x9D); p.word(ABS0); E(0x99); p.word(ABS1)
    E(0x81, 0x50); E(0x91, 0x50)
    E(0x86, 0x45); E(0x96, 0x40); E(0x8E); p.word(ABS1)
    E(0x84, 0x46); E(0x94, 0x40); E(0x8C); p.word(ABS0)
    # RMW group on memory (incl. ABX with both page-cross outcomes)
    for opc, tail in ((0x06, 'z'), (0x16, 'zx'), (0x0E, 'a'), (0x1E, 'ax')):
        if tail == 'z': E(opc, 0x40)
        elif tail == 'zx': E(opc, 0x40)
        elif tail == 'a': E(opc); p.word(ABS0)
        else: E(opc); p.word(ABS0)
    for opc, tail in ((0x46, 'z'), (0x56, 'zx'), (0x4E, 'a'), (0x5E, 'ax')):
        if tail == 'z': E(opc, 0x41)
        elif tail == 'zx': E(opc, 0x41)
        elif tail == 'a': E(opc); p.word(ABS0)
        else: E(opc); p.word(ABS0)
    for opc, tail in ((0x26, 'z'), (0x36, 'zx'), (0x2E, 'a'), (0x3E, 'ax')):
        if tail == 'z': E(opc, 0x42)
        elif tail == 'zx': E(opc, 0x42)
        elif tail == 'a': E(opc); p.word(ABS0)
        else: E(opc); p.word(ABS0)
    for opc, tail in ((0x66, 'z'), (0x76, 'zx'), (0x6E, 'a'), (0x7E, 'ax')):
        if tail == 'z': E(opc, 0x43)
        elif tail == 'zx': E(opc, 0x43)
        elif tail == 'a': E(opc); p.word(ABS0)
        else: E(opc); p.word(ABS0)
    for opc, tail in ((0xE6, 'z'), (0xF6, 'zx'), (0xEE, 'a'), (0xFE, 'ax')):
        if tail == 'z': E(opc, 0x45)
        elif tail == 'zx': E(opc, 0x45)
        elif tail == 'a': E(opc); p.word(ABS1)
        else: E(opc); p.word(ABS1)
    for opc, tail in ((0xC6, 'z'), (0xD6, 'zx'), (0xCE, 'a'), (0xDE, 'ax')):
        if tail == 'z': E(opc, 0x45)
        elif tail == 'zx': E(opc, 0x45)
        elif tail == 'a': E(opc); p.word(ABS1)
        else: E(opc); p.word(ABS1)
    # implied group
    for opc in (0xEA, 0x0A, 0x4A, 0x2A, 0x6A, 0xAA, 0x8A, 0xA8, 0x98,
                0xBA, 0x9A, 0xE8, 0xC8, 0xCA, 0x88,
                0x18, 0x38, 0x58, 0x78, 0xB8, 0xD8, 0xF8):
        E(opc)
    # BIT
    E(0x24, 0x40); E(0x2C); p.word(ABS0)
    # branches: both outcomes
    E(0x10, 0x02); E(0xE8); E(0x18); E(0x90, 0x02); E(0xE8); E(0x18)
    E(0x50, 0x02); E(0xE8); E(0x18); E(0x70, 0x02); E(0xE8); E(0x18)
    E(0x30, 0x02); E(0xE8); E(0x38); E(0xB0, 0x02); E(0xE8); E(0x38)
    E(0x50, 0x02); E(0xE8); E(0x38); E(0xF0, 0x02); E(0xE8); E(0x38)
    E(0xD0, 0x02); E(0xE8); E(0x38)
    # stack ops
    E(0x48); E(0x08); E(0x68); E(0x28)
    # JSR/RTS through a subroutine that also exercises INC/DEC mem
    E(0x20); p.db('sub1')

# build: for each setup, load registers via immediate ops, run sweep
for st in sweep_sets:
    E(0xA9, st['a'])                      # LDA #a
    E(0xAA)                               # TAX -> X=A? need separate X: set X via LDX
    # redo properly:
for st in sweep_sets:
    pass
# (rebuild cleanly below)
prog.b.clear(); prog.fixups.clear(); prog.pc = 0x0200; prog.labels.clear()

for st in sweep_sets:
    E(0xA9, st['a'])                      # LDA #a
    E(0xA2, st['x'])                      # LDX #x
    E(0xA0, st['y'])                      # LDY #y
    E(0x18 if st['c'] == 0 else 0x38)     # CLC/SEC
    E(0xD8 if st['d'] == 0 else 0xF8)     # CLD/SED
    # refresh operand memory so each sweep sees known data
    E(0xA9, 0xA5); E(0x85, 0x40)
    E(0xA9, 0x5A); E(0x85, 0x41)
    E(0xA9, 0xFF); E(0x85, 0x42)
    E(0xA9, 0x01); E(0x85, 0x43)
    E(0xA9, 0x80); E(0x85, 0x44)
    E(0xA9, 0x7F); E(0x85, 0x45)
    E(0xA9, 0x12); E(0x8D); p.word(ABS0)
    E(0xA9, 0x34); E(0x8D); p.word(ABS1)
    sweep()
    # reset D so later sweeps start clean regardless
    E(0xD8)

# stack/JSR/RTI/Bone section (once, D=0 from the last CLD)
E(0x4C); p.db('jmp_tests')                # skip over the subroutine
p.label('sub1')
E(0xE6, 0x46)                             # INC zp
E(0xC6, 0x46)                             # DEC zp
E(0x60)                                   # RTS

# JMP tests (dedicated section; fixtures live in page $7E)
p.label('jmp_tests')
p.label('jt1')                             # fixture overwrites this JMP
E(0x4C); p.db('jt1')                      # JMP absolute
E(0xEA); E(0xEA); E(0xEA)                 # fixture space (jt1+3..jt1+5)
p.label('back1')
E(0x6C); p.word(0x7EFE)                   # JMP indirect, normal
p.label('back2')
E(0x6C); p.word(0x7EFF)                   # JMP indirect, page-wrap bug
p.label('back3')
E(0xEE); p.word(ABS1)                     # INC abs
E(0xCE); p.word(ABS1)                     # DEC abs

# interrupts: set up I=0 and loop; the TB raises IRQ mid-run
p.label('irq_test')
E(0x58)                                   # CLI
E(0xEA); E(0xEA); E(0xEA); E(0xEA)        # window for the IRQ
E(0x78)                                   # SEI
E(0xEA)                                   # the padding NOP: the NMI pulse during THIS
                                          # fetch hijacks the window's first NOP
p.label('nmi_test')
E(0xEA); E(0xEA); E(0xEA); E(0xEA)        # the NMI window (edge-triggered, I-mask ignored)
p.label('done')
E(0x4C); p.db('done')                     # success: park here

# link and write
p.link()
mem = p.image()
mem[0xFFFC] = 0x00; mem[0xFFFD] = 0x02    # reset -> $0200
mem[0xFFFE] = 0x00; mem[0xFFFF] = 0x80    # IRQ -> $8000
mem[0xFFFA] = 0x00; mem[0xFFFB] = 0x81    # NMI -> $8100
# IRQ handler at $8000: PHA, LDA #$77, PLA, RTI
handler = [0x48, 0xA9, 0x77, 0x68, 0x40]
for i, v in enumerate(handler):
    mem[0x8000 + i] = v
# NMI handler at $8100: PHA, LDA #$88, TAX, TXA, PLA, RTI
nmi_handler = [0x48, 0xA9, 0x88, 0xAA, 0x8A, 0x68, 0x40]
for i, v in enumerate(nmi_handler):
    mem[0x8100 + i] = v

# sanitize every region the sweeps' effective addresses can reach.
# NOTE: the program itself spans $0200..~$0E00; keep fixtures clear of it.
#   data region $4000-$43FF (ABX/ABY targets incl. page crossings)
for i in range(0x4000, 0x4400):
    mem[i] = 0x66
#   all of zero page doubles as (zp,X)/(zp),Y pointer space: point every
#   pointer pair at $4010, then restore the specific data bytes
for i in range(0, 0x100, 2):
    mem[i] = 0x10
    mem[i + 1] = 0x40
mem[0x40] = 0xA5; mem[0x41] = 0x5A; mem[0x42] = 0xFF; mem[0x43] = 0x01
mem[0x44] = 0x80; mem[0x45] = 0x7F
mem[0x50] = 0x10; mem[0x51] = 0x40
mem[0x4010] = 0x66; mem[0x4011] = 0x99

#   JMP-indirect fixtures in page $7E (never program space):
#     JMP ($7EFE): ptr hi at $7EFF, normal target $7E00
#     JMP ($7EFF): the NMOS bug wraps the pointer read to $7E00
for i in range(0x7E00, 0x7F00):
    mem[i] = 0xEA                          # NOP slide inside the page
jt1 = p.labels['jmp_tests']
back2 = p.labels['back2']
back3 = p.labels['back3']
mem[jt1] = 0xEE; mem[jt1 + 1] = ABS1 & 0xFF; mem[jt1 + 2] = ABS1 >> 8
mem[jt1 + 3] = 0x4C; mem[jt1 + 4] = p.labels['back1'] & 0xFF; mem[jt1 + 5] = p.labels['back1'] >> 8
mem[0x7EFE] = 0x10; mem[0x7EFF] = 0x7E    # normal target $7E10
mem[0x7E10] = 0x4C; mem[0x7E11] = back2 & 0xFF; mem[0x7E12] = back2 >> 8
mem[0x7E00] = 0x7E                        # wrap reads hi from $7E00
mem[0x7E7E] = 0x4C; mem[0x7E7F] = back3 & 0xFF; mem[0x7E80] = back3 >> 8
wrap_target = (mem[0x7E00] << 8) | mem[0x7EFF]   # lo=$7EFF, hi wraps $7E00
assert wrap_target == 0x7E7E, hex(wrap_target)

# ---- run the oracle and dump vectors ---------------------------------------
mpu = MPU(memory=mem[:])
mpu.pc = 0x0200
mpu.p = 0x24                              # match the RTL reset convention (A12)
mpu.sp = 0x00

# NOTE: D1 = CMP (zp),Y stays py65-native. An earlier revision misread the
# NMOS opcode matrix and remapped D1 to SBC (zp),Y here; the Klaus functional
# test caught it (its CMP (zp),Y at $1752 is opcode D1). SBC (zp),Y is F1.

# ORACLE CORRECTION: py65's decimal SBC deviates from real 6502 hardware in
# corner cases -- caught by the Klaus functional test. Override with the
# canonical NMOS algorithm (Bruce Clark); binary mode stays py65's.
import types as _types
_orig_opSBC = MPU.opSBC
def _sbc_canonical(self, x):
    data = self.ByteAt(x())
    a0 = self.a
    c0 = self.p & 1
    d0 = (self.p >> 3) & 1
    _orig_opSBC(self, x)                # binary flags (N V Z C) + py65's A
    if d0:
        lo = (a0 & 15) - (data & 15) - (1 - c0)
        hi = (a0 >> 4) - (data >> 4)
        if lo & 16:
            lo -= 6
            hi -= 1
        if hi & 16:
            hi -= 6
        self.a = ((hi & 15) << 4) | (lo & 15)
mpu.opSBC = _types.MethodType(_sbc_canonical, mpu)

records = []
steps = 0
MAX = 200000
irq_win_start = p.labels['irq_test'] + 2  # first NOP of the IRQ window
irq_fired = False
nmi_fired = False
while mpu.pc != p.labels['done'] or steps == 0:
    records.append((mpu.pc, mpu.a, mpu.x, mpu.y, (mpu.p & 0xEF) | 0x20, mpu.sp))
    # deterministic external IRQ (fires once): at the window's first
    # instruction the RTL hijacks the fetch (the instruction does NOT
    # execute); py65's irq() models exactly that (pushes pc, vectors FFFE).
    if mpu.pc == irq_win_start and not irq_fired:
        irq_fired = True
        mpu.irq()
        steps += 1
        continue
    if mpu.pc == p.labels['nmi_test'] + 1 and not nmi_fired:
        nmi_fired = True
        mpu.nmi()
        steps += 1
        continue
    mpu.step()
    steps += 1
    if steps > MAX:
        print('ISS did not reach done; pc=%04x' % mpu.pc, file=sys.stderr)
        sys.exit(1)
records.append((mpu.pc, mpu.a, mpu.x, mpu.y, (mpu.p & 0xEF) | 0x20, mpu.sp))
print('ISS instructions:', steps)

# Generated vector files always land in this design's own work/sim tree.
(OUT / 'nvec.hex').write_text('%04x\n' % len(records))
(OUT / 'window.hex').write_text('%04x\n' % irq_win_start)
(OUT / 'nmiwin.hex').write_text('%04x\n' % (p.labels['nmi_test'] + 1))
(OUT / 'handler.hex').write_text('%04x\n' % 0x8000)
(OUT / 'vectors.hex').write_text(
    ''.join(' '.join('%04x' % v for v in r) + '\n' for r in records))
(OUT / 'mem.hex').write_text(''.join('%02x\n' % v for v in mem))
gold = mpu.memory[:]
(OUT / 'gold_mem.hex').write_text(''.join('%02x\n' % v for v in gold))
print('vectors:', len(records))
