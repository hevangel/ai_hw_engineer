#!/usr/bin/env python3
"""Independent shared-ISA oracle: Unicorn 2.1.4, never a translated RTL model.

Intel 210498-005 defines the undefined-bit masks and 286 count masking.
The oracle supplies results, flags, decoded sizes, and actual next PCs.
"""
import hashlib
import json
from pathlib import Path
import random
import sys

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
sys.path.insert(0, str(WORK_ROOT / 'oracle'))
import unicorn
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_HOOK_INSN
from unicorn.x86_const import (
    UC_X86_REG_AX, UC_X86_REG_CX, UC_X86_REG_DX, UC_X86_REG_BX,
    UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_SI, UC_X86_REG_DI,
    UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS,
    UC_X86_REG_IP, UC_X86_REG_EFLAGS,
    UC_X86_INS_IN, UC_X86_INS_OUT,
)

REGS = [UC_X86_REG_AX, UC_X86_REG_CX, UC_X86_REG_DX, UC_X86_REG_BX,
        UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_SI, UC_X86_REG_DI]
SEGS = [UC_X86_REG_ES, UC_X86_REG_CS, UC_X86_REG_SS, UC_X86_REG_DS]
SEED = 0x802862A
EDGES = [0, 1, 0xf, 0x10, 0x7f, 0x80, 0xff, 0x100, 0x7fff, 0x8000, 0xffff]
RNG = random.Random(SEED)


def word(value):
    return bytes([value & 255, (value >> 8) & 255])


