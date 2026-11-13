#!/usr/bin/env python3
"""Generate protected-mode scenario images for the PCE-286 oracle comparison.

Each scenario is a memory image run from RESET by both the PCE-286 oracle
(tb/pce_oracle/pce286_oracle.c) and the RTL (tb/pce_oracle/replay.cpp).
Scenarios end in HLT: either the program's own, or an exception handler's.
Every IDT vector v points at handler 0038:(4*v), a single HLT, so the final
CS:IP names the vector and the pushed frame is checked by the memory diff.

Add a family by writing a function decorated with @family that yields
(name, Env) pairs. Keep names stable: waivers and reports key on them.
"""
import argparse
import fnmatch
from pathlib import Path

GDT, IDT, TSS0, TSS1, LDT = 0x1000, 0x1800, 0x2000, 0x2100, 0x2800
CODE0, DATA0, STACK0 = 0x10000, 0x20000, 0x30000
CODE3, DATA3, STACK3, HANDLER = 0x40000, 0x50000, 0x60000, 0x70000
BIGSTACK = 0x80000
# Selectors. T0..T3 are free slots for the descriptor under test.
S_CODE0, S_DATA0, S_STACK0 = 0x08, 0x10, 0x18
S_CODE3, S_DATA3, S_STACK3 = 0x20, 0x28, 0x30
S_HANDLER, S_TSS0, S_LDT, S_TSS1, S_TGATE = 0x38, 0x40, 0x48, 0x50, 0x58
T0, T1, T2, T3 = 0x60, 0x68, 0x70, 0x78
S_BIGSTACK = 0x80


def w16(v):
    return bytes([v & 0xff, (v >> 8) & 0xff])


def desc(limit, base, access, tail=0):
    return w16(limit) + bytes([base & 0xff, (base >> 8) & 0xff, (base >> 16) & 0xff, access]) + w16(tail)


def gate(offset, selector, access, count=0, tail=0):
    return w16(offset) + w16(selector) + bytes([count, access]) + w16(tail)


# Instruction encoders (bytes).
def mov_r(reg, imm): return bytes([0xb8 + reg]) + w16(imm)
def mov_ax(imm): return mov_r(0, imm)
MOV_DS_AX, MOV_ES_AX, MOV_SS_AX = b'\x8e\xd8', b'\x8e\xc0', b'\x8e\xd0'
def mov_sp(imm): return mov_r(4, imm)
def push_imm(v): return b'\x68' + w16(v)
def jmp_far(sel, off): return b'\xea' + w16(off) + w16(sel)
def call_far(sel, off): return b'\x9a' + w16(off) + w16(sel)
def int_n(n): return bytes([0xcd, n])
HLT, NOP, IRET, RETF, PUSHF, POPF, CLI, STI = (bytes([b]) for b in (0xf4, 0x90, 0xcf, 0xcb, 0x9c, 0x9d, 0xfa, 0xfb))
def retf_n(n): return b'\xca' + w16(n)
LTR_AX, LLDT_AX, SLDT_AX, STR_AX = b'\x0f\x00\xd8', b'\x0f\x00\xd0', b'\x0f\x00\xc0', b'\x0f\x00\xc8'
VERR_AX, VERW_AX = b'\x0f\x00\xe0', b'\x0f\x00\xe8'
LAR_BX_AX, LSL_BX_AX, ARPL_AX_BX = b'\x0f\x02\xd8', b'\x0f\x03\xd8', b'\x63\xd8'
LMSW_AX, SMSW_AX, CLTS = b'\x0f\x01\xf0', b'\x0f\x01\xe0', b'\x0f\x06'


