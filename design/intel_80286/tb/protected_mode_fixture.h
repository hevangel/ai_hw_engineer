// Source-frozen ring-0 protected-mode fixture. Include from bootstrap.cpp only
// after the protected-mode architectural path and bus checks are implemented.
// Expected semantics: Intel 210498-005 §§7.4.1, 9.4, 9.6.7, 10.2.2, 10.4.2;
// 86Box 286 gate/IRET corroboration is pinned at commit
// 1db9ae4cc910b0b7e6e9b49995910b0cc19747a0.
#ifndef INTEL_80286_PROTECTED_MODE_FIXTURE_H
#define INTEL_80286_PROTECTED_MODE_FIXTURE_H

#include <cstdint>

namespace protected_mode_fixture {

constexpr uint32_t kResetVector = 0x00fffff0;
constexpr uint32_t kRealCodeBase = 0x000f0000;
constexpr uint32_t kGdtBase = 0x00000300;
constexpr uint32_t kIdtBase = 0x00000500;
constexpr uint32_t kCodeBase = 0x00010000;
constexpr uint32_t kHandlerBase = 0x00011000;
constexpr uint32_t kWideDataBase = 0x00020000;
constexpr uint32_t kNarrowDataBase = 0x00030000;
constexpr uint32_t kEsDataBase = 0x00040000;
constexpr uint32_t kStackBase = 0x00050000;

constexpr uint16_t kCodeSelector = 0x0008;
constexpr uint16_t kHandlerSelector = 0x0030;
constexpr uint16_t kWideDataSelector = 0x0010;
constexpr uint16_t kNarrowDsSelector = 0x0018;
constexpr uint16_t kEsSelector = 0x0020;
constexpr uint16_t kSsSelector = 0x0028;
constexpr uint16_t kInitialSp = 0x0080;
constexpr uint16_t kFaultIp = 0x0221;
constexpr uint16_t kFaultSuccessorIp = 0x0225;
constexpr uint16_t kHandlerIp = 0x0300;
constexpr uint16_t kSavedFlags = 0x0603;  // CF=1, IF=1, DF=1, reserved bit 1.
constexpr uint16_t kFaultVector = 13;
constexpr uint16_t kFaultError = 0x0000;

// Real-mode reset jump to F000:0100, then LGDT/LIDT, flags setup, LMSW, the
// required same-segment queue flush, and the protected far JMP to 0008:0200.
constexpr uint8_t kResetJump[] = {0xea, 0x00, 0x01, 0x00, 0xf0};
constexpr uint8_t kRealModeProgram[] = {
    0x0f, 0x01, 0x16, 0x40, 0x00,  // F000:0100 LGDT [0040]
    0x0f, 0x01, 0x1e, 0x46, 0x00,  // F000:0105 LIDT [0046]
    0xf9,                          // F000:010A STC
    0xfd,                          // F000:010B STD
    0xfb,                          // F000:010C STI
    0xb8, 0x01, 0x00,              // F000:010D MOV AX,0001
    0x0f, 0x01, 0xf0,              // F000:0110 LMSW AX (sets sticky PE)
    0xeb, 0x00,                    // F000:0113 JMP $+2
    0xea, 0x00, 0x02, 0x08, 0x00  // F000:0115 JMP FAR 0008:0200
};

// Seven GDT entries: null, code, wide data, narrow DS, ES, SS and handler CS.
// Each 286 descriptor is eight bytes. Accessed bits start clear.
constexpr uint8_t kGdtImage[] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xff, 0x0f, 0x00, 0x00, 0x01, 0x9a, 0x00, 0x00,  // 0008 code, base 010000
    0xff, 0x00, 0x00, 0x00, 0x02, 0x92, 0x00, 0x00,  // 0010 data, base 020000
    0x0f, 0x00, 0x00, 0x00, 0x03, 0x92, 0x00, 0x00,  // 0018 data, base 030000
    0xff, 0x00, 0x00, 0x00, 0x04, 0x92, 0x00, 0x00,  // 0020 data, base 040000
    0xff, 0x00, 0x00, 0x00, 0x05, 0x92, 0x00, 0x00,  // 0028 stack, base 050000
    0xff, 0x0f, 0x00, 0x10, 0x01, 0x9a, 0x00, 0x00   // 0030 handler code, base 011000
};

// The descriptor-table pseudo-descriptors are six bytes on the 80286.
constexpr uint8_t kGdtrImage[] = {0x37, 0x00, 0x00, 0x03, 0x00, 0x00};
constexpr uint8_t kIdtrImage[] = {0x6f, 0x00, 0x00, 0x05, 0x00, 0x00};