class Generator:
    def __init__(self, out):
        if unicorn.__version__ != '2.1.4':
            raise ValueError('Expected pinned Unicorn 2.1.4')
        self.out = out
        self.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc.mem_map(0, 0x200000)
        self.seen = []
        self.active_code_hook=None
        self.uc.hook_add(UC_HOOK_CODE,self.code_hook)
        self.cases = self.steps = 0
        self.families = {}
        self.bus = []
        self.shadow = {}
        self.dirty = set()
        self.ports = {}
        self.read_hook_handle=self.uc.hook_add(UC_HOOK_MEM_READ, self.read_hook)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.write_hook)
        self.uc.hook_add(UC_HOOK_INSN, self.in_hook, None, 1, 0, UC_X86_INS_IN)
        self.uc.hook_add(UC_HOOK_INSN, self.out_hook, None, 1, 0, UC_X86_INS_OUT)

    def code_hook(self,uc,address,size,data):
        if self.active_code_hook is None: self.seen.append((address,size))
        else: self.active_code_hook(uc,address,size)

    def continuous_case(self,prefix,instruction,masks,limit,regions):
        # Segment-changing returns are sampled at the actual next code hook,
        # avoiding stale IP values returned by count=1 emulation boundaries.
        pending=None; completed=0; mask=0xffff; ax_mask=0xffff
        def finish(next_ip):
            nonlocal pending,completed,mask,ax_mask
            pc,op,size,index=pending
            if index<len(prefix) and size!=len(prefix[index]): raise ValueError('Independent prefix decode mismatch')
            if index==len(prefix):
                if size!=len(instruction): raise ValueError('Independent target decode mismatch')
                mask &= masks
                if op==0x9f: ax_mask &= ~0x2a00
            flags=self.uc.reg_read(UC_X86_REG_EFLAGS)&65535
            regs=[self.uc.reg_read(r) for r in REGS]
            segs=sum(self.uc.reg_read(r)<<(16*n) for n,r in enumerate(SEGS))
            values=[pc,op,next_ip,flags,mask,segs,ax_mask]+regs
            self.out.write('STEP '+' '.join(f'{v:x}' for v in values)+'\n')
            self.out.write(f'FETCH {pc:x} {size:x}\n')
            for transfer in self.bus: self.out.write('BUS '+' '.join(f'{v:x}' for v in transfer)+'\n')
            self.out.write('CHECK\n'); self.steps+=1; completed+=1; pending=None
        def code_hook(uc,address,size):
            nonlocal pending
            if pending is not None:
                finish((address-uc.reg_read(UC_X86_REG_CS)*16)&65535)
                if completed>=limit: uc.emu_stop(); return
            if not any(start<=address and address+size<=end for start,end in regions):
                raise ValueError(f'Independent oracle executed unprovided code at {address:x}')
            op=self.shadow.get(address,0); n=0; override=None
            while op in (0x26,0x2e,0x36,0x3e):
                override=op; n+=1; op=self.shadow.get(address+n,0)
            pending=(address,op,size,completed); self.bus.clear()
            # Unicorn 2.1.4's read-hook instrumentation itself corrupts RETF/
            # IRET, even with an empty callback. Architectural execution below
            # has that hook disabled. Intel B-23/B-94/B-51 supply the explicit
            # pointer/frame read contracts for these narrowly defined fixtures.
            if op in (0xca,0xcb,0xcf):
                first=uc.reg_read(UC_X86_REG_SS)*16+uc.reg_read(UC_X86_REG_SP)
                self.bus.extend((first+i,self.shadow.get(first+i,0),0,0) for i in range(6 if op==0xcf else 4))
            elif op==0xff:
                modrm=self.shadow.get(address+n+1,0)
                if modrm&0xc7!=6 or (modrm>>3)&7 not in (3,5): raise ValueError('Unsupported far bus-contract fixture')
                segment_reg={None:UC_X86_REG_DS,0x26:UC_X86_REG_ES,0x2e:UC_X86_REG_CS,0x36:UC_X86_REG_SS,0x3e:UC_X86_REG_DS}[override]
                offset=self.shadow.get(address+n+2,0)|(self.shadow.get(address+n+3,0)<<8)
                first=uc.reg_read(segment_reg)*16+offset
                self.bus.extend((first+i,self.shadow.get(first+i,0),0,0) for i in range(4))
        self.active_code_hook=code_hook
        self.uc.hook_del(self.read_hook_handle)
        try:
            self.uc.emu_start(0x1000,0,count=limit+1)
            if pending is not None:
                if pending[1]!=0xf4: raise ValueError('Oracle stopped without a complete instruction boundary')
                finish((pending[0]+pending[2]-self.uc.reg_read(UC_X86_REG_CS)*16)&65535)
        finally:
            self.active_code_hook=None
            self.read_hook_handle=self.uc.hook_add(UC_HOOK_MEM_READ,self.read_hook)

    def read_hook(self, uc, access, address, size, value, data):
        # Mirror fixture bytes and oracle writes without reentrant memory APIs.
        # Far cases disable the read hook entirely; see continuous_case.
        self.bus += [(address+i, self.shadow.get(address+i,0), 0, 0) for i in range(size)]

    def write_hook(self, uc, access, address, size, value, data):
        self.bus += [(address+i, (value >> (8*i)) & 255, 1, 0) for i in range(size)]
        for i in range(size): self.shadow[address+i]=(value>>(8*i))&255
        self.dirty.update(range(address, address+size))

    def in_hook(self, uc, port, size, data):
        value = 0
        for i in range(size):
            p = (port+i) & 65535
            byte = self.ports.get(p, 0)
            self.bus.append((p, byte, 0, 1))
            value |= byte << (8*i)
        return value

    def out_hook(self, uc, port, size, value, data):
        for i in range(size):
            p = (port+i) & 65535
            self.ports[p] = (value >> (8*i)) & 255
            self.bus.append((p, self.ports[p], 1, 1))

    def normalize_ins_bus(self,wide):
        # Unicorn 2.1.4 qemu/target/i386/translate.c gen_ins deliberately writes
        # zero to probe for a page fault before consuming input. This is an
        # emulator implementation detail, not an Intel INS transfer. Validate
        # the entire probe/input/store triple before excluding only the probe.
        # https://github.com/unicorn-engine/unicorn/blob/2.1.4/qemu/target/i386/translate.c#L1326
        width=2 if wide else 1
        if len(self.bus)%(3*width): raise ValueError('Unexpected INS callback count')
        normalized=[]
        for first in range(0,len(self.bus),3*width):
            probe=self.bus[first:first+width]
            inputs=self.bus[first+width:first+2*width]
            stores=self.bus[first+2*width:first+3*width]
            for n in range(width):
                address,value,write,io=stores[n]
                if probe[n]!=(address,0,1,0) or (write,io)!=(1,0):
                    raise ValueError('Unexpected INS probe/store callback')
                port,input_value,input_write,input_io=inputs[n]
                if (input_write,input_io)!=(0,1) or input_value!=value or port!=((self.uc.reg_read(UC_X86_REG_DX)+n)&65535):
                    raise ValueError('Unexpected INS input callback')
                if address!=stores[0][0]+n: raise ValueError('Noncontiguous INS element')
            normalized.extend(inputs+stores)
        self.bus=normalized

    def case(self, family, instruction, registers=None, lowflags=None, overflow=None, masks=0xffff,
             branch=False, memory=(), ports=(), segments=False, tail=None, followup=None, direction=None):
        registers = list(registers if registers is not None else [RNG.randrange(65536) for _ in REGS])
        lowflags = RNG.randrange(256) if lowflags is None else lowflags
        overflow = RNG.randrange(2) if overflow is None else overflow
        # Establish OF independently through an arithmetic instruction, then
        # establish low status flags through SAHF. Restore every register.
        prefix = [bytes.fromhex('b0 7f' if overflow else 'b0 00'), bytes.fromhex('04 01'),
                  bytes([0xb4, lowflags]), bytes([0x9e])]
        if direction is not None: prefix.append(bytes([0xfd if direction else 0xfc]))
        if segments:
            prefix += [bytes.fromhex('b8 00 10'), bytes.fromhex('8e d8'),
                       bytes.fromhex('b8 00 20'), bytes.fromhex('8e c0'),
                       bytes.fromhex('b8 00 30'), bytes.fromhex('8e d0')]
        prefix += [bytes([0xb8+n]) + word(v) for n, v in enumerate(registers)]
        code = b''.join(prefix) + instruction + (bytes.fromhex('90 90 f4') if tail is None else tail)
        for address in self.dirty:
            self.uc.mem_write(address, b'\0')
            self.shadow[address]=0
        self.dirty.clear()
        self.ports = dict(ports)
        for address, data in memory:
            self.uc.mem_write(address, data)
            self.shadow.update((address+i,v) for i,v in enumerate(data))
            self.uc.ctl_remove_cache(address,address+len(data))
            self.dirty.update(range(address,address+len(data)))
        self.uc.mem_write(0x1000, code)
        self.shadow.update((0x1000+i,v) for i,v in enumerate(code))
        self.uc.ctl_remove_cache(0x1000, 0x2000)
        for reg in REGS + SEGS:
            self.uc.reg_write(reg, 0)
        self.uc.reg_write(UC_X86_REG_EFLAGS, 2)
        self.out.write(f'CASE {family}_{self.cases} {code.hex()}\n')
        for address, data in memory:
            self.out.write(f'MEM {address:x} {data.hex()}\n')
        for address, value in ports:
            self.out.write(f'PORT {address:x} {value:x}\n')
        self.cases += 1
        self.families[family] = self.families.get(family, 0) + 1
        if family.startswith('far_'):
            limit=len(prefix)+(followup if followup is not None else 4)
            self.continuous_case(prefix,instruction,masks,limit,
                                 [(0x1000,0x1000+len(code))]+[(address,address+len(data)) for address,data in memory])
            self.out.write('END\n'); return
        mask = 0xffff
        ax_mask = 0xffff
        pc = 0x1000
        for i in range(len(prefix) + (followup if followup is not None else 3 if branch else 4)):
            op = self.uc.mem_read(pc, 1)[0]
            prefix_offset = 0
            repeated=False
            while op in (0x26,0x2e,0x36,0x3e,0xf2,0xf3):
                repeated |= op in (0xf2,0xf3)
                prefix_offset += 1
                op = self.uc.mem_read(pc+prefix_offset,1)[0]
            self.seen.clear(); self.bus.clear()
            repetitions=0
            while True:
                self.uc.emu_start(pc, 0, count=1)
                repetitions+=1
                actual_pc=self.uc.reg_read(UC_X86_REG_CS)*16+self.uc.reg_read(UC_X86_REG_IP)
                if not repeated or actual_pc!=pc: break
                if repetitions>65536: raise ValueError('Oracle REP failed to finish within CX range')
            if len(self.seen) != repetitions or any(address!=pc for address,size in self.seen):
                raise ValueError('Oracle did not execute exactly the expected PC')
            if op in (0x6c,0x6d): self.normalize_ins_bus(op&1)
            if i < len(prefix):
                if self.seen[0][1] != len(prefix[i]):
                    raise ValueError('Independent decode disagrees with vector encoding')
            elif i == len(prefix):
                if self.seen[0][1] != len(instruction):
                    raise ValueError('Independent target instruction size mismatch')
                mask &= masks
                if op == 0x9f:
                    ax_mask &= ~0x2a00  # Intel leaves LAHF bits 5,3,1 indeterminate.
            flags = self.uc.reg_read(UC_X86_REG_EFLAGS) & 0xffff
            next_pc = self.uc.reg_read(UC_X86_REG_IP)
            regs = [self.uc.reg_read(r) for r in REGS]
            segs = sum(self.uc.reg_read(r) << (16*n) for n, r in enumerate(SEGS))
            values = [pc, op, next_pc, flags, mask, segs, ax_mask] + regs
            self.out.write('STEP ' + ' '.join(f'{x:x}' for x in values) + '\n')
            self.out.write(f'FETCH {pc:x} {self.seen[0][1]:x}\n')
            for transfer in self.bus:
                # QEMU batches PUSHA stores in ascending address order. Intel
                # B-88's AX..DI push sequence has separate directed order tests.
                self.out.write(('BUS_ANY ' if op==0x60 else 'BUS ') + ' '.join(f'{v:x}' for v in transfer) + '\n')
            self.out.write('CHECK\n')
            self.steps += 1
            pc = self.uc.reg_read(UC_X86_REG_CS)*16+next_pc
            if op == 0xf4:
                break
        self.out.write('END\n')