class Env:
    """Standard protected-mode image; see the module docstring."""

    def __init__(self, steps=400, gdt_limit=0x87, idt_vectors=0x30):
        self.mem = {}
        self.steps = steps
        self.put(0xfffff0, jmp_far(0xf000, 0x0100))
        self.put(0x0ffff0, jmp_far(0xf000, 0x0100))
        boot = (b'\x0f\x01\x16\x40\x00' + b'\x0f\x01\x1e\x46\x00' +   # LGDT [0040], LIDT [0046]
                mov_ax(1) + LMSW_AX + b'\xeb\x00' + jmp_far(S_CODE0, 0))
        self.put(0xf0100, boot)
        self.put(0x40, w16(gdt_limit) + bytes([GDT & 0xff, GDT >> 8, 0, 0]))
        self.put(0x46, w16(idt_vectors * 8 - 1) + bytes([IDT & 0xff, IDT >> 8, 0, 0]))
        self.gdt(S_CODE0, desc(0xffff, CODE0, 0x9a))
        self.gdt(S_DATA0, desc(0xffff, DATA0, 0x92))
        self.gdt(S_STACK0, desc(0xffff, STACK0, 0x92))
        self.gdt(S_CODE3, desc(0xffff, CODE3, 0xfa))
        self.gdt(S_DATA3, desc(0xffff, DATA3, 0xf2))
        self.gdt(S_STACK3, desc(0xffff, STACK3, 0xf2))
        self.gdt(S_HANDLER, desc(0xffff, HANDLER, 0x9a))
        self.gdt(S_TSS0, desc(0x002b, TSS0, 0x81))
        self.gdt(S_LDT, desc(0x003f, LDT, 0x82))
        self.gdt(S_TSS1, desc(0x002b, TSS1, 0x81))
        self.gdt(S_TGATE, gate(0, S_TSS1, 0x85))
        self.gdt(S_BIGSTACK, desc(0xffff, BIGSTACK, 0x92))
        for v in range(idt_vectors):
            self.idt(v, gate(4 * v, S_HANDLER, 0xe6 if v >= 0x20 else 0x86))
            self.put(HANDLER + 4 * v, HLT)
        # Current task: ring-0 stack 0018:F000 for inward transitions.
        self.put(TSS0 + 2, w16(0xf000) + w16(S_STACK0))
        self.put(TSS0 + 42, w16(S_LDT))
        # Second task: starts at 0008:0900 (HLT) with distinct registers.
        image = [0x0900, 0x0002, 0x1111, 0x2222, 0x3333, 0x4444, 0x7000, 0x5555, 0x6666, 0x7777,
                 S_DATA0, S_CODE0, S_STACK0, S_DATA0, S_LDT]
        self.put(TSS1 + 2, w16(0xe000) + w16(S_STACK0))
        self.put(TSS1 + 14, b''.join(w16(v) for v in image))
        self.put(CODE0 + 0x0900, HLT)
        self.put(LDT + 0x08, desc(0xffff, DATA0, 0x92))
        self.put(LDT + 0x10, desc(0xffff, CODE0, 0x9a))
        self.put(LDT + 0x18, desc(0xffff, DATA3, 0xf2))
        self.init = (mov_ax(S_DATA0) + MOV_DS_AX + MOV_ES_AX + mov_ax(S_STACK0) + MOV_SS_AX +
                     mov_sp(0x8000) + mov_ax(S_TSS0) + LTR_AX + mov_ax(S_LDT) + LLDT_AX)

    def put(self, address, data):
        for i, b in enumerate(data):
            self.mem[(address + i) & 0xffffff] = b

    def gdt(self, selector, data): self.put(GDT + (selector & ~7), data)
    def idt(self, vector, data): self.put(IDT + 8 * vector, data)

    def ring0(self, body):
        """Run body at CPL 0 after the standard init; HLT is appended."""
        self.put(CODE0, self.init + body + HLT)
        return self

    def ring3(self, body, flags=0x0002, pre=b''):
        """Run pre at CPL 0, then IRET to CPL 3 and run body there."""
        to3 = (push_imm(S_STACK3 | 3) + push_imm(0x8000) + push_imm(flags) +
               push_imm(S_CODE3 | 3) + push_imm(0) + IRET)
        self.put(CODE0, self.init + pre + to3 + HLT)
        self.put(CODE3, body + HLT)
        return self

    def run(self, cpl, body, flags=0x0002, pre=b''):
        if cpl == 0:
            # Load the requested IOPL/flags image with POPF at CPL 0.
            return self.ring0(pre + (push_imm(flags) + POPF if flags != 0x0002 else b'') + body)
        return self.ring3(body, flags, pre)

    def text(self, name):
        lines = [f'NAME {name}', f'STEPS {self.steps}']
        run_start, run = None, []
        for address in sorted(self.mem):
            if run_start is not None and address == run_start + len(run) and len(run) < 256:
                run.append(self.mem[address])
            else:
                if run: lines.append(f'MEM {run_start:x} ' + bytes(run).hex())
                run_start, run = address, [self.mem[address]]
        if run: lines.append(f'MEM {run_start:x} ' + bytes(run).hex())
        return '\n'.join(lines) + '\n'


FAMILIES = {}


def family(function):
    FAMILIES[function.__name__] = function
    return function


# Access bytes: (label, type bits with S, i.e. access & 0x1f).
SEGMENT_TYPES = [('data_ro', 0x10), ('data_rw', 0x12), ('data_down_rw', 0x16), ('code_x', 0x18),
                 ('code_xr', 0x1a), ('code_conf_x', 0x1c), ('code_conf_xr', 0x1e)]
SYSTEM_TYPES = [('sys0', 0x00), ('tss_avail', 0x01), ('ldt', 0x02), ('tss_busy', 0x03),
                ('callgate', 0x04), ('taskgate', 0x05), ('intgate', 0x06), ('trapgate', 0x07),
                ('sys8', 0x08)]


def access(type_bits, dpl, present=True):
    return type_bits | (dpl << 5) | (0x80 if present else 0)


