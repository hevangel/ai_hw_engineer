"""Replay an IBM AT BIOS trace in Unicorn and compare it step by step.

Shared by the 286 design's AT fixture checkers and the IBM PC AT system.
The trace holds `B` data-transfer records followed by the `R` retirement
record of the instruction that made them. The CPU's observed I/O input
bytes are supplied to Unicorn; every architectural register, the defined
FLAGS bits, the next CS:IP and every data transfer must then agree.
Device behavior is not checked here: the inputs come from the trace.

Memory reads outside RAM (000000-09FFFF) and the fitted ROMs (the BIOS ROM
and any adapter ROM images given) are device inputs too, for example the
EGA's video memory at A0000-BFFFF, whose read path (planes, latches, read
modes) is not plain RAM. They are served to Unicorn from the trace inside
its memory-read hook, one byte per access in the CPU's order, so a string
instruction that reads many device bytes, or rereads one, gets each value
the CPU saw; the address of every such read must match the CPU's next one.
Writes there are compared like any transfer but do not decide later reads.
A ROM read always returns the image byte, also after a write to it.

Two event records are also accepted:
  A <byte>  an interrupt-acknowledge cycle; a hardware interrupt between two
            instructions is a pair of them, the second carrying the vector,
            followed by the entry transfers. No R record is emitted for the
            event; its transfers precede the handler's first R record.
  Z         a processor reset with memory kept (8042 reset pulse or
            shutdown); the next R record must be the reset-vector far jump.
An exception is likewise not retired: the faulting instruction has no R
record, and its entry transfers precede the handler's first R record.

Two board records describe what other bus masters and the A20 gate did
(written by the IBM PC AT system's runner; the 286 fixtures emit neither):
  D <addr> <byte> <write>  a DMA memory transfer: write = 1, the DMA
            controller stored the byte at physical address addr; write = 0,
            it read the byte there for a device. A DMA cycle happens while
            the CPU holds HLDA, between two of its bus cycles, so it can fall
            inside an instruction. Ordering rule: a D record belongs to the
            instruction whose R record follows it and is applied to the
            oracle's memory before that instruction executes (a read is
            compared with the oracle's memory there). This is exact unless
            that instruction made a memory transfer at the same address
            before the D record (in trace order); such a trace is rejected,
            not approximated. The address must be RAM (DMA memory is RAM).
  G <level> the 8042's A20 GATE output changed (1 = A20 passes, 0 = the
            board forces A20 low). The change applies from the instruction
            whose R record follows; a trace where that instruction made a
            memory transfer before the G record is rejected. While the gate
            is closed, an oracle access with address bit 20 set is folded
            onto the address with bit 20 clear, as the board does: its read
            sees that byte, its write lands there, and the bus record is
            compared with bit 20 clear; the oracle's memory at the high
            address is left unchanged.
Expansion RAM from 100000h (ext_ram_kb) is RAM like the base 640 KiB.

Unicorn has no interrupt pin and does not vector INT n or exceptions (it
reports them through UC_HOOK_INTR), so event entry is performed on its state
here: the IVT entry or IDT gate is read from its memory, the pushes and the
far transfer to the handler are executed as real instructions in Unicorn
(PUSHF, PUSH imm16, JMP ptr16:16, so Unicorn's own stack and descriptor
logic is used), and TF/IF/NT are cleared. Unicorn also does not check
segment limits or access rights on data accesses; an exception the CPU takes
for such a fault is accepted only when the 286 rule (Intel 210498-005
section 6.3 segment limit and type checks, and the section 9 descriptions
of exceptions 12 and 13), evaluated on Unicorn's own segment cache,
requires it. Unicorn's caches equal the 286's only because every descriptor
the CPU loads has a zero reserved word, which is checked. Each case where
Unicorn is not a 286 oracle is documented where it is handled and counted in
`stats`. No instruction is accepted without comparison: a construct Unicorn
cannot follow (task switch, inter-privilege entry, protected far RET,
single-step entry) stops the replay with an error.
"""
import hashlib
import struct
from collections import deque
from pathlib import Path

from generate_firmware_trace import decode
from generate_vectors import Generator, REGS, SEGS, UC_X86_REG_CS, UC_X86_REG_IP, UC_X86_REG_EFLAGS, word
from unicorn import UcError, UC_HOOK_INTR, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_CR0, UC_X86_REG_IDTR

ROM_SHA256 = '74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f'
# The first record after power-on or a processor reset: the far jump at
# FFFFF0 with the 286 reset state (CS F000, IP FFF0, FLAGS 0002, segment
# registers 0; the general registers are 0 in this CPU).
RESET_RECORD = (0xfffff0, 0xea, 0xf000, 0xe05b, 2, 0xf0000000, [0]*8)
# IBM AT memory map (Technical Reference 1502494, system board): 640 KiB RAM
# at 000000-09FFFF, the 64 KiB BIOS ROM at 0F0000-0FFFFF aliased at
# FF0000-FFFFFF; nothing else is fitted on this board.
RAM_END = 0xa0000
# Offset of CPUX86State.segs[] (ES, CS, SS, DS, FS, GS; each selector u32,
# pad, base u64, limit u32, flags u32) in a Unicorn 2.1.4 x86 context image.
# Verified by loading known descriptors; Generator pins Unicorn 2.1.4.
SEG_CACHE = 224
ERROR_CODE = 5424
FAR_OPS = frozenset((0xca, 0xcb, 0xcd, 0xcf, 0xea))


def is_bios_rom(address):
    return 0xf0000 <= address < 0x100000 or 0xff0000 <= address < 0x1000000


def strip_cpu_accessed(bus):
    """Split the CPU's descriptor accessed-byte writes from its transfers.

    The CPU reads a descriptor as eight ascending bytes and then writes its
    access byte OR 01h back to descriptor+5, also when A was already set
    (design assumption A11, spec/segment_load_transaction.md; 86Box's 286
    path writes unconditionally). LTR likewise writes the access byte with
    the busy bit (type bit 1) set (210498-005 Appendix B LTR). Returns
    (transfers, [(address, value, access byte read)]).
    """
    out = []
    writes = []
    for transfer in bus:
        address, value, write, io = transfer
        if write and not io and len(out) >= 8:
            last = out[-8:]
            if all(last[n][0] == address - 5 + n and not last[n][2] and not last[n][3] for n in range(8)) \
                    and value in (last[5][1] | 1, last[5][1] | 2):
                # 210498-005 6.3.1: the last descriptor word is reserved and
                # must be zero for 80386 compatibility; the 286 ignores it,
                # Unicorn (a later CPU) uses it as base 31..24 and limit
                # 19..16. Unicorn's segment caches are 286-correct only if it
                # is zero, so a nonzero one is not accepted.
                if last[6][1] or last[7][1]:
                    raise ValueError(f'descriptor at {address-5:06x} has a nonzero reserved word')
                writes.append((address, value, last[5][1]))
                continue
        out.append(transfer)
    return out, writes