def generate(g):
    # All register aliases/directions, with arithmetic edge values and random state.
    for kind in range(8):
        for wide in range(2):
            for direction in range(2):
                for dst in range(8):
                    for src in range(8):
                        regs = [RNG.choice(EDGES) for _ in REGS]
                        op = kind*8 + direction*2 + wide
                        g.case('alu_rm', bytes([op, 0xc0 | src*8 | dst]), regs,
                               masks=0xffef if kind in (1, 4, 6) else 0xffff)
            for value in EDGES:
                g.case('alu_acc', bytes([kind*8+4+wide]) + (word(value) if wide else bytes([value & 255])),
                       masks=0xffef if kind in (1, 4, 6) else 0xffff)
        for op in (0x80, 0x81, 0x83):
            for value in EDGES:
                g.case('alu_group', bytes([op, 0xc0 | kind*8 | RNG.randrange(8)]) +
                       (word(value) if op == 0x81 else bytes([value & 255])),
                       masks=0xffef if kind in (1, 4, 6) else 0xffff)
    for _ in range(2000):
        kind, wide, direction = RNG.randrange(8), RNG.randrange(2), RNG.randrange(2)
        g.case('alu_random', bytes([kind*8+direction*2+wide, 0xc0 | RNG.randrange(64)]),
               masks=0xffef if kind in (1, 4, 6) else 0xffff)

    for op in (0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b):
        for modrm in range(0xc0, 0x100):
            g.case('test_move_exchange', bytes([op, modrm]), masks=0xffef if op in (0x84, 0x85) else 0xffff)
    for op in range(0x40, 0x50):
        for value in EDGES:
            g.case('incdec', bytes([op]), [value]*8)
    for op in (0xfe, 0xff, 0xf6, 0xf7):
        for extension in ((0, 1) if op >= 0xfe else (0, 2, 3)):
            for r in range(8):
                for value in EDGES:
                    encoding = bytes([op, 0xc0 | extension*8 | r])
                    if op in (0xf6, 0xf7) and extension == 0:
                        encoding += word(value) if op == 0xf7 else bytes([value & 255])
                    g.case('unary_test', encoding, [value]*8,
                           masks=0xffef if op in (0xf6, 0xf7) and extension == 0 else 0xffff)
    for op in (0xa8, 0xa9):
        for value in EDGES:
            g.case('test_acc', bytes([op]) + (word(value) if op & 1 else bytes([value & 255])), masks=0xffef)
    for op in range(0x91, 0x9a):
        for value in EDGES:
            g.case('exchange_extend', bytes([op]), [value]*8)
    for op in (0x8c, 0x8e):
        for segment in range(4):
            if op == 0x8e and segment == 1:
                continue
            for r in range(8):
                g.case('segments', bytes([op, 0xc0 | segment*8 | r]))
    for flags in range(256):
        g.case('sahf', bytes([0x9e]), [flags << 8] * 8)
        g.case('lahf', bytes([0x9f]), lowflags=flags)

    # All 256 immediate/CL count bytes, all 7 documented group extensions,
    # both widths; operand register chosen independently, including CL/CH.
    for kind in (0, 1, 2, 3, 4, 5, 7):
        for wide in range(2):
            for source in ('immediate', 'cl', 'one'):
                for count in (range(256) if source != 'one' else range(8)):
                    r = RNG.randrange(8)
                    regs = [RNG.choice(EDGES) for _ in REGS]
                    if source == 'cl':
                        regs[1] = (regs[1] & 0xff00) | count
                    actual_count = (count & 31) if source != 'one' else 1
                    op = (0xc0 if source == 'immediate' else 0xd2 if source == 'cl' else 0xd0) + wide
                    encoding = bytes([op, 0xc0 | kind*8 | r])
                    if source == 'immediate':
                        encoding += bytes([count])
                    mask = 0xffff
                    if actual_count:
                        if kind >= 4:
                            mask &= ~0x10
                            if kind in (4, 5) and actual_count >= (16 if wide else 8):
                                mask &= ~1
                        if actual_count != 1:
                            mask &= ~0x800
                    g.case('shift_' + source, encoding, regs, masks=mask)

    # Every condition for every combination of its five input flags.
    for condition in range(16):
        for bits in range(32):
            low = ((bits & 1) | ((bits & 2) << 1) | ((bits & 4) << 4) | ((bits & 8) << 4))
            for displacement in (0, 2, 0xfe):
                g.case('jcc', bytes([0x70+condition, displacement]), lowflags=low,
                       overflow=(bits >> 4), branch=True)
    for op in range(0xe0, 0xe4):
        for count in (0, 1, 2, 0xffff):
            for zero in (0, 0x40):
                regs = [RNG.randrange(65536) for _ in REGS]
                regs[1] = count
                for displacement in (0, 2, 0xfe):
                    g.case('loops', bytes([op, displacement]), regs, lowflags=zero, branch=True)