@family
def seg_load():
    """MOV DS/ES/SS with every descriptor class, DPL, presence, RPL and CPL."""
    for reg, load in (('ds', MOV_DS_AX), ('es', MOV_ES_AX), ('ss', MOV_SS_AX)):
        for label, bits in SEGMENT_TYPES + SYSTEM_TYPES[:3]:
            for dpl in (0, 3):
                for present in (True, False):
                    for rpl in (0, 3):
                        for cpl in (0, 3):
                            e = Env()
                            e.gdt(T0, desc(0x0fff, DATA3, access(bits, dpl, present)))
                            e.run(cpl, mov_ax(T0 | rpl) + load + NOP)
                            yield f'seg_load.{reg}.{label}.dpl{dpl}.p{int(present)}.rpl{rpl}.cpl{cpl}', e
        for label, selector in (('null', 0), ('null_rpl3', 3), ('gdt_limit', 0x88), ('ldt_data', 0x0c),
                                ('ldt_limit', 0x44), ('ldt_data3', 0x1f)):
            for cpl in (0, 3):
                e = Env()
                use = b'\xa1\x00\x00' if reg == 'ds' else b'\x26\xa1\x00\x00' if reg == 'es' else b''
                e.run(cpl, mov_ax(selector) + load + NOP + use)
                yield f'seg_load.{reg}.{label}.cpl{cpl}', e


def far_targets():
    """(label, setup(env) -> selector) for far JMP/CALL destinations."""
    for label, bits in SEGMENT_TYPES:
        for dpl in (0, 3):
            for present in (True, False):
                def setup(e, bits=bits, dpl=dpl, present=present):
                    e.gdt(T0, desc(0xffff, CODE3 if dpl == 3 else CODE0, access(bits, dpl, present)))
                    return T0
                yield f'{label}.dpl{dpl}.p{int(present)}', setup
    for label, bits in SYSTEM_TYPES:
        if bits in (0x01, 0x03, 0x04, 0x05):
            continue
        def setup(e, bits=bits):
            e.gdt(T0, desc(0xffff, CODE0, access(bits, 3)))
            return T0
        yield label, setup
    # Call gates: gate DPL/presence, then target variations.
    for gdpl in (0, 3):
        for present in (True, False):
            for tlabel, taccess, tsel in (('code0', 0x9a, S_CODE0), ('code3', 0xfa, T1 | 3), ('conf0', 0x9e, T1),
                                          ('data', 0x92, T1), ('code0_np', 0x1a, T1), ('null', 0x9a, 0)):
                def setup(e, gdpl=gdpl, present=present, taccess=taccess, tsel=tsel):
                    e.gdt(T1, desc(0xffff, CODE3 if taccess == 0xfa else CODE0, taccess))
                    e.gdt(T0, gate(0x0a00, tsel, access(0x04, gdpl, present), count=0xe2, tail=0xa55a))
                    return T0
                yield f'callgate.dpl{gdpl}.p{int(present)}.{tlabel}', setup
    # Task state segments and task gates.
    for label, taccess, limit in (('tss_avail', 0x81, 0x2b), ('tss_avail_dpl3', 0xe1, 0x2b), ('tss_busy', 0x83, 0x2b),
                                  ('tss_np', 0x01, 0x2b), ('tss_short', 0x81, 0x2a)):
        def setup(e, taccess=taccess, limit=limit):
            e.gdt(S_TSS1, desc(limit, TSS1, taccess, tail=0xa55a))
            return S_TSS1
        yield label, setup
    for label, gaccess, target in (('taskgate', 0x85, S_TSS1), ('taskgate_dpl3', 0xe5, S_TSS1),
                                   ('taskgate_np', 0x05, S_TSS1), ('taskgate_null', 0x85, 0),
                                   ('taskgate_ldt_sel', 0x85, S_TSS1 | 4), ('taskgate_to_code', 0x85, S_CODE0)):
        def setup(e, gaccess=gaccess, target=target):
            e.gdt(S_TGATE, gate(0x1234, target, gaccess, count=0xff, tail=0x5aa5))
            return S_TGATE
        yield label, setup


@family
def far_xfer():
    """Far JMP and CALL to every destination class, by selector RPL and CPL."""
    for op, encode in (('jmp', jmp_far), ('call', call_far)):
        for label, setup in far_targets():
            for rpl in (0, 3):
                for cpl in (0, 3):
                    e = Env()
                    selector = setup(e)
                    for base in (CODE0, CODE3):
                        e.put(base + 0x0a00, HLT)
                        e.put(base + 0x0500, HLT)
                    e.run(cpl, encode(selector | rpl, 0x0500))
                    yield f'far_xfer.{op}.{label}.rpl{rpl}.cpl{cpl}', e
        for label, selector in (('null', 0), ('gdt_limit', 0x88), ('ldt_code', 0x14), ('ldt_limit', 0x44)):
            for cpl in (0, 3):
                e = Env()
                e.put(CODE0 + 0x0500, HLT)
                e.run(cpl, encode(selector, 0x0500))
                yield f'far_xfer.{op}.{label}.cpl{cpl}', e