// Vector 13 at IDT+13*8: present ring-0 interrupt gate to 0030:0300.
constexpr uint8_t kVector13Gate[] = {
    0x00, 0x03, 0x30, 0x00, 0x00, 0x86, 0x00, 0x00
};

// Protected program at physical 010200. DS:000F word read crosses the narrow
// DS limit and is the only faulting instruction. Its first byte is the DS
// override prefix; the exact retry successor is INC BP at CS:0225.
constexpr uint8_t kProtectedProgram[] = {
    0xb8, 0x18, 0x00, 0x8e, 0xd8,              // 0200 MOV DS,0018
    0xb8, 0x20, 0x00, 0x8e, 0xc0,              // 0205 MOV ES,0020
    0xb8, 0x28, 0x00, 0x8e, 0xd0,              // 020A MOV SS,0028
    0xbc, 0x80, 0x00,                          // 020F MOV SP,0080
    0xa1, 0x02, 0x00,                          // 0212 MOV AX,[DS:0002]
    0xa3, 0x04, 0x00,                          // 0215 MOV [DS:0004],AX
    0x26, 0xa3, 0x06, 0x00,                    // 0218 MOV [ES:0006],AX
    0x50,                                      // 021C PUSH AX
    0x5b,                                      // 021D POP BX
    0xb8, 0xfe, 0xca,                          // 021E MOV AX,CAFE
    0x3e, 0xa1, 0x0f, 0x00,                    // 0221 DS: MOV AX,[000F] => #GP(0)
    0x45,                                      // 0225 INC BP, exact retry successor
    0xf4                                       // 0226 HLT
};

// Same-level handler at physical 011300. It discards the error word, preserves
// AX while widening DS, and IRETs to the exact first byte of the faulting op.
constexpr uint8_t kVector13Handler[] = {
    0x83, 0xc4, 0x02,  // 0300 ADD SP,2 (discard #GP error code)
    0x50,               // 0303 PUSH AX
    0xb8, 0x10, 0x00,   // 0304 MOV AX,0010 (wider data descriptor)
    0x8e, 0xd8,         // 0307 MOV DS,AX
    0x58,               // 0309 POP AX
    0xcf                // 030A IRET
};

constexpr uint8_t kNarrowDataSeed[] = {0x34, 0x12};
constexpr uint8_t kWideRetryWord[] = {0xef, 0xbe};

struct ExpectedRead {
    uint32_t address;
    uint8_t length;
};

// Full eight-byte descriptor reads, in transaction order. IDT gate lookup is
// followed by the target CS descriptor; IRET reloads and validates CS again.
constexpr ExpectedRead kDescriptorReads[] = {
    {0x00000308, 8},  // far JMP -> protected CS
    {0x00000318, 8},  // MOV DS, narrow descriptor
    {0x00000320, 8},  // MOV ES
    {0x00000328, 8},  // MOV SS
    {0x00000568, 8},  // IDT vector 13 gate
    {0x00000330, 8},  // gate target handler CS
    {0x00000310, 8},  // handler widens DS
    {0x00000308, 8}   // IRET return CS
};

struct ExpectedAccessWrite {
    uint32_t address;
    uint8_t value;
};

// Functional 286 descriptor transactions write access OR 01 before cache
// publication, including a code descriptor whose accessed bit is already set.
constexpr ExpectedAccessWrite kAccessWrites[] = {
    {0x0000030d, 0x9b},  // far JMP CS
    {0x0000031d, 0x93},  // narrow DS
    {0x00000325, 0x93},  // ES
    {0x0000032d, 0x93},  // SS
    {0x00000335, 0x9b},  // #GP handler CS
    {0x00000315, 0x93},  // wider DS
    {0x0000030d, 0x9b}   // IRET CS
};

struct ExpectedByteWrite {
    uint32_t address;
    uint8_t value;
};

// Same-level exception frame write order: FLAGS, CS, IP, then error code.
// At handler entry SS:SP is 0028:0078. The handler later overwrites the error
// word with the saved AX value while preserving the original stack frame.
constexpr ExpectedByteWrite kFaultFrameWrites[] = {
    {0x0005007e, 0x03}, {0x0005007f, 0x06},  // saved FLAGS = 0603
    {0x0005007c, 0x08}, {0x0005007d, 0x00},  // saved CS = 0008
    {0x0005007a, 0x21}, {0x0005007b, 0x02},  // saved IP = 0221
    {0x00050078, 0x00}, {0x00050079, 0x00}   // #GP(0), EXT=0
};