def generate_memory(g):
    # Manufacturer table B-1 supplies encodings; Unicorn supplies executed
    # addresses/side effects. The address calculation here only seeds data;
    # every actual address is independently observed by Unicorn's memory hooks.
    opcodes = [kind*8+form for kind in range(8) for form in range(4)]
    opcodes += [0x84,0x85,0x86,0x87,0x88,0x89,0x8a,0x8b,0x8c,0x8e,0x8d,0xc4,0xc5]
    opcodes += [0x80,0x81,0x83,0xc6,0xc7,0xf6,0xf7,0xfe,0xff,0xc0,0xc1,0xd0,0xd1,0xd2,0xd3]
    for op in opcodes:
        for mode in range(3):
            for rm in range(8):
                for override in (None,0x26,0x2e,0x36,0x3e):
                    regs = [RNG.randrange(65536) for _ in REGS]
                    displacement = RNG.choice(EDGES)
                    if mode == 1:
                        displacement &= 255
                    disp_size = 2 if mode == 2 or (mode == 0 and rm == 6) else 1 if mode == 1 else 0
                    disp_value = displacement if disp_size == 2 else (displacement-256 if displacement&128 else displacement) if disp_size else 0
                    base = [regs[3]+regs[6],regs[3]+regs[7],regs[5]+regs[6],regs[5]+regs[7],regs[6],regs[7],
                            0 if mode == 0 else regs[5],regs[3]][rm]
                    offset = (base+disp_value)&65535
                    if offset > 65530:
                        continue  # Boundary exceptions have Intel-derived tests.
                    segment = 0x3000 if rm in (2,3) or (rm==6 and mode!=0) else 0x1000
                    if override is not None:
                        segment = {0x26:0x2000,0x2e:0,0x36:0x3000,0x3e:0x1000}[override]
                    address = segment*16+offset
                    if address < 0x2000 and address+8 >= 0x1000:
                        continue
                    extension = RNG.randrange(8)
                    if op == 0x8c: extension = RNG.randrange(4)
                    if op == 0x8e: extension = RNG.choice([0,2,3])
                    if op in (0xc6,0xc7): extension = 0
                    if op in (0xf6,0xf7): extension = RNG.choice([0,2,3])
                    if op in (0xfe,0xff): extension = RNG.randrange(2)
                    if op in (0xc0,0xc1,0xd0,0xd1,0xd2,0xd3): extension = RNG.choice([0,1,2,3,4,5,7])
                    instruction = bytes([op,mode*64+extension*8+rm])
                    if disp_size: instruction += word(displacement) if disp_size==2 else bytes([displacement])
                    if op in (0x80,0x81,0x83,0xc6,0xc7) or (op in (0xf6,0xf7) and extension==0):
                        instruction += word(RNG.randrange(65536)) if op in (0x81,0xc7,0xf7) else bytes([RNG.randrange(256)])
                    if op in (0xc0,0xc1): instruction += bytes([RNG.randrange(256)])
                    if override is not None: instruction = bytes([override])+instruction
                    mask=0xffff
                    kind = extension if op in (0x80,0x81,0x83) else op//8
                    if op<=0x3b and kind in (1,4,6) or op in (0x80,0x81,0x83) and kind in (1,4,6) or op in (0x84,0x85) or op in (0xf6,0xf7) and extension==0:
                        mask &= ~0x10
                    if op in (0xc0,0xc1,0xd0,0xd1,0xd2,0xd3):
                        count=instruction[-1]&31 if op in (0xc0,0xc1) else regs[1]&31 if op in (0xd2,0xd3) else 1
                        if count:
                            if extension>=4: mask &= ~0x10
                            if count!=1: mask &= ~0x800
                            if extension in (4,5) and count >= (16 if op&1 else 8): mask &= ~1
                    data=bytes(RNG.randrange(256) for _ in range(8))
                    g.case('memory',instruction,regs,masks=mask,memory=[(address,data)],segments=True)

    for op in range(0xa0,0xa4):
        for prefix in (None,0x26,0x2e,0x36,0x3e):
            for offset in (0,1,0x7fff,0xfffe):
                base = 0x10000 if prefix is None else {0x26:0x20000,0x2e:0,0x36:0x30000,0x3e:0x10000}[prefix]
                encoding = bytes([op])+word(offset)
                if prefix is not None: encoding=bytes([prefix])+encoding
                g.case('moffs',encoding,memory=[(base+offset,bytes.fromhex('12 a5'))],segments=True)
    for op in list(range(0x50,0x60))+[0x06,0x0e,0x16,0x1e,0x07,0x17,0x1f,0x9c,0x9d,0x68,0x6a,0x8f,0xff]:
        for sp in (0,2,0x7fff,0xfffe):
            regs=[RNG.randrange(65536) for _ in REGS]; regs[4]=sp
            encoding=bytes([op])
            if op==0x68: encoding+=word(RNG.randrange(65536))
            if op==0x6a: encoding+=bytes([RNG.randrange(256)])
            if op==0x8f: encoding+=bytes([0xc0|RNG.randrange(8)])
            if op==0xff: encoding+=bytes([0xf0|RNG.randrange(8)])
            # No TF/NT/IOPL in POPF fixture; those require 286-specific handling.
            value=0x0cc5 if op==0x9d else RNG.randrange(65536)
            g.case('stack',encoding,regs,segments=True,memory=[(0x30000+sp,word(value))])
    for displacement in (3,0x20):
        regs=[RNG.randrange(65536) for _ in REGS]; regs[4]=0x8000
        tail=bytes.fromhex('90 90 f4')+bytes([0x90])*(displacement-3)+bytes.fromhex('b8 ef be c3')
        g.case('near_call_ret',bytes([0xe8])+word(displacement),regs,segments=True,tail=tail,followup=8)
    for op in (0xc2,0xc3):
        regs=[RNG.randrange(65536) for _ in REGS]; regs[4]=0x8000
        encoding=bytes([op])+(word(6) if op==0xc2 else b'')
        g.case('near_return',encoding,regs,segments=True,memory=[(0x38000,word(0x1800)),(0x1800,b'\xf4')])
    for op, extension in ((0x8f,0),(0xff,2),(0xff,4),(0xff,6)):
        regs=[RNG.randrange(65536) for _ in REGS]; regs[4]=0x8000
        code=bytes([op,extension*8+6])+word(0x4000)
        data=word(0x1800 if extension in (2,4) else 0xa55a)
        destination=bytes.fromhex('b8 34 12 c3') if extension==2 else b'\xf4'
        g.case('stack_indirect',code,regs,segments=True,followup=10,
               memory=[(0x14000,data),(0x38000,word(0xbabe)),(0x1800,destination)])
    for prefix in (0x26,0x2e,0x36,0x3e):
        regs=[RNG.randrange(65536) for _ in REGS]; regs[4]=0x8000
        g.case('stack_override',bytes([prefix,0x50]),regs,segments=True,tail=bytes.fromhex('5b f4'))
    for op in list(range(0xe4,0xe8))+list(range(0xec,0xf0)):
        for port in (0,1,0xff,0x8000,0xffff):
            regs=[RNG.randrange(65536) for _ in REGS]; regs[2]=port
            encoding=bytes([op])+(bytes([port&255]) if op<0xe8 else b'')
            actual=port&255 if op<0xe8 else port
            g.case('io',encoding,regs,ports=[(actual,0x69),((actual+1)&65535,0xa5)])
    for register in range(8):
        for call in (False,True):
            regs=[RNG.randrange(65536) for _ in REGS]
            regs[4]=0x8000; regs[register]=0x1800
            destination=bytes.fromhex('b8 34 12 c3') if call else b'\xf4'
            g.case('near_register_target',bytes([0xff,(0xd0 if call else 0xe0)|register]),regs,
                   segments=True,followup=10,memory=[(0x1800,destination)])