@family
def int_gate():
    """INT n through every gate class, gate DPL, presence and handler segment."""
    for glabel, gbits in (('intgate', 0x06), ('trapgate', 0x07), ('callgate', 0x04), ('sys0', 0x00), ('tss', 0x01)):
        for gdpl in (0, 3):
            for present in (True, False):
                for hlabel, haccess, hsel in (('code0', 0x9a, T0), ('code3', 0xfa, T0 | 3), ('conf0', 0x9e, T0),
                                              ('data', 0x92, T0), ('np', 0x1a, T0), ('null', 0x9a, 0),
                                              ('limit', 0x9a, 0x88)):
                    for cpl in (0, 3):
                        e = Env()
                        e.gdt(T0, desc(0xffff, CODE3 if haccess == 0xfa else CODE0, haccess))
                        e.idt(0x2a, gate(0x0a00, hsel, access(gbits, gdpl, present), count=0xff, tail=0xa55a))
                        for base in (CODE0, CODE3):
                            e.put(base + 0x0a00, HLT)
                        e.run(cpl, int_n(0x2a), flags=0x0302 if cpl == 0 else 0x3302)
                        yield f'int_gate.{glabel}.dpl{gdpl}.p{int(present)}.{hlabel}.cpl{cpl}', e
    for label, gaccess, target, taccess in (('taskgate', 0x85, S_TSS1, 0x81), ('taskgate_dpl3', 0xe5, S_TSS1, 0x81),
                                            ('taskgate_busy', 0xe5, S_TSS1, 0x83),
                                            ('taskgate_np_tss', 0xe5, S_TSS1, 0x01),
                                            ('taskgate_null', 0xe5, 0, 0x81), ('taskgate_ldt', 0xe5, S_TSS1 | 4, 0x81)):
        for cpl in (0, 3):
            e = Env()
            e.gdt(S_TSS1, desc(0x2b, TSS1, taccess, tail=0x5aa5))
            e.idt(0x2a, gate(0x4321, target, gaccess, count=0xff, tail=0xa55a))
            e.run(cpl, int_n(0x2a))
            yield f'int_gate.{label}.cpl{cpl}', e
    for label, limit in (('idt_limit_in', 0x2a * 8 + 7), ('idt_limit_out', 0x2a * 8 + 6)):
        for cpl in (0, 3):
            e = Env()
            e.put(0x46, w16(limit))
            e.run(cpl, int_n(0x2a))
            yield f'int_gate.{label}.cpl{cpl}', e


TSS2 = 0x2200


def stack_fault_tasks(e, handler_accessed=True):
    """Deliver #SS (12) and #DF (8) through task gates on their own stacks.

    A CPL-0 stack fault would otherwise be delivered on the faulting stack,
    escalate to #DF and shut down, so the first fault's vector and error code
    would never be compared. #SS switches to TSS1 (0008:0900), #DF to TSS2
    (0008:0904); the error code lands on that task's stack and the outgoing
    TSS0 image records the faulting CS:IP and SS:SP.

    handler_accessed presets the accessed bit of the 0038 handler CS. Whether
    a delivery that later faults on its frame has already set that bit is
    not defined by Intel (see spec/protected_mode_integration.md A19); the
    *.abit.* scenarios exercise that order separately.
    """
    e.idt(12, gate(0, S_TSS1, 0x85))
    e.gdt(T3, desc(0x002b, TSS2, 0x81))
    image = [0x0904, 0x0002, 0x1111, 0x2222, 0x3333, 0x4444, 0x6000, 0x5555, 0x6666, 0x7777,
             S_DATA0, S_CODE0, S_STACK0, S_DATA0, S_LDT]
    e.put(TSS2 + 2, w16(0xd000) + w16(S_STACK0))
    e.put(TSS2 + 14, b''.join(w16(v) for v in image))
    e.put(CODE0 + 0x0904, HLT)
    e.idt(8, gate(0, T3, 0x85))
    if handler_accessed:
        e.gdt(S_HANDLER, desc(0xffff, HANDLER, 0x9b))
    return e


@family
def stack_frames():
    """Frames pushed near the ends of the stack segment."""
    for sp in (0x0000, 0x0001, 0x0002, 0x0004, 0x0005, 0x0006, 0x0008, 0x0100):
        for limit in (0xffff, 0x00ff, 0x7fff):
            for op, body in (('int', int_n(0x2a)), ('callfar', call_far(S_HANDLER, 0x2a * 4)),
                             ('push', b'\x50'), ('pusha', b'\x60'), ('callnear', b'\xe8\x00\x00'),
                             ('fault_gp', mov_ax(0x88) + MOV_DS_AX)):
                e = stack_fault_tasks(Env())
                e.gdt(S_BIGSTACK, desc(limit, BIGSTACK, 0x92))
                e.ring0(mov_ax(S_BIGSTACK) + MOV_SS_AX + mov_sp(sp) + body)
                yield f'stack_frames.{op}.sp{sp:04x}.limit{limit:04x}', e
    # Accessed-bit order: the handler CS starts not accessed and its
    # delivery frame then faults (waived; Intel does not define the order).
    for op, body in (('int', int_n(0x2a)), ('fault_gp', mov_ax(0x88) + MOV_DS_AX)):
        e = stack_fault_tasks(Env(), handler_accessed=False)
        e.gdt(S_BIGSTACK, desc(0x00ff, BIGSTACK, 0x92))
        e.ring0(mov_ax(S_BIGSTACK) + MOV_SS_AX + mov_sp(0x0002) + body)
        yield f'stack_frames.abit.{op}.sp0002.limit00ff', e
    for sp0 in (0x0000, 0x0002, 0x0008, 0x000a, 0x000c, 0x0100):
        for op, body in (('int', int_n(0x2a)), ('fault_gp', b'\xfa')):
            # Preset the inner SS accessed bit too: it is loaded before the
            # inner frame room check that faults (same undefined order).
            e = stack_fault_tasks(Env())
            e.gdt(S_BIGSTACK, desc(0xffff, BIGSTACK, 0x93))
            e.put(TSS0 + 2, w16(sp0) + w16(S_BIGSTACK))
            e.ring3(body)
            yield f'stack_frames.inner.{op}.sp0_{sp0:04x}', e
    e = stack_fault_tasks(Env(), handler_accessed=False)
    e.put(TSS0 + 2, w16(0x0002) + w16(S_BIGSTACK))
    e.ring3(b'\xfa')
    yield 'stack_frames.abit.inner.fault_gp.sp0_0002', e