struct ExpectedPc {
    uint16_t cs;
    uint16_t ip;
    uint16_t next_cs;
    uint16_t next_ip;
};

// Control-flow boundaries that must match exactly. The event and IRET entries
// are included even though exception entry is not an instruction retirement.
constexpr ExpectedPc kPcTrace[] = {
    {0xf000, 0xfff0, 0xf000, 0x0100},
    {0xf000, 0x0100, 0xf000, 0x0105},
    {0xf000, 0x0105, 0xf000, 0x010a},
    {0xf000, 0x010a, 0xf000, 0x010b},
    {0xf000, 0x010b, 0xf000, 0x010c},
    {0xf000, 0x010c, 0xf000, 0x010d},
    {0xf000, 0x010d, 0xf000, 0x0110},
    {0xf000, 0x0110, 0xf000, 0x0113},
    {0xf000, 0x0113, 0xf000, 0x0115},
    {0xf000, 0x0115, 0x0008, 0x0200},
    {0x0008, 0x0200, 0x0008, 0x0203},
    {0x0008, 0x0203, 0x0008, 0x0205},
    {0x0008, 0x0205, 0x0008, 0x0208},
    {0x0008, 0x0208, 0x0008, 0x020a},
    {0x0008, 0x020a, 0x0008, 0x020d},
    {0x0008, 0x020d, 0x0008, 0x020f},
    {0x0008, 0x020f, 0x0008, 0x0212},
    {0x0008, 0x0212, 0x0008, 0x0215},
    {0x0008, 0x0215, 0x0008, 0x0218},
    {0x0008, 0x0218, 0x0008, 0x021c},
    {0x0008, 0x021c, 0x0008, 0x021d},
    {0x0008, 0x021d, 0x0008, 0x021e},
    {0x0008, 0x021e, 0x0008, 0x0221},
    {0x0008, 0x0221, 0x0030, 0x0300},  // vector-13 entry
    {0x0030, 0x0300, 0x0030, 0x0303},
    {0x0030, 0x0303, 0x0030, 0x0304},
    {0x0030, 0x0304, 0x0030, 0x0307},
    {0x0030, 0x0307, 0x0030, 0x0309},
    {0x0030, 0x0309, 0x0030, 0x030a},
    {0x0030, 0x030a, 0x0008, 0x0221},  // IRET retry
    {0x0008, 0x0221, 0x0008, 0x0225},  // successful replay
    {0x0008, 0x0225, 0x0008, 0x0226}, // INC BP, then HLT
    {0x0008, 0x0226, 0x0008, 0x0227}  // HLT
};

struct ExpectedDataTransfer {
    uint32_t address;
    uint8_t value;
    bool write;
};

// Filtered ordinary operand/stack traffic before the fault. These addresses
// distinguish the descriptor bases from selector-times-sixteen addressing.
constexpr ExpectedDataTransfer kDataTransfersBeforeFault[] = {
    {0x00030002, 0x34, false}, {0x00030003, 0x12, false}, // DS word read
    {0x00030004, 0x34, true},  {0x00030005, 0x12, true},  // DS word write
    {0x00040006, 0x34, true},  {0x00040007, 0x12, true},  // ES override write
    {0x0005007e, 0x34, true},  {0x0005007f, 0x12, true},  // PUSH AX
    {0x0005007e, 0x34, false}, {0x0005007f, 0x12, false}  // POP BX
};

constexpr ExpectedDataTransfer kDataTransfersOnRetry[] = {
    {0x0002000f, 0xef, false}, {0x00020010, 0xbe, false}
};

// The denied read must issue no transaction at 03000F/030010 and leave AX=CAFE
// at handler entry. After DS becomes selector 0010, replay reads 02000F/10,
// producing AX=BEEF; BP increments from 0 to 1 before the exact HLT.
constexpr uint32_t kDeniedReadFirst = 0x0003000f;
constexpr uint32_t kDeniedReadLast = 0x00030010;
constexpr uint32_t kRetryReadFirst = 0x0002000f;
constexpr uint32_t kRetryReadLast = 0x00020010;
constexpr uint16_t kAxAtHandler = 0xcafe;
constexpr uint16_t kAxAfterRetry = 0xbeef;
constexpr uint16_t kBxAfterStackRoundTrip = 0x1234;
constexpr uint16_t kBpAfterSuccessor = 0x0001;
constexpr uint16_t kLiveFlagsAtHandler = 0x0403;  // interrupt gate clears IF.

}  // namespace protected_mode_fixture

#endif