def generate_procedures(g):
    def set_operand(regs,r,wide,value):
        if wide: regs[r]=value&65535
        elif r&4: regs[r&3]=(regs[r&3]&255)|((value&255)<<8)
        else: regs[r]=(regs[r]&0xff00)|(value&255)
    def operand(regs,r,wide):
        return regs[r] if wide else (regs[r&3]>>(8 if r&4 else 0))&255
    for wide in (0,1):
        for extension in (4,5,6,7):
            for r in range(8):
                for trial in range(36):
                    regs=[RNG.randrange(65536) for _ in REGS]
                    if extension<6:
                        regs[0]=RNG.choice(EDGES) if trial<11 else RNG.randrange(65536)
                        set_operand(regs,r,wide,RNG.choice(EDGES) if trial<11 else RNG.randrange(65536))
                    else:
                        signed=extension==7; bits=16 if wide else 8; limit=1<<(bits-1)
                        divisor=RNG.randrange(-limit,limit) if signed else RNG.randrange(1,1<<bits)
                        if divisor==0: divisor=1
                        quotient=RNG.randrange(-limit,limit) if signed else RNG.randrange(1<<bits)
                        dividend=divisor*quotient
                        remainder=RNG.randrange(abs(divisor))
                        dividend+=-remainder if dividend<0 else remainder
                        regs[0]=dividend&65535
                        if wide: regs[2]=(dividend>>16)&65535
                        set_operand(regs,r,wide,divisor)
                        if signed and (wide and r==2 or not wide and r==4):
                            regs[0]=RNG.randrange(0x8001,0x10000) if wide else RNG.randrange(0xff81,0x10000)
                            if wide: regs[2]=0xffff
                        d=operand(regs,r,wide)
                        n=(regs[2]<<16)|regs[0] if wide else regs[0]
                        if signed:
                            if d&limit: d-=1<<bits
                            if n&(1<<(bits*2-1)): n-=1<<(bits*2)
                        if not d: continue
                        q=abs(n)//abs(d)
                        if (n<0) != (d<0): q=-q
                        if not (-limit<=q<limit if signed else 0<=q<(1<<bits)): continue
                    g.case('muldiv',bytes([0xf6+wide,0xc0|extension*8|r]),regs,
                           masks=0xff2b if extension<6 else 0xf72a)
    for op in (0x69,0x6b):
        for r in range(8):
            for dest in range(8):
                for value in EDGES:
                    code=bytes([op,0xc0|dest*8|r])+(word(value) if op==0x69 else bytes([value&255]))
                    g.case('imul_immediate',code,masks=0xff2b)
    for extension in range(4,8):
        for wide in (0,1):
            for value in (1,2,0x7f,0x80,0xff,0x7fff,0x8000,0xffff):
                regs=[RNG.randrange(65536) for _ in REGS]
                regs[0]=0x017e; regs[2]=0
                if extension==7 and wide: regs[0]=0xff81; regs[2]=0xffff
                if extension==6 and not wide and value&255==1: regs[0]=0x007e
                # Check valid division only; explicit fault frames have directed tests.
                d=value if wide else value&255
                n=regs[2]*65536+regs[0] if wide else regs[0]
                if extension==7:
                    if d&(0x8000 if wide else 0x80): d-=65536 if wide else 256
                    if n&(0x80000000 if wide else 0x8000): n-=0x100000000 if wide else 65536
                if extension>=6 and d==0: continue
                q=abs(n)//abs(d) if d else 0
                if (n<0)!=(d<0): q=-q
                if extension>=6 and not ((-32768<=q<=32767 if wide else -128<=q<=127) if extension==7 else q<=(65535 if wide else 255)): continue
                g.case('muldiv_memory',bytes([0xf6+wide,extension*8+6])+word(0x4000),regs,
                       masks=0xff2b if extension<6 else 0xf72a,segments=True,memory=[(0x14000,word(value))])
    for op in (0x60,0x61):
        for sp in (0x100,0x8000,0x8001,0x9000):
            regs=[RNG.randrange(65536) for _ in REGS]; regs[4]=sp
            data=bytes(RNG.randrange(256) for _ in range(16))
            g.case('push_pop_all',bytes([op]),regs,segments=True,memory=[(0x30000+sp,data)])
    for level in range(256):
        regs=[RNG.randrange(65536) for _ in REGS]; regs[4]=0x8000; regs[5]=0x9000
        data=bytes(RNG.randrange(256) for _ in range(64))
        allocation=RNG.choice([0,1,2,16,0x8000,0xffff])
        g.case('enter_leave',bytes([0xc8])+word(allocation)+bytes([level]),regs,segments=True,
               memory=[(0x38fc0,data)],tail=bytes.fromhex('c9 f4'))
    for prefix in (None,0x26,0x36,0x3e):
        for indirect in (False,True):
            for cleanup in (None,0,6):
                regs=[RNG.randrange(65536) for _ in REGS]; regs[4]=0x8000
                address={None:0x14000,0x26:0x24000,0x36:0x34000,0x3e:0x14000}[prefix]
                code=bytes.fromhex('ff 1e 00 40') if indirect else bytes.fromhex('9a 00 02 34 12')
                if prefix is not None: code=bytes([prefix])+code
                ret=b'\xcb' if cleanup is None else b'\xca'+word(cleanup)
                g.case('far_call_return',code,regs,segments=True,followup=10,
                       memory=[(address,bytes.fromhex('00 02 34 12')),(0x12540,bytes.fromhex('b8 ef be')+ret)])
    for op in (0xea,0xff,0xca,0xcb,0xcf):
        regs=[RNG.randrange(65536) for _ in REGS]; regs[4]=0x8000
        code=bytes.fromhex('ea 00 02 34 12') if op==0xea else bytes.fromhex('ff 2e 00 40') if op==0xff else bytes([op])+(word(6) if op==0xca else b'')
        g.case('far_jump_iret',code,regs,segments=True,memory=[(0x14000,bytes.fromhex('00 02 34 12')),
               (0x38000,bytes.fromhex('00 02 34 12 c5 0c')),(0x12540,b'\xf4')])