@family
def far_return():
    """RETF/IRET from CPL 0 over hand-built frames: CS, SS and stack-extent cases."""
    cs_cases = [('same', S_CODE0, None), ('outer3', S_CODE3 | 3, None), ('rpl3_dpl0', S_CODE0 | 3, None),
                ('null', 0, None), ('null_rpl3', 3, None), ('data', S_DATA3 | 3, None), ('limit', 0x8b, None),
                ('np', T0 | 3, 0x7a), ('conf_dpl0', T0 | 3, 0x9e), ('conf_dpl3', T0 | 3, 0xfe),
                ('dpl0_code', T0 | 3, 0x9a)]
    ss_cases = [('ok', S_STACK3 | 3, None), ('null', 0, None), ('rpl0', S_STACK3, None), ('code', S_CODE3 | 3, None),
                ('dpl0', S_STACK0 | 3, None), ('np', T1 | 3, 0x72), ('ro', T1 | 3, 0xf0), ('limit', 0x8b, None)]
    for op, tail in (('retf', RETF), ('retf4', retf_n(4)), ('iret', IRET)):
        def frame_for(cs, ss):
            frame = w16(0x0600) + w16(cs) + (w16(0x0002) if op == 'iret' else b'')
            return frame + (b'\x11\x11\x22\x22' if op == 'retf4' else b'') + w16(0x9000) + w16(ss)
        for clabel, cs, caccess in cs_cases:
            for slabel, ss, saccess in (ss_cases if clabel in ('outer3', 'conf_dpl3') else ss_cases[:1]):
                e = Env()
                if caccess is not None: e.gdt(T0, desc(0xffff, CODE3, caccess))
                if saccess is not None: e.gdt(T1, desc(0xffff, STACK3, saccess))
                if slabel != 'ok':
                    # The SS check faults after a valid return CS was read.
                    # Preset its accessed bit: Intel does not define whether
                    # that bit is set before a later SS fault (A-bit order is
                    # exercised by far_return.abit.*, waived).
                    if clabel == 'outer3': e.gdt(S_CODE3, desc(0xffff, CODE3, 0xfb))
                    else: e.gdt(T0, desc(0xffff, CODE3, caccess | 1))
                e.put(CODE3 + 0x0600, HLT); e.put(CODE0 + 0x0600, HLT)
                e.put(STACK0 + 0x7000, frame_for(cs, ss))
                e.ring0(mov_sp(0x7000) + tail)
                yield f'far_return.{op}.cs_{clabel}.ss_{slabel}', e
        e = Env()
        e.gdt(T1, desc(0xffff, STACK3, 0x72))
        e.put(CODE3 + 0x0600, HLT)
        e.put(STACK0 + 0x7000, frame_for(S_CODE3 | 3, T1 | 3))
        e.ring0(mov_sp(0x7000) + tail)
        yield f'far_return.abit.{op}.ss_np', e
        for sp in (0xfff0, 0xfff6, 0xfff8, 0xfffa, 0xfffc, 0xfffe):
            for target in (S_CODE0, S_CODE3 | 3):
                e = Env()
                e.put(CODE3 + 0x0600, HLT); e.put(CODE0 + 0x0600, HLT)
                for i, b in enumerate(frame_for(target, S_STACK3 | 3)):
                    if sp + i <= 0xffff: e.put(BIGSTACK + sp + i, bytes([b]))
                e.ring0(mov_ax(S_BIGSTACK) + MOV_SS_AX + mov_sp(sp) + tail)
                yield f'far_return.{op}.sp{sp:04x}.cs{target:02x}', e


@family
def selector_query():
    """LAR, LSL, VERR, VERW and ARPL over descriptor classes, DPL, RPL and CPL."""
    for op, code in (('lar', LAR_BX_AX), ('lsl', LSL_BX_AX), ('verr', VERR_AX), ('verw', VERW_AX)):
        for label, bits in SEGMENT_TYPES + SYSTEM_TYPES:
            for dpl in (0, 3):
                for rpl in (0, 3):
                    for cpl in (0, 3):
                        e = Env()
                        e.gdt(T0, desc(0x1234, DATA3, access(bits, dpl)))
                        e.run(cpl, mov_r(3, 0xbbbb) + mov_ax(T0 | rpl) + code + NOP)
                        yield f'selector_query.{op}.{label}.dpl{dpl}.rpl{rpl}.cpl{cpl}', e
        for label, selector in (('null', 0), ('gdt_limit', 0x88), ('ldt_data', 0x0c), ('ldt_limit', 0x44)):
            e = Env()
            e.ring0(mov_r(3, 0xbbbb) + mov_ax(selector) + code + NOP)
            yield f'selector_query.{op}.{label}', e
    for dst in (0x0060, 0x0061, 0x0062, 0x0063, 0x0000, 0x0003):
        for src in (0x0000, 0x0001, 0x0002, 0x0003, 0x0010):
            for cpl in (0, 3):
                e = Env()
                e.run(cpl, mov_ax(dst) + mov_r(3, src) + ARPL_AX_BX + NOP)
                yield f'selector_query.arpl.dst{dst:04x}.src{src:04x}.cpl{cpl}', e


