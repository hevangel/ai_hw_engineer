#!/usr/bin/env python3
"""Run unmodified pinned py65 to generate all immediate ADC/SBC expectations."""
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'work/external/python'))
from py65.devices.mpu6502 import MPU

memory = [0] * 65536
cpu = MPU(memory=memory, pc=0x8000)
with (ROOT / 'work/arithmetic.bin').open('wb') as output:
    output.write(struct.pack('<I', 524288))
    for op in (0x69, 0xe9):
        memory[0x8000] = op
        for decimal in (0, 8):
            for carry in (0, 1):
                initial_p = 0x24 | decimal | carry
                for a in range(256):
                    for operand in range(256):
                        cpu.pc, cpu.a, cpu.p = 0x8000, a, initial_p
                        memory[0x8001] = operand
                        cpu.step()
                        assert cpu.pc == 0x8002
                        output.write(bytes((op, a, operand, initial_p, cpu.a, cpu.p)))
print('Generated 524288 exhaustive unmodified py65 arithmetic expectations')