def generate_bounds_translation(g):
    for prefix in (None,0x26,0x2e,0x36,0x3e):
        base={None:0x10000,0x26:0x20000,0x2e:0,0x36:0x30000,0x3e:0x10000}[prefix]
        for bx in (0,0x4000,0xff00,0xffff):
            for index in range(256):
                regs=[RNG.randrange(65536) for _ in REGS]
                regs[0]=(regs[0]&0xff00)|index; regs[3]=bx
                code=bytes([0xd7]) if prefix is None else bytes([prefix,0xd7])
                address=base+((bx+index)&0xffff)
                g.case('xlat',code,regs,segments=True,memory=[(address,bytes([RNG.randrange(256)]))])
        for mode in range(3):
            for rm in range(8):
                for reg in range(8):
                    for value in (0,1,0x7fff,0x8000,0xffff):
                        regs=[0x1234,0x2345,0x3456,0x6000,0x8000,0x7000,0x100,0x200]
                        regs[reg]=value
                        offset=[regs[3]+regs[6],regs[3]+regs[7],regs[5]+regs[6],regs[5]+regs[7],
                                regs[6],regs[7],regs[5],regs[3]][rm]
                        displacement=b''
                        if mode==0 and rm==6: offset=0x4000; displacement=word(offset)
                        if mode==1: offset-=16; displacement=b'\xf0'
                        if mode==2: offset-=16; displacement=word(0xfff0)
                        offset&=0xffff
                        segment=0x30000 if rm in (2,3) or (rm==6 and mode!=0) else 0x10000
                        if prefix is not None: segment=base
                        address=segment+offset
                        if offset>0xfffc or address<0x2000 and address+4>0x1000: continue
                        signed=value if value<0x8000 else value-65536
                        # Both endpoints are inclusive; alternate which is equal.
                        lower=signed if rm&1 else max(-32768,signed-1)
                        upper=min(32767,signed+1) if rm&1 else signed
                        code=bytes([0x62,mode*64+reg*8+rm])+displacement
                        if prefix is not None: code=bytes([prefix])+code
                        g.case('bound_in_range',code,regs,segments=True,
                               memory=[(address,word(lower&0xffff)+word(upper&0xffff))])