@family
def system_ops():
    """LLDT, LTR, SLDT, STR, LMSW, SMSW, CLTS, LGDT, LIDT, SGDT, SIDT and HLT by CPL."""
    for label, bits in SEGMENT_TYPES[:2] + SYSTEM_TYPES:
        for present in (True, False):
            for op, code in (('lldt', LLDT_AX), ('ltr', LTR_AX)):
                e = Env()
                e.gdt(T0, desc(0x003f, LDT, access(bits, 0, present), tail=0x5aa5))
                e.ring0(mov_ax(T0) + code + SLDT_AX + b'\x89\xc1' + STR_AX)
                yield f'system_ops.{op}.{label}.p{int(present)}', e
    for op, code in (('lldt', LLDT_AX), ('ltr', LTR_AX)):
        for label, selector in (('null', 0), ('null_rpl3', 3), ('ti', T0 | 4), ('gdt_limit', 0x88)):
            e = Env()
            e.gdt(T0, desc(0x003f, LDT, 0x82 if op == 'lldt' else 0x81))
            e.ring0(mov_ax(selector) + code + NOP)
            yield f'system_ops.{op}.{label}', e
    bodies = [('lldt', mov_ax(S_LDT) + LLDT_AX), ('ltr', mov_ax(S_TSS1) + LTR_AX), ('sldt', SLDT_AX),
              ('str', STR_AX), ('lmsw', mov_ax(0x000f) + LMSW_AX + SMSW_AX),
              ('lmsw_clear_pe', mov_ax(0) + LMSW_AX + SMSW_AX), ('smsw', SMSW_AX), ('clts', CLTS + SMSW_AX),
              ('lgdt', b'\x0f\x01\x16\x40\x00'), ('lidt', b'\x0f\x01\x1e\x46\x00'),
              ('sgdt', b'\x0f\x01\x06\x00\x01' + b'\xa1\x00\x01'), ('sidt', b'\x0f\x01\x0e\x00\x01' + b'\xa1\x00\x01'),
              ('hlt', HLT), ('lgdt_reg', b'\x0f\x01\xd0'), ('sgdt_reg', b'\x0f\x01\xc0')]
    for op, code in bodies:
        for cpl in (0, 3):
            e = Env()
            pre = mov_ax(S_DATA3 | 3) + MOV_DS_AX if cpl == 3 else b''
            e.run(cpl, pre + code + NOP)
            yield f'system_ops.{op}.cpl{cpl}', e


@family
def iopl():
    """IOPL-sensitive instructions and POPF/IRET flag loading, CPL 0/3 by IOPL 0..3."""
    bodies = [('in', b'\xe4\x10'), ('out', b'\xe6\x10'), ('in_dx', b'\xba\x10\x00\xec'),
              ('out_dx', b'\xba\x10\x00\xee'), ('insb', b'\xba\x10\x00\x6c'), ('outsb', b'\xba\x10\x00\x6e'),
              ('cli', CLI), ('sti', STI), ('lock_nop', b'\xf0\x90'), ('lock_xchg', b'\xf0\x87\x06\x00\x01'),
              ('pushf', PUSHF + b'\x58'), ('popf_all', push_imm(0xffff) + POPF + PUSHF + b'\x58'),
              ('popf_zero', push_imm(0) + POPF + PUSHF + b'\x58')]
    for op, code in bodies:
        for level in range(4):
            for cpl in (0, 3):
                e = Env()
                pre = (mov_ax(S_DATA3 | 3) + MOV_DS_AX + MOV_ES_AX) if cpl == 3 else b''
                e.run(cpl, pre + code + NOP, flags=0x0202 | (level << 12))
                yield f'iopl.{op}.iopl{level}.cpl{cpl}', e
    for image in (0x0002, 0x7fd7, 0x3202, 0x4002, 0x0302):
        for level in (0, 3):
            e = Env()
            e.put(CODE3 + 0x0600, PUSHF + b'\x58' + HLT)
            body = (push_imm(S_STACK3 | 3) + push_imm(0x8000) + push_imm(image) +
                    push_imm(S_CODE3 | 3) + push_imm(0x0600) + IRET)
            e.ring3(body, flags=0x0202 | (level << 12))
            yield f'iopl.iret3_same.flags{image:04x}.iopl{level}', e