def strip_oracle_accessed(bus):
    """Split Unicorn's accessed-bit updates from its transfers.

    QEMU (Unicorn) writes the descriptor's second dword back with A set only
    when A was clear (helper_load_seg), as four byte writes at descriptor+4;
    helper_ltr writes it with the busy bit set the same way.
    Returns (transfers, [(access byte address, value)]).
    """
    out = []
    writes = []
    i = 0
    while i < len(bus):
        address, value, write, io = bus[i]
        if write and not io and i + 3 < len(bus):
            group = bus[i:i+4]
            if all(group[n][0] == address + n and group[n][2] and not group[n][3] for n in range(4)):
                reads = {t[0]: t[1] for t in out if not t[2] and not t[3]}
                if all(address - 4 + n in reads for n in range(8)) and \
                        all(group[n][1] == reads[address+n] for n in (0, 2, 3)) and \
                        group[1][1] in (reads[address+1] | 1, reads[address+1] | 2):
                    writes.append((address + 1, group[1][1]))
                    i += 4
                    continue
        out.append(bus[i])
        i += 1
    return out, writes


class _Replay:
    def is_ram(self, address):
        return address < RAM_END or 0x100000 <= address < self.ext_end

    def rom_byte(self, address):
        """The ROM byte at address, or None where no ROM is fitted."""
        if is_bios_rom(address):
            return self.rom[address & 0xffff]
        for base, image in self.adapter_roms:
            if base <= address < base + len(image):
                return image[address - base]
        return None

    def read_hook(self, recorder, uc, access, address, size, value, data):
        """Unicorn's memory-read hook: settle the bytes, then record them.

        QEMU calls the hook before it loads, so a byte written here is the
        value Unicorn reads. A device byte (neither RAM nor ROM) is the
        CPU's next device read, which must be at this address; otherwise it
        is left unserved, reported after the instruction, and the transfer
        comparison fails. A ROM byte is reset to the image in case this
        instruction wrote it. Generator's recorder then logs the transfer.
        """
        shadow = self.g.shadow
        if not self.a20:
            # A20 forced low: the byte at the folded address is what the
            # board returns; keep the high address's own value to restore.
            for a in range(address, address + size):
                if a & 0x100000:
                    low = a & ~0x100000
                    if low >= RAM_END and self.rom_byte(low) is None:
                        raise ValueError(f'folded read {a:06x} -> {low:06x} outside RAM and ROM is not supported')
                    if a not in self.folded:
                        self.folded[a] = shadow.get(a, 0)
                    byte = shadow.get(low, 0)
                    if shadow.get(a, 0) != byte:
                        uc.mem_write(a, bytes([byte]))
                        shadow[a] = byte
        if address + size > RAM_END:
            for a in range(max(address, RAM_END), address + size):
                if self.is_ram(a) or (not self.a20 and a & 0x100000):
                    continue
                byte = self.rom_byte(a)
                if byte is None:
                    if not self.device_reads or self.device_reads[0][0] != a:
                        self.device_unserved.append(a)
                        continue
                    byte = self.device_reads.popleft()[1]
                    self.stats['open_bus_reads'] += 1
                if shadow.get(a, 0) != byte:
                    uc.mem_write(a, bytes([byte]))
                    shadow[a] = byte
        recorder(uc, access, address, size, value, data)

    def unfold(self):
        """After an instruction with A20 forced low: move its writes to the
        folded addresses, restore the high addresses and fold the bus."""
        if not self.folded and self.a20:
            return
        g, uc, shadow = self.g, self.uc, self.g.shadow
        for index, (address, value, write, io) in enumerate(g.bus):
            if io or not address & 0x100000 or self.a20:
                continue
            low = address & ~0x100000
            if write:
                if not self.is_ram(low):
                    raise ValueError(f'folded write {address:06x} -> {low:06x} outside RAM is not supported')
                uc.mem_write(low, bytes([value]))
                shadow[low] = value
                uc.ctl_remove_cache(low, low + 1)
                if address not in self.folded:
                    self.folded[address] = None
            g.bus[index] = (low, value, write, io)
            self.stats['a20_folded'] = self.stats.get('a20_folded', 0) + 1
        for address, old in self.folded.items():
            if old is None:
                old = 0
            uc.mem_write(address, bytes([old]))
            shadow[address] = old
        self.folded = {}

    def apply_board_records(self, pending, dma, gates, where):
        """Apply D and G records before the instruction that follows them."""
        uc, shadow = self.uc, self.g.shadow
        for index, address, value, write in dma:
            if any(not io and a == address for a, _, _, io in pending[:index]):
                raise ValueError(f'DMA transfer at {address:06x} follows a CPU access there in one instruction {where}')
            if not self.is_ram(address):
                raise ValueError(f'DMA transfer outside RAM at {address:06x} {where}')
            if write:
                uc.mem_write(address, bytes([value]))
                shadow[address] = value
                uc.ctl_remove_cache(address, address + 1)
                self.stats['dma_writes'] = self.stats.get('dma_writes', 0) + 1
            else:
                if shadow.get(address, 0) != value:
                    raise ValueError(f'DMA read {address:06x}={value:02x} but the oracle holds '
                                     f'{shadow.get(address, 0):02x} {where}')
                self.stats['dma_reads'] = self.stats.get('dma_reads', 0) + 1
        for index, level in gates:
            if any(not io for _, _, _, io in pending[:index]):
                raise ValueError(f'A20 gate change inside an instruction after its memory transfers {where}')
            self.a20 = bool(level)
            self.stats['a20_changes'] = self.stats.get('a20_changes', 0) + 1

    def __init__(self, rom, adapter_roms=(), ext_ram_kb=0, no_coprocessor=False):
        self.ext_end = 0x100000 + ext_ram_kb * 1024
        self.no_coprocessor = no_coprocessor
        self.a20 = True
        self.folded = {}
        g = self.g = Generator(None)
        uc = self.uc = g.uc
        uc.mem_map(0x200000, 0xe00000)  # the 286's full 16 MiB physical space
        for base in (0xf0000, 0xff0000):
            uc.mem_write(base, rom)
            g.shadow.update((base+i, v) for i, v in enumerate(rom))
        self.rom = rom
        # ROMs on adapter cards (base address, image): read-only memory the
        # oracle executes and reads like the BIOS ROM.
        self.adapter_roms = [(base, bytes(image)) for base, image in adapter_roms]
        for base, image in self.adapter_roms:
            if base < RAM_END or is_bios_rom(base) or is_bios_rom(base + len(image) - 1):
                raise ValueError(f'adapter ROM at {base:06x} overlaps board memory')
            uc.mem_write(base, image)
            g.shadow.update((base+i, v) for i, v in enumerate(image))
        # Device-memory reads the current instruction made on the CPU, in
        # order: (address, byte). read_hook serves them to Unicorn.
        self.device_reads = deque()
        self.device_unserved = []
        uc.hook_del(g.read_hook_handle)
        recorder = g.read_hook
        # Generator re-registers g.read_hook after a far RET (see run); the
        # serving hook replaces it there too.
        g.read_hook = lambda u, access, address, size, value, data: \
            self.read_hook(recorder, u, access, address, size, value, data)
        g.read_hook_handle = uc.hook_add(UC_HOOK_MEM_READ, g.read_hook)
        self.intr = []
        uc.hook_add(UC_HOOK_INTR, lambda u, number, data: self.intr.append(number))
        self.cr0_reset = uc.reg_read(UC_X86_REG_CR0) & ~1
        self.stats = dict(resets=0, hardware_interrupts=0, software_interrupts=0, exceptions={},
                          exceptions_by_286_rule=0, accessed_writes=0, accessed_adopted=0,
                          flags_image_adopted=0, open_bus_reads=0, rom_writes=0, unpopulated_writes=0,
                          smsw_adopted=0, sgdt_sixth_byte=0)
        self.reset_cpu()

    def reset_cpu(self):
        # 80286 reset state (210498-005 section 10.1 / data sheet Table 2):
        # FLAGS 0002, MSW FFF0, IP FFF0, CS F000, DS/SS/ES 0000, IDT base 0
        # limit 03FF. Real-mode segment caches are reloaded, so no limit or
        # base from protected mode survives. Memory is kept.
        uc = self.uc
        uc.reg_write(UC_X86_REG_CR0, self.cr0_reset)
        for register in REGS + SEGS:
            uc.reg_write(register, 0)
        uc.reg_write(UC_X86_REG_CS, 0xf000)
        uc.reg_write(UC_X86_REG_EFLAGS, 2)
        uc.reg_write(UC_X86_REG_IDTR, (0, 0, 0x3ff, 0))
        uc.ctl_remove_cache(0, 0x1000000)
        self.pm = False
        self.cs_base = 0xf0000

    def caches(self):
        """Unicorn's ES/CS/SS/DS caches: (selector, base, limit, access byte)."""
        image = self.uc.context_save().__getstate__()[0]
        result = []
        for n in range(4):
            selector, base, limit, flags = struct.unpack_from('<I4xQII', image, SEG_CACHE + 24*n)
            result.append((selector & 0xffff, base, limit, (flags >> 8) & 0xff))
        return result

    def refresh_cs(self):
        cs = self.uc.reg_read(UC_X86_REG_CS)
        self.cs_base = self.caches()[1][1] if self.pm else cs * 16

    def deliver(self, vector, return_ip, error, software):
        """Enter an interrupt or exception handler on Unicorn's state.

        Returns (expected transfers, addresses of the pushed FLAGS bytes).
        The transfer order is that of QEMU's do_interrupt_real (vector, then
        FLAGS/CS/IP pushes) and do_interrupt_protected (gate, CS descriptor,
        FLAGS/CS/IP[/error code] pushes), 210498-005 sections 5.2 and 9.3.
        """
        uc, g = self.uc, self.g
        cs = uc.reg_read(UC_X86_REG_CS)
        ip = uc.reg_read(UC_X86_REG_IP)
        flags = uc.reg_read(UC_X86_REG_EFLAGS)
        if flags & 0x100:
            raise ValueError(f'event {vector:02x} with TF set at {cs:04x}:{ip:04x}: single-step entry is not supported')
        _, base, limit, _ = uc.reg_read(UC_X86_REG_IDTR)
        shadow = g.shadow
        expected = []
        gate_type = None
        if not self.pm:
            if vector*4 + 3 > limit:
                raise ValueError(f'real-mode vector {vector:02x} beyond the IDT limit {limit:04x}')
            entry = [shadow.get(base + vector*4 + n, 0) for n in range(4)]
            expected += [(base + vector*4 + n, entry[n], 0, 0) for n in range(4)]
        else:
            if vector*8 + 7 > limit:
                raise ValueError(f'protected-mode vector {vector:02x} beyond the IDT limit {limit:04x}')
            gate = [shadow.get(base + vector*8 + n, 0) for n in range(8)]
            expected += [(base + vector*8 + n, gate[n], 0, 0) for n in range(8)]
            access = gate[5]
            gate_type = access & 0x1f
            # Only present 286 interrupt (6) and trap (7) gates to the same
            # privilege level are performed here; a task gate needs a task
            # switch, which Unicorn cannot perform in 286 format.
            if not access & 0x80 or gate_type not in (6, 7):
                raise ValueError(f'IDT gate {vector:02x} access {access:02x} is not a present 286 interrupt/trap gate')
            if software and (access >> 5) & 3 < (cs & 3):
                raise ValueError(f'INT {vector:02x} through a gate of lower DPL (#GP) is not supported')
            entry = gate[:4]
        target_ip = entry[0] | entry[1] << 8
        target_cs = entry[2] | entry[3] << 8
        code = (b'\x9c\x68' + word(cs) + b'\x68' + word(return_ip) +
                (b'\x68' + word(error) if error is not None else b'') + b'\xea' + word(target_ip) + word(target_cs))
        linear = self.cs_base + ip
        original = bytes(uc.mem_read(linear, len(code)))
        uc.mem_write(linear, code)
        uc.ctl_remove_cache(linear, linear + len(code))
        parts = []
        try:
            for _ in range(5 if error is not None else 4):
                g.bus.clear()
                self.intr.clear()
                uc.emu_start(cs*16 + uc.reg_read(UC_X86_REG_IP), 0, count=1)
                if self.intr:
                    raise ValueError(f'entry to vector {vector:02x} faulted in Unicorn ({self.intr[0]}): '
                                     'inter-privilege or invalid target is not supported')
                parts.append(list(g.bus))
        finally:
            uc.mem_write(linear, original)
            uc.ctl_remove_cache(linear, linear + len(code))
            g.bus.clear()
            g.seen.clear()
        pushes = [t for part in parts[:-1] for t in part]
        if any(linear <= t[0] < linear + len(code) for t in pushes):
            raise ValueError('event entry pushes overlap the interrupted code')
        if (uc.reg_read(UC_X86_REG_CS), uc.reg_read(UC_X86_REG_IP)) != (target_cs, target_ip):
            raise ValueError(f'Unicorn did not reach handler {target_cs:04x}:{target_ip:04x}')
        # Entry clears TF; real-mode entry and interrupt gates clear IF;
        # protected entry clears NT (210498-005 sections 5.2, 9.3.1;
        # QEMU do_interrupt_protected).
        flags &= ~0x100
        if not self.pm or gate_type == 6:
            flags &= ~0x200
        if self.pm:
            flags &= ~0x4000
        uc.reg_write(UC_X86_REG_EFLAGS, flags)
        self.refresh_cs()
        return expected + parts[-1] + pushes, {pushes[0][0], pushes[1][0]}

    def probe(self, cs, ip):
        """Execute one instruction in Unicorn and undo it completely."""
        uc, g = self.uc, self.g
        context = uc.context_save()
        writes = []

        def capture(u, access, address, size, value, data):
            writes.append((address, bytes(u.mem_read(address, size))))
        handle = uc.hook_add(UC_HOOK_MEM_WRITE, capture)
        ports = dict(g.ports)
        g.bus.clear()
        g.seen.clear()
        self.intr.clear()
        error = None
        try:
            uc.emu_start(cs*16 + ip, 0, count=1)
        except UcError as exc:
            error = exc
        finally:
            uc.hook_del(handle)
        bus, intr = list(g.bus), list(self.intr)
        if intr:
            # CPUX86State.error_code of the raised exception (offset in the
            # Unicorn 2.1.4 context image, verified with #GP(selector)).
            intr.append(struct.unpack_from('<i', uc.context_save().__getstate__()[0], ERROR_CODE)[0] & 0xffff)
        for address, old in reversed(writes):
            uc.mem_write(address, old)
            g.shadow.update((address+n, v) for n, v in enumerate(old))
            uc.ctl_remove_cache(address, address + len(old))
        uc.context_restore(context)
        g.ports = ports
        g.bus.clear()
        g.seen.clear()
        self.intr.clear()
        return bus, intr, error

    def segment_fault(self, pc, bus):
        """The 286 limit/rights fault Unicorn omits, or None.

        Applies 210498-005 section 6.3 to each byte Unicorn accessed, using
        Unicorn's own segment cache: the offset must be within the limit
        (expand-up: <= limit; expand-down: > limit), a write needs a
        writable data segment, a read of a code segment needs R, and a null
        selector cannot be used. A violation is #SS(0) for SS and #GP(0)
        otherwise (210498-005 section 9 exceptions 12 and 13, and the
        protected-mode exception lists of the instructions in Appendix B). Returns (vector, error, index of the first
        transfer of the violating access).
        """
        raw = bytes(self.uc.mem_read(pc, 10))
        n = 0
        override = None
        while raw[n] in (0x26, 0x2e, 0x36, 0x3e, 0xf2, 0xf3):
            if raw[n] not in (0xf2, 0xf3):
                override = {0x26: 0, 0x2e: 1, 0x36: 2, 0x3e: 3}[raw[n]]
            n += 1
        op = raw[n]
        caches = self.caches()
        if op in (0xa4, 0xa5, 0xa6, 0xa7, 0xaa, 0xab, 0xac, 0xad, 0xae, 0xaf):
            source = 3 if override is None else override
            plan = {0xa4: (source, 0), 0xa5: (source, 0), 0xa6: (source, 0), 0xa7: (source, 0),
                    0xaa: (0,), 0xab: (0,), 0xae: (0,), 0xaf: (0,), 0xac: (source,), 0xad: (source,)}[op]
        elif op <= 0x3b and op % 8 < 4 or op in (0x80, 0x81, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a,
                                                   0x8b, 0x8c, 0x8e, 0xc4, 0xc5, 0xc6, 0xc7, 0xd0, 0xd1, 0xd2,
                                                   0xd3, 0xf6, 0xf7, 0xfe, 0x62, 0xa0, 0xa1, 0xa2, 0xa3):
            if op in (0xa0, 0xa1, 0xa2, 0xa3):
                segment = 3
            else:
                modrm = raw[n+1]
                mod, rm = modrm >> 6, modrm & 7
                if mod == 3:
                    return None
                segment = 2 if rm in (2, 3) or rm == 6 and mod != 0 else 3
            plan = (segment if override is None else override,)
        else:
            raise ValueError(f'exception at {pc:06x}: no 286 segment rule for opcode {op:02x}')
        # Group the bytes into accesses: consecutive transfers in one
        # direction at ascending addresses.
        groups = []
        for index, (address, _, write, io) in enumerate(bus):
            if io:
                continue
            if groups and groups[-1][2] == write and address == groups[-1][3] + 1:
                groups[-1][3] = address
            else:
                groups.append([index, address, write, address])
        for number, (index, first, write, last) in enumerate(groups):
            segment = plan[min(number, len(plan) - 1)] if len(plan) > 1 else plan[0]
            selector, base, limit, access = caches[segment]
            for address in range(first, last + 1):
                offset = (address - base) & 0xffffff
                if offset > 0xffff:
                    raise ValueError(f'access {address:06x} at {pc:06x} is outside segment {segment} base {base:06x}')
                within = offset > limit if access & 0x14 == 0x14 and not access & 0x08 else offset <= limit
                code = access & 0x18 == 0x18
                allowed = (selector & 0xfffc and access & 0x90 == 0x90 and within and
                           (not write or not code and access & 2) and (write or not code or access & 2))
                if not allowed:
                    return (12 if segment == 2 else 13), 0, index
        return None

    def compare_event(self, expected, actual, flag_addresses, valid_flags, where):
        """Compare an event's expected transfers with the start of `actual`.

        `actual` has the CPU's accessed-byte writes already removed. FLAGS
        bits the replay does not compare in the register (undefined flags,
        and bits 12-14 in real mode, where the 286 keeps them clear but
        Unicorn models a later CPU) are not compared in the pushed image
        either; the CPU's byte is adopted. Returns the remaining transfers.
        """
        expected, oracle_writes = strip_oracle_accessed(expected)
        part = actual[:len(expected)]
        mask = valid_flags | 0x2a | (0x7000 if self.pm else 0)
        adopt = []
        ok = len(part) == len(expected)
        for e, a in zip(expected, part):
            if e == a:
                continue
            if e[0] == a[0] and e[2:] == a[2:] == (1, 0) and e[0] in flag_addresses:
                lane_mask = (mask >> (8 * (e[0] != min(flag_addresses)))) & 0xff
                if not (e[1] ^ a[1]) & lane_mask:
                    adopt.append(a)
                    shift = 8 * (e[0] != min(flag_addresses))
                    details = self.stats.setdefault('flags_image_differences', {})
                    key = f'{where.split("CPU ")[-1]} bits {(e[1] ^ a[1]) << shift:04x}'
                    details[key] = details.get(key, 0) + 1
                    continue
            ok = False
        if not ok:
            raise ValueError(f'event transfer mismatch {where}: CPU {part}, oracle {expected}')
        for address, value, _, _ in adopt:
            self.uc.mem_write(address, bytes([value]))
            self.g.shadow[address] = value
            self.stats['flags_image_adopted'] += 1
        return actual[len(expected):], oracle_writes

    def run(self, trace_path, on_step, allow_trailing):
        g, uc, stats = self.g, self.uc, self.stats
        ip = 0xe05b
        valid_flags = 0x8fd5
        pending = []
        acks = []
        dma = []
        gates = []
        steps = 0
        last_pc = None
        expect_reset = True
        inhibit = False
        with Path(trace_path).open() as trace:
            for line in trace:
                fields = line.split()
                if not fields:
                    raise ValueError('blank trace record')
                kind = fields[0]
                if kind == 'B':
                    if len(fields) != 5:
                        raise ValueError('malformed bus record')
                    pending.append(tuple(int(value, 16) for value in fields[1:]))
                    continue
                if kind == 'A':
                    if len(fields) != 2:
                        raise ValueError('malformed interrupt-acknowledge record')
                    acks.append((len(pending), int(fields[1], 16)))
                    continue
                if kind == 'D':
                    if len(fields) != 4 or fields[3] not in ('0', '1'):
                        raise ValueError('malformed DMA record')
                    dma.append((len(pending), int(fields[1], 16), int(fields[2], 16), fields[3] == '1'))
                    continue
                if kind == 'G':
                    if len(fields) != 2 or fields[1] not in ('0', '1'):
                        raise ValueError('malformed A20 gate record')
                    gates.append((len(pending), int(fields[1])))
                    continue
                if kind == 'Z':
                    if len(fields) != 1 or pending or acks:
                        raise ValueError(f'processor reset inside an instruction after step {steps}')
                    self.apply_board_records(pending, dma, gates, f'before the reset after step {steps}')
                    dma, gates = [], []
                    stats['resets'] += 1
                    self.reset_cpu()
                    ip = 0xe05b
                    valid_flags = 0x8fd5
                    inhibit = False
                    expect_reset = True
                    continue
                if kind != 'R' or len(fields) != 15:
                    raise ValueError('malformed retirement record')
                values = [int(value, 16) for value in fields[1:]]
                pc, op, next_cs, next_ip, actual_flags, actual_segs, *actual_regs = values
                steps += 1
                self.apply_board_records(pending, dma, gates, f'at step {steps}')
                dma, gates = [], []
                if expect_reset:
                    if (pc, op, next_cs, next_ip, actual_flags, actual_segs, actual_regs, pending, acks) != \
                            RESET_RECORD + ([], []):
                        raise ValueError(f'reset-vector transition mismatch at step {steps}')
                    expect_reset = False
                    last_pc = pc
                    continue
                where = f'at step {steps}, CPU {pc:06x}'
                # Memory outside RAM and ROM belongs to devices (video memory)
                # or is unpopulated: what a read returns there is board
                # behavior, an input from the trace like an I/O read, served
                # in order by read_hook. These records cover the faulting
                # instruction (if any), the event entry and this instruction.
                self.device_reads = deque((address, value) for address, value, write, io in pending
                                          if not write and not io and not self.is_ram(address) and
                                          self.rom_byte(address) is None)
                self.device_unserved = []
                # This firmware uses one byte input per instruction. Reject a
                # trace that would require different values for one port in the
                # same instruction, rather than silently collapsing its history.
                inputs = {}
                for address, value, write, io in pending:
                    if io and not write:
                        if address in inputs and inputs[address] != value:
                            raise ValueError('multiple distinct inputs for one port in an instruction')
                        inputs[address] = value
                g.ports.update(inputs)
                cs = uc.reg_read(UC_X86_REG_CS)
                actual = pending
                cpu_writes = None
                oracle_writes = []
                if acks:
                    # A hardware interrupt between the previous instruction and
                    # this one: INTA, INTA (vector), entry transfers, then this
                    # (the handler's first) instruction's own transfers.
                    if len(acks) != 2 or acks[0][0] or acks[1][0]:
                        raise ValueError(f'interrupt acknowledge not at an instruction boundary {where}')
                    if not uc.reg_read(UC_X86_REG_EFLAGS) & 0x200 or inhibit:
                        raise ValueError(f'interrupt taken with IF clear or in an interrupt shadow {where}')
                    vector = acks[1][1]
                    expected, flag_addresses = self.deliver(vector, uc.reg_read(UC_X86_REG_IP), None, False)
                    actual, cpu_writes = strip_cpu_accessed(pending)
                    actual, oracle_writes = self.compare_event(expected, actual, flag_addresses, valid_flags, where)
                    stats['hardware_interrupts'] += 1
                    stats.setdefault('interrupt_vectors', {}).setdefault(f'{vector:02x}{"p" if self.pm else "r"}', 0)
                    stats['interrupt_vectors'][f'{vector:02x}{"p" if self.pm else "r"}'] += 1
                    cs = uc.reg_read(UC_X86_REG_CS)
                    ip = uc.reg_read(UC_X86_REG_IP)
                    acks = []
                expected_pc = self.cs_base + ip
                if pc != expected_pc:
                    # The instruction at expected_pc faulted: it has no R
                    # record and the handler's first instruction follows.
                    if cpu_writes is not None:
                        raise ValueError(f'exception during interrupt entry {where}')
                    fault_pc = expected_pc
                    decoded = decode(uc, fault_pc, extended=True)
                    if decoded is None:
                        raise ValueError(f'PC mismatch {where}: oracle {fault_pc:06x} (unsupported instruction)')
                    bus, intr, error = self.probe(cs, ip)
                    if error is not None:
                        raise ValueError(f'PC mismatch {where}: oracle {fault_pc:06x} raised {error}')
                    if intr:
                        vector = intr[0]
                        if decoded[0] == 0xcd or vector in (1, 2, 3, 8) or vector > 13:
                            raise ValueError(f'PC mismatch {where}: oracle {fault_pc:06x} raised {vector} '
                                             '(not a supported fault)')
                        # Faults 10-13 push an error code (210498-005 9.4);
                        # Unicorn's value is compared with the CPU's push.
                        partial, error_code = bus, intr[-1] if 10 <= vector <= 13 else None
                    else:
                        fault = self.segment_fault(fault_pc, bus)
                        if fault is None:
                            raise ValueError(f'PC mismatch {where}: oracle {fault_pc:06x} retires without a 286 fault')
                        vector, error_code, index = fault
                        partial = bus[:index]
                        stats['exceptions_by_286_rule'] += 1
                    entry, flag_addresses = self.deliver(vector, ip, error_code, False)
                    actual, cpu_writes = strip_cpu_accessed(pending)
                    actual, oracle_writes = self.compare_event(partial + entry, actual, flag_addresses,
                                                               valid_flags, where)
                    key = f'{vector:02x} at {fault_pc:06x}'
                    stats['exceptions'][key] = stats['exceptions'].get(key, 0) + 1
                    cs = uc.reg_read(UC_X86_REG_CS)
                    ip = uc.reg_read(UC_X86_REG_IP)
                    expected_pc = self.cs_base + ip
                    if pc != expected_pc:
                        raise ValueError(f'PC mismatch after exception {where}: oracle {expected_pc:06x}')
                decoded = decode(uc, pc, extended=True)
                if decoded is None or decoded[0] != op:
                    raise ValueError(f'opcode mismatch at {pc:06x}, CPU {op:02x}, oracle {decoded}')
                _, raw = decoded
                # decode() returns the bytes from the opcode on; the bytes before
                # it are prefixes. decode() accepts a repeat prefix only on a
                # repeatable string opcode.
                repeated = any(b in (0xf2, 0xf3) for b in bytes(uc.mem_read(pc, 10 - len(raw))))
                system = (raw[2] >> 3) & 7 if op == 0x0f and raw[1] == 0x01 else None
                before = [uc.reg_read(r) for r in REGS]
                flags_before = uc.reg_read(UC_X86_REG_EFLAGS)
                g.bus.clear()
                g.seen.clear()
                self.intr.clear()
                # The CPU trace has one R record per whole instruction; a repeated
                # string instruction's element transfers all precede it. Unicorn
                # executes one element per count=1 step and stays at the same PC
                # until the count ends, so step it until it leaves the instruction
                # (as Generator.case does) and compare the aggregate.
                repetitions = 0
                if op in (0xca, 0xcb):
                    # Unicorn 2.1.4's memory-read hook instrumentation leaves
                    # EIP stale after a far RET (CS and SP are updated; see
                    # Generator.continuous_case). Execute it without the hook
                    # and supply its stack reads: IP then CS, four ascending
                    # bytes at SS:SP (210498-005 Appendix B RET). Only the
                    # real-mode form is supported; a protected far RET would
                    # also read a descriptor.
                    if self.pm:
                        raise ValueError(f'protected-mode far RET at {pc:06x} is not supported')
                    ss, sp = uc.reg_read(SEGS[2]), uc.reg_read(REGS[4])
                    uc.hook_del(g.read_hook_handle)
                    try:
                        uc.emu_start(cs*16 + ip, 0, count=1)
                    finally:
                        g.read_hook_handle = uc.hook_add(UC_HOOK_MEM_READ, g.read_hook)
                    g.bus[:0] = [(ss*16 + ((sp + n) & 0xffff), g.shadow.get(ss*16 + ((sp + n) & 0xffff), 0), 0, 0)
                                 for n in range(4)]
                    repetitions = 1
                escape = 0xd8 <= op <= 0xdf and self.no_coprocessor
                if escape:
                    # No 80287 is fitted (IBM PC AT system, assumption
                    # AT17). On the 286 an ESC instruction with MSW EM and TS
                    # clear hands the opcode to the processor extension
                    # through I/O cycles at ports 00F8h-00FFh and then moves
                    # operand words only when the extension asserts PEREQ
                    # (210498-005 sections 1.4/11 and Appendix B ESC); with
                    # no extension nothing else happens and the instruction
                    # changes no register or memory. Unicorn emulates an x87
                    # instead, so it does not execute the instruction: the
                    # oracle advances IP by the instruction's length and
                    # accepts only I/O writes to 00F8h-00FFh as its
                    # transfers. Their values (the 286's processor-extension
                    # protocol) are not judged by Unicorn; they are counted.
                    if uc.reg_read(UC_X86_REG_CR0) & 0xc:
                        raise ValueError(f'ESC at {pc:06x} with MSW EM or TS set is not supported')
                    modrm = raw[1]
                    mod, rm = modrm >> 6, modrm & 7
                    disp = 2 if mod == 2 or (mod == 0 and rm == 6) else 1 if mod == 1 else 0
                    length = (10 - len(raw)) + 2 + disp
                    if not actual or any(not (t[2] and t[3] and 0xf8 <= t[0] <= 0xff) for t in actual):
                        raise ValueError(f'ESC at {pc:06x} without an 80287: CPU transfers {actual[:8]} are not '
                                         'only processor-extension port writes')
                    uc.reg_write(UC_X86_REG_IP, (ip + length) & 0xffff)
                    g.bus[:] = list(actual)
                    g.seen[:] = [(pc, length)]
                    repetitions = 1
                    stats['esc_without_coprocessor'] = stats.get('esc_without_coprocessor', 0) + 1
                while op not in (0xca, 0xcb) and not escape:
                    uc.emu_start(cs*16 + ip, 0, count=1)
                    repetitions += 1
                    if not repeated or uc.reg_read(UC_X86_REG_CS)*16 + uc.reg_read(UC_X86_REG_IP) != cs*16 + ip:
                        break
                    if repetitions > 65536:
                        raise ValueError(f'oracle repeat at {pc:06x} did not finish within the CX range')
                self.unfold()
                if len(g.seen) != repetitions or any(address != pc for address, _ in g.seen):
                    raise ValueError(f'oracle synchronization error at {pc:06x}')
                if self.device_unserved or self.device_reads:
                    raise ValueError(f'device-memory read mismatch at {pc:06x}: oracle read '
                                     f'{[f"{a:06x}" for a in self.device_unserved[:8]]} without a CPU read there, '
                                     f'CPU reads left {[f"{a:06x}={v:02x}" for a, v in list(self.device_reads)[:8]]}')
                bus = g.bus
                flag_addresses = ()
                if op == 0x9c and len(bus) == 2:
                    # PUSHF stores the whole FLAGS image, including flags that
                    # are undefined at this point; those bits are compared
                    # like the register's (compare_event) and adopted.
                    flag_addresses = {bus[0][0], bus[1][0]}
                if self.intr:
                    # Unicorn reports INT n through the interrupt hook with IP
                    # after the instruction and does not vector it.
                    if op != 0xcd or self.intr != [raw[1]] or uc.reg_read(UC_X86_REG_IP) != (ip + 2) & 0xffff:
                        raise ValueError(f'oracle raised exception {self.intr} at {pc:06x}, which the CPU retired')
                    own = list(bus)
                    entry, flag_addresses = self.deliver(raw[1], uc.reg_read(UC_X86_REG_IP), None, True)
                    bus = own + entry
                    stats['software_interrupts'] += 1
                if op == 0x0f and raw[1] == 0x01 and system == 6:
                    self.pm = bool(uc.reg_read(UC_X86_REG_CR0) & 1)
                if op in FAR_OPS or self.intr or op == 0xff and (raw[1] >> 3) & 7 == 3:
                    self.refresh_cs()
                elif not self.pm:
                    self.cs_base = uc.reg_read(UC_X86_REG_CS) * 16
                ip = uc.reg_read(UC_X86_REG_IP)
                # CMPS/SCAS set OF/SF/ZF/AF/PF/CF as CMP does; the other string
                # forms, the repeat itself and an initially zero CX (no element)
                # leave every flag unchanged (Intel 210498-005 §3.7.2 and the
                # Appendix B CMPS/SCAS/LODS/MOVS/STOS/REP entries; see
                # design/intel_80286/spec/string_execution.md).
                if op in (0xa6, 0xa7, 0xae, 0xaf) and (not repeated or before[1]):
                    valid_flags |= 0x8d5
                # 0F 01 SGDT/SIDT/LGDT/LIDT/SMSW/LMSW change no flags (210498-005
                # Appendix B entries; spec/system_register_execution.md).
                if op <= 0x3d and op % 8 <= 5 or op in (0x80, 0x81, 0x83):
                    kind = (raw[1] >> 3) & 7 if op in (0x80, 0x81, 0x83) else op // 8
                    valid_flags |= 0x8d5
                    if kind in (1, 4, 6):
                        valid_flags &= ~0x10
                if op in (0x84, 0x85, 0xa8, 0xa9) or op in (0xf6, 0xf7) and (raw[1] >> 3) & 7 == 0:
                    # TEST (all forms): OF/CF cleared, SF/ZF/PF set, AF
                    # undefined (210498-005 Appendix B TEST).
                    valid_flags = (valid_flags | 0x8c5) & ~0x10
                if op in (0xf6, 0xf7) and (raw[1] >> 3) & 7 == 3:
                    valid_flags |= 0x8d5  # NEG defines OF/SF/ZF/AF/PF/CF
                if op in (0xf6, 0xf7) and (raw[1] >> 3) & 7 in (4, 5):
                    # MUL/IMUL define OF and CF; SF/ZF/AF/PF are undefined.
                    valid_flags = (valid_flags | 0x801) & ~0xd4
                if op in (0xf6, 0xf7) and (raw[1] >> 3) & 7 in (6, 7):
                    valid_flags &= ~0x8d5  # DIV/IDIV leave all six undefined
                if 0x40 <= op <= 0x4f or op in (0xfe, 0xff) and (raw[1] >> 3) & 7 in (0, 1):
                    valid_flags |= 0x8d4  # INC/DEC define OF/SF/ZF/AF/PF, CF unchanged
                if op in (0xc0, 0xc1, 0xd0, 0xd1, 0xd2, 0xd3):
                    extension = (raw[1] >> 3) & 7
                    shift_count = (bytes(uc.mem_read(pc, g.seen[0][1]))[-1] & 31) if op in (0xc0, 0xc1) else before[1] & 31 if op in (0xd2, 0xd3) else 1
                    if shift_count:
                        if extension >= 4:
                            valid_flags = (valid_flags | 0xc5) & ~0x10
                        valid_flags = valid_flags | 0x800 if shift_count == 1 else valid_flags & ~0x800
                        if extension in (4, 5) and shift_count >= (16 if op & 1 else 8):
                            valid_flags &= ~1
                if op == 0x9e:
                    valid_flags |= 0xd5
                # POPF and IRET load every flag from the stack image.
                if op in (0x9d, 0xcf):
                    valid_flags = 0x8fd5
                # ARPL, VERR/VERW, LAR and LSL define ZF only (210498-005
                # Appendix B); the other flags are unchanged.
                if op == 0x63 or op == 0x0f and (raw[1] in (0x02, 0x03) or raw[1] == 0 and (raw[2] >> 3) & 7 in (4, 5)):
                    valid_flags |= 0x40
                flags = uc.reg_read(UC_X86_REG_EFLAGS) & 0xffff
                segs = sum(uc.reg_read(r) << (16*n) for n, r in enumerate(SEGS))
                regs = [uc.reg_read(r) for r in REGS]
                reg_masks = [0xffff] * 8
                if op == 0x9f:
                    reg_masks[0] = 0xd5ff
                if system == 4:
                    # SMSW r16: Unicorn stores a later CPU's CR0 low word. Only
                    # PE/MP/EM/TS (bits 0-3) are defined MSW bits on the 286;
                    # bits 4-15 are reserved (210498-005 MSW description and
                    # Appendix B SMSW). Unicorn is not a 286 oracle for them, so
                    # they are not compared and the CPU's value is adopted.
                    reg_masks[raw[2] & 7] = 0x000f
                if (uc.reg_read(UC_X86_REG_CS), ip) != (next_cs, next_ip):
                    raise ValueError(f'next CS:IP mismatch at {pc:06x}: CPU {next_cs:04x}:{next_ip:04x}, '
                                     f'oracle {uc.reg_read(UC_X86_REG_CS):04x}:{ip:04x}')
                # In protected mode IOPL and NT (bits 12-14) are defined 286
                # flags and are compared too.
                flag_mask = valid_flags | (0x7000 if self.pm else 0)
                if (flags ^ actual_flags) & flag_mask or segs != actual_segs:
                    raise ValueError(f'flags/segments mismatch at {pc:06x}: CPU {actual_flags:04x} {actual_segs:016x}, '
                                     f'oracle {flags:04x} {segs:016x}, mask {flag_mask:04x}')
                for index, (expected, actual_reg) in enumerate(zip(regs, actual_regs)):
                    if (expected ^ actual_reg) & reg_masks[index]:
                        raise ValueError(f'register {index} mismatch at {pc:06x}: CPU {actual_reg:04x}, oracle {expected:04x}')
                if system in (0, 1):
                    # SGDT/SIDT store limit16, base24 and a sixth byte the 286
                    # manual leaves unused (210498-005 Appendix B SGDT/SIDT;
                    # assumption A12 in spec/system_register_execution.md).
                    # Require six ascending writes that agree in every address,
                    # direction and the five defined values; the sixth value is
                    # not authoritative in Unicorn, so the CPU's byte is copied
                    # into the oracle's memory to keep later reads in step.
                    if (len(bus) != 6 or len(actual) != 6 or bus[:5] != actual[:5] or
                            (bus[5][0],) + bus[5][2:] != (actual[5][0],) + actual[5][2:] or
                            any(bus[n][0] != bus[0][0] + n or bus[n][2:] != (1, 0) for n in range(6))):
                        raise ValueError(f'bus mismatch at {pc:06x}: CPU {actual}, oracle {bus}')
                    address, value = actual[5][:2]
                    uc.mem_write(address, bytes([value]))
                    g.shadow[address] = value
                    stats['sgdt_sixth_byte'] += 1
                elif op == 0x60:
                    # QEMU batches PUSHA's stores in ascending address order
                    # (the BUS_ANY case of generate_vectors.py). Require the
                    # same bytes and Intel's order: AX, CX, DX, BX, SP, BP,
                    # SI, DI, each a word push at the next lower address
                    # (210498-005 Appendix B PUSHA).
                    if (sorted(bus) != sorted(actual) or len(actual) != 16 or cpu_writes is not None or
                            any(actual[2*n][0] != actual[0][0] - 2*n or actual[2*n+1][0] != actual[2*n][0] + 1
                                for n in range(8))):
                        raise ValueError(f'PUSHA mismatch at {pc:06x}: CPU {actual}, oracle {bus}')
                elif flag_addresses:
                    actual, writes = strip_cpu_accessed(actual)
                    cpu_writes = (cpu_writes or []) + writes
                    rest, more = self.compare_event(bus, actual, flag_addresses, valid_flags, f'at {pc:06x}')
                    oracle_writes += more
                    if rest:
                        raise ValueError(f'bus mismatch at {pc:06x}: CPU has extra transfers {rest}')
                elif bus != actual or cpu_writes is not None:
                    # Descriptor accessed-bit updates differ by design between
                    # the 286 and Unicorn (see strip_cpu_accessed and
                    # strip_oracle_accessed); compare everything else exactly.
                    oracle_rest, more = strip_oracle_accessed(bus)
                    oracle_writes += more
                    if cpu_writes is None:
                        actual, cpu_writes = strip_cpu_accessed(actual)
                    if oracle_rest != actual:
                        raise ValueError(f'bus mismatch at {pc:06x}: CPU {actual}, oracle {bus}')
                if cpu_writes or oracle_writes:
                    cpu = {address: (value, read) for address, value, read in cpu_writes or ()}
                    for address, value in oracle_writes:
                        if cpu.get(address, (None,))[0] != value:
                            raise ValueError(f'oracle wrote access byte {address:06x}={value:02x} but the CPU '
                                             f'did not, {where}')
                    # The 286 sets A on every descriptor load (210498-005
                    # 6.3.1); QEMU only on some loads and only when clear.
                    # The CPU's value is adopted where Unicorn left A clear;
                    # any other access-byte change must match Unicorn's.
                    for address, (value, read) in cpu.items():
                        stats['accessed_writes'] += 1
                        if g.shadow.get(address, 0) != value:
                            if value != read | 1:
                                raise ValueError(f'CPU access-byte write {address:06x}={value:02x} not made by '
                                                 f'the oracle, {where}')
                            uc.mem_write(address, bytes([value]))
                            g.shadow[address] = value
                            stats['accessed_adopted'] += 1
                if system == 4:
                    if (regs[raw[2] & 7] ^ actual_regs[raw[2] & 7]) & 0xfff0:
                        stats['smsw_adopted'] += 1
                    uc.reg_write(REGS[raw[2] & 7], actual_regs[raw[2] & 7])
                # Writes outside RAM do not change memory on this board.
                for address, value, write, io in pending:
                    if write and not io and not self.is_ram(address):
                        byte = self.rom_byte(address)
                        if byte is not None:
                            stats['rom_writes'] += 1
                            uc.mem_write(address, bytes([byte]))
                            g.shadow[address] = byte
                        else:
                            stats['unpopulated_writes'] += 1
                inhibit = (op == 0xfb and not flags_before & 0x200 or op == 0x17 or
                           op == 0x8e and (raw[1] >> 3) & 7 == 2)
                pending = []
                if on_step:
                    on_step(pc, next_ip, inputs)
                last_pc = pc
        if (dma or gates) and not allow_trailing:
            raise ValueError('trace ends with board records after the last retirement')
        if acks or expect_reset and steps:
            raise ValueError('trace ends inside an event')
        if pending and not allow_trailing:
            raise ValueError('trace ends with data records after the last retirement')
        return steps, last_pc, pending


def replay(rom_path, trace_path, on_step=None, allow_trailing=False, stats=None, adapter_roms=(),
           ext_ram_kb=0, no_coprocessor=False):
    """Compare the trace with Unicorn.

    on_step(pc, next_ip, inputs) is called after each compared instruction,
    where inputs maps port -> byte read by that instruction. With
    allow_trailing, data records after the last retirement (an instruction
    the run stopped inside) are returned instead of rejected. If stats is a
    dict it receives the event and non-oracle counters. adapter_roms is a
    sequence of (base address, image bytes) for ROMs on adapter cards;
    ext_ram_kb is the expansion RAM from 100000h in KiB. With no_coprocessor
    (a board with no 80287), ESC instructions are judged as the 286 runs them
    without a processor extension (see run).
    Returns (steps, last_pc, trailing_records).
    """
    rom = Path(rom_path).read_bytes()
    if len(rom) != 65536 or hashlib.sha256(rom).hexdigest() != ROM_SHA256:
        raise ValueError('unrecognized IBM AT BIOS')
    state = _Replay(rom, adapter_roms, ext_ram_kb, no_coprocessor)
    try:
        return state.run(trace_path, on_step, allow_trailing)
    finally:
        if stats is not None:
            stats.update(state.stats)