def generate_strings(g):
    def fixture(op,prefix,source,destination,count,wide,variant,direction):
        unit=2 if wide else 1
        source_base={None:0x10000,0x26:0x20000,0x2e:0,0x36:0x30000,0x3e:0x10000}[prefix]
        data={}
        for n in range(max(1,min(count,17))):
            value=0x2211 if wide else 0x11
            other=value ^ (1 if variant==1 and n==0 or variant==2 and n==count//2 or variant==3 and n==count-1 else 0)
            for byte in range(unit):
                displacement=n*unit*(-1 if direction else 1)+byte
                data[source_base+((source+displacement)&65535)]=(value>>(byte*8))&255
                data[0x20000+((destination+displacement)&65535)]=(other>>(byte*8))&255
        return [(address,bytes([value])) for address,value in sorted(data.items())]
    for op in (0xa4,0xa5,0xa6,0xa7,0xaa,0xab,0xac,0xad,0xae,0xaf,0x6c,0x6d,0x6e,0x6f):
        for prefix in (None,0x26,0x2e,0x36,0x3e):
            for direction in (False,True):
                for source,destination in ((0x4000,0x5000),(0,0),(0xfffe,0xfffe),(0xffff,0xffff)):
                    wide=op&1
                    if wide and (source==0xffff or destination==0xffff):continue
                    regs=[0x2211,0x7fff,0x1234,0x6789,0x8000,0x9000,source,destination]
                    code=bytes([op]) if prefix is None else bytes([prefix,op])
                    g.case('string_single',code,regs,segments=True,direction=direction,
                           memory=fixture(op,prefix,source,destination,1,wide,0,direction),
                           ports=[(0x1234,0x5a),(0x1235,0xa5)],tail=bytes.fromhex('43 42 f4'))
    for op in (0xa4,0xa5,0xa6,0xa7,0xaa,0xab,0xae,0xaf,0x6c,0x6d,0x6e,0x6f):
        compare=op in (0xa6,0xa7,0xae,0xaf)
        for repeat in ((0xf3,0xf2) if compare else (0xf3,)):
            for prefix in (None,0x26,0x2e,0x36,0x3e):
                for direction in (False,True):
                    for count in (0,1,2,3,17):
                        for variant in (range(4) if compare else (0,)):
                            wide=op&1
                            source,destination=RNG.choice([(0x4000,0x5000),(0,0),(0xfffe,0xfffe)])
                            regs=[0x2211,count,0x1234,0x6789,0x8000,0x9000,source,destination]
                            head=bytes([repeat]) if prefix is None else bytes([prefix,repeat]) if variant&1 else bytes([repeat,prefix])
                            memory=fixture(op,prefix,source,destination,count,wide,variant,direction)
                            g.case('string_repeat',head+bytes([op]),regs,segments=True,direction=direction,
                                   memory=memory,ports=[(0x1234,0x5a),(0x1235,0xa5)],tail=bytes.fromhex('43 42 f4'))
    for direction in (False,True):
        for wide in (0,1):
            for count in (2,17):
                source=0x5020 if direction else 0x5000
                destination=source-(2 if wide else 1) if direction else source+(2 if wide else 1)
                regs=[0x2211,count,0x1234,0,0x8000,0,source,destination]
                g.case('string_overlap',bytes([0x26,0xf3,0xa4+wide]),regs,segments=True,direction=direction,
                       memory=fixture(0xa4+wide,0x26,source,destination,count,wide,2,direction),tail=bytes.fromhex('43 42 f4'))
    for wide in (0,1):
        for direction in (False,True):
            regs=[0x2211,0xffff,0x1234,0,0x8000,0,0,0]
            g.case('string_full_count',bytes([0xf3,0xa4+wide]),regs,segments=True,direction=direction,
                   memory=[(0x10000,bytes(range(256)))],tail=bytes.fromhex('43 42 f4'))


def generate_decimal(g):
    # Intel 210498-005 and pinned 86Box 1db9ae4 x86_ops_bcd.h establish
    # defined-bit masks, whole-AX AAA/AAS propagation and arbitrary bases.
    for op in (0x27,0x2f,0x37,0x3f):
        for al in range(256):
            for ah in ((0,1,0x7f,0xff) if op in (0x37,0x3f) else (RNG.randrange(256),)):
                for af_cf in range(4):
                    regs=[RNG.randrange(65536) for _ in REGS];regs[0]=(ah<<8)|al
                    flags=((af_cf&2)<<3)|(af_cf&1)
                    g.case('decimal_adjust',bytes([op]),regs,lowflags=flags,
                           masks=0xf73b if op in (0x37,0x3f) else 0xf7ff,
                           tail=bytes.fromhex('43 42 f4'))
    for base in range(256):
        for ah in (0,1,9,0xff):
            for al in (0,1,9,10,0x7f,0x80,0xff):
                regs=[RNG.randrange(65536) for _ in REGS];regs[0]=(ah<<8)|al
                g.case('aad_bases',bytes([0xd5,base]),regs,masks=0xf7ee,tail=bytes.fromhex('43 42 f4'))
        if base:
            for al in (0,1,9,10,0x7f,0x80,0xff):
                regs=[RNG.randrange(65536) for _ in REGS];regs[0]=(RNG.randrange(256)<<8)|al
                g.case('aam_bases',bytes([0xd4,base]),regs,masks=0xf7ee,tail=bytes.fromhex('43 42 f4'))
    for al in range(256):
        regs=[RNG.randrange(65536) for _ in REGS];regs[0]=(RNG.randrange(256)<<8)|al
        g.case('aam_decimal',bytes([0xd4,10]),regs,masks=0xf7ee,tail=bytes.fromhex('43 42 f4'))
    for subtract in (False,True):
        for lhs in range(100):
            for rhs in range(100):
                for carry in (0,1):
                    regs=[RNG.randrange(65536) for _ in REGS]
                    regs[0]=(RNG.randrange(256)<<8)|((lhs//10)*16+lhs%10)
                    g.case('packed_decimal_chain',bytes([0x1c if subtract else 0x14,(rhs//10)*16+rhs%10]),
                           regs,lowflags=carry,masks=0xf7ff,tail=bytes([0x2f if subtract else 0x27,0x43,0xf4]))
        for ah in (0,1,0x7f,0xff):
            for lhs in range(10):
                for rhs in range(10):
                    regs=[RNG.randrange(65536) for _ in REGS];regs[0]=(ah<<8)|lhs
                    g.case('unpacked_decimal_chain',bytes([0x2c if subtract else 0x04,rhs]),regs,
                           masks=0xf73b,tail=bytes([0x3f if subtract else 0x37,0x43,0xf4]))


def main():
    if unicorn.__version__ != '2.1.4':
        raise ValueError('Expected pinned Unicorn 2.1.4')
    dest = WORK_ROOT / 'vectors'
    dest.mkdir(parents=True, exist_ok=True)
    path = dest / 'registers.txt'
    with path.open('w') as out:
        generator = Generator(out)
        generate(generator)
        generate_memory(generator)
        generate_procedures(generator)
        generate_bounds_translation(generator)
        generate_strings(generator)
        generate_decimal(generator)
    manifest = {'oracle': 'Unicorn', 'version': unicorn.__version__, 'seed': SEED,
                'cases': generator.cases, 'steps': generator.steps, 'families': generator.families,
                'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                'scope': 'Shared 16-bit register/memory/stack/I/O ISA; not 286 protected-mode or silicon validation'}
    (dest / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'PASS: generated {generator.cases} independent-oracle cases, {generator.steps} instruction states')


if __name__ == '__main__':
    main()