@family
def limits():
    """Operand accesses at segment-limit edges, write/execute permissions, SS versus DS faults."""
    forms = [('rd_byte', lambda o: b'\xa0' + w16(o)), ('rd_word', lambda o: b'\xa1' + w16(o)),
             ('wr_byte', lambda o: b'\xa2' + w16(o)), ('wr_word', lambda o: b'\xa3' + w16(o)),
             ('rmw_word', lambda o: b'\xff\x06' + w16(o)), ('es_rd_word', lambda o: b'\x26\xa1' + w16(o)),
             ('cs_rd_word', lambda o: b'\x2e\xa1' + w16(o)), ('cs_wr_word', lambda o: b'\x2e\xa3' + w16(o))]
    for tlabel, taccess in (('rw', 0x92), ('ro', 0x90), ('down_rw', 0x96), ('code_x', 0x98), ('code_xr', 0x9a)):
        for offset in (0x00fe, 0x00ff, 0x0100, 0x0101, 0xfffe, 0xffff, 0x0000):
            for flabel, form in forms:
                if flabel.startswith('cs_') and tlabel != 'rw':
                    continue
                e = Env()
                e.gdt(T0, desc(0x00ff, DATA3, taccess))
                e.ring0(mov_ax(T0) + MOV_DS_AX + MOV_ES_AX + form(offset) + NOP)
                yield f'limits.{tlabel}.{flabel}.off{offset:04x}', e
    for tlabel, taccess, limit in (('up', 0x92, 0x00ff), ('down', 0x96, 0x00ff), ('ro', 0x90, 0xffff)):
        for sp in (0x0100, 0x0101, 0x0102, 0x00ff, 0x0002, 0x0001, 0x0000):
            for flabel, code in (('push', b'\x50'), ('pop', b'\x58'), ('bp_rd', b'\x89\xe5\x8b\x46\x00'),
                                 ('bp_wr', b'\x89\xe5\x89\x46\x00'), ('enter', b'\xc8\x04\x00\x00'),
                                 ('leave', b'\x89\xe5\xc9'), ('popa', b'\x61'), ('ss_rd', b'\x36\xa1\x00\x01')):
                e = stack_fault_tasks(Env())
                e.gdt(T0, desc(limit, BIGSTACK, taccess))
                e.ring0(mov_ax(T0) + MOV_SS_AX + mov_sp(sp) + code + NOP)
                yield f'limits.stack_{tlabel}.{flabel}.sp{sp:04x}', e
    for limit in (0x0500, 0x0501, 0x0502, 0x0503, 0x0504):
        e = Env()
        e.gdt(T0, desc(limit, CODE0, 0x9a))
        e.put(CODE0 + 0x0500, mov_ax(0x1234) + NOP + HLT)
        e.ring0(jmp_far(T0, 0x0500))
        yield f'limits.cs_fetch.limit{limit:04x}', e


@family
def tasks():
    """Task switches by JMP, CALL, INT and NT IRET, with incoming-state faults."""
    variants = [('ok', {}), ('ldt_bad', {14: 0x0010}), ('ldt_null', {14: 0}), ('cs_null', {11: 0}),
                ('cs_data', {11: S_DATA0}), ('cs_np', {11: T0}), ('ss_null', {12: 0}),
                ('ss_rpl3', {12: S_STACK0 | 3}), ('ss_code', {12: S_CODE0}), ('ds_code_x', {13: T1}),
                ('es_limit', {10: 0x88}), ('ip_limit', {0: 0xffff, 11: T2}),
                ('cs3_ss3', {11: S_CODE3 | 3, 12: S_STACK3 | 3, 13: S_DATA3 | 3, 10: S_DATA3 | 3}),
                ('nt_flags', {1: 0x4202})]
    for op, body in (('jmp_tss', jmp_far(S_TSS1, 0)), ('call_tss', call_far(S_TSS1, 0)),
                     ('jmp_gate', jmp_far(S_TGATE, 0)), ('call_gate', call_far(S_TGATE, 0)),
                     ('int_gate', int_n(0x2a))):
        for label, patch in variants:
            e = Env(steps=600)
            e.gdt(T0, desc(0xffff, CODE0, 0x1a))
            e.gdt(T1, desc(0xffff, DATA0, 0x98))
            e.gdt(T2, desc(0x0fff, CODE0, 0x9a))
            e.idt(0x2a, gate(0, S_TSS1, 0xe5))
            for index, value in patch.items():
                e.put(TSS1 + 14 + 2 * index, w16(value))
            e.put(CODE3 + 0x0900, HLT)
            e.ring0(mov_r(3, 0xb0b0) + mov_r(6, 0x5151) + body + NOP)
            yield f'tasks.{op}.{label}', e
    # The same incoming-task faults with #TS/#NP/#SS/#GP each routed through a
    # task gate to its own handler task (vector v: TSS at 2200+40h*(v-10),
    # selector 88h+8*(v-10), starts at 0008:0A00+4v, a HLT). The handler then
    # needs no stack in the faulting task, so the vector (final IP), the error
    # code (pushed on the handler task's stack) and the faulting task's saved
    # image (written to TSS1) are compared even where that task's SS is
    # invalid or not yet validated. es_limit uses 00A8, beyond the GDT.
    for op, body in (('jmp_tss', jmp_far(S_TSS1, 0)), ('call_tss', call_far(S_TSS1, 0)),
                     ('jmp_gate', jmp_far(S_TGATE, 0)), ('call_gate', call_far(S_TGATE, 0)),
                     ('int_gate', int_n(0x2a))):
        for label, patch in variants:
            if label in ('ok', 'ldt_null', 'cs3_ss3', 'nt_flags'):
                continue
            e = Env(steps=600, gdt_limit=0xa7)
            e.gdt(T0, desc(0xffff, CODE0, 0x1a))
            e.gdt(T1, desc(0xffff, DATA0, 0x98))
            e.gdt(T2, desc(0x0fff, CODE0, 0x9a))
            e.idt(0x2a, gate(0, S_TSS1, 0xe5))
            for vector in (10, 11, 12, 13):
                tss, sel = 0x2200 + 0x40 * (vector - 10), 0x88 + 8 * (vector - 10)
                e.gdt(sel, desc(0x002b, tss, 0x81))
                e.idt(vector, gate(0, sel, 0x85))
                e.put(tss + 14, b''.join(w16(v) for v in (
                    0x0a00 + 4 * vector, 0x0002, 0xa1, 0xa2, 0xa3, 0xa4, 0x6000, 0xa5, 0xa6, 0xa7,
                    S_DATA0, S_CODE0, S_STACK0, S_DATA0, 0)))
                e.put(CODE0 + 0x0a00 + 4 * vector, HLT)
            for index, value in patch.items():
                e.put(TSS1 + 14 + 2 * index, w16(0xa8 if label == 'es_limit' else value))
            e.put(CODE3 + 0x0900, HLT)
            e.ring0(mov_r(3, 0xb0b0) + mov_r(6, 0x5151) + body + NOP)
            yield f'tasks.{op}.{label}.tsgate', e
    # Nested task returns: the second task edits its own back link through ES
    # (selector T3 maps TSS1 as data) before IRET.
    links = [('ok', b''), ('null', mov_ax(0) + b'\x26\xa3\x00\x00'), ('ldt', mov_ax(S_TSS0 | 4) + b'\x26\xa3\x00\x00'),
             ('limit', mov_ax(0x88) + b'\x26\xa3\x00\x00'), ('to_code', mov_ax(S_CODE0) + b'\x26\xa3\x00\x00'),
             ('self', mov_ax(S_TSS1) + b'\x26\xa3\x00\x00')]
    for label, code in (('call_iret', call_far(S_TSS1, 0)), ('int_iret', int_n(0x2a))):
        for link, edit in links:
            e = Env(steps=600)
            e.idt(0x2a, gate(0, S_TSS1, 0xe5))
            e.gdt(T3, desc(0x002b, TSS1, 0x92))
            e.put(TSS1 + 14 + 2 * 10, w16(T3))
            e.put(CODE0 + 0x0900, edit + IRET + HLT)
            e.ring0(code + mov_r(2, 0xd00d) + NOP)
            yield f'tasks.{label}.link_{link}', e


@family
def npx_msw():
    """WAIT and ESC against the MSW MP/EM/TS bits in protected mode."""
    for msw in range(8):
        for op, code in (('wait', b'\x9b'), ('esc_reg', b'\xd9\xd0'), ('esc_mem', b'\xdd\x06\x00\x01')):
            e = Env()
            e.ring0(mov_ax((msw << 1) | 1) + LMSW_AX + code + NOP)
            yield f'npx_msw.{op}.msw{msw}', e


@family
def review_2026_11_09():
    """The protected-transfer rules changed by the 2026-11-09 review."""
    e = Env(); e.gdt(T0, desc(0xffff, CODE0, 0x1a)); e.ring0(call_far(T0, 0x0500))
    yield 'review.call_np_code', e
    e = Env(); e.gdt(T0, desc(0xffff, CODE0, 0x1a)); e.ring0(jmp_far(T0, 0x0500))
    yield 'review.jmp_np_code', e
    for level in range(4):
        e = Env(); e.ring3(b'\xf0\x90', flags=0x0202 | (level << 12))
        yield f'review.lock_cpl3.iopl{level}', e
    for unused, tail in ((0x00, 0x0000), (0xff, 0xa55a)):
        for gbits in (0x06, 0x07):
            e = Env()
            e.idt(0x2a, gate(0x0a00, S_CODE0, access(gbits, 3), count=unused, tail=tail))
            e.put(CODE0 + 0x0a00, HLT)
            e.ring0(int_n(0x2a))
            yield f'review.gate{gbits}.unused{unused:02x}.tail{tail:04x}', e


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('outdir')
    parser.add_argument('-k', default='*', help='fnmatch pattern on scenario names')
    args = parser.parse_args()
    out = Path(args.outdir)
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob('*.scn'):
        old.unlink()
    seen, count = set(), 0
    for name in sorted(FAMILIES):
        for scenario, env in FAMILIES[name]():
            if scenario in seen:
                raise ValueError(f'duplicate scenario name: {scenario}')
            seen.add(scenario)
            if fnmatch.fnmatch(scenario, args.k):
                (out / f'{scenario}.scn').write_text(env.text(scenario))
                count += 1
    print(f'generated {count} scenarios from {len(FAMILIES)} families')


if __name__ == '__main__':
    main()
