# Intel MCS-8 8008 User Manual (November 1973)

Source: https://deramp.com/downloads/mfe_archive/050-Component%20Specifications/Intel/Microprocessors%20and%20Support/8008%20Family/i8008UM%20Nov%2073.pdf

This searchable transcription was extracted from the archived Intel scan. Diagrams, tables, and OCR may require checking against the PDF.


## Scan page 1

m(S' ~8 Microcomputer Set
8008
NOVEMBER 1973
REV . 4
Second Printing
8 Bit Parallel
Central Processor Unit
USERS MANUAL
C Intel Corp . 197J


## Scan page 2

InTEL
SUPPORT
mdKES
SYSTEm
BUilDInG
EdSY.
The MCS-S™ parallel 8-bit microcomputer set is de
signed for efficient handling of large volumes of data.
It has interrupt capability, operates synchronously or
asynchronously with external memory, and executes
subroutines nested up to seven levels. The 8008 CPU,
heart of the MCS-8, replaces 125 TTL packs. With it
you can easi Iy address up to 16k 8-bit words of ROM,
RAM or shift registers. Using bank switching techniques,
you can extend its memory indefinitely.
The PL/M™ High Level Language is an easy-to-Iearn,
systems oriented language derived from IBM's PL/I by
Intel for programming the MCS-8 and future 8-bit micro
computers. It gives the microcomputer programmer the
same high level language advantages currently available
in mini and large computers. By actual tests, PL/M pro
gramming and debugging requires less than 10% of the
time needed for assembly language. The PL/M compiler
is written in Fortran IV for time-share, and needs little
or no alteration for most general purpose computers.
Inteliec™S Development Systems provide flexible, inex
pensive, and simplified methods for OEM product de
velopment. They use RAM for program storage instead
of ROM, making program loading and modification
easier. The I ntellec features are:
• Display and Control Console
• Standard DMA channel
• Standard software package
• Expandable memory and I/O
• TTY interface
• PROM programming capability
"The Intellec control panel is used for system monitoring
and debugging. These features and the many standard
Intellec modules add up to faster turn around and re
duced costs for your product development.
And, There's More .....
Intel's Microcomputer Systems Group continues to de
velop new design aids that make microcomputer system
building easier. They will provide assistance in every
phase of your program development.
For additional information:
Microcomputer Systems Group
I NTE L Corporation
3065 Bowers Avenue
Santa Clara, California 95051
Phone (408) 246-7501
intel®
delivers.


## Scan page 3

8008
8 Bit Parallel· Central Processor Unit
The 8008 is a complete computer system central' processor unit which may be interfaced with memories
having capacities up to 16K bytes. The processor communicates over an 8-bit data and address bus and
uses two leads for internal control and four leads for external control. The CPU contains an 8-bit
parallel arithmetic unit, a dynamic RAM (seven 8-bit data registers and an 8x14 stack), and complete
instruction decoding and control logic.
DO
0 1
O2
03
04
05
0 6
0 7
Features
• 8-Bit Parallel CPU on a
Single Chip
• 48 Instructions, Data
Oriented
• Complete Instruction
Decoding and Control
Included
• Instruction Cycle Time-
12.5 p,s with 8008-1 or 20 p,s
with 8008
• TTL Compatible (Inputs,
Outputs and Clocks)
.' Can be used with any type
or speed semiconductor
memory in any combination
BLOCK DIAGRAM
ACCUMULATOR,DATA
ALU REGISTERS, PROG.
COUNTER STACK
INT
TIMING
ROY
So S, S2 9, ¢2 SYNC
. • Directly addresses 16K x 8
bits of memory (RAM, ROM,
or S.R.)
• Memory capacity can be
indefinitely expanded
through bank switching
using 110 instructions
• Address stack contains
eight 14-bit registers
(including program counter)
which permit nesting of
subroutines up to seven
levels
• Contains seven 8-bit
registers
• Interrupt. Capability
• Packaged in 18-Pin DIP
PIN CONFIGURATION
Voo 18 INTERRUPT
~0.....2 17 READY
0 6 16 9,
0 5 92
DATA 0 4 SYNC
BUS 0 3 13
O2 12
0, 11
00 0..... 9 10 Vee


## Scan page 4

i ntel lee
A NEW, EASY AND INEXPENSIVE WAY
m DmlOP MICROCOMPUTER SYSTEMS
From Intel, the people who invented the microcom
puter, comes a new, inexpensive and easy way to
develop OEM microcomputer systems. The wide
spread usage of low-cost microcomputers is made
possible by Inters MCS-4 four bit; and MCS-8 eight
bit, microcomputer sets. To make it easier to use
these microcomputer sets, Intel now offers complete
4-bit and 8-bit modular microcomputer development
systems called Intellec 4 and Intellec 8. The Intellec
modular microcomputers are self-contained expand
able systems complete with central processor.
memory, 1/0, crystal clock, TTY interface, power
supplies, standard software, and a control and display
console.
The Intellec microcomputer development systems
feature:
• 4-bit and 8-bit parallel processor systems
• Program development using RAMS for easier
loading and modification
• Standard DMA channel
• Standard software package
• Crystal controlled clocks
• Expandable memory and I/O
• Control panel for system monitoring and program
debugging
• PROM programming capability
• Less time and cost for microcomputer systems
development
The Intellec 8 is an eight-bit modular microcomputer
development system with 5K bytes of memory, ex-
pandable to 16K bytes. At the h~art of this system is
the Intel 8008 CPU chip which has a repertoire of 48
instructions, seven working registers, an eight level
address stack, interrupt capability and direct address
capability to 16K bytes of memory.
The Intellec 4 is a four-bit modular microcomputer
development system with 5K bytes of program
memory. At the heart of this system is the Intel 4004
CPU chip with a repertoire of 45 instructions, sixteen
working registers, a four level address stack, and the
capability of directly addressing over 43K bits
of memory.
Standard Microcomputer Modules. The individual
modules used to develop the 4-bit and 8-bit micro
computer systems are also available as off-the-shelf
microcomputer building blocks. These include 4-bit
and 8-bit CPU modules, 1/0 Modules, PROM
Programmer Modules, Data Storage Modules,
Control Modules, a Universal OEM Module and other
standard modules for expanding the Intellec systems
or developing pre-production systems.
With these modules you can tailor the components
to your specific microcomputer needs, buying as little
or as much as you need to do the job.
Write for complete details on the Intellec modular
microcomputer development systems. They will be
available in 120 days, but plan now. Intel Corporation,
3065 Bowers Avenue, Santa Clara, California 95051
(408) 246-7501.
intel®
deJivers.
Ad Reprint, June 1973 See Appendix VI


## Scan page 5

CONTENTS
Page No.
I. Introduction .................. -. . . . . . . . . . . . . . . . . . . . . . . . . . . . 3
II. Processor Timing. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 4
III.
IV.
V.
VI.
VII.
VIII.
IX.
X.
XI.
XII.
A. State Control Coding ...................................... 4
8. Timing ................................................ 4
C. Cycle Control Coding ...................................... 5
Basic Functional Blocks
A. Instruction Register and Control .............................. .
B. Memory ................................................ .
C. Arithmetic/Logic Unit ..................................... .
D. I/O Buffer ............................................. .
Basic Instruction Set
A. Data and I nstruction Formats ................................ .
B. Summary of Processor Instructions ............................. .
C. Complete Functional Definition ............................... .
D. Internal Processor Operation ................................. .
Processor Control Signals ..................................... .
A. Interrupt Signal ...... _ ................................... .
B. Ready Signal ........................................... .
Electrical Specifications ..................................... .
A .. DC and Operating Characteristics ............................. .
B. AC Characteristics ........................................ .
C. Timing Diagram ......................................... .
D. Typical DC Characteristics ................................. .
E. Typical AC Characteristics ................................. .
The SIMS-01 - An MCS-S Micro Computer ......................... .
A. SI M8-0 1 Specifications ..................................... .
B. SIM8-01 Schematic ....................................... .
C. System Description ...... , ................................ .
D. Normal Operation ....................................... .
E. SIM8-01 Pin Description ................................... .
MCS-8 PROM Programming System ............................. .
A. General System Description and Operating Instructions ............... .
B. MP7-03 PROM Programmer ................................. .
C. Programming System Interconnection ........................... .
Micro Computer Program Development ........................... .
A. MCS-8 Software Library .................................... .
B. Development of a Microcomputer System ......................... .
C. Execution of Programs from RAM on SI M8-01 Using
Memory Loader Control Programs ., .... ' ..................... .
MCBS-10 Microcomputer Interconnect and Control Module ............... .
Appendices .............................................. .
I. SI M8 Hardware Assembler .................................. .
II. MCS-8 Software Package - Assembler .......................... .
A. Assembler Specifications ................................. .
8. Tymshare Users Guide for Assembly ......................... .
C. General Electric Users Guide for Assembly ..................... .
D. Sample Program Assembly ................................ .
III. MCS-8 Software Package - Simulator .......................... .
A. Introduction ......................................... .
B. Basic Elements ........................................ .
C. INTERP/8 Commands ................................... .
D. I/O Formatting Commands ................................ .
E. Error Messages ........................................ .
F. Examples ........................................... .
IV. Teletype Modifications for SIM8-01 ............................ .
V. Programming Examples .................................... .
A. Sample Program to Search a String of Characters ................. .
B. Teletype and Tape Reader Control Program ..................... .
C. Memory Chip Select Decodes and Output Test Program ............ .
D. RAM Test Program ............... _ ...................... .
E. Bootstrap Loader Program ................................ .
VI. Intellec 8, Bare Bones 8, and Microcomputer Modules ............... .
Ordering Information ....................................... .
A. Sales Offices .................•..........................
B. Distributors ........................ , ................... .
C. Ordering Information/Packaging Information ...................... .
7
7
7
7
7
8
8
8
io
15
18
18
20
21
22
23
23
23
23
24
25
26
28
29
31
33
33
39
40
44
44
46
47
49
56
56
71
71
81
81
82
84
84
84
84
88
89
90
95
98
98
99
99
99 --
lOa
103
124
124
125
126
NOTICE: The circuits contained herein are suggested applications only. Intel Corporation makes no warranties whatsoever with respect to the com
pleteness, accuracy, patent or copyright status; or applicability of the circuits to a user's requirements. The user is cautioned to check these circuits
for applicability to his specific situation prior to use. The user is further cautioned that in the event a patent or copyright claim is made against him
as a result of the use of these circuits, Intel shalf have no liability to user with respect to any such claim.


## Scan page 6

8008 Photomicrograph With Pin Designations
2


## Scan page 7

I. INTRODUCTION
The 8008 is a single chip MOS 8-bit parallel central processor unit for the MCS-8 micro computer
system. A micro computer system is formed when the 8008 is interfaced with any type or speed
standard semiconductor memory up to 16K 8-bit words. Examples are INTEL's 1101, 1103, 2102 (RAMs),
1302, 1602A, 1702A (ROMs) I 1404, 2405 (Shift Registers).
The processor communicates over an 8-bit data and address bus (Do through 0 7 ) and uses two input leads
(READY and I NTE R RUPT) and four output leads (So' S1' S2 and Sync) for control. Time multiplexing
of the data bus allows control information, 14 bit addresses, and data to be transmitted between the
CPU and external memory.
This CPU contains six 8-bit data registers, an 8-bit accumulator, two 8-bit temporary registers, four fla'g
bits, and an 8-bit parallel binary arithmetic unit which implements addition, subtraction, and logical
operations. A memory stack containing a 14-bit program counter and seven 14-bit words is used internally
to store program and subroutine addresses. The 14-bit address permits the direct addressing of 16K words
of memory (any mix of RAM, ROM or'S.R.).
The control portion of the chip contains logic to implement a variety of register transfer, arithmetic
control, and logical instructions. Most instructions are coded in ·one byte (8 bits); data immediate in
structions use two bytes; jump instructions utilize three bytes. Operating with a 500kHz clock, the
8008 CPU executes non-memory referencing instructions in 20 microseconds. A selected device, the
8008-1, executes non-memory referencing instructions in 12.5 microseconds when operating from an
800kHz clock.
All inputs (including clocks) are TTL compatible and all outputs are low-power TTL compatible.
The instruction set of the 8008 consists of 48 instructions including data manipulation, binary arith
metic,· and jump to subroutine.
The normal program flow of the 800B may be interrupted through the use of the "INTERRUPT"
control line. This allows the servicing of slow I/O peripheral devices while also executing the main
program.
The "READY" command line synchronizes the 8008 to the memory cycle allowing any type or speed
of semiconductor memory to be used.
ST ATE and SYNC outputs indicate the state of the processor at any ti me in the instruction cycle.
3


## Scan page 8

II. PROCESSOR TIMING
The 8008 is a complete central processing unit intended for use in any arithmetic, control, or decision
making system. The internal organization is centered around an 8-bit internal data bus. All communication
within the processor and with external components occurs on this bus in the form of 8-bit bytes of
address, instruction or data. (Refer to the accompanying block diagram for the relationship of all of
the internal elements of the processor to each other and to the data bus.) For the MCS-8 a logic 111" is
defined as a high level and a logic "0" is defined as a low level.
A. State Control Coding
The processor controls the use of the data bus and
determines whether it will be sending or receiving
data. State signals So' S1 ' and S2' along with SYNC
inform the peripheral circuitry of the state of the
processor. A table of the binary state codes and
the designated state names is shown below.
B. Timing
So
0
0
0
0
1
1
1
1
S1
1
1
0
0
0
1
1
0
S2 STATE
0 Tl
1 Tll
1 T2
0 WAIT
0 T3
0 STOPPED
1 T4
1 T5
Typically, a machine cycle consists of five states, two states in which an address is sent to m~mory
(T1 and T2), one for the instruction or data fetch (T3), and two states for the execution of the in
struction (T4 and T5). If the processor is used with slow memories, the READY line synchronizes the
processor with the memories. When the memories are not available for either sending or receiving data,
the processor goes into the WAIT state. The accompanying diagram illustrates the processor activity
during a single cycle.
~,
4>2
SYNC
So
S,
~
T11
CPU
INTERRUPTED
T1
LOWER
8· BITS
ADDRESS
OUT
T2
HIGHER
6·BITS
ADDRESS,
TWO BITS
CONTROL
OUT
WAIT
EXTERNAL
MEMORY
NOT READY
(OPTIONAL)
T3
INSTRUCTION
OR DATA
FETCH, OR
DATA OUT
18·BITS)
STOPPED
HALT
INSTRUCTION
RECEIVED BY
CPU
T4 T5
EXECUTION OF
INSTRUCTION
~------------ TYPICAL PROCESSOR CYCLE --------------.a
INCLUDES T1, T2, T3, T4, T5
Figure 1. Basic 8008 I nstruction Cycle
4


## Scan page 9

The receipt of an INTE RRUPT is acknowledged by t~T11. When the proc~ssor has been interrupted,
this state replaces T1. A READY is acknowledged by T3. The STOPPED state acknowledges the receipt
, of a HALT instruction.
Many of the instructions for the 8008 are mUlti-cycle and do not require the two execution states, T4
and T5. As a result, these states are omitted when they are not needed and the 8008 operates asyn
chronously with respect to the cycle length. The external state transition is shown below. Note that the
WAIT state and the STOPPED may be indefinite in length (each of these states will be 2n clock periods).
The use of READY and INTER RUPT with regard to these states will be explained later.
YES
Figure 2. CPU State Transition Diagram
C. Cycle Control Coding
As previously noted, instructions for the 8008 require one, two, or three machine cycles for complete
execution. The first cycle is always an instruction fetch cycle (PCI). The second and third cycles are
for data reading (PCR), data writing (PCW), or I/O operations (PCe).
The cycle types are coded with two bits, D6 and D7 , and are only present on the data bus during T2.
D6 D7 CYCLE FUNCTION
0 0 PCI· Designates the address is for a memory read
(first byte of instruction).
0 1 PCR Designates the address is for a memory read
data (additional bytes of instruction or data).
. 1 0 PCC Designates the data as a command I/O operation.
1 1 PCW Designates the address is for a memory write
data.
5


## Scan page 10

INTERNAL DATA BUS
CARRY
LOOK AHEAD
(8 BITS)
8 - BIT PARALLEL J.....oIII-I~---_L.J
ARITHMETIC
UNIT
FLIP-FLOPS (Z,C,S,P)I- .... --------...J
.. ----- .... AND CONDITION
LOGIC
STATUS
SIGNALS
REGISTER
AND
ARITHMETIC
UNIT
CONTROL
8 BIT DATA BUS
INSTRUCTION
DECODER
STATE TIMING
GENERATOR
Figure 3. 8008 Block Diagram
MEMORY
AND
1/0 CONTROL
INTERNAL DATA BUS
ACCUMULATOR
AND
SCRATCH PAD
MEMORY
7 WORDS)( 8 BITS
MEMORY
MULTIPLEXER AND
REFRESH
STACK AND
PROGRAM COUNTER
8 WORDS It 14 BITS
READY INTERRUPT


## Scan page 11

III. BASIC FUNCTIONAL BLOCKS
The foar basic functional blocks of this Intel processor are the instruction register, memory, arithmetic
logic unit, and I/O buffers. They communicate with each other over- the internal 8-bit data bus.
A. Instruction Register and Control
The instruction register is the heart of all processor control. Instructions are fetched from memory, stored
in the instruction register, and decoded for control of both the memories and the ALU. Since instruction
executions do not all require the same number of states, the instruction decoder also controls the state
transitions.
B. Memory
Two separate dynamic memories are used in the 8008, the pushdown address stack and a scratch pad.
These internal memories are automatically refreshed by each WAIT, T3, and STOPPED state. In the worst
case the memories are completely refreshed every eighty clock periods.
1. Address Stack
The address stack contains eight 14-bit registers providing storage for eight lower and six higher
order address bits in each register. One register is used as the program counter (sto'ring the effective
address) and the other seven permit address storage for nesting of subroutines up to seven levels.
The stack automatically stores the content of the program counter upon the execution of a CALL
instruction and automatically restores the program counter upon the execution of a RETU RN. The
CALLs may be nested and the registers of the stack are used as last in/first out pushdown stack.
A three-bit address pointer is used to designate the present location of the program counter. When
the capacity of the stack is exceeded the address. pointer recycles and the content of the lowest
level register is destroyed. The program counter is incremented immediately after the lower order
address bits are sent out. The higher order address bits are sent out at T2 and then incremented
if a carry resulted from T1. The 14-bit program counter provides direct addressing of 16K bytes
of memory. Through the use of an I/O instruction for bank switching, memory may be indefinitely
expanded.
2. Scratch Pad Memory or I ndex Registers
The scratch pad contains the accumulator (A register) and six additional 8-bit registers (B, C, D,
E, H, L). All arithmetic operations use the accumulator as one of the operands. All registers are
independent and may be used for temporary storage. In the case of instructions which require
operations with a register in external memory, scratch pad registers H & L provide indirect ad
dressing capability; register L contains the eight lower order bits of address and register H contains
the six higher order bits of address (in this case bit 6 and bit 7 are "don't cares").
C. Arithmetic/Logic Unit (ALU)
All arithmetic and logical operations (ADD, ADD with carry, SUBTRACT, SUBTRACT with borrow,
AND, EXCLUSIVE OR, OR, COMPARE, INCREMENT, DECREMENT) are carried out in the 8-bit
parallel arithmetic unit which includes carry-look-ahead logic. Two temporary resisters, register lI a" and
register lib", are used to store the accumulator and operand for ALU operations. In addition, they are
used for temporary address and data storage during intra-processor transfers. Four control bits, carry
flip-flop (c) , zero flip-flop (z) , sign flip-flop (s) , and parity flip-flop (p) , are set as the result of each
arithmetic and logical operation. These bits provide conditional branching capability through CALL,
JUMP, or RETURN on condition instructions. In addition, the carry bit provides the ability to do mul
tiple precision binary arithmetic.
D. I/O Buffer
This buffer is the only link between the processor and the rest of the system. Each of the eight buffers
is bi-directional and is under control of the instruction register and state timing. Each of the buffers is
low power TTL compatible on the output and TTL compatible on the input.
7


## Scan page 12

IV. BASIC INSTRUCTION SeT
The following section presents the basic instruction set of the 8008.
A. Data and Instruction Formats
Data in the 800B is stored in the form of 8-bit binary integers. All data transfers to the system data bus will be
in the same format.
I 0 7 0 6 0 5 0 4 0 3 O2 0 1 DO I
DATA WORD
The program instructions may be one, two, or three bytes in length. Multiple byte instructions must be stored
. in successive words in program memory. The instruction formats then depend din the particular operation
executed.
One Byte Instructions
107 06 05 04 0 3 O2 0, DO 1 OPCOOE
Two Byte Instructions
107 06 05 0 4 0 3 O2 0, DO I. OP CODE
1 0 7 0 6 Os 0 4 0 3 O2 0, DO! OPERAND
Three Byte Instructions
107 0 6 05 0 4 0 3 O2 0, DO I OP CODE
1 0 7 0 6 05 0 4 03 O2 0, DO I LOW ADDRESS
I X X 05 04 03 ~ 0, DO 1 HIGH ADDRESS·
TYPICAL INSTRUCTIONS
Register to register, memory reference,
I/O arithmetic or logical, rotate or
return instructions
I mmediate mode instructions
JUMP or CALL instructions
-For the third byte of this instruction, 0 6 and 0 7 are "don't care" bits.
For the MCS-8 a logic "1" is defined as a high level and a logic "Oil is defined as a low level.
B. Summary of Processor Instructions
Index Register Instructions
The load instructions do not affect the flag flip-flops. The increment and decrement instructions affect all flip
flops except the carry.
MINIMUM INSTRUCTION CODE
MNEMONIC STATES E? 0 6 °5 0 4 0 3 D:z 0 1 DO DESCRIPTION OF OPERATION
REQUIRED
(1) lrl r2 (5) 1 1 0 0 0 S S S load index register rl with the content of index register r2.
T,2TlrM (8' 1 1
°
0 0 1 1 1 load index register r with the content of memory register M.
lMr (1' 1 1 , 1 1 5 S 5 load memory register M with the content of index registtr r.
(3}lrl (8) 0 0 0 0 0 1 1 0 load index register r with data B ..• B.
B B B B B B B B
lMI (9' 0 0 1 1 1 1 1 0 load memory register M with data B ... B.
B B B B B B B B
INr (5) 0 0 0 0 0 0 0 0 I ncrement the content of index register r (r f A).
OCr (5) 0 0 0 0 0 0 0 1 Decrement the content of index register r (r fA).
Accumulator Group Instructions
The result of the AlU instructions affect all of the flag flip-flops. The rotate instructions affect only the carry flip-flop.
AOr (5' 1 0 0 0 0 S 5 S Add the content of index register r, memory register M, or data
ADM (8) 1 0 0 0 0 1 1 1 B ••. B to the accumulator. An overflow (carry) sets the carry
AOI (8) 0 0 0 0 0 1 0 0 flip-flop.
B B B B B B B B
ACr (5) 1 0 0 0 1 5 5 5 Add the content of index register r, memory register M, or data
ACM (8' 1 0 0 0 1 1 1 1 B ... B to the accumulator with carry. An overflow (carry'
ACI (8) 0 0 0 0 1 1 0 0 sets the carry flip-flop.
B B B B B B B B
SUr (5) 1 0 0 1 0 5 S S Subtract the content of index register r, memory register M. or
5UM (8' 1 0 () 1 0 1 1 1 data B .•• B from the accumulator. An underflow Ul,orrow)
SUI (8' 0 0 0 1 0 1 0 0 sets the carry flip-flop.
B B B B B B B B
5Br (5' 1 0 0 1 1 5 5 5 Subtract the content of index register r, memory register M, or data
5BM (8' 1 0 0 1 1 1 1 1 data B ..• B from the accumulator with borrow. An underflow
5BI (8' 0 0, 0 1 1 1 0 0 (borrow) sets the carry flip-flop.
B B B B B B B B
8


## Scan page 13

MINIMUM INSTRUCTION CODE
MNEMONIC STATES 0 7 0 6 DsD4 D3 ~D1 q, DESCRIPTION OF OPERATION
REQUIRED
NOr (5) 1 0 1 0 0 S S S Compute the logical AND of the content of index register r,
NOM (8) 1 0 1 0 0 1 1 1 memory 'register M, or data B •.• B with the accumulator.
NDI (8) 0 0 1 0 0 1 0 0
B B B B B B B B
XRr (5) 1 0 1 0 1 S S S Compute the EXCLUSIVE OR of the content of index register
XRM (8) 1 0 1 0 1 1 1 1 r, memory register M, or data B .•• B with the accumulator.
XRI (8) 0 0 1 0 1 1 0 0
B B B B B B B B
ORr (5) 1 0 1 1 0 S S S Compute the INCLUSIVE OR of the content of index register
ORM (8) 1 0 1 1 0 1 1 1 r, memory register m, or data B .•• B with the accumulator.
ORI (8) 0 0 1 1 0 1 0 0
B B B B B B B B
CPr (5) 1 0 1 1 1 S S S Compare the content of index register r, memory register M,
CPM (8) 1 0 1 1 1 1 1 1 or data B ••• B with the accumulator. The content of the
CPI (8) 0 0 1 1 1 1 0 0 accumulator is unchanged.
B B B B B B B B
RLC (5) 0 0 0 0 0 0 1 0 Rotate the content of the accumulator left.
RRC (5) 0 0 0 0 1 0 1 0 Rotate the content of the accumulator right.
RAL (5) 0 0 0 1 0 0 1 0 Rotate the content of the accumulator left through the carry.
RAR (5) 0 0 0 1 1 0 1 0 Rotate the content of the accumulator right through the carry.
Program Counter and Stack Control Instructions
(4) JMP (11) 0 1 X X X 1 0 0 Unconditionally jump to memory address B3 ••• B3B2 ••• B2.
B2 B2 B2 B2 B2 B2 B2 B2
X X B3 B3 B3 B3 B3 B3
(5) JFc (9 or 11) 0 1 0 C4 C3 0 0 0 Jump to memory address B3 ••• B3B2 ••• B2 if the condition
B2 B2 B2 B2 B2 B2 B2 B2 flip-flop c is false. OtherWise, execute the next instruction in sequence.
X X B3 B3 B3 B3 B3 B3
JTc (9 or 11) 0 1 1 C4 C3 0 0 0 Jump to memory address B3 ••• B3B2 .•• B2 if the condition
~~ B2~ B2 ~~B2 flip-flop c is true. Otherwise, execute the next instruction in sequence.
X X B3 B3 B3 B3 B3 B3
CAL (11) 0 1 X X X 1 1 0 Unconditionally call the subroutine at memory address B3 •• '.
~B2 B2B2~ B2~ B2 B3B2 ••• B2. Save the current address (up one leve! in the stack).
X X B3 B3 B3 B3 B3 B3
CFc (9 or 11) 0 1 0 C4 C3 0 1 0 Call the subroutine at memory address B3 •.. B3B2 ••• B2 if the
~B2 B2B2 ~ ~B2 B2 condition flip-flop c is false, and save the current address (up one
X X Sa B3 B3 B3 B3 B3 level in the stack.) Otherwise, execute the next instruction in sequence.
CTc (9 or 11) 0 1 1 C4 C3 0 1 0 Call the subroutine at memory address B3 ••• B3B2 ••• B2 if the
~B2 ~~~ ~~B2 condition flip-flop c is true, and save the current address (up one
X X B3 B3 B3 B3 B3 B3 level in the stack). Otherwise, execute the next instruction in sequence.
RET (5) 0 0 X X X 1 1 1 Unconditionally return (down one level in the stack).
RFc (3 or 5) 0 0 0 C4 C3 0 1 1 Return (down one level in the stack) if the condition flip-flop c is
false. Otherwise, execute the next. instruction in sequence.
RTc (3 or 5) 0 0 1 C4 C3 0 1 1 Return (down one level in the stack) if the condition flip-flop c is
true. Otherwise, execute the next instruction in sequence.
RST (5) 0 0 A A A 1 0 1 Call the subroutine at memory address AAAOOO (up one level in the,stack).
I nput/Output Instructions
INP (8) 0 1 ' 0 0 M M M 1 Read the content of the selected input port (MMM) into the
accumulator.
OUT (6) 0 1 R R M M M 1 Write the content of the accumulator into the selected output .
port (RRMMM, RR f. 00).
Machine Instruction
HLT (4) o 0 000 o 0 X Enter the STOPPED state and remain there until interrupted.
HLT (4) Enter the STOPPED state and remain there until interrupted.
NOTES:
(1) SSS = Source Index Register } These registers, F'j, are de.signatedA(aCCumulator-OOO),
DOD = Destination Index Register B(001), C(010), 0(011), E(100), H(101), L(110L
(2) Memory registers are addressed by the contents of registers H & L.
(3) Additional bytes of instruction are designated by BBBBBBBB.
(4) X = "Don't Care".
(5) Flag flip-flops are defined by C4C3: carry (OO-overflow or underflow), zero (01-result is zero), sign (10-MSB of result is "1 "),
parity (11-parity is even) .
9


## Scan page 14

c. Complete Functional Definition
The following pages present a detailed description of the complete 8008 I nstruction Set.
Symbols
<B2>
<B3>
r
M
( )
1\
-¥
V
Am
STACK
P
xxx
SSS
DDD
Meaning
Second byte of the instruction
Third byte of the instruction
One of the scratch pad register references: A, B, C, D, E, H, L
One of the following flag flip-flop references: C, Z, S, P
Flag flip-flop codes
00 carry
01 zero
10 sign
11 parity
Condition for True
Overflow, underflow
Result is zero
MSB of resu It is "1"
Parity of result is even
Memory location indicated by the contents of registers Hand L
Contents of location or register
Logical product
Exclusive lIor"
I nclusive "or"
Bit m of the A-register
I nstruction counter (P) pushdown register
Progra m Cou nter
Is transferred to
A "don't care"
Source register for data
Destination register for data
Register # Register Name
(SSS or ODD)
000 A
001 B
010 C
011 D
100 E
101 H
110 L
10


## Scan page 15

INDEX REGISTER INSTRUCTIONS-'
LOAD DATA TO INDEX REGISTERS - One Byte
Data may be loaded into or moved between any of the index registers, or memory registers.
Lr1 r2 11 DOD SSS (r,}-(r2) Load register r, with the content ,of r2.
(one cycle - PCI) The content of r2 remains unchanged. If SSS=DDD,
LrM
(two cycles
PCI/PC~)
LMr
(two cycles
PCI/PCW)
11 DOD 111
11 111 SSS
LOAD DATA IMMEDIATE - Two Bytes
the instruction is a NOP (no operation).
(r)-(M) Load register r with the content of the
memory location addressed by the contents of
registers Hand L. (000#111 - HALT instr.)
(M}-(r) Load the memory location addressed by
the contents of registers Hand L with the content
of register r. (SSS#111 - HALT instr.)
A byte of data immediately following the instruction may be loaded into the processor or 'into the _
memory
Lrl 00 DOD 110
(two cycles - <B2>
PCI/PCR)
LMI 00 111 110
(three cycles - < B2>
PC I fPC R/PCW)
INCREMENT INDEX REGISTER - One Byte
INr 00 DOD 000
(one cycle ~ PCI)
DECREMENT INDEX REGISTER - One Byte
OCr 00 DOD 001
(one cycle - PCI)
(r) - <B2 > Load byte two of the instruction into
register r.
(M) - <B2> Load byte two of the instruction into
the memory location addressed by the contents of
registers Hand L.
(r) - (r)+1. The content of register r is incr"emented by
one. All of the condition flip-flops except carry are
affected by the result. Note that 0001000 (HALT
instr.) and 000#111 (content of memory may not
be incremented).
(r)-(r}-1. The content of register r is decremented
by one. All of the condition flip-flops except carry
are affected by the result. Note that 0001000 (HALT
instr.) and DDD#111 (content of memory may not be
decremented) .
ACCUMULATOR GROUP INSTRUCTIONS
Operations are performed and the status flip-flops, C, Z, S, P, are set based on the result of the operation.
Logical operations (NOr, XRr, ORr) set the carry flip-flop to zero. Rotate operations affect only the
carry flip-flop. Two's complement subtraction is used.
ALU INDEX REGISTER INSTRUCTIONS - One Byte
(one cycle - PCI)
Index Register operations are carried out between the accumulator and the content of one of the index
registers (SSS=OOO thru SSS=11 0). The previous ~ontent of register SSS is unchanged by the operation.
ADr 10 000 SSS (A)-(A)+(r) Add the content of register r to the
content of register A and place the result into
register A.
ACr 10 001 SSS (A)-(A)+(r)+(carry) Add the content of register r
and the contents of the carry flip-flop to the content
of the A register and place the result into Register A.
SUr 10 010 SSS (A)-(A}-(r) Subtract the content of register r from
the content of register A and place the result into
register A. Two's complement subtraction is used.
11


## Scan page 16

ACCUMULATOR GROUP INSTRUCTIONS - Cont'd.
SBr 10 all SSS
NOr 10 100 SSS
XRr 10 101 SSS
ORr 10 110 SSS
CPr 10 111 SSS
ALU OPERATIONS WITH MEMORY - One Byte
(two cycles - PCI/PCR)
(A)-(A)-(r)-(borrow) Subtract the content of
register r and the content of the carry flip-flop from
the content of register A and place the result into
register A.
(A)-{A) I\(r) Place the logical product of the register
A and register r into register A.
(A)-(A)V(r) Place the lIexciusive - or" of the
content of register A and register r into register A.
(A)-(A)V(r) Place the "inclusive - or" of the
content of register A and register r into register A.
(A)-(r) Compare the content of register A with
the content of register r. The content of register A
remains unchanged. The flag flip-flops are set by the
result of the subtraction. Equality (A=r) is indicated
by the zero flip-flop set to 111". Less than (A<r) is
indicated by the carry flip-flop, set to "1".
Arithmetic and logical operations are carried out between the accumulator and the byte of data
addressed by the contents of registers Hand L.
ADM 10 000 111 (A)-(A)+(M) ADD
ACM 10 001 111 (AHA)+(M)+(carry) ADD with carry
SUM 10 010 111 (A)-(A)-(M) SUBTRACT
SBM 10 all 111 (A)-(A)-(M).:...(borrow) SUBTRACT with borrow
NOM 10 100 111 (A)-(A) I\(M) Logical AND
XRM 10 101 111 (A)-(A)V(M) Exclusive OR
ORM 10 110 111 (A)-(A)V(M) Inclusive 0 R
CPM 10 111 111 (A)-(M) COMPA RE
ALU IMMEDIATE INSTRUCTIONS - Two Bytes
. (two cycles -PCI/PCR)
Arithmetic and logical operations are carried out between the accumulator and the byte of data
immediately following the instruction.
AOI 00 000 100 (A)-(A)+<B2>
<B2>
ACI 00 001
<B2>
SUI 00 010
<B2>
SBI 00 all
<B2>
NOI 00 100
<B2>
XRI 00 101
<B2>
ORI 00 110
<B2>
CPI 00 111
<B2>
100
100
100
100
100
100
100
ADD
(A)-(A)+<B2>+(carry)
ADD with carry
(A)--(A)-<B2>
SUBTRACT
(A)-(A)-<B2> -(borrow)
SUBTRACT with borrow
(A)-(A)I\<B2>
Logical AND
(A)-(A)¥ <B2>
Exclusive OR
(A)-(A)V <B2>
Inclusive 0 R
(A)- <B2>
COMPARE
12


## Scan page 17

ROTATE INSTRUCTIONS - One 8yte
(one cycle - PCI)
The accumulator content (register A) may be rotated either right or left, around the carry bit or
through the carry bit. Only the carry flip-flop is affected by these instructions; the other flags are
unchanged.
RLC
RRC
00 000 010
00 001 010
A m+1-Am, A o-A7, {carry)-A 7
Rotate the content of register A left one bit.
Rotate A7 into Ao and into the carry flip-flop.
A m-Am+1 , A 7-Ao, {carry)-Ao
Rotate the content of register A right one bit.
Rotate Ao into A7 and into the carr~ flip-flop.
RAL 00 010 010 A m+1-Am ,Ao-(carry),(carry)-A 7 .
Rotate the content of Register A left one bit.
Rotate the content of the carry flip-flop into Ao.
Rotate A7 into the carry flip-flop.
RAR 00 011 010 Am-Am+1,A7 -(carry), (carry)-A o
Rotate the content of register A right one bit.
Rotate the content of the carry flip-flop into A7.
Rotate Ao into the carry flip-flop.
PROGRAM COUNTER AND STACK CONTROL INSTRUCTIONS
JUMP INSTRUCTIONS - Three 8ytes
(three cycles - PCI/PCR/PCR)
Normal flow of the microprogram may be altered by jumping to an address specified by bytes two
and three of an instruction.
JMP 01 XXX 100
(Jump Unconditionally)
JFc
(Jump if Condition
False)
JTc
(Jump if Condition
True)
01
01
<82>
<~>
OC4C3
<~>
<83 >
000
1C4 C3 000
<82 >
<83 >
CALL INSTRUCTIONS - Three 8ytes
(three cycles - PCI/PCR/PCR)
{P)-<8 3><B2> Jump unconditionally to the
instruction located in memory location addressed
by byte two and byte three.
If (c) = 0, {P)-<83> <82>. Otherwise, (P) = {P)+3.
If the content of flip-flop c is zero, then jump to
the instruction located in memory location <83> <82> ;
otherwise, execute the next instruction in sequence.
If (c) = 1, {P)--<8 3> <8 2>. Otherwise, (P) = {P)+3.
If the content of flip-'flop c is one, then jump to the
instruction located in memory location <83> <82> ;
otherwise, execute the next instruction in sequence.
Subroutines may be called and nested up to seven levels.
CAL 01 XXX 110 (Stack)-(P), (P)-<8 3> <8 2>. Shift the content of P
(Call subroutine < 82> to the pushdown stack. Jump unconditiona lIy to the
Unconditionally) < 83> instruction located in memory location addressed by
CFc 01
(Call subroutine
if Condition False)
CTc 01
(Call subroutine
if Condition True)
OC4 C3 010
<82>
<83 >
1C4C3 010
<82>
<8 3>
byte two and byte three.
If (c) = 0, (Stack)-(P), (P)-<8 3><82>. Otherwise,
(P) = (P)+3. If the content of flip-flop c is zero, then
shift contents of P to the pushdown s~ack and jump
to the instruction located in memory location<8 3><B2> ;
otherwise, execute the next instruction in sequence.
If (c) = 1, (Stack)-{P), {P)-<8 3> <82>. Otherwise,
(P) = (P)+3. If the content of flip-flop c is one, then
shift contents of P to the pushdown stack and jump
to the instruction located in memory location<8 3> < 82>;
otherwise, execute the next instruction in sequence.
In the above JUMP and CALL instructions < 82 > contains the least significant half of the address and
< 83> contains the most sign ificant half of the address. Note that D6 and D7 of< 83 > are "don't care"
bits since the CPU uses fourteen bits of address.
13


## Scan page 18

RETURN INSTRUCTIONS - One Byte
(one cycle - PCI)
A return instruction may be used to exit from a subroutine; the stack is popped-up one level at a time.
RET 00 XXX 111 (P)-(Stack). Return to the instruction in the memory
location addressed by the last value shifted into the
pushdown stack. The stack pops up one level.
RFc
(Return Condition
False)
RTc
(Return Condition
True)
RESTART INSTRUCTION - One Byte
(one cycle - PCI)
If (c) = 0, (P)-(Stack); otherwise, (P) = (P)+l.
If the content of flip-flop c is zero, then return to
the instruction in the memory location addressed by
the last value inserted in the pushdown stack. The stack
pops up one level. Otherwise, execute the next instruction
in sequence.
If (c) = 1, (P)-(Stack); otherwise, (P) = (P}+l.
If the content of flip-flop c is one, then return to
the instruction in the memory location addressed by
the last value inserted in the pushdown stack. The stack
pops up one level. Otherwise, execute the next instruction
in sequence.
The restart instruction acts as a one byte call on eight specified locations of page 0, the first 256 instruction
words.
RST 00 AAA 101 (Stack)-(P),(P)-(OOOOOO OOAAAOOO)
Shift the contents of P to the pushdown stack.
The content, AAA, of the instruction register is
shifted into bits 3 through 5 of the P-counter. All
other bits of the P-counter are set to zero. As a one
word IIca II " I eight eight-byte subroutines may be
accessed in the lower 64 words of memory.
INPUT/OUTPUT INSTRUCTIONS
One Byte
(two cycles - PCI/PCC)
Eight input devices may be referenced by the input instruction
INP 01 OOM MM1 (A)-(input data lines). The content of register A
is made available to external equipment at state T1
of the pee cycle. The content of the instruction
register is made available to-external equipment at
state T2 of the pec cycle. New data for the
accumulator is loaded at T3 of the PCC cycle.
MMM denotes input device number. The content of the
condition flip-flops, S,Z,P IC, is output on Do, 0 1 , O2 ' 03
respectively at T 4 on the PCC cycle.
Twenty-four output devices may be referenced by the output instruction.
OUT 01 R RM MM 1 (Output data lines)-(A). The content of register A
is made available to external equipment at state T1
and the content of the instruction register is made
available to external equipment at state T2 of the pce
cycle. R RMMM denotes output device number (R R =1=
00).
MACHINE INSTRUCTION
HALT INSTRUCTION - One Byte
(one cycle - PCI)
HLT 00 000 OOX
or
11 111 111
On receipt of the Halt Instruction, the activity of the
processor is immediately suspended in the STOPPED
state. The content of all registers and memory is un
changed. The P-counter has been updated and the
internal dynamic memories continue to be refreshed.
14


## Scan page 19

D. Internal Processor Operation
I nternally the processor operates through five different states:
I nternal State
I
NORMAL
T1-----I INTERRUPT
T2-----t/.
~========== WAIT
T3-----~ NORMAL
. STOPPED
T4 and T5 ---1 ... ________ _
Typical Function
Send out lower eight bits of address and increment program counter.
Send out lower eight bits of address and suppress incrementing of program counter and
acknowledge interrupt.
Send out six higher order bits of address and two control bits, 06 and 07. Increment
program counter if there has been a carry from T1.
Wait for READY signal to come true. Refresh internal dynamic memories while waiting.
Fetch and decode instruction; fetch data from memory; output data to memory. Refresh
internal memories .
Remain stopped until INTERRUPT occurs. Refresh internal memories.
Execute instruction and appropriately transfer data within processor. Content of data
bus transfer is available at I/O bus for convenience in testing. Some cycles do not require
these states. I n those cases, the states are skipped and the processor goes directly to T1.
The 8008 is driven by two non-overlapping clocks.
Two clock periods are required for each state of
the processor. cf>1 is generally used to precharge all
data lines and memories and cf>2 controls all data
transfers within the processor. A SYNC signal
(divide by two of cf>2) is sent out by the 8008. This
signal distinguishes between the two clock periods
of each state.
9,
¢2
Jo4----TCy----I·~1 I"
SYNC
J \~_---Jr
~----ONE.MACHINE STATE----------,l.~1 I ..
Processor Clocks
The figure below shows state transitions relative to the internal operation of the processor. As noted
in the previous table, the processor skips unnecessary execution steps during any cycle. The state
counter within the 8008 operates is a five bit feedback shift register with the feedback path controlled
by the instruction being executed. When the processor is either waiting or stopped, it is internally
cycling through the T3 state. This state is the only time in the cycle when the internal dynamic memories
can be refreshed.
(CYCLE 1) (HL T • INT + RETURN (CF)) + (CYCLE 2) (OUT + LMrI + (CYCLE 3) (LMI + JUMP (CF) + CALL (CF))
(CYCLE 1) (HL T • iNT) +RDY
(CYCLE 2) (LMI + JUMP + CALL)
(CYCLE 1) (LrM + ALUM + ALUI + INP + OUT + Lrl + JUMP + CALL)
(CYCLE 1) (LMr)
NORMAL RETURN AT END OF MEMORY CYCLE
NOTE: C.F. INDICATES A FAILED CONDITION
Transition State Diagram (Internal)
The following pages show the processor activity during each state of the execution of each instruction.
15


## Scan page 20

INTERNAL PROCESSOR OPERATION
INDEX REGISTER INSTRUCTIONS
INSTRUCTION CODING #OF STATES
OPERATION TO EXECUTE
0 7 0 6 0 5 0 4 03 ~01 DO INSTRUCTION T1 (2)
1 1 0 0 0 S S S Lrlr2 S PCLOUT
(4)
1 1 D D 0 1 1 1 LrM 8 PCLOUT
1 1 1 1 1 S S S LMr 7 PCLOUT
a a 0 0 0 1 1 a Lrl 8 PCLOUT
a a 1 1 1 1 1 0 LMI 9 PCLOUT
0 a 0 0 0 0 0 0 INr 5 PCLOUT
0 0 0 0 0 0 0 1 OCr S PC LOUT
ACCUMULATOR GROUP INSTRUCTIONS
1 0 P P P S S S ALU OP r 5 PCLOUT
1 0 P P P 1 1 1 ALU OP M 8 PCLOUT
0 0 P P P 1 0 0 ALU OP I 8 PCLOUT
0 0 0 0 0 a 1 0 RLC 5. PC LOUT
0 0 0 0 1 0 1 a RRC 5 PCLOUT
G 0 a 1 0 0 1 a RAL 5 PCLOUT
a 0 0 1 1 0 1 0 RAR 5 PCLOUT
PROGRAM COUNTER AND STACK CONTROL INSTRUCTIONS
0 1 X X X 1 0 0 JMP 11
0 1 0 C C 0 0 0 JFc 9 or 11
0 1 1 C C 0 0 0 JTc 90r 11
0 1 X X X 1 1 0 CAL 11
0 1 0 C C 0 1 0 CFc 9 or 11
0 1 1 C C 0 1 0 CTc 9 or 11
0 a X X X 1 1 1 RET 5
a 0 0 C C 0 1 1 RFc 3 or S
a 0 1 C C a 1 1 RTc 3 or 5
0 0 A A A 1 0 1 RST S
1/0 INSTRUCTIONS
0 1 0 0 M M M 1 INP 8
0 1 R R M M M 1 OUT 6
MACHINE INSTRUCTIONS
o 0 000 o 0 X HLT 4
1 1 1 1 1 1 1 1 HLT 4
NOTES:
1. The first memory cycle is always a PCI (instruction) cycle.
2. Internally, states are defined as Tl through T5. IR some cases
more than one memory cycle is required to execute an instruction.
3. Content of the internal data bus at T4 and T5 is available at the
data bus. This is designed for testing purposes only.
4. Lower order address bits in the program counter are denoted
by PCL arid higher order bits are designated by PCH.
5. During an instruction fetch the instruction comes from memory
to the instruction register and is decoded.
16
PCLOUT
PCLOUT
PC LOUT
PCLOUT
PCLOUT
PC LOUT
PCLOUT
PCLOUT
PCLOUT
PCLOUT
PC LOUT
PC LOUT
MEMORY CYCLE ONE (1)
T2 T3 T4(3) T5
PCHOUT FETCH INSTR.(S) SSSTO REG. b REG. bTO DOD
TOIR&REG.b (6)
PCHOUT FETCHINSTR. ~
TO IR & REG. b (7)
PCHOUT FETCHINSTR. SSSTO REG.b ,..
TOIR & REG •. b
PCHOUT FETCH INSTR.
TO IR & REG.b
~
PCHOUT FETCH INSTR. ~
TO IR & REG. b
PCHOUT FETCH I NSTR. X ADD OP - FLAGS
TO IR & REG.b AFFECTED
PCHOUT FETCH INSTR. X SUB OP - FLAGS
TO IR & REG.b AFFECTED
PCHOUT FETCH INSTR. SSS TO REG; b ALU OP - FLAGS
TO IR & REG. b AFFECTED
PCHOUT FETCH INSTR. ~
TOIR&REG.b
PCHOUT FETCH tNSTR. ~
TOIR&REG.b
PCHOUT FETCH tNSTR. X ROTATE REG. A
TO IR & REG.b CARRY AFFECTED
PCHOUT FETCH INSTR. X ROTATE REG. A
TO IR & REG.b CARRY AFFECTED
PCHOUT FETCH INSTR. X ROTATE REG. A
TO IR & REG. b CARRY AFFECTED
PCHOUT FETCH INSTR. X ROTATE REG. A
TO IR & REG. b CARRY AFFECTED
PCHOUT FETCH I NSTR.
~
TO IR & REG.b
PCHOUT FETCH INSTR.
~
T01R & REG. b
PCHOUT FETCH INSTR.
~
TO IR & REG. b
PCHOUT FETCH INSTR.
TO IR & REG. b
~
PCHOUT FETCH INSTR.
~
TOIR&REG.b
PCHOUT FETCH INSTR.
TO IR & REG.b
~
PCHOUT FETCH INSTR. POP STACK X
TO IR & REG. b
PCHOUT FETCH INSTR. POP STACK (13) X
TO IR & REG. b
PCHOUT FETCH INSTR. POP STACK (13) X
TO IR & REG. b
PCHOUT FETCH INSTR. REG. a TOPCH REG. b TO PCL
TO REG.bAND (14' PUSH STACK
(a-REG. a)
PCHOUT FETCH INSTR.
~
TO IR & REG. b
PCHOUT FETCH INSTR.
TO IR & REG. b
~
6. Temporary registers are used internally for arithmetic operations
and data transfers (Register a and Register bJ
7. These states are skipped.
8. PCR cycle (Memory Read Cycle).
9: "X" denotes an idle state.
10. PCW cycle (Memory Write Cycle).
11. When the JUMP is conditional and the condition fails, states
T4 and T5 are skipped and the state counter advances to
the next memory cycle.


## Scan page 21

T1
REG. LOUT
(10)
PCLOUT (S)
PCLOUT (S)
PCLOUT(S)
PCLOUT(S)
PCLOUT(S)
PCLOUT(S)
PCLOUT(S)
PCLOUT(S)
REG.A
TO OUT(15)
REG. A (15)
TO OUT
MEMORY CYCLE TWO
T2
PCHOUT
PCHOUT
PCHOUT
PCHOUT
PCHOUT
PCHOUT
REG.b
TO OUT
REG.b
TO OUT
T3
LOWER ADD.
TO REG.b
LOWER ADD.
TO REG.b
LOWER ADD.
TO REG.b
LOWER ADD.
TOREG.b
DATA TO
REG.b
x
(17)
T4(3) T5
12. When the CALL is conditional and the condition fails. states
T4 and T5 are skipped and the state coul)ter advances to
the next memory.cycle. If the condition is true. the stack
is pushed at T4. and the lower and higher order address
bytes are loaded into the progr~m counter.
13. When the RETURN condition is true, pop up the stack;
otherwise. advance to next memory cycle skipping T4 and T5.
14. Bits 03 through 05 are loaded into PCL and all other bits
are set to zero; zeros are loaded into PCH.
..
..
.. ..
.. ..
I
MEMORY CYCLE THREE
T1 T2 T3 T4(3) T5
PCLOUT(S) PCHOUT HIGHER ADD. REG.a REG.b
REG. a TO PCH TO PCL
PCLOUT(S) PCHOUT HIGHER ADD. REG.a REG.b
REG.a (11) TO PCH TOPCl
PCLOUT(S) PCHOUT HIGHER ADD. REG.a REG.b
REG.a (11) TO PCH TO PC
PCLOUT(S) PCHOUT HIGHER ADD. REG.a REG.b
REG.a TO PCH TOPCL
PCLOUT(S) PCHOUT HIGHER ADD. REG.b
REG. a (12) TO PCl
PCLOUT(S) PCHOUT REG.b
I II· II
15. PCC cycle (1/0 Cycle).
16. The content of the condition flip-flops is available at the data bus:
S at DO. Z at 01. Pat 02. C at 03.(04 - 07 all ones)
17. A READY command must be supplied for the OUT operation
to be completed. An idle T3 state is used and then the state
counter advances to the next memory cycle.
lS. When a HALT command occurs. the CPU internally remains
in the T3 state until an INTERRUPT is recognized. Externally.
the STOPPED state is indicated.
17


## Scan page 22

V. PROCESSOR CONTROL SIGNALS
A. Interrupt Signal (I NT)
1) INTERRUPT REQUEST
If the interrupt line is enabled (Logic "1"), the CPU recognizes an interrupt request at the
next instruction fetch (PCI) cycle by outputting So S1 S2 = 011 at T11 time. The lower
and higher order address bytes of the program counter are sent out, but the program
counter is not advanced. A successive instruction fetch cycle can be used to insert an
arbitrary instruction into the instruction register in the CPU. (If a mUlti-cycle or multi
byte instruction is inserted, an interrupt need only be inserted for the first cycle.)
When the processor is interrupted, the system INTERRUPT signal must be synchronized with
the leading edge of the ~1 or ~2 clock. To assure proper operation of the system, the interrupt
line to the CPU must not be allowed to change within 200ns of the falling edge of ~1' An
example of a synchronizing circuit is shown on the schematic for the SIMB-01 (Section V").
I I
0\ ~~ ______ J·I I~'--~---
1/>1
I I
I I I
II , ______ -4)o- __ +-1 ---+-----1 11----
INTERRUPT ---'
TO SYSTEM
- ,S I I
SYNCHRONIZED ~ ss I J
INTERRUPT TO ~ I \
CPU ___ .... (200ns I I I 1'---
I I I I~-----
T11 INTERRUPT ~
ACKNOWLEDGE ---------------~S~~S ____ ...... ___ .
INTERRUPT
I I RECOGNIZED
Figure 4. Recognition of Interrupt
If a HALT is inserted,the CPU enters a STOPPED state; if a NOP is inserted, the CPU
continues; if a "JUMP to 0" is inserted, the processor executes program from location 0,
etc. The RESTART instruction is particularly useful for handling interrupt routines since
it is a one byte call.
18


## Scan page 23

ADDR. LOCATION
N -1
N
INTR. N-1
INSTR. N
N + 1 INSTR. N + 1
PC CONTENTS
N (INTERRUPT ARRIVES HERE)
~ __ --I USER SUPPLIES ALTERNATE
INSTRUCTION (RESTART OR
CALL TO SRT), RELEASES
INTERRUPT,
PC IS SAVED IN STACK
(VALUE = N)
SUBROUTINE FOR HANDLING INTERRUPT:
S INSTR. S
S+1 INSTR.S+1
S+2
S+K RETURN STACK POPS - WITH VALUE N
AFTER COMPLETION OF SUBROUTINE,. 8008 RETURNS TO
EXE~UTE ORIGINALLY REQUESTED INSTRUCTION, WHICH
BLOCKING ADVANCE OF PC HAS SAVED.
Figure 5. 8008 Interrupt
2) START-UP OF THE 8008
When power (Voo ) and clocks (cP1 , cP2 ) are first turned on, a flip-flop internal to the
8008 is set by sensing the rise of Voo . This internal signal forces a HALT (00000000)
into the instruction register and the 8008 is then in the STOPPE D state. The following
sixteen clock periods after entering the STOPPED state are required to clear (logic "0")
memories (accumulator, scratch pad, program counter, and stack). During this time the
interrupt line has been at logic "0". Any ti me after the memories are cleared, the 8008
is ready for normal operation.
To reset the flip-flop and also escape from the stopped state, the interrupt line must go to
a logic "1"; It should be returned to logic "0" by decoding the state T11 at some time later
than ¢ 11. Note that whenever the 8008 is in a T11 state, the program counter is not incre
mented. As a result, the same address is sent out on two successive cycles.
Three possible sequences for starting the 8008 are shown on the following page. The
RESTART instruction is effectively a one cycle call instruction, and it is convenient to use·
this instruction to call an initiation subroutine. Note that it is not necessary 10 start the
8008 with a RESTART instructLon.
The selection of initiation technique to use depends on the sophistication of the system
using the 8008. If the interrupt feature is used only for the start-up of the 8008 use the
ROM directly, no additional external logic associated with instructions from source other
than the ROM program need be considered. If the interrupt feature is used to jam in
structions into the 8008, it would then be consistent to use it to jam the initial instruction.
The timing for the interrupt with the start-up timing is shown on an accompanying sheet.
The jamming of an instruction and the suppression of the program counter update are
handled the same for all interrupts.
19


## Scan page 24

EXAMPLE 1:
Shown below are two start-up alternatives where an instruction is not forced into the 8008 during
the interrupt cycle. The normal program fl.ow starts the 8008.
a.
b.
8008 ADDR ESS OUT
a a a a a a
000000
o a a a a a
a a a a a a
a 0 0 a a a a a
00000000
a 0 a 0 000 1
a a 0 a a a 1 0
8008 ADDRESS OUT
a a a a 0 a
000000
a a a a a a
a 0 a a a a a a
OOXYZOOO
00XYZ001
EXAMPLE 2:
INSTRUCTION IN ROM
NOP
NOP
INSTR1
INSTR2
(LAA 11 000 000) }
INSTRUCTION IN ROM
RST
INSTR1
INSTR2
(RST =00 XYZ 101) }
Entry Directly To
Main Program
A Jump To The
Main Program
A RESTART instruction is jammed in and first instruction in ROM initially ignored.
8008 ADDRESS OUT
a 0 a a a 0
000000
000000
000000
000000
000000
000 a a 000
OOXYZOOO
OOXYZOOl
o ann n n n n
000 a 0 0 a a
o 0 a 0 0 001
INSTRUCTION IN ROM
INSTR1 (RST = 00 XYZ 101)}
I NSTRa
INST~
RETURN
Start-up
Routine
INSTR1 (lNSTR1 executed now) Main Program
INSTR2
Note that during the interrupt cycle the flow of the instruction to the 8008 either from ROM or
another source must be controlled by hardware external to 8008.
START-UP OF THE 800B
B. Ready (ROY)
The 8008 is designed to operate with any type or speed of semiconductor memory. This flex
ibility is provided by the READY command line. A high-speed memory will always be ready
with data (tie READY line to Vee ) almost immediately after the second byte of the address
has been sent out. As a result the 8008 will never be required to wait for the memory. On the
other hand, with slow ROMs, RAMs or shift registers, the data will not be immediately avail
able; the 8008 must wait until the READY command indicates that the valid memory data is
available. As a result any type or any combination of memory types may be used. The READY
command line synchronizes the 8008 to the memory cycle. When a program is being developed,
the READY signal provides a means of stepping through the program, one cycle at a time.
20


## Scan page 25

VI. ELECTRICAL SPECI FICATION
The following pages provide the electrical characteristics for the 8008. All of the inputs are TTL
compatible, but input pull-up resistors are recommended to insure proper V1H levels. All outputs are
'low-power TTL compatible. The transfer of data to and from the data bus is controlled by the CPU.
During both the WAIT and STOPPED states the data bus output buffers are disabled and the data bus
is floating.
- - - -- -v:-l
I
I
I ' FROM -------41 ... ---- .....
INTERNAL
DATABUS---------~------~ __ .... ~I ..... DATA BUS
I/O
TO INTERNAL _ .... _---.
DATA BUS
OUTPUT ___ ..... ~_~I--~
DISABLE
8008 vee
, ~c
-----------------~---------~
.---I
I
I
I
I
I
I
IN .... -01-0-41-- ....
Vce
Input Buffer
(cf>1' cf>2' ROY, INT)
Figure 6. Data Bus I/O Buffer
Figure 7. I/O Circuitry
21
.... ---+--~ OUT
I
I
I
I .
_...J
Vee
Output Buffer
(SYNC, So' S1' S2)


## Scan page 26

ABSOLUTE MAXIMUM RATINGS*
Ambient Temperature
Under Bias
Storage Temperature
Input Voltages and Supply
Voltage With Respect
to Vee
Power Dissipation
O°C to +70°C
-55°C to +150°C
+0.5 to -20V
1.0 W @ 25°C
D.C. AND OPERATING CHARACTERISTICS
*COMMENT
Stresses above those listed under" Absolute Max
imum Ratings" may cause permanent damage to
the device. This is a stress rating only and func
tional operation of the device at these or any other
condition above those indicated in the operational
sections of this specification is not implied_
T A = O°c to 70°C, Vee = +5V ±5%, VDD = -9V ±5% unless otherwise specified_ Logic "1" is defined
as the more positive level (V1H ' VOH ). Logic "0" is defined as the more negative level (V1L , VOL).
SYMBOL PARAMETER MIN.
IDD AVERAGE SUPPLY CURRENT-
OUTPUTS LOADED*
III INPUT LEAKAGE CURRENT
VIL INPUT LOW VOLTAGE
(INCLUDING CLOCKS) VDD
VIH INPUT HIGH VOLTAGE
(INCLUDING CLOCKS) Vee-1.5
VOL OUTPUT LOW VOLTAGE
VOH OUTPUT HIGH VOLTAGE Vee -1.5
A.C. CHARACTERISTICS
LIMITS
TYP. MAX.
30 60
10
Vee-4.2
Vee +0.3
0.4
UNIT
mA
p.A
V
V
V
V
TEST
CONDITIONS
TA = 25°C
VIN = OV
IOL = 0.44mA
CL = 200 pF
10H =0.2mA
*Measurements are made while
the 800S is executing a typical
sequence of instructions. The
test load is selected such that
at VOL = O.4V, IOL"" O.44mA
on each output.
TA = O°C to 70°C; Vce = +5V ±5%, VOO = -9V ±5%. All measurements are referenced to 1.5V levels.
8008 8008-1
LIMITS LIMITS
SYMBOL PARAMETER UNIT TEST CONDITIONS
MIN. MAX. MIN. MAX.
tCY CLOCK PERIOD 2 3 1.25 3 J,J.s tR,t F = 50ns
t R,t F CLOCK RISE AND FALL TIMES 50 50 ns
t</>1 PULSE WIDTH OF </>1 .70 .35 J,J.s
t</>2 PULSE '''-'IDTH OF </>2 .55 .35 J,J.s
t01 CLOCK DELAY FROM FALLING .90 1.1 1.1 J,J.s
EDGE OF </>1 TO FALLING EDGE
OF </>2
t02 CLOCK DELAY FROM </>2 TO </>1 .40 .35 J,J.s
t03 CLOCK DELAY FROM </>1 TO </>2 .20 .20 J,J.s
too DATA OUT DELAY 1.0 1.0 J,J.s CL = 100pF
tOH HOLD TIME FOR DATA BUS OUT .10 .10 J,J.s
tlH HOLD TIME FOR DATA IN [1 ] [1 ] J,J.S
tso SYNC OUT DELAY .70 .70 J,J.s CL = 100pF
tS1 STATE OUT DELAY (ALL STATES 1.1 1.1 J,J.S CL = 100pF
EXCEPT T1AND T11) [2]
tS2 STATE OUT DELAY (STATES 1.0 1.0 J,J.S Cl = 100pF
T1 AND T11)
tRW PULSE WIDTH OF READY OUR ING .35 .35 J,J.S
</>22 TO ENTER T3 STATE
tRO READY DELAY TO ENTER WAIT .20 .20 J,J.S
STATE
(1) MIN> tlH -tso 12J If the I NTERRUPT is not used, all states have the same output delay, tS1 '
22


## Scan page 27

TIMING DIAGRAM
SYNC
DATA BUS [' LINES
(~···Dol .
STATE
LINES
READY {
• '4
Notes: 1. READY line must be at "0" prior to ¢22 of T2 to guarantee entry into the WAIT state.
2. INTERRUPT line must not change levels within 200ns (max.) of falling edge of ¢1.
TYPICAL D. C. CHARACTERISTICS
o o
<i
! ...
60
50
Z 40
0::
0::
::> u
': 30
t
iil
0:: 20
~
ri:
0
0
r-
r--
r-
POWER SUPPLY CURRENT
VS. TEMPERATURE
--~ --
Vee -Voo = 14V
--~C~~3V
I
i
--
10 20 30 40 50 60 70 60
AMBIENT TEMPERATURE (OC)
TYPICAL A. C. CHARACTERISTICS
DATA OUT DelAY VS.
OUTPUT LOAD CAPACITANCE
1
2.4
_5
;;i 2.2
! ... z
~ 2.0
~ 1.8
iii z
(ij
~ 1.6
... ::> o
1.4
2
"'"
-
OUTPUT SINKING CURRENT
VS. TEMPERATURE.
...........
............ ~Voo =14V
J-
VOl=rV r-
----
10 20 30 40 50 60 70 80
AMBIENT TEMPERATURE (OC)
<i
! ...
Z
0::
0::
a
U
0::
::>
Sl ...
~
~ 2
o
1
o 1.0
T,
OUTPUT SOURCE CURRENT
VS. OUTPUT VOLTAGE
vool= -9)
Vee =5V -
TA = 70°C
-......
"-
~
,,~
"
~
"r'\.
2.0 3.0 4.0 5.0
OUTPUT VOLTAGE (V). VOH
>
e
1.0
/'
/ CAPACITANCE f = 1MHz; TA = 25°C; Unmeasured Pins Grounded
> ..
9
8
::} .7
...
:::J
:::J
o .6
.5
o
/
/
/ /
50 100 150 200 250 300
DATA BUS CAPACITANCE (OF I. COB
SYMBOL TEST LIMIT (pF)
TYP. MAX.
CIN INPUT CAPACITANCE 5 10
COB DATA BUS I/O CAPACITANCE 5 10
COUT OUTPUT CAPACITANCE 5 10
23


## Scan page 28

VII THE SIM8-01 - AN MCS-8T•M• MICRO COMPUTER
During the development phase of systems using the 8008, Intel's single chip 8-bit parallel central processor
unit, both hardware and software must be designed. Since many systems will require similar memory and
I/O interface to the 8008, I ntel has developed a prototyping system, 1he SI M8-01. Through the use of this
system and Intel's programmable and erasable ROMs (1702), MCS-8 systems can be completely developed
and checked-out before committing to mask programmed ROMs (1301).
The SI M8-01 is a complete byte-oriented computing system including the processor (8008), 1 K x 8 memory
(1101), six I/O ports (two in and four out), and a two-phase clock generator. Sockets are provided for 2K
x 8 of ROM or PROM memory for the system microprogram. The SIM8-01 may be used with either the
8008 or 8008-1. To operate at clock frequencies greater than 500kHz, former SIM8-01 boards must be
modified as detailed in the schematic and the following system description. Note that all Intel-developed
8008 programs interface with TTY and require system operation at 500kHz. Currently, the SIM8-01 is
supplied with the 8008-1 CPU and the system clock preset to 500kHz ..
The following block diagram shows the basic configuration of the SI M8-01. All interface logic for the
8008 to operate with standard ROM and RAM memory is included on the board. The following pages
present the SI M8.:01 schematic and deta'iled system description.
8008
DATA
BUS
~~ r-f+
8008
t
READY
lID INPUT PORTS AND
INTERRUPT INSTRUCTION
PORT
++++++++
BUFFERS '.!-
& :::
MPXERS :::: -
MEMORY,
INTERRUPT
rr=il & INPUT
MEMORY
ROM· RAM
8 BITS/BYTE
TO 16 K BYTES
I/O
"'r-
DEVICE
;:SELECT ...
ENABLES I ADDRESS, CONTROL
H
ADDRESS r
REGISTER·8 BITS REGISTER· 8 BITS
ttl ttl
I J.. I J..
... ...
BUFFERS
STATUS
LOGIC
~ !..
R/W
SYNC EXTERNAL INTERRUPT
tNT.
it J CLOCK I ... i GENERATOR
Figure S. MCS-S Basic System.
24
1/0
OUTPUT
DATA


## Scan page 29

SIMS-01 SPECIFICATIONS
Card Dimensions:
• 11.5 inches high
• 9.5 inches deep
Sys~em Components I ncluded on Board:
.8008-i
• Complete TTL interface to memory
• lK x 8 RAM memory
• Sockets for 2K x 8 PROM memory
• TTY interface ckts.
• Two input and four output ports (8 bits each)
• Two phase clock generator
Maximum Memory Configuration:
• 1 K x 8 RAM
• 2K x 8 PROM
• All control lines are provided for
memory expansion
15
A¢> CS
HOI
Poo,
A7 RIW
15
.1. 16
An CS
1101
As3
A7 RIW
NOTE: 1101',
+5V - PIN 5
-9V - PIN 4, 8
15
.I. 16
13
~3
PIN 14 NOT USED· DATA OUT
cs
1101
A2S
1101
A.oo
1101
Ass
= = = -=
= = = --<:=
= = = ----<=
I
CS
1101
A38
I
1101
As,
1101
Aas
I--< ::
::
r- =
=
I--< = = r-'=
= = = ----<.=
I
CS
1101
A23
T
1101
A38
I
1101
Aoo
1101
Ao.
= = .= 1--=
= = = -:=
:=
= = --<=
= - :=
= ---<:=
I
CS
1101
~
T
1101
Aa7
I
1101
Poo.
I
1101
As3
Operating Speed
• 2 f.J.S clock period
• 20 f.J.S typical instruction cycle
D.C. Power Requirement:
• Voltage:
Vcc = 5V ±5%
TTL GRD = OV
Voo = -9V ±5%
• Current:
Eight ROMs
Typical
Icc = 2.5 amps
100 = 1.0 amps
Connector:
Maximum
4.0 amps.
1.5 amps.
• Wire wrap type Amphenol 86 pin
= :: - = --c _
= = =
-< =
= ::
---<::
connector PIN 261-10043-2
CS
1101
A"
1101
Aao
1101
A.os
1101
Au
= = = r--=
= = :
- :
:
-
--< -
:::
= ---<::
CS
lJOl
A20
1101
'A35
1101
P007
1101
A6,
= I--< =
= f-'- =
= = =
I--< =
= = = - =
~ = :: ----<=
CSDATA 13
OUT
1101
A,fA~~ ~
R/W
15
cs
1101
AJ4
R/W
15
CS
1101
Aos
R/W
15
CS
1101
Aoo
13
13
13
CM
CM
CM
Cs FOR
RAM
Figure 9. MCS-8 Memory System
25


## Scan page 30

+5
-9
FROM TTY TRANSMITTER
{
" I .,
,""' '1)' !
RAM
DATA IN
EXPANSION
MPX
MEMORY DATA
INPUT PORT.p
INPUT PORT 1
[;~~if
:~;~g~ ~::::::::::::::::::::::::::::::::::::::::::::::::::=4~::::::~~::::::::::::::::::::::::::::::
:~~~ ~::::::::::::::::::::::::::::::::::::::::::::::::::=4~::::::~~::::::::::::::::::::::::::::::,
r.J/_6() MI¥>::============~::I; 'P / J ~ L1 ~;!~ ~~~ > ~ e IIPJ' ~ A Z'~ I4P¥ F----------
·~:fJ::: J69 nr/.~:f-----Itt;::::::t:p#~ A5~ }:J~+'-----------
II-IIJI., 8211J 8 ?
-:z:~.:z:;.z~============3~Ji "'2/.1 II 26 F.rf'llz:::;-. ________ _ ~~~; H
~~~:::~:::::::::::::::::::::::::~~H~~~ ~r/~+~----tti111,;::tt~/~ ~F/S-~---------.
J/~2/.rI!l, >-------------11ltr'l,:s~o~/Ic~'7.s~J~ S() .51
fl-"'I/~~~~~~~=----~~~~-~~~g~~_+~I.~/~~~~~ ~~~~/~" ___ ?~--~-_--------
(AlOitMAUY TQ +sv)tJI-Z' ,lMTA ~OI"tPtG"".Nr
J~72ID ~---~--------~~~-~~_+~I~ •• ------~ ~~S~Lj.~~~i_-------------
MPX
MEMORY DATA
INPUT PORT ¢
INPUT PORT 1
INTERRUPT
INSTRUCTION
PORT
r" H /s /t. , 'J
V..e-~ Alt>,,> _____________ +-+-H~~44 ,SI>QC $1 ""-w/.;:::'O;.-.-----+-+-H-_--i/ct'".,,- ~ 51 ,."'~'__ ________ ~ JI-,ZI I44 iii r>O,- _.
JI-Zt.ZIl4 >------------++-t-H ...... ~~C ZI6 Mft
/ /of p X r-----: ,.,ro X L"/ ~
~:f.,:::~~~~~~~~~~~~~E~~~ II?/) ~, II .. r' ... ~'__ ________ _ J/~aIZn ~ A56
~=::;::: 8263 ~ 13 I~ 8Z67 F.tto'2 ___________ _
JI-3+IIII. r---B-
.:;r,/-'H /lin 1'1 14? I~
~::i:; ~ ~ r-------------
'-
26


## Scan page 31

---------------------;rJH
'1.
-
" 12
ROM
00
CS7 DATA FROM CM3 MEMORY RAM
0 7 CMO -.
NOTE:
THIS SCHEMATIC
IS INCLUDED FOR
REFERENCE ONLY.
27
N"~h' 171/'/)£'"
#"Af"SS 17U r
AI3
t:t:~} CyclE eouTloL
ed, CODIA/6
"}'1'1.1>- ".,..: 4,lA.-tfi<l,< '
.. ! '-.. .;c' ~ _
~ <r~ 0 "
---~. ; .'\
'" <~~ .. BII DI(2. (No. 00014)
Figure 10. Complete SIM8-01 Schematic


## Scan page 32

SYSTEM DESCRIPTION
The 8008 processor communicates over an 8-bit data bus (DO through 07) and uses two input lines
(R EAOY and I NTE R R LJPT) and four output lines (SO, 51, 52, and SYNC) for control. Time multi
plexing of the data bus allows control information, 14-bit addresses, and data to be transmitted between
the CPU, memory, and I/O. All inputs, outputs, and control lines for the SIM8-01 are positive-logic
TTL compatible.
Two Phase Clock Generator
The basic system timing for the SIM8-01 is provided by two non-overlapping clock phases generated
by 9602 single shot multivibrators (A 1, A2 ). The clocks are factory adjusted as shown in the timing
diagram below. Note that this is the maximum specified operating frequency of the 8008. I n addition,
all Intel-developed TTY programs are synchronized to operate with the SIM8-01 at 500kHz. The'
clock widths and delays are set in accordance with the 8008-1 specification since an 8008-1 is provided
on the board. An option is provided on the board for using external clocks. If the jumper wires in box
A are removed, external. clocks may be connected at pins J1-52 and J1-12. (Normally these pins are
the output of the clock "generators on the board.) The clock generator may be adjusted for operation
up to 800kHz when using the 80OB-1 at maximum speed.
..
J~t¢1~\
(500ns) 1,.-
Memory Organization
tey
(2~s)
t01
(1000ns)
1
----t¢2
(500n5)
~
'~tD2----'
(500ns)
Figure 11. SIMS-01 Timing Diagram
_~I ,
t R• tF
I'
10-90% OF INPUT
AMPLITUDE
The SIM8-01 has capacity for 2K x 8 of ROM or PROM and 1 K x 8 of RAM. The memory can easily
be expanded to 16K x 8 using the address and chip select control lines provided. Further memory
expansion may be accomplished by dedicating an output port to the control of memory bank switching.
In an MCS-8 system, it is possible to use any combination of memory elements. The SIM8-01 is
shipped from the factory with the ROM memory designated from address 0 ~ 2047, RAM memory
from 2048~3071, and memory expansion for all addresses 3072 and above. Jumper wires provided
on the board (boxes C, 0, E) allow complete flexibility of the memory organization. They may
be rearranged to meet any requirement. the Intel 3205 data sheet provides a complete description of
the one of eight decoder used in this system. the 3205 truth table is shown below.
ADDRESS ENABLE OUTPUTS
AO Al A2 El E2 E3 0 1 2 3 4 5 6 7
L L L L L H L H H H H H H H
H L L L L H H L H H H H H H
L H L L L H H H L H H H H H
H H L L L H H H H L H H H H
L L H L L H H H H H L H H H
H L H L L H H H H H H L H H
L H H L L H H H H H H H L H
H H H L L H H H H H H H H L
X X X L L L H H H H H H H H
X X X H L L H H H H H H H H
X X X L H L H H H H H H H H
X X X H H L H H H H H H H H
X X X H L H H H H H H H H H
X X X L H H H H H H H H H H
X X X H H H H H H H H H H H
Control Lines
• Interrupt
The interrupt control line is directly available as an input to the board. For manual control, a normally
open push-button switch may be connected to terminals J1-50 and J 1-53. The interrupt may be inserted
28


## Scan page 33

under system control on pin J1-1. An external flip-flop (A33) latches the interrupt and is reset by T11
when the CPU recognizes the interrupt. Instructions inserted under interrupt control may be set up
automatically or by toggle switches at the interrupt input port as shown on the schematic. Use the
interrupt line and interrupt input port to start up the 800S .
Note that the interrupt line has two different connections to the input to the board (box B). The path
from J 1-1 directly to pin 4 of package A3 is the normal interrupt path (the board is shipped from the
factory with this connection). Lfet..he connection from pin 8 of package A 15 to pin 4 of package A3 is
marla instead the processor will reCQgnfze an interrupt only when it is in the STOPPED state. This is
used to recognize the " start character" when entering data from TTY .
• Ready
The ready line on the 8008 provides the flexibility for operation with any type of semiconductor memory.
On the SIM8-01 board, the ready line is buffered; and at the connector (J1-30), the READY line is active
low. During program development, the READY line may be used to step the system through a program.
NORMAL OPERATION OF SYSTEM
The 8008 CPU exercises control over the entire system using its state lines (So, S" S2) and two control
bits (CCO, CC1) which are sent onto the data bus with the address. The state lines are decoded by a
3205 (A44) and gated with appropriate clock and SYNC signals. The two control bits form part of the
control for the multiplexers to the data bus (A55, A56), the memory readlwrite line (A33) and the I/O
line (A17).
I n normal operation, the lower order address is sent out of the CPU at state T1, stored in 3404 latches
(A59, A72) and provided to all memories. The' high order address is sent out at a state T2 and stored in
3404 latches (A72, A73). These lines are decoded as the chip selects to the memory. The two highest
order bits (CCO, CC1) are decoded for control.
. To guarantee that instructions and data are available to the CPU at the proper time, the T3 state is
anticipated by setting aD-type flip-flop (A 16) at the end of each T2 state. This line controls the
multiplexing of data to the 8008. This flip-:flop is reset at the end of each T3 state. In addition, switched
pull-up resistors are used on the data-bus to minimize data bus loading and increase bus response. The use
of switched resistors on the data bus is mandatory when using the SOOS-1. SIMS-01 boards built prior to
October,.1972 must be modified in order to operate with the SOOS-1 at clock frequencies greater than 500kHz.
Normally, the 8008 executes instructions and has no interaction with the rest of the system during states
T4 and T5. In the case of the INP instruction, the content of the flag flip-flops internal to the 8008 is
sent out at state T4 and stored in a 3404 latch (A43).
Instructions and data are multiplexed onto the 8008 data bus through four multiplexers (A55, A56, A69,
A70). In normal operation, line J1-29 should be at +5V in order for IItrue" data to reach the S008 data bus.
System I/O
The SI M8-01 communicates with other systems or peripherals through two input ports and four output ports.
All control and 1/0 selection decoding lines are provided for expansion to the full complement of eight input
ports and twenty-four output ports. To expand the number of input ports, break the trace at the output of
Device A68, pin 11, and generate input port decoding external to the SIM8-01. Control the input multi
plexer through pin J1-69. The output ports latch data and remain unchanged until referenced again under
software control. Note that all output ports complement data. When power is first applied to the board,
the output ports should be cleared under software control to guarantee a known output state. To enable the
I/O device decoder, pin J2-8 should be at ground.
Teletype Interface
The 8008 is designed to operate with all types of terminal devices. A typical example of peripheral interface
'is the teletype (ASR-33). The SIM8-01 contains the three simple transistor TTY interface circuits shown on
the following page. One transistor is used for receiving serial data from the teletype, one for transmitting
data back to the teletype, and the third for tape reader.control.
The teletype must be operating in the full duplex mode. Refer to your teletype operating manual for making
connections within the TTY itself. Many models include a nine terminal barrier strip in the rear of
29


## Scan page 34

the machine. It is at this point where the
connections are made for full duplex
operation. The interconnections to the
SIM8-01 for transmit and receive are made
at this same point.
A complete description of the interconnection
of the S I M8-0 1 and the AS R -33 is presented
in Appendix IV.
FULL DUPLEX
RECEIVE
FROM SIMS-01
SEND
TO SIM8-01
~~
co 0
L J1-86 " 0
J2-40 \Q 0
It)
0
1 J2-37 (2) o;t
J2-59 M (2)
N (2)
(2)
Figure 12. Teletype Terminal Strip
+5 DATA
FROM
SIM8-01
+5
DATA
FROM
SIMS-01
+5
J2-27 >-"JV'v. ..... J1-84 >--VV\-+ ....
J2-83
-9
FROM TTY TRANSMITTER
-9
RELAY
TO BE
ADDED
TO TTY
TAPE READER CONTROL
Figure 13. SIMS-01 Teletype Interface Circuitry
-9
TO TTY RECEIVER
To use the teletype tape reader with the SIM8-01, the machine must contain a reader power pack.
The contacts of a 10V dc relay must be connected in series with the TTY automatic reader (refer
to TTY manual) and the coil is connected to the SIM8-01 tape reader control as shown.
For all Intel developed TTY programs for the SIM8-01, the following I/O port assignments have been made:
1. DATA IN -- INPUT PORT 0, BIT 0 (J2-83 connected to J1-11)
2. DATA OUT -- OUTPUT PORT 2, BIT 0 (J1-84 connected to J2-36)
3. READER CONTROL -- OUTPUT PORT 3, BIT 0 (J2-27 connected to J2-44)
Note that the SIMS-01 clock generator must remain set at 500kHz. All Intel developed TTY programs
are synchronized to operate with the SIMS-01 at 500kHz.
In order to sense the start character, data in is also sensed at the interrupt input (J2-83 connected to J1-1)
and the interrupt jumper (box B) must be between pin 8 of A 15 and pin 4 of A3. It requires approximately
110ms for the teletype to transmit or receive eight serial data bits plus three control bits. The first and last
bits are idling bits, the second is the start bit, and the following eight bits are data. Each bit stays 9.09ms.
While waiting for data to be transmitted, the 8008 is in the STOPPED state; when the start character is
received, the processor is interrupted and forced to call the TTY processing routine. Under software control,
the processor can determine the duration of each bit and strobe the character at the proper time.
A listing of a teletype control program is shown in Appendix V.


## Scan page 35

Pin No.
2,4
84 .. 86
1,3
60
63
17
77
38
41
45
74
11
10
14
19
28
33
37
36
6
13
16
21
26
31
34
39
61
67
54
51
53
49
50
47
75
80
78
60
65.
57
62
55
36
34
25
24
22
19
16
21
44
, 43
39
42
33
29
26
31
69
82
58
23
63
17
32
48
68
67
80
56
76
71
74
73
61
15
56
59
58
Connector
J1
J2
J2
J1
J1
Jl
J1
J2
J2
J2
J2
J1
J1
J1
J1
J1
Jl
J1
Jl
Jl
Jl
Jl
Jl
Jl
Jl
J1
Jl
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
Jl
Jl
Jl
J2
Jl
Jl
Jl
Jl
Jl
J1
Jl
J1
J1
Symbol
SIM8-01 MICRO COMPUTER BOARD PIN DESCRIPTION
Description
+5VDC POWJ::R SUPPLY
-9VDC POWER SUPPLY
GROUND
DATA FROM MEMORY ~ BIT ~
uAl'A FROM MEMORY 1 BIT 1
DATA FROM MEMORY 2 BIT 2
DATA FROM MEMORY 3 BIT 3
DATA FROM MEMORY 4 BIT 4
DATA FROM MEMORY 5 BIT 5
DATA FROM MEMORY 6 BIT 6
DATA FROM MDlORY 7 BIT 7
DATA INPUT PORT II BIT II
DATA INPUT PORT II BIT 1
DATA INPUT PORT S BIT 2
DATA INPUT PORT II bIT 3
DATA INPUT PORT II BIT 4
DATA INPUT PORT II BIT 5
DATA INPUT PORT ~ BIT 6
DATA INPUT POR'l' II BIT 7
DATA INPUT PORT 1 B1'l' II
UATA INPUT PORT 1 !:lIT 1
DATA INPuT PORT 1 1:IIT 2
DATA INPUT PORT 1 BIT 3
DATA nlPUT PORT 1 BIT 4
DATA INPUT PORT 1 BIT 5
DATA INPUT PORT 1 BIT 6
DATA INPUT PORT 1 BIT 7
OUTPUT PORT ~ BIT ~
OUTPUT PORT II bIT 1
OUTPUT PORT II i..I'l' 2
OUl'PUl' PORT ~ !:lIT 3
OUTPUT PORT II !:lIT 4
OUTPUT PORT ~ BIT 5
ou~r~:J,' PORT II fiI'i' 6
OUTPL'T POilT II IlI'1' 7
OUTPUT PORT 1 BIT ~
OUTPUT PORT 1 bIT 1
OUTPU'1' PORT 1 BIT 2
OUTPUT PORT 1 BI1' 3
OUTPUT PORT 1 BIT 4
OUTPUT PORT 1 BIT 5
OUTPUT POR'!' 1 BIT 6
OUTPUT PORT 1 .:lIT 7
OUTPUT POR'l' 2 BIT II
OUTPUT PORT 2 BIT 1
OUTPU'l' PORT 2 !:lIT 2
OUTPUT PORT 2 BI'1' 3
OUTPU'!' PORT 2 BIT 4
OUTPUT POR,!' 2 BI'!' 5
OUTPUT PORT 2 !:lIT 6
OUTPUT PORT 2 BIT 7
OUTPUT PORT 3 BIT II
OUTPUT PORT 3' BIT 1
OUTPUT PORT 3 1:II'l' 2
OUTPUT PORT 3 BIT 3
OUTPUT PORT 3 BIT 4
OUTPUT PORT 3 BIT 5
OU1'PUT PORT 3 BIT 6
OUTPUT PORT 3 BI1' 7
LOW ORDER ADDRESS OUT
LOW ORDER ADDRESS OUT
LOW ORDER ADDRESS OUT
LOW ORDI;R ADDRESS OUT
LOW ORDER ADDRESS OUT
LOW ORDER ADDRESS OUT
LOW ORDER AllDRESS OUT
LOli ORDER ADDRESS OUT
HIGH ORDER ADDRESS OUT
HIGH ORDER ADDRESS OUT
HIGH ORDER ADDRESS OUT
HIGH ORDER ADDRI;;SS OUT
HIGH ORDJ::R ADDRESS OUT
HIGH ORDER ADDRESS OUT
CYCLE CONTROL CODING
CYCLE CONTROL CODING
RAM DATA IN Dil
RAM DATA IN 0 1
RAM DATA IN O2
RAM DATA IN 0 3
RAM DATA IN D 4
31
Pin t.o.
,.
57
55
54
48
49
46
45
42
44
47
43
79
81
63
6
2
4
85
82
85
78
62
64
70
35
46
72
5
13
12
15
14
11
9
7
3
5
23
25
7
9
18
20
24
27
38
40
59
37
83
27
18
28
84
10
86
40
81
72
41
69
8
29
52
12
75
30
1
8
79
77
50
53
52
71
20
30
22
32
35
Connector
Jl
J1
Jl
Jl
Jl
J1
Jl
Jl
Jl
Jl
Jl
Jl
Jl
Jl
J2
J2
J2
Jl
J1
J2
Jl
J1
J1
J1
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J2
J1
J1
J1
J1
J1
Jl
J1
J1
J1
J1
J1
J1
J2
J2
J2
J2
J2
J2
J1
J2
J1
J2
J2
Jl
J1
Jl
Jl
J1
Jl
J1
Jl
J1
J1
J2
J2
J2
J1
J1
J2
J2
J2
J2
J1
J1
Jl
Symbol
111
SLI1
u
SL1
Des=iption
RAM DATA IN D5
RAM DATA IN D6
RAM DATA IN D7
STATE COUNTER
STATE COUNTER
STATE COUNTER
STATE. COUNTER
STATE COUNTER
STATE COUNTER
STATE COUNTER
STATE COUNTJ::R
RAM CHIP SELECT II
RAM CHIP SELECT 1
RAM CHIP SELECT 2
RAM CHIP SELEC1' 3
RAM CHIP SELEC1' 4
RAM CHIP SELECT 5
RAM CHIP SELECT 6
RAM CHIP SELECT 7
ROM CHIP SELECT II
ROM CHIP SELECT 1
ROM CHIP SJ::LECT 2
ROM CHIP SELECT 3
ROM CHIP SELJ::CT 4
ROM CHIP SELECT 5
ROM CHIP SELECT 6
RON CHIP SELECT 7
I/O DECODE OUl' 0 7
I/O DECODE OUT 0 6
I/O DECOD': OUT 05
I/O ,DECODE OUT 0 4
I/O DECODE OUT 0 3
I/O DECODE OUT O2
I/O OECOOE OUT 0 1
I/O DECODE OU'l' 011
FLAG FLIP FLOP-Sign
FLAG FLIP FLOP-Zero
FLAG FLIP FLOP-Parity
f'LAG FLIP FLOP-Carry
INTERRUPT INSTRUCTION INPUT II
INTERRUPT INSTRUCTIOi~ INPUT l'
INTERRUPT INSTRUCTION INPUT 2
IN1'ERRUPT INSTRUCTION INPUT 3
INTERRUPT INSTRUCTION INPUT 4
INTERRUPT INSTRUCTION INPuT 5
INTERRUPT INSTRUCTION INPUT 6
INTERRUPT INSTRUCTION INPUT 7
FROM TTY TRANSMITTER IN}
FROM TTY TRANSMITTER OUT' TTY BUFFER
DATA FROM TTY TRANSMITTER BUFFEJil,
TAPE READER CONTROL IN
TAPE READER CONTROL OUT
TAPE READER CONTROL (-9VDC)
DATA. TO TTY RECEIVER BUFFER
To TTY RECEIVER OUT
TO TTY RECEIVER OUT
TO TTY RECEIVER OUT
READ/WRITE
} '" "'''',.
MULTIPLEXER CONTROL LINES N8263
MULTIPLEXER CONTROL LINES N8267
MULTIPLEXER CONTROL LINES N8263
MULTIPLEXER CONTROL LINES N8267
PATA COMPLEf.'.ENT
111 CLOCK (alternate clock)
112 CLOCK (alternate clock)
SYNC OU'l'
READY IN
INTERRUPT INTERRUPT IN
I/O ENABLE ENABLE OF I/O DEVICE DECODER
ITo SYSTEM 1/0 CONTROL
IN
N.O. '
N.C ..
'till
SYSTEM INPUT CONTROL
PUSH BUTTON SWITCH} INTERRUPT
PUSH BUTTON SWITCH
OUTPUT LAl'CH STROBE PORT II
WI OUTPUT LATCH STROBE PORT 1
W 2 OUTPUT LATCH STROBE PORT 2
W 3 OUTPUT LATCH STROBE PORT 3
INT CYCLE INTERRUPT CYCLE INDICATOR
TJA ANTICIPATED T3 OUTPUT
T 3A ANTICIPATED T 3 OUTPUT


## Scan page 36

FigUre 14. SI M8-01 Assembly Diagram
32


## Scan page 37

VIII. MCS-8 PROM PROGRAMMING SYSTEM
A. General System Description and Operating Instructions
Intel has developed a low-cost micro computer programming system for its electrically programmable
ROMs. Using Intel's eight bit micro computer system and a standard ASR 33 teletype (TTY), a
complete low cost and easy to use ROM programming system may be assembled. The system features
the following functions:
1) Memory loading
2) Format checking
3) ROM programming
4) Error checking
5) Program listing
For specifications of the Intel PROMs, (1602A/1702A) refer to the Intel Data Catalog.
A086~CONT
A0861 PROG
ROL
A0863 RAM
RAM
MEMO RY
ROM MEMORY
¢ 1 2 3 4 5 6 7
00000000000 l..t ...
I .-.
r'I ..
r BANK ~ 0 0 0 0 DOD 0
BANK 1 0 0 0 0 0 0 0 0
BANK 2 0 0 0 0 0 0 0 0
~BANK 3 0 0 0 0 0 0 0 0 L.-
r~
SIMS-01
Figure 15. MCS-8 PROM Programming System
This programming system has four basic parts:
1) The micro computer (SI MS-01)
PROM SOCKET
/ /-
D
MP7-03
PROM PROGRAMMING
BOARD
.... TIY ,.. ASR33
This is the MCS-8 prototype board, a complete micro-computer which uses 1702A PROMs
for the microprogram control. The total system is controlled by the SOOS CPU.
2) The control program (AOS60, AOS61 , AOS63)
These control ROMs contain the microprograms which control the bootstrap loading, pro
gramming, format and error checking, and listing functions. For programming of Intel's
1702A PROM, use control PROM AOS63.
3) The programmer (MP7-03)
This is the programmer board which contains all of the timing and level shifting required to
program the Intel ROMs. This is the successor of the MP7-02.
4) ASR 33 (Automatic Send Receive) Teletype
This provides both the keyboard and paper tape I/O devices for the programming system.
In addition, a short-wave ultraviolet light is required if the erasable and reprogrammable 1702As
are used.
This system has two modes of operation:
1) Automatic - A paper tape is used in conjunction with the tape reader on the teletype.
The tape contains the program for the ROM.
2) Manual - The keyboard of the TTY is used to enter the data content of the word to
be programmed.
33


## Scan page 38

PROGRAMMING THE 1602A/1702A
Information is introduced by selectively programming "1"s (output high) and "0"S (output low) into the
proper bit locations. Note that these ROMs are defined in terms of positive logic.
Word address selection is done by'the same decoding circuitry used in the READ mode. The eight
output terminals are used as data inputs to determine the information pattern in the eight bits of
each word. A low data input level (ground - P on tape) will leave a "1" and a high data input level
(+48V - N on tape) will allow programming of "0". All eight bits of one word are programmed
simultaneously by setting the desired bit information patterns on the data input terminals.
TAPE FORMAT
The tape reader used with a model 33 ASR teletype accepts 1" wide paper tape using 7 or 8 bit
ASCII code. For a tape to correctly program a 1602A/1702A, it must follow exactly the format rules
below:
Start Character 1 Stop Character 11 Data F;eld I MSB r;n 111 LSB ~IP;n 41
Leader: B P P P N N N N N F B N N N N N N P P F ... B N P N P P P N N F Trailer:
Rubout for at
least 25 frames.
'-----v-------, l ___ -...- __ ~
Word Field 0 Word Field 1
The format requirements are as follows:
T
Word Field 255
Rubout for at
least 25 frames
1) There must be exactly 256 word fields in consecutive sequence, starting with word field 0
(all ad,dress lines low) to program an entire ROM. If a short tape is needed to program only
a portion of the ROM, the same format requirements apply.
2) Each word field must consist of ten consecutive characters, the first of which must be the
start character B. Following that start character, there must be exactly eight data characters
(P's or N's) and ending with the stop character F. NO OTHER CHARACTERS ARE
ALLOWED ANYWHERE IN A WORD FIELD. If an error is made while preparing a tape
and the stop character "F" has not been typed, a typed "B" will eliminate the previous
characters entered. This is a feature not available on Intel's 7600 programmer; the format
shown in the Intel Data Catalog must be used when preparing tapes for other programming
systems. An example of this error correcting feature is shown below:
TYPED ON TTY PROGRAMMED IN ROM
BNNPPNPBNPPPNPNPF
I I
------~. NPPPNPNP
I data word
eliminated
If any character other than P or N is entered, a format error is indicated. If the stop
character is entered before the error is noticed, the entire word field, including the B
and F, must be rubbed out. Within, the word field, a P results in a high level output,
and N results in, a low level output. The first data character corresponds to the desired
output for data bit 8 (pin 11), the second for data bit 7 (pin 10), etc.
3) Preceding the first word field and following the last word fie1d, there must be a leader/
trailer length of at least 25 characters. This shou Id consist of rubout punches.
34


## Scan page 39

4) Between word fields, comments not
containing B's or F's may be inserted.
It is important that a carriage return
and line feed characters be inserted
(as a "comment") just before each
word field or at least between every
four word fields. When these carriage
returns are inserted, the tape may be
easi Iy I isted on the teletype for
purposes of error checking. It may
also be helpful to insert the word
number (as a Jlcomment'q at least
every four word, fields.
IMPORTANT
PROM PIN CONFIGURATION
A1 2 23 </>1
AO 3 22 </> 2
'DATA OUT 1 4 (LSB) 21 A3
'DATA OUT 2 5 20 A4
'DATA OUT 3 6 19 AS
'DATA OUT 4 7 18 A6
'DATA OUT 5 . 8 17 A7
-DATA OUT 6 9 16 VGG
-DATA OUT 7 10 15 jVBB
-DATA OUT 8 11 (MSB) 14 Cs
1 PROGRAM
, Vee 12 13 J
1602A/1702A
It should be noted that the PROM's are described in the data sheet with respect to positive
logic (high level = p-Iogic 1). The MCS-8 system is also defined in terms of positive logic.
Consider the instruction code for LHD (one of the 48 instructions for the MCS-8).
1 1 101 011
When entering this code to the programmer it should be typed,
BPPPNPNPPF
This is the code that will be put into the 1302, Intel's mask programmed ROM, when the
final system is defined.
OPERATING THE PROGRAMMER
The S.lM8-01 is used as the micro computer controller for the programming. The control program
performs the function of a bootstrap loader of data from the TTY into the RAM memory. It then
presents data and addresses to the PROM to be programmed and controls the programming pulse.
The following steps must be followed when programming a PROM:
1) Place control ROMs in SI M8-01
2) Turn on system power
3) Turn on TTY to Jlline" position
4) Reset system with an INTERRUPT (lnstr. RST = 00000 101)
5) Change instruction at interrupt port to a NO OP
6) Start system with an INTERRUPT (lnstr NO OP = 11 000 000)
7) Load data from TTY into micro computer memory
8)' Insert PROM into MP7-03
9) Program PROM
10) Remove PROM from MP7-03~ To prevent programming of unwanted bits,
never turn power on or off while the PROM is in the MP7-03.
LOADING DATA TO THE MICRO COMPUTER (THE BOOTSTRAP LOADER)
The programming system operates in an interactive mode with the user. After resetting and starting
the system with an INTERRUPT [steps 4), 5), 6)], a "*,, will appear on the TTY. This is the signal
that.the system is ready for a command .. To load a data tape, the following sequence must be followed:
35


## Scan page 40

TYPED BY SYSTEM
Ready for command
Request for RAM BA NK #
Request for address f
within RAM BANK
ield
Ready for new comm and
-.. *T
-" Bn
.... A
xxx
yyy
It
*
'--
r-
!-
""-
-
-
-
TYPED BY USER
DATA ENTRY command
RAM BANK in which data will be stored.
Enter bank number (0, 1, 2 or 3). Each
bank stores 256 bytes.
Initial addreSS} Address 0 through 255
Final address
Start tape reader and load data into RAM
memory. Data entry must be in specified
format. All format checking is done at this
time. If data is entered from the keyboard,
depress the R ETU R N key after manually
entering each complete word.
This RAM bank may be edited by re-entering blocks of data prior to programming a PROM. More than
one RAM bank may be loaded in preparation for programming several different PROMs or to permit
the merging of blocks of data from different banks into a single PROM. (See the explanation of the
CONTINUE command in section IXJ .
FORMAT CHECKING
When the system detects the first format error (data words entered either on tape or manually),
it will stop loading data and it will print out the address where the format error occurred.
At this time, an "R" may be typed and the data can be RE-ENTERED manually. This is shown below.
EXAMPLE 1:
020
021
022
Listing
by
TTY
BNPNPNPNPF
B P P P P N N N N F
BNNNNPPPPN FE
o 2 2 ...... t---------- format error indicated at address
#022 (too many characters in
data field).
R ......... t------------ RE-ENTER cpmmand
B N N N N P P P P F ..... Stop tape reader and manually
RE-ENTER the data word
023 B N P N P N P N P F .... ~t---- Start the tape reader and continue
024 B P N M F E
o 2 4 ...... 1---------- Format error indicated at address
#024 (illegal character in data field).
R ...... 1----------- RE-ENTER command
B P N P N P N P N F ~ RE-ENTER data
}-
Continue to completion of data
entry.
* ... -111(1------------ Ready for new command
36


## Scan page 41

PROGRAMMING
After data has been entered, the PROM may be programmed. Data from a designated address field
in a designated RAM bank is programmed into corresponding addresses in the PROM. A complete
PROM or any portion of a PROM may be programmed in the following manner:
TYPED BY SYSTEM
Ready for command
Request for RAM BA NK #
f data Request for address 0
field within RAM ban k
Ready for new comm and
ERROR CHECKING
,
-"
*P
... Bn .... '" ~
..lI~ A
xxx ...
yyy
~
-
I ]-
*
TYPED BY USER
Program command
RAM BAN K in which data has been stored.
Enter bank number (0, 1, 2 or 3). Each
bank stores 256 bytes.
Initial address } Address 0 through 255
Final address
TTY will list data address as each locatjon
in PROM is programmed.
After each location in ROM is programmed, the content of the location is read and compared against
the programming data. In the event that the program\TIing is not correct, the ROM location will be
programmed again. The MCS-8 programming system allows each location of the ROM to be repro
grammed up to four times. A "$" will be printed for each reprogramming. If a location in ROM will
not accept a data word after the fourth time, the system will stop programming and a II?" will be
printed. This feature of the system guarantees that the programmed ROM will be correct, and in
completely erased or defective ROMs will be identified.
EXAMPLE 2:
.--------~ 1st programming
!
2nd programming
I 1 3rd programming
Listed --{ + ,
by 006 $ $ $ ? ....... 1---- failure to program
System
If a location in the ROM will not program, a new ROM must be inserted in the programmer. The
system must be reset before continuing. (If erasable ROMs are being used, the "faulty" ROM should
be erased and reprogrammed).
PROGRAM LISTING
Before or after the programming is finished, the _c~mplete content of the ROM, or any portion
may be listed on the teletype. A duplicated programming tape may also be made using the teletype
tape punch. To list the ROM:
37


## Scan page 42

TYPED BY SYSTEM TYPED BY USER
Ready for command *L List command
Request for PROM a ddress :. A
xxx I nitial address
yyy Final address
! }-Listing from PROM
Ready for new comm and --* ..
The listing feature may also be used to verify that a 1702A is completely erased.
EXAMPLE 3:
Ready for command~*T ...... r-.------------ DATA F.NTRY
B0 } A Specification of RAM
000 memory add ress
010
000
001
002
003
004
005
006
007
008
009
010
BNPNPNPNNF
B P P P P P P P P F
B P P P P P P P P F
BPPNPPPNPF
B P P P P P P P P F
BNNPNNPPPF
BNPNNPNPPF
BPNPNPPPPF
BNPNPPNPPF
BNNNNPPPNF
B P P N P P P P N F
Loading of data listing of
tape and verifying correct
format
Ready for command~ *P ........ 1------------ PROGRAM
B0 } A Specification of PROM
005 locations to be programmed
008
005
006
007
008
}
Programming bf PROM and
verifying correct transfer of
data
Ready, for command ~*L ..... "11(1------------ LIST
~00 } Address specification
010
000
001
002
003
004
005
006
007
008
009
010
Ready for command~*
B P P P P P P P P F
B P P P P P P P P F
B P P P P P P P P F
B P P P P P P P P F
B P P P P P P P P F
B N N P N N P P P F Listing of PROM
BNPNNPNPP~F~J BPNPNPPPP
BNPNPPNPP
B P P P P P P P P
B P P P P P P P P
38


## Scan page 43

1702A ERASING PROCEDURE
The 1702A may be erased by exposure to high intensity short-wave ultraviolet light at a wave:length
of 2537 A. The recommended integrated dose (Le., UV intensity x exposure time) is 6W-sec/cm2•
Example of ultraviolet sources which can erase the 1702A in 10 to 20 minutes is the Model S-52 and
Model UVS-54 short-wave ultraviolet lamps manufactured by Ultra-Violet Products, Inc. (San Gabriel,
California).' The lamps should be used without short-wave filters, and the 1702A to be erased should
be placed about one inch away from the lamp tubes.
B. MP7-03 PROM Programmer
The MP7-03 is the PROM programming board which easily interfaces with the SIM8-01. All
address and data lines are completely TTL compatible. The MP7-03 requires +5VDC @ 0.8 amps,
-9 VDC @ 0.1 amps, and 50 Vrms @ 1 amp. Two Stancor P8180 (or equivalent) filament transformers
(25.2 Vrms @ 1 amp) with their secondaries connected in series provide the 50 Vrms.
This programmer board is the successor of the MP7-02. The MP7-03 enables programming of Intel's
1702A, a pin-for-pin replacement for the 1702.
When the MP7-03 is used under SIM8-01 control with control ROM A0862 replaced by A0863, the
1702A may be programmed an order of magnitude faster than the 1702, less than three minutes.
IMPORTANT:
Only use the A0863 control PROM when programming the new 1702A. Never use it when programming
the 1702. The programming duty cycle is too high for the 170? and it may be permanently damaged.
The MP7-03 features'three data control options:
1) Data-in switch (Normal-Complement). If this switch is in the complement position, data
into the PROM is complemented.
2) Data-out switch (Normal-Complement). If this switch is in the complement position, data
read from the PROM is complemented.
3) Data-out switch (Enable-Disable). If this switch is in the enable position, data may be read
from the PROM. In the disable position, the output line may float up to a high level
(logic "1"). As a result, the input ports on the prototype system may be used for other
functions without removing the MP7-03 card.
MP7 -03 Programmer Board Specifications
Features:
eHigh speed programming of Int~I's
1702A (three minutes)
elnputs and outputs TTL
compatible
e Board sold complete with trans
formers, capacitor and connector
eDirectly interfaces with SIM8.;.01
Board
Dimensions:
8.4 inches high
9.5 inches deep
Power Requirement:
Vee = +5 @ 0.8 amps
TTL GRD = OV
*Voo = -9V @ 0.1 amps
Vp = 50Vrms @ 1 amp
Connector:
a. Solder lug type/ Amphenol
72 pin connector
PIN 225-23621-101
b. Wire wrap type - Amphenol
72 pin connector
PIN 261-15636
*This board may be used with a -10V
supply because a pair of diodes (i.e. 1 N9l4
or equivalent) are located on the board in
series with the supply. Select the appropriate
pin for either -9V or -10V operation.
A micro computer bulletin which describes the modification of the MP7·02 for programming the
1602A/1702A is available on request. These modifications include complete failsafe circuitry (now
on MP7·03) to protect the PROMs and the 50V power supply.
39


## Scan page 44

c. Programming System Interconnection
+5 GND -9V
I
84 1,3
86
INTERR
~
Jl-53
Jl-50
- ~ Jl-29
[
J2-36
+5-
~
J1-84
READ Y '-- Jl-3O
-* [
J2-44
J2-27
""'- J2-8
J2-18
TAPE
READER
CONTRO [
SIMS-01
L
. TTY
PRINTE
R~
TTY
KEYBOARD
OR TAPE READE
NOTES:
E
Rill
:
phenol
J2-28
J1-86
J2-40
Jl-l
Jl·11
J2-83
J2-37
J2-59
1. SIMS-02 Connector
Wire ~ type/Am
88 pin connector PIN 261-10043·2_
2. MP7'()2 Connector s:
a. Solder lug type I Amp!lenol
n pin connector PIN 225-23621-101.
b. Wire wnp type/Amphenollstwwn above)
72 pin connector PIN 261-15636-2.
I
2,4 OUTPUT
J2·61
OArp PORTrp
J2-67 0A1
J2·54 OA2
J2-51 OA3
J2-53 OA4
J2-49 OAS
-
J2-50 OA6
J2-47 OA7
OUTPUT
J2-75 0841 PORT 1
J2-60 OBl
J2-78 082
J2·60 OB3
J2-65 084
J2-57 085
J2-62 OB6
J2-55 OB7
INPUT
Jl-6
1841 PORT 1
Jl-13 IB1
Jl-16 182
Jl-21 IB3
Jl-26 184
Jl-31 IB5
Jl-34 186
J1-39 187
J2-43 001
J2·39
0 02 4_7K ~ .
1
1/4W ~
3. If the u. of lite 24 pin socket on the MP7-03 is not desired, the
pin connections for external socket ... as follows:
EXTERNAL SOCKET PROGRAMMING
MP7'()3
FUNCTION PIN FUNCTION
A. "OUT" DEVICE UNDER TEST 56 Os
A, 58 0,
~ 60 07
Aa 62 D.
A.t 64 CHIP SELECT OUT
As 66 PROGRAM OUT
At 68 Vee OUT
A, 70 VQGOUT
0, "OUT" DEVICE UNDER TEST 71 "n OUT
O2 69 VooOUT
0 3 67 .1,.2 OUT
D. 65
1
.
• ~
MP7'()3
~
63
61
59
57
72
22
2,4
26
24
30
2
1 1
13, 15 19,21 20 ENABLE +5
A.
47 33 OAT A OUT
A,
45 DISABLE~
A2 43 ":"
A3 +5
41
.. ~ 4.7 A. 66 :,. YaW
Ali
53 31
K
A.
51
A7
49 3
0, 23 NoRMAL +5
...
02 37 25
0 3 27 COMPLEME~
D.
DATA IN
29 COMPo 0---:.-011
DATA OUT
48
D.
50
0 7 52
D. 54
0, 32
1D2
T :03
34
36
T , '0"
38
; : : :05
T I : : :0,
40
T , , I , 'D 42
i: : : : : :0,
44
46
r:: : :: ::~ 8 . ,
35 -
MP7'()3
":"
NORMAL
a; ::::::J
9
11
10,12
17
14
2-P-8180 ST ANCOR
n
2L~·~1"
,""YRMS. II 1.0A
1: T2
8110
ANCOR --.-J;",d ::-
75·100VDC
I I I I I I I', 16 6
1+5V I I I I I IRIWA I+5V +5V
IIIII
11111
I I I I L
11II
III "-
II L_
II
IL_
I L __
SN 7407 N
In)
UIII
rot
LED
MV·1OB
MONSANTO
"'''''1'
220n
YaW
The complete interconnection bet-.m the SIM8-01 and the MP7'()3
is provided by the MCB8-'0 system interface and control module.
See the MCB8·10 description.
% AMPS
$LO ILO
Figure 16. MP7-03/Sim8-01 PROM Programming System
40


## Scan page 45

P I.C.12 I
111111111111111111111111111111111111
:1 :9 :7 :5 ~3 :1 ~ :7·:5 :3 :1 ~9 ~7 : :3 :1 : :7 :5 : :1 : :7 : :3 :1 ~9 ~7 ~5 ~3 :1 : : : : ~ I ~I
Solder Connector PfN 225·23621·101
Wir_ap Connector PIN 261·15636·2
Wir ...... ap Connector PIN VPB01E36EOOAl 72 70 68 66 64 62 60 58 56 54 52 50 48 46 44 42 40 38 J6 34 32 30 28 26 24 22 20 18 16 14 12 10 8 6 4 2 CDC
!oIdor Connector PfN 225-23621·101
w_apConnec_ PIN 261·15636·2
Figure 17a. Component Side of MP7-Q3 Card
nllnlllllllllllllllllllllllllllill
1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 J6 !
Amphonol
2 4 6 8 10 12 14 16 18 20 22· 24 26 28 30 32 34 36 38 40 42 44 46 48 50 52 54 56 58 60 62 64 66 68 70 72
w_ap Connector PfN VPBOI.E36EOOA 1 1 3 5 7 9 11 13 15 17 19 21 23 25 27 29 31 33 35 37 39 41 43 46 47 49 51 53 55 57 59 61 63 65 67 69 71 CDC
Figure 17b. Pin Definition - Reverse Side of MP7-Q3 Card
41


## Scan page 46

POWER SUPPLY REGULATOR
I
FILTER CAP
1N4002
-9 ~~ ____ ~C~R~7 __________________________ ~ ____ -1
PROGRAM PULSE TIMING
+5
+5 1-........ -.--.--.-----+5
6
SN7405
IC 11
+5
42
~ ____ ~ ________________ ~PR~G~M~ ____ -,~U
eR12
1N4002
+5
R52
4.7K
SN7405
IC 11
13
R53
4.7K
Voo
+BOV
SN7405 -=
Ie 11
9
NOTES: Unless otherwise specified-
1. RESISTORS ARE RATED IN n. %W. 10%.
SN7405
Ie 11
2. TRANSISTORS ARE SE6021. or 2N3658 or 2N3722.
3. PIN NUMBERS ARE SPECIFIED FOR AMPHENOL
WIRE WRAP CONNECTORS.
+5
R23
470
L.~.~.~~
\
LJ
R16
4.7K
3.0ms


## Scan page 47

DATA OUT
ENABLE
~~~R~~ ~~--r----------+--r---------~
i
DATA DRIVER
R47
6.8K
DATA 1
PIN4
D.U.T.
DATA 2
PIN 5
D.U.T.
DATA 3
PIN6
D.U.T.
DATA 4
PIN 7
D.U.T.
DATA 5
PIN8
D.U.T.
DATA 6
PIN9
D.U.T.
DATA 7
PIN 10
D.U.T.
DATA 8
PIN 11
D.U.T.
A2
A1
AD
DATA OUT 1
2
6
DATA OUT 8
Vee
Vccs OUT
3
I
ADDRESS DRIVER
4 (LSB)
24
23
22
21
20
19
R28
6.8K
Voo
<1>,
<1>2
A3
A4
AS
18 AS
17 A7
10
11 (MSB)
12
16
15.
14
13
DEVICE TO BE PROGRAMMED
NOTE:
THIS SCHEMATIC
IS INCLUDED FOR
REFERENCE ONLY.
VGG
Vss
CS
PROGRAM
Figure 18. MP7·03 PROM Programmer Board Schematic
43


## Scan page 48

IX. MICROCOMPUTER PROGRAM DEVELOPMENT
A. MCS-8 Software Library
1.0 PL/M™ COMPI LER - A High Level Systems Language
It's easy to program the MCS-8 Microcomputer using PL/M, a new high level language concept developed to meet
the special needs of microcomputer systems programming. Programmers can now utilize a true high level language
to efficiently program microcomputers. PL/M is an assembly language replacement that can fully command the
800B CPU and future processors to produce efficient run-time object code. PL/M was designed to provide addi
tional developmental software support for the MCS-8 microcomputer system, permitting the programmer to con
centrate more on his problem and less on the actual task of programming than is possible with assembly language.
Programming time and costs are drastically reduced, and training, documentation and program maintenance are
simplified. User application programs and standardsystems programs may be transferred to future computer sys
tems that support PL/M with little or no reprogramming. These are advantages of high-level language program
ming that have been proven in the large computer field and are now available to the microcomputer user.
PL/M is derived from IBM's PL/I, a very extensive and sophis
ticated language which promises to become the most widely
known and used language in the near future. PL/M is de
signed with emphasis on those features that accurately reflect
the nature of systems programming requirements for the
MCS-8 microcomputer system.
/- SA~PLE PROGP.Ul
lOCATE 'lL PRI"[' "u~tJ['lS V£T"ErN 1 AND 50.
PUT i\lSULTS !~; Tf(UTH T.\U~( AS rOLLOnS:
PRIME(I) = THuE Ir I IS A PRlflE 0'
C[CLARE 1'";"[(5;~) GYTe;
!"!ECLl.Pf' (1, 1<:) nVTE;
O[CL·'\Q[ ii::UE LI'ER4LLV '1', FALSE LITEfH.LLY 'e',
PRIKE(1) • TRUE, ,. 1 IS A PRIME 0'
DO I = 2 TO 51"
PRI"f.( I) = r~LSEI /. 1~ITIALIlE T'DlE TO FALSE 0'
K = 2,
00 WHILE I "Q~ " () ~; '0 LOOP Ut;TIL TEST rOR PRIME rAilS 0'
K = K • 1;
END:
J r K = I T~j['1-.j
00; I- F"Ot:':D /.. PR 1I1E 01
PRP,«(I) = HUE;
rtf)'
EN~ I
(or I" END or r-ROGRMI 0'
PLIM Coding
Program Development Time: 15 minutes
PL/M vsASSEMBL Y LANGUAGE
As an example of comparative programming effort between PL/M and assem
bly language, this program to computer prime numbers was written twice,
first in PLIM, and then in assembly language. The PL/M version wa~written
in fifteen minutes, compiled correctly on the second try (an "end" was
omitted the first time) and ran correctly the first time. The program was
then coded in Intel MCS-8 assembly language. Coding took four hours,
program entry and editing another two hours, debug took an hour to find
incorrect register designation, the kind of problem completely eliminated by
coding in PL/M. Results of this one short test shows a 28 to 1 reduction in
coding time. This ratio may be somewhat high, overall ratio in a mix of pro
grams is more on the order of 10 to 1.
PL/M Is An Efficient language
Tests on sample programs indicate that a PL/M program can
be written in less than 10% of the time it takes to write the
same program in assembly language with little efficiency
loss. The main reason for this savings in time is the fact
that PL/M allows' the programmer to define his problem in
terms natural to him, not in the computer's terms. Consider
the following sample program which selects the ,largest of
two numbers. In PL/M, the programmer might write:
If A > B, then C = A; else C = B;
Hesa MACRO ASSc.t~;Lun PAGE 1
t000
, /- SA1"1PL( f'ROGR",~
I LOCATE ALL r"1~E :'IiUf1f1£kS S(i~:f.["~ 1 AND ::;r..
I poT Rt.SULT~ !tJ lQUTr-I HEILE .6$ fCLLOWSt
I PRlt;« I) = iHU( If I IS A PRI"'l£.. ./
• EOU I DEnNE r.EGIST[RS
8 EUU
C EOU
o l'Jll
[ [OU
H [OU
~ [au
H [au
I
Sf A~TI
\ PRP1[(1) = 'HIVE; '* 1 lS l PRt~E -,
('lV-OS ~601 K~ t •• 1
00e2 36l:r2E~" LX 1 H, PR lW:E
0~96 66 .DO ~
eW07 (8 MOV A.8
Vpe8 (5 MQV H. A
fil'e9 ~Cl.~;': i.e J il
IH1P1f1 r 1 MOV V. L
e:~ec [8 HOV A,M
0000 3[01 HV I H.l
J 00 I := 2 T Q 5:'\;
cor.r 36'2'~~~~ LX I H.I
r013 3(:'!2 ~v 1 H.2
~015
~015 1ll637.
rG113{·1.2?[U'
0018 sr
€l"<lC 6"6E~r
LOOPij;
~\I J A,53
LX I Hoi
CYIP H
JC DONE
J F'Rl".(( 11 ':0 r"'I..~E.1 I" I:~!'T'ULll£ TABLE 10 rALSE -I
e.;nf 3b6-?C:'[] LX I H,PH!"(
PI~23 86 ADO L
0142" ':6 HOV .',9
~325 C5 "OV M.A
""A26 CCC~ AC I "
f.02/:i ~1 1':0\1 P.l.
""29 (8 MDV ... ,M
IHi2A 3U'>0 P':'VI M,III
GA2e :.'i6,\ :'\2E~O
0.30 J(n
t:~32 ~oA?2Ei'~
e:~36 C7
t< II 2.
LXI "d(
~'V I H. 2
; 00 WHILE I I~OO K <) ", Ie LOOr UNTIL T(ST rOR PRH1E. r41LS _I
Lo~r 11
LXI t~. 1
HOV H.,
HeS8 r~AeRO "SS(HEiL[R:
on31 36A32[ea
PLG(
~X I
2
H,K
er,30 CF'
ret .~c
er·3C 91
~~P3i) < ~:3 C""
004;1 Bl
0041 3C!1:J
ed~3 684!:JC1
e1'l46 CF'
e9<7 J£
00-46 1='9
MOV ».8
lOOP2'
SuB 9
J'.C lOOP2
ADD B
CP,! 0
J;! ~OO?3
K ; K • 1:
~:O\' t1. B
INR a
HO~ B, H
I [tJ0'
JHP L.OOPl
LOOP31
; IF j( :r: 1 TH(t~
J 00; ,- rOUNO to PfilM( -,
004C 360432£00 LX I H, K
t!I~5;' C7 MOV /1, A
Efl51 31 OCR L.
e:~52 '3F CfoiP H
"~'..13 406400 JI\i! LOOf'4
0r56 C7
~"~:"7 :!!.c.rtn:~:}
0:"5A ft6
~j::'C c~
C~5:J t:~
~J~1: r,C~0
'!tl6~ r 1.
0361 lO
e062 :iC~l
PCffH( (I) :: TRUE;
MOV P1.A
LX 1 Iof, PP, :~,t:
AnD L
fo'!OV A..a
I'IIJV H/A
.C I 0
HOV 9. L
t10V A,H
Mvt H,l
, [NDI
kH'I~4 :"OOP41
G~54 ~&!. :'!2£uQl
0006 r:F
1Il0"r,I 1,0
0"6A r9
I [NOI
~, I
HOV
It~ R
HOY
1lI06!) "''H5J:J JHP L.OOf' 0
(~:J t.t: ('10 I~E I ,
I (or I. t: ;.v or PROG iiI. ~1 .1
~e6( I).~ H~ T
I
, DECLt~l£ j.:RP1(5'·) Dyrt I
J OlCL"~~( (J,j~) uYTr.;
, O::C~J..;,':: j;:\,;£ LITUl:'I.LY '1', r.t.5E t.1T£RAI..L.Y tiP'
I
p~ i~' E ~ os
Jl os
KI DS
£r~o
51
1
1
Assembly Coding
Program Development Time: 7 hours
Meaning: "If variable A is greater than variable B, then assign A to variable C; otherwise, assign B to C."
44


## Scan page 49

A corresponding program in assembly language is twelve separate machine instructions, and conveys little of
original intent of the program. "
Because of the ease and conciseness with which programs can be written and the error free translation into
machine language achieved by the compiler, the time to program a given system is reduced substantially over
assembly language.
Debug and checkout time of a PL/M program is also much less than that of an assembly language program, partly
because of the inherent clarity of PL/M, but also because writing a program in PL/M encourages good program
ming techniques. Furthermore, the structure of the PL/M language enables the PL/M compiler to detect error
. conditions that would 'Slip by an assembler. The PL/M compiler is written in ANSI FORTRAN IV and thus will
execute on most large· scale machines with little alteration.
2.0 MCS-8 CROSS ASSEMBLER SOFTWARE PACKAGE
The MCS-8 cross assembler translates a symbolic representation of the instructions and data into a form which
can be loaded and executed by the MCS-8. By cross assembler, we mean an assembler executing on a machine
other than the MCS-8, which generates code for the MCS-8. Initial development time can be significantly re
duced by taking advantage of a large scale computer's processing, editing and high speed peripheral capability.
Programs are written in the assembly language using mnemonic symbols both for 800B instruction and for special
assembler operations. Symbolic addresses can be used in the source program; however, the assembled program
will use absolute address. (See Appendix II.)
The Assembler is designed to operate from a time shared terminal. The assembled program may be punched
out at the terminal in BNPF format.
The Assembler is written in FORTRAN IV and is designed to run on a PDP-10. Modifications to the program
may be required for machines other than PDP-1 O.
3.0 MCS-8 SIMULATOR SOFTWARl: PACKAGE
The MCS-8 Simulator is a computer program written in FORTRAN IV language and called INTERP/8. This
program provides a software simulation of the Intel 800B CPU, along with execution monitoring commands to
aid program development for the MCS-8.
INTE RP/8 accepts machine code produced by the 800B Assembler, along with execution' commands from a
time sharing terminal, card reader, or disk file. The execution commands allow manipulation of the simulated
MCS-8 memory and the 800B CPU registers. In addition, operand and instruction breakpoints may be set to
stop execution at crucial points in the program. Tracing features are also available which allow the CPU opera
tion to be monitored. INTERP/8 also accepts symbol tables from either the PL/M compiler or MCS-8 cross
assembler to allow debugging, tracing and braking, and displaying of program using symbolic names.
The PL/M compiler, MCS-8 assembler, and MCS-8 simulator software packages may be procured from Intel on
magnetic tape. Alternatively, designers may contact several nation-wide computer time sharing services for access'
to the programs.
4.0 BOOTSTRAP LOADER FOR SIM8-01
When developing MCS-8 software using the SI M8-01, programs may be loaded, stored, and executed directly from
RAM memory. A set of three 1702A control PROMs (1702A/860 set) is required for this function. In addition,
this same control PROM set is requlrt:id when the SIM8-01 is used as the controller for PROM programming.
(See Appendix V.)
5.0 SIM8 HARDWARE ASSEMBLER
The SI M8 Hardware Assembler is a program which translates a symbolic assembly language into an octal repre
sentation of the SIM8 machine language. An auxilliary program then translates the octal object code into the
"BNPF" format suitable for bootstrap loading or PROM programming. Eight PROMs and three tapes (1702A/
840 set)[1] containing the assembly program plug into the SI M8-01 prototyping board permitting assembly of
all MCS-8 software when used with an ASR 33 teletype.
The assembler accepts the sou rce text from the paper tape reader on the fi rst of two passes and constructs a
name table. On a second pass the assembler translates the source using the previously determined name values,
creates an octal object paper tape, and if directed, writes the object code into Read/Write memory.
The assembler's commands allow for TTY keyboard manipulation of R/W memory and execution of stored pro
grams so that program debugging may be undertaken directly after assembly. If a "BNPF" tape is desired, an
auxilliary "tape generator" program may be loaded and executed by the assembler. (See Appendix I.)
46


## Scan page 50

6.0 PROGRAM LIBRARY
These program listings are available to all Intel microcomputer users. We encourage all users to submit all non-proprietary
programs to Intel to add to the program library so that we may make them available to other users.
* MCS-8 bootstrap loader and control program and PROM programming
systems routine for the SIM8-01 and SIM8-01/MP7-03 PROM pro
gramming system (A0860, A0861, A0863) [1] .
• Floating point multiply routine for the MCS-8.
* Fixed point multiply routine for the MCS-8.
• Fast Fourier transform program for the MCS..a using the algorithm by
G.D. Berglund (see IEEE Transactions on Computers, April, 1972).
• Debug Program
• Binary Search Routine
• Interrupt Service Routine
• Analog to digital controller - MCS-8.
• MCS-8 driving an incremental X-V plotter such as those manufactured
by CALCOMP.
• Three dimensional blackboard stroke generator using MCS-8.
• MCS-8 program for saving CPU states on an interrupt.
• MCS-8 program for controlling the timing for a serial input
from a teletype.
• Fast Fourier transform program for the MCS-8.
• MCS-8 Assembler for use on HP 2100
* MCS-8 teletype and tape reader control program (A0800) [1 ] .
* MCS-8 memory chip select decode and output test program
for the SIM8-01 card (A0801) [1].
* MCS-8 RAM test program for the SIM8-01 card (A0802) [1].
* Single precision multiply/divide.
* Program written by Intel.. Program submitted by customers.
Note 1. These are the program numbers that should be used when ordering the programs in PROMs.
B. Development of a Microcomputer System
The flowchart shows the ~teps required
for the development of a microcomputer
system. The SIM8-01 system can be used
throughout the complete cycle for pro
gram assembly, PROM programming, and
prototype system hardware. Ultimately,
custom systems using 1702A PROMs may
be delivered. For high volume applications
(100 or more identical systems) lower
cost metal masked ROMs may be used.
To combine the advantages of the metal
masked ROM and the PROMs, subroutines
may be stored in metal masked ROMs
and a customized main program may be
stored in PROM.
Build Pre-production
Systems Using
1702A PROMs
46
Order Metal
Masked ROMs
for High Volume
Production
Customize
Individual Systems
Using I
1702A PROMs


## Scan page 51

C. Execution of Programs from RAM on SIMS-01 Using Memory Loader Control Programs
The previous section provided a description of the preparation of tapes and the programming of PROMs for permanently
storing the microcomputer programs. During the system development, programs may be loaded, stored, and executed direct
ly from RAM memory. This section explains these additional features.
ROM MEMORY
I I I
:- 1 2 3 4 5 6 7 SlM8-01 MEMORY ORGANIZATION
~ ~~DDDDD
ROMe' .OW-255
ROM 1 256-511
A0860} I ROM 2 512-767
A0861 CONTROL
----i BANK .: 0 ODD DODO ROM 3 768-1023
PROGRAM ROM4 1024-1279 A0863
BANK 1 0.0 0 0 0 0 0 0
ROM5 1280-1535
RAM ROM6 1536-1791
MEMORY
BANK 2 0 0 0 0 0 0 0 0
ROM 7 1792-2047
RAM BANK kl' 2048-2303
c-BANK 3 0 0 0 0 0 0 0 0
~ J
I
RAM BANK 1 2304-2559
TTY RAM BANK 2 2560-2815
"II1II
""
ASR33
RAM BANK 3 2816-3071
SIM8·01
Figure 19. MCS-8 Operating System
The system has three basic parts:
1. The microcomputer(SI MS-01)
2. The bootstrap memory loader control prowam (AOS60, AOS61, AOS63)
3. ASR 33 (Automatic Send Receive) Teletype
The control program provides the complete capability for executing programs from RAM. Two additional program commands
are required; "C", the CONTINUE command for loading more than one bank of memory, and liE", the program EXECU
TION command.
Operating The Microcomputer System
To use the SIMS-01 as the microcomputer controller for the bootstrap loadi~g of a program from the DY into RAM memory
and the execution of programs stored in RAM, the following steps must be followed:
1. Place control ROMs in SIMS-01
2. Turn on system power
3. Turn on TTY to "line" position
4. Reset systeritwith an INTERRUPT (lnstr. RST =00 000101
5. Change instruction at interrupt port to a NO OP
6. Start system with an INTER RUPT (lnstr. NO OP = 11 000000)
7. Load data from TTY into microcomputer RAM memory
S. Execute the program stored in RAM
Loading of Multiple RAM Banks
Through the use of the command "C",
(CONTINUE) subsequent RAM banks may
be loaded with data without entering a new
data entry command and new memory bank
and address designations.
Note that the CONTINUE command should
only be used when the subsequent RAM will
be completely loaded with 256 bytes of data.
For partial loading of RAM banks, always
use the DATA ENTRY command. The con
tent of a RAM bank may be edited by using
the DATA ENTRY command and revising
TYPED BY SYSTEM
Ready for command --~ ..
Request for RAM BAN K =
Request for Address Field
within RAM BANK
Ready for new command
Ready for new command
47
xxx
255
I
TYPED BY USER
DATA ENTRY command
RAM BANK = in which data will be stored. Enter
bank number (.rr.1,2,3). Eilch bank stores 256 bytes.
Initial Address
Final Address = 255
j
Start tape reader and load data into RAM memory.
Data entry must be in specified format. All format
checking is done at this time. If data is entered from
the keyboard, depress the RETURN key after manually
entering each complete word.
CONTINUE command
1-- Start tape and continue loading data into
J RAM memory. Data is loaded into the next RAM
BANK (n + 1) beginnin'g with address 000 and
ending at address 255.


## Scan page 52

and re-entering sections of the bank. When a program is being stored in memory, the first instruction of the program should
be located at address Gte in a RAM bank. The entire RAM memory with the exception of the last fifteen bytes of RAM
bank 3 may be used for program storage in conjunction with the bootstrap loader.
Program Execution
The program which has been loaded into RAM may be executed directly from RAM.
TYPED BY SYSTEM TYPED BY USER
Ready for command .. *E ~ Program EXECUTION command
Request for RAM BANK # ~ Bn 04 RAM BANK in which the program has been stored.
The first instruction in a program must be at address
dJ1I1 in a RAM bank.
}-
Program beginning at address.0W of RAM BAN K # n
will be executed by the MCS·8 system.
To return to the bootstrap control program, the
ending statement of the program being executed
Ready for command ~ * should be ''.IMP 462"
CAUTION: When executing a program from a single RAM bank or multiple RAM banks, care must be taken
to insure that all JUMP addresses and subroutine CA LL addresses are appropriately assigned
within the memory storage being used.
Summary of System Commands
Using Intel's special control ROMs (A0860, A0861, A0863) the following control commands are available:
COMMAND EXPLANATION
T DATA ENTRY - Enter data from TTY into a RAM bank
C CONTINUE - Continue entering 256 byte blocks of data into subsequent
RAM banks
R RE-ENTER - Re-enter a data word where a format error has occurred and
continue entering data
E EXECUTE - Execute the program stored in RAM memory
P PROGRAM - Program a PROM using data stored in RAM memory
L LIST - List the content of the PROM on the TTY
The.complete Bootstrap Loader Program is presented in Appendix V.
48


## Scan page 53

x. MC8S-10 MICRO COMPUTER INTERCONNECT AND CONTROL MODULE
The MCB8-10 is a completely assembled interconnect, display and control switch assembly which elim
inates all hand wiring associated with an MP7-03/SIM8-01 setup. With the additions noted below, it
becomes a self-contained system featuring the following:
1. General Purpose Micro Processor with I/O and Display (with SIM8-01, power supplies)
2. Automatic PROM Programming (with SIM8-01, PROM set A0860, A0861, A0863, MP7-03, power
supplies, TTY) .
3. Test System for checkout of programs, features single-step capability (with SIM8-01, power supplies)
The MCB8-10 shown in Figure 20 includes the following:
1. All interconnect circuitry necessary to implement the programming system described in Section VIII
of the MCS-8 Users Manual.
2. ·Connectors for the SIM8-01 and MP7-03 boards.
3. A zero insertion force 24-pin socket for PROMs to be programmed. Appropriate connections to the
MP7-03 connector are provided.
4. Teletype, keyboard, printer, tape punch and reader control connections to SIM8-01. Access to these
signals is provided by a 16-pin socket (TTY-J8). Aflat cable is provided for the connection.
5.Control switches (2) and logic necessary for true-complement of programmer input or output data.
6. Breakout of all computer signals to open sockets for easy access. This includes output ports, flags
(carry, sign, parity, zero), I/O decode (select I/O port 0,1,2,3), I/O selection, cycle control, two
decoded states (stop and wait), lower and higher order address.
7.60 bits of LED display from SIM8-01.
8. All control lines are "OR-tied" to MCB8-10 or its connectors for external control.
9. Two toggle switches are provided for the following operations:
a. For A0860 program (Bootstrap Loader and PROM programmer control ROMs), set the switches
as shown in the figure above.
b. For A0840 program (SIM8 Hardware Assembler) set S16* to "INTERRUPT" and S15* to IITTY".
c. For operation not using teletype as an I/O device, set S16 to IIINTERRUPT" and S15 to "IN-AO".
1 O. Two memontary pushbutton switches are used for interrupt and single step function.
11. 8 toggle switches are provided for interrupt instruction input.
12. A toggle switch is provided for JlWAIT" control.
13. Two transformers, 115V AC/220V AC, capacitor, fuse holder and AC input jack wired to develop
the unregulated 80V DC which in turn is regulated on MP7-03 to 47V DC programming voltage.
14. A control switch for disabling the programming voltage.
15. Input jacks for applying externally supplied +5V DC and -9V DC to the assembly. (Note: internal
supplies are not included).
*See figure 24.
The setup for the PROM programming application is shown in Figure 21. The MP7-03 (rear) and the
SI M8-01 boards are installed in the MCB8-10.
49


## Scan page 54

Figure 20. MC8S-10
Figure 21. MC8S-10/MP7-03/SIMS-01 System
A. Micro Processor System
When the MCB8-10 is used as a microprocessor, its features, such as the display (for the output ports,
I/O decode, flag flip flops, cycle control, step and wait state, and in and out control and input ports),
may be uti lized at the discretion of the user. As an example, consider the testing of the SI M8-01 boards
loaded with a PROM containing the following program: Read Port A and Port B, add the two values and
output the results at Port A. The test could be implemented by connecting 8 switches to the A and B
input sockets. The actual switch circuit would consist of a single pole double throw switch wired with
one pole to ground and the wiper wired to the appropriate socket connector pin in accordance with the
MeB8-10 schematic. The SI M8-01 is then inserted into the "SI M8-01" connector and a bench supply
connected to the +5V DC and the -9V DC input jacks. The actual test may now be performed. The
system is started according to the user's instructions and the program is executed. The result appears
at the LED display and may be verified for correctness. The display lights of interest are identified on
the system's printed circuit board (Figure 22) as "OUTPUT PORTS" 0, 1, 2, 3 (Bits 0-7).
'RfWOR!< A
• • -9V -lIN£ ~K£T
LQ~
GHD GHD +5V
• •
•
• " 115V/220V
••••••••••••
71
•
JI~
•• •
••• FI
I/l-
S.B.
JI~
•
•
Figure 22. MC8S-10 Printed Circuit Board
50
•
•


## Scan page 55

B. Programm ing System
Consider the actual programming (in the hardware sel)se) of the 17Q2A PROM in the example above. The system can
perform this function with the addition of an MP7-Q3 board inserted into the MP7-Q3 connector. An automatic pro
gramming system which allows data entry from a keyboard or paper tape, automatic verification, listing of ROM contents,
and hands-off programming is provided by the further addition of three preprogrammed PROMs (AQS6Q, AQS61, AQS63)
and a modified teletype. The teletype modification consists of the addition of simple relay network described by the
MCS-S Users Manual. The procedure for programming a PROM, then, is as follows:
1. Insert MP7-Q3 and SIMS-Ql boards (SIMS~Ql loaded with PROMs AQS6Q, AQS61, AQS63).
2. Connect teletype to "TTY" socket.
3. Connect +5V DC, -9V DC and 115/22QV AC. Verify 115/22Q switch is in proper position.
4. Insert instruction "0.0.0.0.0.10.1" with the S toggle switches provided for interrupt instruction input .(i.e., RESTART
to location 0.).
Depress "INTERRUPT"
Insert instruction "110.0.0.0.0.0." (Le., NOP) with the same S toggle switches
Depress "INTERRUPT"
5. Set PROG.AC" to "ON"
6. Set data enable switch to "ENABLE".
7. Set the data "IN/OUT" switches to "TRUE" or "COMPLEMENT"
8. Place teletype in "ON-LINE" mode
9. Insert PROM
10.. Use AQS6Q program directives as described in Section IX of this Users Manual.
C. Program Debugging
Program debugging may be performed by using the "SI NGLE-STEP" switch and LED display provided.
The procedure is as follows: .
1. For executing program in ROM (or ROMs):
a. Turn off system power.
b. Set toggle switch to "WAIT".
c. Insert programmed ROM (or ROMs).
d. Turn on system power.
e. Set interrupt instruction input (using the 8 toggle switches provided) with an RST 0 (00000101)
instruction.
f. Depress III NTE R RUPT" switch.
g. Depress "SI NG LE-STEP" switch. This causes the CPU to execute the RST 0 instruction.
h. Continue to depress IISI NGLE-STEP" switch to advance the program one location at a time (a
three-byte instruction requires three depressions of the IISINGLE-STEP" switch).
2. For executing program in RAM:
a. Load program in RAM using A0860, A0861 , A0863 program.
b. Set toggle switch to "WAIT".
c. Set interrupt instruction input (using the 8 toggle switches provided) with a JMP instruction to
select the desired RAM bank where the program has been loaded in step a. Ehter the three byte
JMP instruction as follows:
Load 1 st byte (01000100).
Depress "INTER RUPT" switch.
Depress "SI NGLE STEP" switch.
Load 2nd byte.
Depress "SI NG LE-STEP" switch.
Load 3rd byte.
Depress IISI NG LE-STEP" switch.
Set the 2nd and 3rd bytes according to the following examples:
For BANK 0-
00000000 (2nd byte)
00001000 (3rd byte)
For BANK 1 -
00000000 (2nd byte)
00001001 (3rd byte)
For BANK 2-
00000000 (2nd byte)
00001010 (3rd byte)
51


## Scan page 56

JI
r'B
I i
I§]
I I
zEJ
I I
38 [>I.TA..
F2otJ\ Y~\oA02.Y .zz
~8
! !
.58
! :
.. ~
! t
"'''1''18
1t-l"T'EIi!2UPT \""-1 I
CIIoT .... ... £,0 ..... "T'T'T'
Ta .... ~MtTTII:It 1!IIJII1IIWE: .
: 1
lB
I I
.@
I I
!EJ
Db.1A. Il.JPu,
: ! POti:T tJ
4~
5"8
l f
<-8
I I
l~
JI
J"
EJ
I ,
~
@
I '
8
I '
~
0
I I
a
I I
Gj
JIO
~IS o--~
r~- ... '; I I
I I
I I , I
0 I I
~
GJ
I I
~
~
bj
I I
.. 5 ~
JII
52
QUTPU"T POIZ. T "
JI
"Ii
tJ~ q
I~ ~
2~ ~
iU.W\ 3~ ~
p ... .,. ... I .....
4~ ~
I '
~ s~
I I
GJ .. ~
I ' I I
,~ ~
)..lOT"C1a~ ..,)oi'-C:'!I~ aT\04~ltWI'>J:. ,.PC,CIf"\I:,O,
"-L.J.- 2&"I~ToliL .",.............c.~ ... E.C 4~ ~ 1/."". IQro.
2. ....~ .... L.. .. OJ, .... Il.C PA.&T ,...e. Q.c. ~~L-~O, £K.D.
~ J4 TO ..rl' ... e.a: ........ -r C!..Ar.~ ~QG.iICJ£.'T.
B:> Col) TI, TI, '2.2.0'1 ~T .... 1e,E. k\Ou ...... TC.P 0"'"' c:..1-\"'~1~


## Scan page 57

,II ,I4
5Ta..'TC O:::UIoolTC£. 451--_----,-1-----4
;;;:Tcil5
~ :
S~~ __ ~~~-------~
T~ I I
, I
"'J>.T£ """" ...... B~--------~
Ti r:
ft~'TE ~"'IZ §] ___ -------~
T2 : 1
mTE _~ .. n""TC2 r:;;I-----------~
T.5 R , ,
511o:TI:. "::::::WTCIZ..§]~--':"'----_~
. T,I I I
, ,
5~T" ~IJWC~~-----_~
~8 6J : l ! :
"~ tq
2~ ~
sr§ ~
!!AU CWIP 'SIE .. cT " I ,
I/o IXCOOE OUT
4 0 0
I I I I
5@ ~
~~ ~
1~ ~
~~ ~
I I
I ~-----------~~
2§] ~
sl;j ~,'31,
1 I
4 8 ~
5~ ~
I I I I
0~ ~
1~ W I , . ,
t;o 1 1--_---1-----4
I I I I
~+~ L£D I~ ~
I I h,'_,' ~~ ~
~~------------~~
¢1@] 0
..1'1 I I
IIJTEIi2uP"T c.yc.1..C IIooIOICATOI2. ~~-----~B
FU..lSI ,:'L.IP FLOP_ '!oIGooto.l 3 1-_----1----1
J2 sa
F20M '''1'''1' 1'eAJJ~IT1"E2. r;9l~-----'--~f4l
TT ..... ~FFE«. A R
F2C)M TT'J' ~1T1'£1l. .r;:p I-;-l
Ti.,.. \!tuFI=~e A R
l7o.P£ ..... "" ... ",,"~eoc =T~ ~
..... "'" 2E...,.,e ==""'- ~ ~.'
(-qy DC.) JI Ii
~f---------l~
-------------lb]
I------------~
.
I I 4~o LED '2.
~~~w.~;'o:.~ @]f--+~-IZ.-.. -z-------
.r/~1'
SYl-Jc' OUT ~I--_________ """
I •
'h ",-O<..IC 152l ___ -----------
(io.LiEe.IJA'TCa.oc..tcn
C,,-.,::,,~~,,)GJ---------""
53
33
E/O l!.fI IZ /70 ".
P'20...., TO 1!!IQ
Peo&rz... ..
eaA.OY' ....
Figure 23. Me8S-10 Schematic (No. 00026) -


## Scan page 58

For BANK 3 ~
00000000 (2nd byte)
00001011 (3rd byte)
The above procedure causes the CPU to execute the JMP instruction that has been jammed in.
d. Continue to depress IISINGLE-STEP" switch to advance the program one location at a time.
D. Procedural Precautions
1. CAUTION: Do not remove DC power while programming AC power is on. Permanent damage to
MP7-03 and PROM may result.
2. The MP7-03 board should be removed when SIMB-01 is not programmed to drive it.
3. Power up and power down for the programming system should be performed-as follows:
a. +5 V DC and -9V DC on
b. Restart procedure:
-Restart instruction 00000 101
-Interrupt
- Restart instruction 11 000 000
-Interrupt
c. TTY on
d. Programming AC on
e. Insert PROM
f. Execute
g. Remove PROM
h. Programming AC off
i. TTY off
j. +5V DC and -9V DC off
(S)
~ 10 1
J>
I"
• -~ ~~ ~ ~
J'~ J4 J'
~---------------------~
0000
,{p
Ii~ .c.- .' _6
T' <1
0
&"1. + -
0 aE 0 0
~ &'
w~ .4-
C'
~
~~~ FlO
-"~
[g 10 1 10 1 ~ 10 1
~
lor [g ..
'D~I 0
~
II [m [m [m
'Oro
[m [m I'~ ~
"'5 c::;?
I'D
~~~
QQ99Q9Q9 ~ ~oQ ·SJ )
D 0 Q Q 00 00000000000000 0000
IsO 0 C;;;'o;oo~'~' ,. oo~o~o~~ Q oooo~~~~
~ ~O" '" ,..' ,. " ,. .. ~" ,. '" 40 ., •• ., •••• ...,......"""
Q '" ~ ~"
9~9
CD
Figure 24. MeSS-'O Assembly Drawing
54


## Scan page 59

MC8S-10 INTERCONNECT AND CONTROL MODULE
SIMS.Q1 MCBS-10 SIMS.Q1 MCBS-10
Pin No. Connector Symbol Description Connection Pin No. Connector Symbol Description Connection
2,4 Jl +5V +SVDC POWt:R SUPPLY 57 Jl DS RAM DATA IN DS J5-6
84 & 8b J2 -9V -9VDC POWER SUPPLY 55 Jl D6 RAM DATA IN D6 J5-7
54 Jl D7 RAM DATA IN D7 J5-8 1,3 J2 GND GROUND
48 Jl WAn' STATE COUNTER J4-1 BIT /1 J5-16 60 Jl MDo DATA FROM MEMORY /1
T J4-8 49 Jl STATE COUNTER 63 Jl MDl UA'!'A FROM MEMORY 1 BIT 1 J5·15 3
46 Jl Tl STATE COUNTER J4-7 17 Jl MD2 DATA FROM MEMORY 2 BIT 2 J5-14
45 Jl STOP STATE. COUNTER J4-2 77 Jl M0 3 DATA FROM MEMORY 3 BIT 3 J5-13
42 Jl ~ STATE COUN,!'ER J4-6 38 J2 MD4 UATA FROM MEMORY 4 BIT 4 J5-12
44 Jl 15 STATE COUNTER J4-5 41 J2 )!I) 5 UATA FROM MEMORY 5 BIT 5 J5-11
47 Jl Tl I 'STATE COUNTER J4-4 45 J2 M06 OA'i'A FROM Mt:MORY b BIT 6 J5-10
43 Jl T STA'rE COUN'!'t:R J4-3 74 J2 M07 DATA FROM ME~IORY 7 BIT 7 J5-9 4
79 Jl CM/1 RAM CIIIP SELECT jil J7-1 11 Jl lAO DATA INPUT PORT II BIT /1 (815) JI0-l
81 Jl eMl RAM CHIP St:LECT 1 J7-2 10 Jl [Al DATA INPU'l' PORT /1 BIT 1 JI0-2
&3 Jl CM2 RAM CHIP SELECT :2 J7-3 14 Jl [AZ DATA INPUT PORT /1 BIT 2 JI0-3
6 J2 CM) RAH CHIP SELt:CT 3 J7-4 19 Jl IA3 UATA INPUT PORT /1 "IT ) JI0-4
2 J2 CM4 RAM CIIIP SEI£C'!' 4 J7-5 28 J! 1A4 DATA INPUT PORT /1 BIT 4 J10-5
4 J2 eMs RAM CHIP SELECT 5 J7-6 33 Jl lAS DATA INPUT PORT /1 BIT 5 JI0-6
DATA INPUT PORT /1 fsiT 6 85 Jl ~6 RAM CHIP SELECT 6 J7-7 37 Jl lA6 JI0-7
82 Jl CM7 RAM CIIIP St:LEc'r 7 J7-8 36 Jl IA7 UA,!'A INPUT PORT /1 BIT 7 J10-8
85 J2 CSjil ROM CHIP SELECT jil
~ J7-16 6 Jl IBO DATA INPUT PORT 1 BI'£ /1 J10-16
7S Jl CS1 ROM CHIP SeLECT 1 J7-I5 13 Jl IB1 UATA INPUT PORT 1 BIT 1 JI0-15
62 Jl CS2 ROM CHIP SELECT 2 J7-14 16 Jl "(B2 DATA ltiPuT PORT 1 BIT 2 JIO-14
64 Jl CS3 ROM CIIIP SELECT 3 J7-13 21 Jl IB3 DATA INPUT PORT 1 BIT 3 J10-I3
70 Jl CS4 ROM CHIP SELECT 4 J7-I2 26 Jl 1B4 DATA I:lPUT PORT 1 !lIT 4 JI0-12
35 J2 CS5 ROM CHIP SELECT 5 J7-11 31 Jl IBS DATA INPUT POR'!' 1 BIT 5 J10-11
46 J2 CS6 ROM CHIP SELECT 6 J7-10 34 Jl IB6 DATA INPUT PORT 1 BIT 6 JIO-IO
JiO-9 72 J2 Cs7 ROH CIIIP SELECT 7 J7-9 39 Jl IB7 DATA INPUT PORT 1 BIT 7
J12-8 5 J2 r:i7 I/O DECODE OUT 0 7 61 J2 :'»./1 OUTPUT PORT /1 BIT jil J13-I6
13 J2 (5'6 I/O DECODE OUT 0 6 ' J12-7
67 J2 ')Al OUTPUT PORT /1 hIT 1 Jl3-15
12 J2 aS I/O DECOD"; OUT 05 J12-6 JA2 OUTPUT POR'I !il ;..n' 2 J13-14 54 J2 15 J2 04 I/O DECODE OU,!' 0 4 J12-5 0A3 OUTPU'l' PORT jil BIT 3 JI3-13 51 J2 14 J2 03 I/O DECODE OUT 0 3 J12-4 0A4 OUTPUT PORT /1 BIT 4 Jl3-I6 53 J2 11 J2 O2 I/O DI::CODE OUT O2 J12-3
:)As OUTPUT PORT /1 BIT 5 Jl3-11 49 J2 9 J2 01 I/O DECODE OUT 0 1 J12-2 0A6 JI3-10 50 J2 OV:l'v'i PORT II [sIT 6 7 J2 Ojil I/O DECODE OUT 0Jil JI2-I
CiA7 OUTPl:T PO;'T II ,,1'1' 7 J13-9 47 J2 3 Jl S FLAG FLIP FLOP-Sign J9-9
75 J2 OBJil OUTPUT PORT 1 BIT Jil J13-1 , Jl Z FLAG FLIP FLOP-Zero J9-10 5
tiD J2 OBI OUTPUT PORT 1 BIT 1 J13-2
Jl P FLAG FLIP FLOP-Parity J9-12 23
78 JZ OB2 OUTPU'!' PORT 1 BIT 2 J13-3
Jl C FLAG FLIP FLOP-Carry J9-11 Z5
60 J2 OB3 OUTPUT PORT 1 1::1'1' 3 J13-4
7 Jl INTERRUPT INSTRUCTION IHPUT Jil J9-I J13-5 DO 65 J2 OB4 OUTPUT PORT 1 BIT 4 9 Jl D1 INTERRUP'!' INSTRUCTIOi, INPUT 1 J9-2
OB5 OUTPUT PORT 1 BIT 5 Jl3-6 57 JZ 18 Jl D2 INTERRUPT INSTR{;CTION INPUT 2 J9-3
62 JZ OB6 OUTPUT POR'!' 1 BIT 6 J13-7 20 Jl IN,!'J::RRUP'r INSTRUCTION INPUT 3 J9-4
J13-8 D3 55 J2' OB7 OUTPUT PORT 1 tilT 7 24 Jl D4 INTERRUPT INSTR{;CTION INPUT 4 J9-5
OC/1 OUTPUT PORT 2 BIT Jil Jl1-16 36 JZ 27 Jl D5 INTERRUPT INSTRUCTION INPuT 5 J9-6
Jl1-15 34 J2 OCl OUTPUT PORT 2 BIT 1 3S Jl D6 Ii,TERRUPT INSTRUCTION INPUT 6 J9-7
25 J2 OC2 OUTPUT PORT 2 BIT 2 Jl1-14 40 Jl D7 INTJ::RRUPT INSTRUCTION INPUT 7 J9-8
24 J2 OC3 OUTPUT PORT 2 liI'l' 3 Jl1-13 59 J2 FROM TTY TRANSMITTER IN} J8-4
22 J2 OC4 OUTPU'!' PORT 2 BIT 4 .111-12 J2 TTY BUFFER J8-5 37 FROM TTY TRANSMITTER OUT
19 J2 OCs OUTPU'!' PORT 2 BI'l.' 5 J11-11 83 J2 DATA FROM TTY TRANSMITTER BUFFER TrY, 816
16 J2 OC6 OUTPUT PORT 2 BIT 6 J11-10 27 J2 TAPE READER CONTROL IN Jll-1
21 J2 OC7 OUTPUT PORT 2 13I'l.' 7 J11-9 lS J2 TAPE READER CONTROL OUT J8-7
44. J2 OOJil OUTPl:T PORT 3 BIT Jil J11-1 28 J2 TAPE READER CONTROL (-9VDC) J8-6
43 J2 001 OUTPUT POR'I' 3 BIT 1 Jll-2 84 Jl DATA TO TTY RECEIVER BUFFER Jll-16
39 J2 502 OUTPUT PORT 3 Ill'!' 2 J11-3 10 J2 TO TTY RECEIVER OU~
} TTY BUFFER
J8-13
42 J2 503 OUTPUT PORT 3 BIT 3 Jl1-4 86 J1 TO TTY RECeIVER OUT J8-12
33 J2 004 OUTPUT PORT 3 BIT 4 Jl1-5 40 J2 TO TTY RECEIVER OUT J8-11
29 J2 005 OUTPU'!' PORT 3 BIT 5 Jll-6 Sl J2 READ/WRITE
26 J2 006 OU'l'PUT PORT 3 BIT 6 Jll-7 72 Jl lJil MULTIPLEXER CONTROL LINES NS263
31 J2 007 OUTPUT PORT 3 13 I'!' 7 Jl1-8 41 Jl SL/1 MULTIPLEXER CONTROL LINES N8267
69 J2 AJil LOW ORDER ADDRI:SS OUT J6-9 69 Jl 11 MULTIPLt:XJ::R CONTROL LINES NS263
82 J2 Al LOW ORDER ADDRESS OUT J6-10 S Jl SL1 MULTIPLEXER CONTROL LINES NS267
58 JZ AZ LOW ORDER ADDRESS OUT J6-11 29 Jl uATA COMPLt:!o'.ENT J9-16
23 J2 A3 LOW ORDLR ADDRESS OUT J6-12 :>2 Jl Jill /1 1 CLOCK (alternate clock) J4-16
63 J2 A4 LOW ORDER ADDRESS OUT J6.-13 lZ Jl Jil 2 /1 2 CLOCK (alternate clock) J4-15
17 J2 AS LOW ORDER ADDRESS OUT J6-14 75 Jl SYNC SYNC our J4-10
32 J2 A6 LOW ORDER AUDRESS OUT J6-15 30 Jl READY READY IN
48 J2 A7 LDI'i ORDER ADDRESS OUT J6-16 1 Jl INTERRUP'!' INTERRUPT IN TrY, 816
68 Jl AS HIGH ORDER ADDRESS OUT J6-1 8 J2 I/O ENABLE ENABLE OF I/O DEVICE DECODER J4-13
67 Jl A9 HIGIl ORDER ADDRESS OUT J6-2 79 J2 I/O SYSTEM I/O. CONTROL J4-9
80 Jl HIGH ORDER ADDRESS OUT J6-3 J2 - SYSTEM INPUT CONTROL J4-12 AIO 77 IN
5b J2 All HIGH ORDER ADDRI:.SS OUT J6-4 50 Jl N.O. PUSH BUTTON SWITCH] INTERRUPT 812
76 Jl A12 HIGH ORDER ADDRESS OUT J6-5 53 Jl ~1j.C .. PUSH BUTTON SWITCH 812
71 Jl Al3 HIGH ORDER ADDRESS OUT J6-6 52 J2 "Jil OUTPUT LA'l'CH STROIlE PORT ~
74 Jl CC~ CYCLE CONTROL CODING J6-7 71 J2 Wl OUTPUT LATCH STROBE PORT' 1
73 Jl CCl CYCLE CONTROL CODING J6-8 20 J2 • Vi 2 OUTPl:T LATCH STROBE PORT 2
61 Jl D~ RAM DATA IN D/1 J5-1 30 J2 W3 OUTPUT LATCH STROBE PORT 3
15 Jl Dl RAM DATA IN D1 J5-2 22 Jl INT CYCLE INTERRUPT CYCLE INDICATOR J12-I6
56 Jl D2 RAM DATA IN D2 J5-3 32 J1 TJA ANTICIPATED if 3 OUTPUT
59 Jl D3 RAM DATA IN D3 J5-4 35 Jl T3 A ANTICIPATED T 3 OUTPUT
511 Jl D4 RAM DATA IN D4 J5-5
55


## Scan page 60

APPENDIX I. SIM8 HARDWARE ASSEMBLER
1.0 INTRODUCTION
The SIMS Hardware Assembler is a program which translates a symbolic assembly language into an octal representation
of the SIMS machine language. An auxilliary .program then translates the octal object code into the "BNPF" format
suitable for bootstrap loading or PROM programming. The program operates on the SIMS-01 micro computer system
with an ASR 33 teletype and utilizes all memory of that system. The components included are the following:
S PROMs (1702): A0840, AOS41, .... , AOS47
S RAMs 1101): Last 256 bytes of assembler
24 RAMs (1101): Name table or object code
Upon purchase of the assembler the customer will receive the following:
S PROMs (AOS40-AOS47) or S paper tapes
1 "SIMS Hardware Assembler - page S" paper tape (AOS4S)
1 "BNPF Tape Generator" (OCTAL) paper tape (AOS49)
1 "BNPF Tape Generator" (SOURCE) pa~r tape (AOS50)
1 "BNPF Tape Generator" Listing
1 SIMS Hardware Assembler Listing
1 SOO8 Users Manual
A system block diagram is given in Figure 1.1.
RAM
MEMOR Y
0 1 2
ROM MEMORY
I
3 4 5 6 7
0000000000000000
r--
00000000 BANKO
BANK 1 00000000
BANK 2 0 0 0 0 0 0 0 0
_BANK 3 0 0 0 0 0 0 0 0
SIM8-01
~
~
L.I
~
L.I
I~
... r
Figure 1.1. SIMS Hardware Assembler System.Configuration
MANUAL
CONTROLS
POWER
SUPPLY
TTY
MR33
The assembler accepts the source text from the paper tape reader on the first of two passes and constructs a name table.
On a second pass the assembler translates the source text using the previously determined name values, creates an octal
object paper tape, and if directed, writes the object code into Read!Write memory.
The assembler's commands allow for TTY keyboard manipulation of R!W memory and execution of stored programs
so that program debugging may be undertaken directly after assembly. If a "BNPF" tape is desired, an auxilliary "tape
generator" program may be loaded and executed by the assembler.
2.0 DESCRIPTION
2.1 Assembly Passes
During Pass 1 the assembler reads the paper tape, constructs a name table and generates a listing. The listing consists of
a line by line copy of the source text with each line prompted by an assembly address. When the assembler detects
a source termination the process is stopped and a symbol table listing all labeled lines is generated. At this point
no diagnostics have been acted upon.
56
\.


## Scan page 61

During pass 2 the assembler generates an object code by reading the source tape and interrogating the name table
for all labeled addresses. The object code is written into pre-assigned R/W memory or onto paper tape at the operator's
option. Diagnostics performed during pass 2 result in omission of the erroneous line and a printout signaling the error.
Errors detected are given below:
Detectable Errors
1. Unrecognized mnemonics
2. Unidentified labels
3. Illegal restart instruction
4. Non numeric literals
5. Illegal I/O instruction formats
2.2 O.,erating Procedures
In addition to being an assembler, this program offers some of the features of a teletype operating system. Its commands
offer the operator a useful interactive mode. The commands "LOAD". "DUMP". and "BEGIN" allow the operator to
read, write, and execute small programs directly from the keyboard;
The assembler requires a source text presented via a teletype reader. The first step of the assembly procedure is therefore
the preparation of a punched paper tape version of the source text. (See Section 9 for details.) This is accomplished
in an "off line" mode.
Before proceeding with the lion line" operations the hardware configuration must be correct. This requires a system
equivalent with one exception to the SIMB-01 portion of the MP7-02/SIM8-01 PROM programming system described
in the SOOS Users manual. The exception is the teletype connection. On the programming system the teletype transmit
,line drives both the interrupt line and the TTY buffer. The hardware assembler, however, must receive TTY data from
the buffer only, so the interrupt must not be connected. A detailed description of the required connections for the
Hardware Assembler is given in Section 10.
The assembler is a program which resides in nine 256 byte blocks or "pages" of memory; On the SIMS-01 eight pages
are permanentJy stored in the "read only" section of its memory. The ninth page must be reloaded into R/W memory
at each "power on" and becomes the second step in the operating procedure. To accomplish this, the paper tape
containing the octal version of "SIM8 Hardware Assembler - Page S" is placed in the reader. If the "interrupt" input is
stimulated. the assembler will bootstrap its 9th page into the R/W memory.
The assembler is now ready to execute commands.
The third step of the procedure is pass 1 of the assembly. To accomplish this the source tape is placed into the reader and
the command below is typed.
ASSEMBLE: 032: 000:
The numeric values select the memory origin point for the assembly. When the reader is placed in the "start" mode the
assembler will read the tape, generate a listing, and assemble a name table.
The fourth step is pass 2 during which the assembler rereads the source tape and compiles the object code. Line
addresses and an octal representation of the object code is printed on the TTY and, if desired, simultaneously loaded
into memory. Pass 2 may be initiated by typing "LOAD:" or "LIST:". "LOAD" will result in loading of memory
and "LIST" will not. If the paper tape punch is enabled, an octal tape of the object code is created. Diagnostics are
performed by the assembler during this pass and errors are flagged by a"?".
At this point the errors have been flagged and an edit of the source tape may proceed. If the program has been loaded
into memory interactive editing is possible. This procedure is continued until the assembly is correct.
If the "BNPF" formatted object tape is required, an auxilliary program must be loaded into memory and executed. The
"LOAD:" :command is used to load the program "BNPF Tape Generator" into memory. The octal tape (2~6 character
maximum) is then loaded into another area of the memory with a second "LOAD:" command. The tape generator
program is executed by asserting the command "BEGIN:". The tape generator program accepts a three digit octal value
terminated by a colon as a start address and begins to translate the memory contents into the "BNPF" format. A print
out and a paper tape will be generated. Sample listings generated during each step described above are given in Figures
2.1, 2.2, 2.3, 2.4, and 2.5. Another example with a step-by-step procedure is given in Section 9.
57


## Scan page 62

ASTST LAB
LCM
JMP ASTST
END
Figure 2.1. Listing of Source Tape
KEYBOARD-.ASSEMBLE: 032: 000:
{
I 032000 ASTST LAB
032001 LCM
PASS 1 032002 JMP ASTST
032004 END
ASTST 03200
KEYBOARD --.. LIST:
PASS 2 {LOAD:
Octal Object 032000
032: 000:
301: 327: 104:
Code
Figure 2.2. Assembly Listing
KEYBOARD --.. LOAD: 013: 000:
{ 013:000
106: 326: 000: 106: 237:
Tape • • .Generator •
013 150 153: 007: 050: 357: 361:
Figure 2.3. Load of Tape Generator
KEYBOARD --.. LOAD: 012: 000:
032: 000:
000: 354:
007:
Octal Object -[ 032 000 301: 327: 104: 032: 000: •••
Code
Figure 2.4. Loading of Octal Object Code
KEYBOARD --- BEGIN: 013: 000:
012:
{OOO
BPPNNNNNPF
"BNPF" 001 •
Object 002
Code 003
004 BNPNPNNPPF
Figure 2.5. Execution of Tape Generator
2.3 Assembly Language
066:
The assembler operates with the 64 character subset of ASCII generated by the ASR-33 teletype with the commercial
at sign, @, given specIal significance and control characters, carriage return, and linefeed. Instruction source fields utilize
a subset of the above including numerics, upper case alphabetics, the colon, quote sign, commercial at, and the control
characters.
The MCS-8 instruction mnemonics as described in the MCS-8 manual and pocket guide are recognized by the assembler.
The instructions set is· augmented by three pseudo operators, "PAM", "ADR" and "LOC" which simplify the assembly
process.
Symbolic addressing and selection of constants are provided by the definition of labels and use of the pseudo operators.
A comment field is also provided.
58


## Scan page 63

3.0 ASSEMBLER COMMANDS
Five commands are used to direct the assembler which provide for teletype/memory interaction, assembly, and execution
of loaded programs. They are defined as follows:
LOAD: The LOAD command is used to store keyboard or paper tape entries into consecutive locations beginning with an
address specified by an address modifier. The modifier consists of 2 three digit octal numbers each terminated by a colon.
The first defines a page address (see memory organization - section 5.0) and the second defines the character address.
The format, described below, requires that leading zeroes be typed. Note that the character address has the range 000 to
3778 = 256 10, LOAD: ,0',':, ,~S:,
Page Char.
Characters of the input tape must be 3 digit octal with leading zeroes, terminated with a colon. During an assembly the
LOAD command may be used without a modifier to initiate pass 2. The source tape is then loaded and the object code
is printed on the teletype printer and stored into memory as well.
DUMP: The DUMP command is used to display memory contents on the teletype printer. The command-reql!ires two
address modifier pairs similar to that described for the LOAD command. The first pair is the address of the last content
to be printed and the second pair is the first. The format is as follows:
DUMP:
Last Address
,0',1:,
Page
,
,O~S:,
Char.
First Address
,01,1: ,
Page
,
,O~:,
Char.
The printout is 3 digit octal with S characters per line. Each line is prompted by a 6 digit octal memory address.
ASSEMBLE: The assemble command initiates pass 1 of the assembly. It is associated with an address modifier which
establishes the origin of the program to be assembled. This address need not be related to the usable memory of the
SIMS-01 card performing the assembly. The format of the command is described below:
Origin
ASSEMBLE:
I ' i
,O~2:, ,O~:,
Page Char.
LIST: The LIST command is recognized only during an assembly. It will initiate pass 2 in such a way that the source
tape is loaded and the object code printed but not stored in memory. The LIST command does not require an address
modifier. Its format is simply:
LIST:
BEGIN: The BEGIN command will initiate execution of a program located at the address specified by its address
modifier. If an RST<I> instruction is hardwired into the interrupt input port, assembler control may be recovered
by generating an external interrupt. It should be noted that the ninth page of memory is not protected, hence care in
execution of a secondary program is warranted. The format of the instruction-is as follows:
Address Modifier
BEGIN: ;Oi2:,' ,~O::
Page Char.
4.0 NUMBER SYSTEM
All numbers used by the assembler are in three digit octal form and require leading zeroes to be typed.
5.0 MEMORY ORGANIZATION
Interaction with memory requires an understanding of its utilization by the assembler. The memory consists of 3000
S bit bytes eacf) directly addressable by the CPU. It is organized in blocks of 256 bytes called pages as shown in Figure
5.1. Addresses are specified by 2 three digit octal numbers each terminated by colon. The first number presented to
the assembler is interpreted as a page designator and the second as a character designator.
59


## Scan page 64

T
ASSEMBLER
(DARK)
,
h
NAME TABLE
AND
OBJECT CODE
j
PAGE
000:
001:
CHAR.
000:
000:
002: 000:
003: 000:
004: 000:
005: 000:
006: 000:
007: 000:
010: 000:
1 PAGE = 256 BYTES = 2K BITS
011 : 000: c:-:::.:-:;;:_:
012:
013:
*011: 020: PAGE 9
000:
PAGE 10
000: PAGE 11
NAME TABLE BEGINS AT 011: 020:
SPACE AVAILABLE FOR
OBJECT CODE LOAD
PAGE CHAR.
000: 377:
001; 377:
002: 377:
003: 377:
004: 377:
005: 377:
006: 377:
007: 377:
010: 377:
011 : 377:
012: 377:
01 :3: 377:
1702
PROM
h J~
1101
R/W
, ,r
VOLATILE AND
UNPROTECTED
DURING ASSEMBLY = 752 - ax (Number of Names)
MAXIMUM NUMBER OF NAMES = 94
Figure 5.1 Memory Map
The assembler resides in the first 9 pages of memory. Two bytes of the 10th page are also dedicated. The first 8 pages,
number 0 through 7, are preprogrammed read only memories and the 9th resides in read write memory, page 8. The last
page is volatile and must be reloaded if power is removed. The memory is unprotected so care must be exercised in
selection of the assembly origin if the object code is to be stored in memory.
The name table created during pass 1 begins at location 011: 020: and displaces 8 contiguous locations for each entry.
The usable RIW memory for loading of object code in pass 2 diminishes as the table develops. The maximum number of
names allowed is 94.
6.0 FORMAT
The assembler is a line-statement, fixed format assembler. Each field of the source statement is defined by its position
in the line. If the positional format is violated the assembler will reject the statement. The format, depicted in Figure
6.1, provides fields for a 6 character label, a 3 character instruction, a 6 character operand, and variable length comment.
The line is terminated by a carriage return followed by a linefeed but may be entirely cancelled by a commercial at
sign, @.
Detailed descriptions of the fields are provided in the following sections.
LABEL MNEMONIC OPERAND COMMENT
-...--\ --+-- ~ 1 ~I - /----+ _____ 1_ ......... CrLf
\ / LEFT
MARGIN UNCOMMITTED TERMINATOR
Figure 6.1 Source Line Statement Format
60


## Scan page 65

6.1 Labels
Any line of the assembly may be aSsign~ a label by placing a one to six character name into the label field. The label
field is the first six, positions of each line. If no label is to be assigned to the line, the fieJd must be filled with spaces.
Each entry into a label field must satisfy the following requirements;
1. The name must be left justified in the field.
2. The name can contain any character except the commercial at sign, @.
3. All unused positions in the field must be filled with spaces.
4. The name must appear e~tly once in a label field of the source text.
5. The total number of names for a single assembly cannot exceed 94.
6.2 Instr:uction Mnemonics
All mnemonics defined in the MCS-8 Users Manual and pocket guide are recognized by the assembler. A concise descrip
tion of each is provided in Appendix A. The reader is referred to the Users Manual for detailed informatIon.
Further explanation and qualifications related to some of the instructions is given below.
JUMP and CALL: The operand field of a JUMP or CALL instruction can contain either a name or an address. If a
name is used, it must be defined at some point in the source input or an error message will result. If an address is used,
the assembler expects the first three digits to be the octal value of the page address and the second three to be the value
of the character address. Examples of the two forms are given below:
6 SPACES TO FILL UNUSED
FILL NAME FIELD INSTRUCTION NAME NAME FIELD
\ \ II nnnnnn JMP n START n COMMENT
n n n n n n JMP n 004006 n COMMENT
/ \
PAGE 4 CHARACTER 6
RESTART: The assembler operates on the operand field of a RESTART instruction in the same manner as on the
operand field of a JUMP or CALL instruction. Its assembled value, however, must be consistent with the 6 bit "AAA
000" format utilized by the processor. If not,an error indication will result.
IMMEDIATES: All Immediate instructions such as LAI can have an operand field occupied by a three digit octal
number (left justified within field) or a character surrounded by double quote marks. (See section 6.3) If an octal
number is found, it will be assembled directly as the immediate value. If a quote mark is found in the first position
of the field, the ASCII equivalent of the character in the second position will be used as the operand value. If the first
character of the operand field is neither a number or double quote mark, an error message will result. Examples of the
formats are given below;
LEFT JUST I FI ED
NUMERIC
\ nnnnnn LAI n 567 nnn COMMENT
nnnnnn LAI n 'IA" n nn COMMENT
/
QUOTE MARK IN
FIRST POSITION
61
IMMEDIATE VALUE IS AN
ASCII A = 11000001


## Scan page 66

INPUT: The INPUT instruction may have either a name or an octal digit with two leading zeroes. The three digit
numeric value is of the form "OOX" where X can vary from zero to seven. The formats are as follows:
nnnnnn INP n NAME nn COMMENT
nnnnnn INP n 007 nnn COMMENT
f
CONSTANTS
The name must assemble to a value between 0 and 7, and numerics must be within the specified range or an error flag will
result.
OUTPUT: The OUTPUT instruction format is similar to the I NPUT instruction but range of operand values is ·Iarger.
Numeric operands may assume values'from octal 010 to octal 037. The leading zero is required. Names must assemble
to values within the specified range or an error flagwill result. Examples o"f the formats are given below:
nnnnnn OUT n NAME nn COMMENT
nnnnnn OUT n 037 nnn COMMENT
/\
CONSTANT MAXIMUM
VALUE
HALT: The HALT instruction may be used as a pseudo operator. If the operand field is blank, it will assemble to its
normal value of 000. If a non-zero value is placed into the first three digits of the operand field, that value will be
assigned. If a quote mark is found in the first position of the operand field, the ASCII value of the digit in the
second position will be assigned.
6.3 Pseudo Operators
Four additional instfuctior,~ dre provided to simplify the assembly process. These instructions are "pseudo operators"
because they are not included in the MCS-8 instruction set. These instructions provide for name address assignment,
memory block address assignment, a double register load for the Hand L registers (see 8008 Manual), and termination
of each pass of the assembly.
Detailed descriptions of these instructions are provided below:
PAM: The instruction "PAM" will assemble as two instructions, "LHI" followed by an "LLI". Its operand field will
be interpreted as two 3 digit octal values. The first and second values specify the LHI and LLI operand fields, respectively.
The values may be numeric or named, but must meet the format requirements of the JMP or CALL instructions. The
realizable range of the first is octal 000 to 077 and 000 to 377 for the second. An example is given below:
SOURCE
STATEMENT
EOUIVALENT
SOURCE
STATEMENT
n n n n n n PAM n 010377 COMMENT
nnnnnn LHI n 010 nnn COMMENT
nnnnnn LLI n 377 nnn COMMENT
62


## Scan page 67

ADR: The instruction "ADR" is non-executable and may appear anywhere in a program except the first instruction.
The address specified in the operand field will be assigned to the name specified in the instruction. With this instruction,
names may be assigned to external subroutines and I/O units. An example is given below:
SOURCE
STATEMENT START n ADR n 0013n COMMENT
. RESULT OF
ASSEMBLY START .... 4-....---- 0013n
LOC: The instruction "LOC" is nonexecutable and must only appear after the last executable instruction. It is used
to reserve blocks of memory locations directly after the assembled programs and to assign a name to the first location.
The name field should contain the desired name and the operand field should contain two three-digit octal numbers to
indicate the length of the array. The form of the number is the same as that used to indicate an address. For example,
the number 001000 would reserve 256 locations and the number 000377 would reserve 255 locations.
END: If the instruction END is encountered by the assembler it will terminate the current pass in process .
. HALT: If the operand value of a H L T instruction is non-zero it is treated as a pseudo operator. Section 6.2 provides
a detailed description.
7.0 ERROR FLAGS
Diagnostics performed in pass 1 and pass 2 may result in error flags during pass 2. If an error is detected, the invalid
source entry followed by a question mark is printed. If the error exists in the operand field but not in the instruction
field, the object code for the instruction will be printed and punched. The assembly must therefore be repeated after
. source text corrections are made.
The conditions that result in error flags are described below:
INVALID MNEMONICS
Every mnemonic fi~ld must contain three letters which can be exactly iqentified as an instruction; otherwise, it will be
rejected as an error.
UNDEFINED NAMES
If a referenced name is not found an error message will result.
INVALID RESTART ADDRESS
The RESTART instruction operates on the operand in the same manner as the JUMP and CALL instruction, except that
it requires that the resulting address be one of the valid restart loc~tions. If this is not true, an error message will result.
INVALID OPERAND FIELD FOR IMMEDIATES
For immediate instructions, the first character of the operand field must be a number or a quote mark.
INVALID OPERAND FIELD FOR JUMP AND CALL INSTRUCTIONS
Operand fields for JUMP and CALL instructions must be a valid name or an octal number.
INVALID OPERAND FIELDS FOR INPUT/OUTPUT INSTRUCTIONS
Section 6.2 defines valid operands fields for the input and output instructions. If those definitions are violated in the
source text, error flags will result.
8.0 OUTPUT TAPE
The assembler generates an octal output tape representation of the object code. Each byte is represented by three digits
terminated with a colon (see Section 9). Lines of 8 bytes are prefixed by the address of the first byte. The address is
not terminated by a colon and will therefore not be accepted by the assembler "LOAD" instruction.
The octal listing is compact and intended for editing operations. To perform standard Intel programming functions, a
"BNPF" formatted tape version of the octal tape must be prepared. To accomplish this, a "BNPF Tape Generator"
program supplied by Intel, and a page of the octal object code is loaded into memory. The BEGIN instruction is then
used to execl:Jte the "Tape Generator" program which reads 256 bytes of memory, translates them to a "BNPF" format,
and transmits them to the teletype for printing and punching.
As an option a "BNPF Tape Generator" source tape is provided so that the ciJstomer may assemble the auxilliary
program with an origin of his choosing. Section 11 provides a detailed, step-by-step description.
A detailed description of the procedure and tape outputs is provided in Section 9.
63


## Scan page 68

9.0 SAMPLE ASSEMBLY WITH A STEP-BY-STEP PROCEDURE
The sample program used in this description is not executable, but includes every instruction, several register pair selections,
erroneous instructions, and the pseudo operators.
STEP 1. PREPARE SOURCE TEXT
The first step, after handwriting of the program, in symbolic language, is to create a punched paper tape and print out on
an ASR 33 teletype. The result of this transcription applied to the sample program is shown in Figure 9.1.
The procedure for creating the source tape is given below:
1. The TTY was placed in the "offline" mode.
2. The paper tape punch control was placed in an "on" condition.
3. Handwritten data was keyed into the teletype keyboard.
Some typographical errors were edited by using the TTY's backspace punch control and rubout character. The rubout is
an all "1"s character which effectively deletes any character over which it is superimposed. The procedure is as follows:
1. Determine the number of backspaces required to return the punch to the erroneous character.
2. Depress the paper tape punch backspace control until the erroneous character is reached.
3. Enter a " rubout" from the keyboard. If a new character must be inserted, the previous character and: the remaining
line or lines must be deleted with rubouts.
4. Enter the desired character and remaining lines.
The assembler's recognition of a commercial at sign, @, may be used as an editing feature since it will effectively
delete the line from the assembly process.
Some comments regarding the format are given below.
1. The first line of the source listing must be named.
2. Strict adherence to the Positional nature of the format is essential.
3. The source listing is terminated by the pseudo operator END.
STEP 2. PREPARE SIMS-01
Step 2 of t~e procedure is the preparation of the SIM8-01. This requires loading of the assembler ROMs, presetting the
interrupt instruction, and bootstrap loading of the last page of the assembler into RIW memory. The procedure is as
follows:
1. Wire SIM8-01 connections in accordance with 8008 Users Manual description of MP7-03/SIM8-01 PROM Programming
Systems with exceptions cited in Appendix C of this note.
2. Hardwire or select by switch a RESTART instruction (00000101) at the interrupt port (see 8008 Users Manual).
3. Install 8 1702 PROMs, A0840 to AOS47, into the SIMS-01.
4. Connect a teletype and power supplies to the SIM8-01 as described in the section VII of the SOOS Users Manual.
5. Place the teletype in the "ON-LINE" mode and set the reader to "FREE".
6. Place the paper tape "SIMS Hardware Assembler - page S for 1101 RAM" (AOS48) in the reader.
7. Depress the interrupt switch.
S. Place the reader in the start mode.
Approximately 256 locations will be loaded into RAM starting at location 010: 000: At completion of load the assembler
is ready to receive commands. Note that its "readiness to accept a command is not prompted by a special character such
as ~rriage return.
STEP 3. COMPLETE PASS 1
With the reader placed in a "free" or "off" mode the source paper tape is placed into the reader. The assembler command
and an origin for the program-is then input from the keyboard. The command is shown below:
ASSEMBLE: r:J 032: r-1 000:
/
I I ,
SIGNIFIES SPACE ORIGIN
64


## Scan page 69

FIRST CHARACTER
MUST HAVE NA~E
LEFT MARGIN~
ASSE~EI 1321 19S.
~TST LAB
LeM
Ll'ID
LEI 123
LMI .....
INK
Del.
ADA
ACB
SUC
SSD
NDE
~
~L
C~
ADI "A"
A~I "S"
SUI "COO
SSI "0"
NDI "E"
XIII HI='"
O'lI "G"
CltI "If"
moe
!'lIlC
hI.
!'tAil
JftP JMP t21ass
J"C JMJt
J,.z Jl'IIt
JFS Jl'IP
JF:P JKP
JTC Jl'IP
JTt JKP
JtS JKP
JTP JM,.
CAL CAl.
CFC CAl.
CFZ CAl.
cn CAL
CP:P CAl.
CtC CAl.
CTt CAl.
CTS CI\l.
CT" 91111J19
'lET
!fTC
!ttl!
Itts
lIlTP
VC
Vz
I"S
lI"P
RST ~"1IJ11!!J
RST TTYOT
TTYOT AOft IJn961
INPII3
IN1=' TYIN
OUt 133
OUt TYOT
HLT
HLt 123
lILT "."
PAM T!JTJ\Y
!'AM 929123
THE FOLLOWING INSTRUCTIONS ARE IN Eft~OR 0
INA
INK
DCA
DCM
LAI
Jl'Ip ASTSY
CAL
'lES TYOT
'lES (lnGU'1
LF'M
CAL CAl.
ADI 'A'
THE FOLLOWING INSTRUCTIONS ARE NONEXECUTABLE. ,
~$tLC LOC 90t.(l1
TSTAY LOC 331 QH"~
£NOLC LOC 99(1931
PASS TYIH AD'! ,e3989
TERMINATOR _______ TYO~..:.T. AD'! 933119
.. END
Figure 9.1 Source Listing
65
OONTROlCHARACTER
"DELETING" LINE


## Scan page 70

AS5EIIB1.lh 132. 1f'8._
LINE ADDRESS~ES 832 IQIGl
ASSIGNED BY 132 '81
132 III
ASSEMBLER 832 883
132 1185
832 ",
112 fill
1f3! III
1321U
e32 8ll
.32 n ..
832 81.5
'32 "l6
832 111
132 821
832 .21
932 123
133 US
1132 1121.
1132 .31
.31 .33
832 135
.32 831.
832 8 .. 1
132 8 .. 2
"32 .... 3
.32 "' .. 832 11&5
132 .58
832 853
132 856,.
"32 961
832 86 ..
832 861
832 812
132 ,,5
832 III
832 t83
832 I.'~
132 ttl
1132 U"
132 lI1
&32 l2!
1132 l2S
fIl2 l31
.32 1.33
'3! 13"
132 ll5
.32 136
'32 131
832 .....
"32 l".
'32 t .. 2
332 t·U
832 ......
332 1."5
832 l .. 6
832 l .. 6
832 .... '
831 LS' 132 1.51
1932 lSI
.32 l53
832 U"
832 ,,5~
132 161
332 165
'32 l65
132 l66
832 l61
832 1.1'
832 1.11
t3! t13
132 .,~
832 211
332 21!
1f32 213
132 21"
132 281
831211
83221.1
332 2l!
833 212
833 213
'33 all
133 213
ASTST 1132
JIIP 832
CAl. "32
Tr(OT "' T5T1.C n2
TST4Y 132
DlDLC .33
tyUt 8.3
TVOT .33
45TST 1.4.13
I.CM
I.IeD
I.EI 123 I.MI .....
INK
DC 1.
404
4ca
SUC
sao
NDE
XltH
ORL.
CPK
401 "4"
4CI "B"
SUI "C"
sal "0"
NDI "E"
X'lI "P'"
O'lI lOG"
CPl "H"
IU.C
R"IC
'l41.
R4'l
JMP JKIIt 828811
JP'C JfiCJt
JP'Z JIIp
JP'S .....,.
J"P JrtP
JTC J!nt
JttJKP
.ITS JKp
JTP .IMP
C41. C41. eM.
CP'C C41.
crt C41.
CF'S CM.
CP'P C41.
CTC C41.
cn eM.
CTS C4l.
CTP 111113111
'tU
'lTC
fttt
QTS
lItTP
ltP'C
V''l.
'l"S
RP'P
Itsr UtlU
''is! TTVOT
TTVOT 40ft 818861
INP It3
INP TYIN
OUT 833
OUT TYOT
H1.T
H1.T 123
H1.T "4"
P4M TST4Y
P4M 821123
- KEYBOARD INPUT
THE "01.LOWING INSTRUCTIONS 4RE IN ERROR •
IN4
INM
DC4
DCIt
WU
JMP 4STSY
C41.
RES TYOT
"lES UI't.
1.P'fiC
CM. C41.
401 '4'
THE r01.LOVING INSTRUCTIONS A~E NONEXECUTAB1.E •
TST1.C I.OC ""Ie I
TS'TAY I.OC "1'"
£NDI.C 1.0C 'e •• , I
tYIN AOft 883'"
TYOT ADft 933""8
END
...
> SYMBOL TABLE
Figure 9.2 Pass 1 Listing
66


## Scan page 71

The origin may assume any octal value from 000: 000: to 777: 777: without consequence if a load comman~ is not used
to enter pass 2. If a load command is used to start pass 2, the object code will be loaded into memory beginning at the
specified origin. If this is done the operator must be ~ure that page 9 and the name table created during pass 1 are not
affected. (See Figure 1.) As an example, if 30 names are used, only 512 object code locations remain available (012:
000: to 013: 377:). An example of the listing generated during pass 1 is given in Figure 9.2. The example is a test
program which includes all instructions, pseudo ops, and some erroneous instructions. The assembler reads the source
tape, prompts all assembly lines, ignores comments, and generates a symbol table. The completion of pass1 is
evidenced by the completion of the symbol table.
STEP 4. COMPLETE PASS 2
Pass 2 requires a reread of the source paper tape so it must be repositioned with the reader in a "STOP" or "FREE" mode.
A "LOAD" or a "LlST" command is used to initiate pass 2 of the assembly. The load command will cause the object code'
to be loaded into memory during pass 2. A list command will not affect memory. When the load instruction is used the
object code must not overlap dedicated memory. (See Figure 5.1.) The commands are entered from the keyboard as follows:
LOAD: or LIST:
A listing generated during pass 2 is shown in Figure 9.3. If the paper tape punch is turned on when the ~ILOAD:" or
"LIST:" command is typed, an octal version of the object code is generated.
KEYBOARD~
1.1$1'1
INPUT 1.0AOI "32. 831iJ.
PARTIAL OUTPUT
FOR LAI (OPERAND
IS MISSING) ~
3n. 327.
1361, 21",
277, 9"".
3'14, lUlU
1113. 1312.
U'" 1l4S,
"321 131,
a4S. a321
186. 1.1'''' U21 122:
Ulh n2.
172c eUI
a"3. 1113.
1!t1. 161,
B32 1318
132,9UJ
332 1iJ21
.,32 If3B
"32 U"
"32 "5"
332 iiJ69
332 17~
332 l~"
132 lie
U2 U9
n2 13~
Ql32 l4e
932 l58
"32 16" 212' "'SS.
INA 1
INt'I ?
DCA
DCM ?
"61
L.AI ?
JM,. A9TSY ?
CAL. ?
'tES 1'YOT 7
37.1. 946. 123. e76.
21le 222. 233. 24 ••
3tll II •• 3321 1124.
3~5, '54, 3136, 164.
012, Gl2!' 832. I'''. 132, I'" , '145, 132.
us, 332., 1 .. 0. Gl4S,
16e, Gl.S' 1432, 173.
1432. 132. UtI a32.
1.39. a32, 1321 U3.
1~2' 1131. 332. 162.
113. 037, ""'3. "531
&23. ~33a 37Sa 1365.
Q1~fh 123, 1"1. 356.
"2B. 13661 123a
I.rrK
"32 173
CAL.
\
7
1361 ~ERROR FLAG
CAL. 7
ADI 'A' 7
Figure 9.3 Pass 2 listing ,
STEP 5. EDIT AND REASSEMBLE
256,
255.
3"3'
387:
lUI.
12~,
132.
1t"5.
112.
a32.
U3.
'163:
101.
"32.
~5".
266.
"3.,
37,'"
12".
'us.
153.
1432,
lB".
142.
332.
~13,
1"1:
366:
OCTAL OBJECT CODE
RESULT OF
DIAGNOSTICS
If errors occur during the assembly. the source text should be edited and the assembly process repeated. If no assembly
errors occur, the user may elect to load the program into memory. assert the "BEGIN" command, and execute the
program. Caution is warranted in this case because the load of the program or its execution may alter the name table
or the 9th page of the assembler. An example of the load and execute is provided in the next section ("BNPF" tape
generation).
67


## Scan page 72

STEP 6. CREATE A "BNPF" PROGRAMMING TAPE
The octal object tape of the assembler is not suitable for PROM programming or bootstrap loading so the next step is
the conversion of the octal tape into a "BNPF" formatted tape.
In summary, this requires the following:
1. Loading of a "BNPF Tape Generator" program (Tape A0849) into R/W memory~
2. Loading a block of 256 bytes of memory with octal object code.
3. Executing the "BNPF Tape Generator" program which creates the desired output tape.
A detailed description is provided below:
The "BNPF Tape Generator" program reads 256 memory locations, translates them, and sends them to the TTY. If the
punch is on, a "BNPF" tape will be generated. The RAM must therefore be loaded with the octal data that must be
translated. The load command; LOAD: 012: 000: was used to load the test tape into locations 012: 000: to 012: 157:
as shown in Figure 9.4. Note that the load instruction does not prefix the data. Also, RAM overlap onto "BNPF" at
013: 000: arid page 8 at 010: 000: must be avoided by proper addressing. With object code loaded a translation may
now be accomplished. The begin instruction is used to jump to the "BNPF" program loaded at 013: 000:. The punch
is turned onand 256 lines of "BNPF" tape are generated. The command; BEGIN: 013: 000: was used as shown in
Figure 9.5. Long tapes must be processed in blocks of 256 eight bit codes.
_________ L.OAD. 013. '00.
KEYBOARD .
INPUT
L.OAD. 3131 IU.
ASSEMBLER OUTPUT~ 113 ta' 116a 326. .tl~1 136, 2311 '001 35". t&61
FOR LATER USE 113 III 0l0, 0~61 10'. t.6, 311t 36.5, rUI, LUI
Il3 '21 113. It3. 301, U,61 Ill. 313. 161. 118,
n3 III l22. 313.. "01. 3.25. 316. 0~6. 313. 866. "BNPF TAPE GENERATOR" Ill'"'' 156, 311. 161. U0. 341, 013. I~I. 372.
3lJ 150 t56. 013a ~6.6. l68. 311' 1!J56. 313. 16.6. OBJECT CODE. THIS IS
ell I"B 161, t16, til" tl6, 326a ,,'it 8 , 056. 113, LOADED INTO MEMORY III '70 366, 156, 36.1 a 186, 341t 380. "061 3021
tl3 l3.1 US, 1156., Bt3a 066. 161. 311, t22. t11, BEGINNING WITH LOCATION
'll llllJ Ill. 121, Il3. 186a 328. 16.5. 1"4, l2~. 013: 000: tt3 l23 \H3. 8U. 316.. US. "56.' 0l3. 866. 1611
III l31 311. 311. 31.11 110, UUI !!1.31 836, lt6.
Il3 l-' t651 I~6. 113. 1661 15&1 3111 1631 1101
113 IS0 153. 113. .511 351. 3611 111.
L.OADI 1121 000.
~03.'" 3011 321. 3U. "461 123, 076. a56, '50,
KEYBOARD 132 ell e611 23'h 211. 2221 233. 244. 255. 266,
INPUT 332828 211'. 0"4. 31h 01_. 382, 024. 313. 334.
032 fUtI 38.41 "44, 315, 354. 3161 3641 317. t1174.
132 840 lUI ~UJ2, 1912. Gl221 1321 1341 l3'. 121,
132 .51 III til , 1"5, 332t II "_ t4St 332. 123, \145.
332 360 132, 131f. Qt45. 832. 14~. Qt45. 332t 15 ••
832 ,1, •• 5. Gl321 163. ".5. f32. 17e, 11,,5. U2,
1!J32 tl10 106, In, U2. ua, lll, U21 112. l3e.
132 lIi Gl32, 122. l81a al2. 132a UII U21 1"2.
332 l29 lie. 032, 1~21 lei. 3321 162. U3. 332.
032 US 1721 3U, tUh 111. 343. 053. t631 1113,
832 lU Qt1l3, t13. ~23t ~331 11~. 165. 1\17 a 131.
332 1.50 1671 1671 8.el 1231 3.11. 356. 8321 166a
332 16. 212. 156a 321. 366a 123. ASSEMBL Y OBJECT INA ?
CODE (ERRORS
HIM 7 INCLUDED). THIS
DCA 7 IS LOADED INTO
MEMORY BEGINNING
DCN WITH LOCATION "6.
L.AI 7 012: 000:
1841
JKP A9T~ 7
UJ6,
CAL. ?
't';T TVOT ?
'!5T 33'31" I 7
L.FN
332 1119 136,
CAL. CAL. ?
1iJ84.
ADI 'A'
Figure 9.4. Loading of "BNPF Tape Generator" and Object Code
68


## Scan page 73

I atGIN. ~13. 11'''.
.
.
. . ~ START OF PROGRAM
~ TO BE EXECUTED
KEYBOARD INPUT L 3121 • START OF DATA BLOCK
~'" B~~NNNPF
'8. B~~NPYPPPF
132 B~PPPPNPPF
183 BlllNPItNPPUP'
0... BNPNPNNPPF
885 BNN~~PPPNP'
836 BPNPNPPPHF
3~1 8NNPNPMNNF
lUI BNf'lPPNlfNJIP'
all BPNNNNNNNF
312 BPNNNPNNPF
31.3 BPNNPNNPNF
346
341
35"
351
3Sa
353
354
355
356
351
36.
361
362
363
36'-
365
366
361
37(
311
·312
313
3'"
315
376
377
BNNNNNNNNF
BNNNNNNNNP'
3NNNNNNNNF
8NNNNNNNNP'
8NNltllllNllPJl'
BNNNNNNNNF
BNNNtrNlfNNF
BNNItNNNNYF
BNNNIftJNNYF
8NNNNNNNYF
8rPPlflfNNNF
8NPNNNlfNNF
8MNNNNNP~F
BNIINIINNNNF
BNPNNIINNNF
8NNNIIMNNNJI'
SNNNNNPMNP'
3NNNNNNNNF
8lfNNNNPtfPF
BNNNNNPNNF
8NNNNN8NNT
8N~NNNNNNF
9NPNNNNNNF
BNNNY"N~PF
BIIPNNNNlftIlI'
8PPP~PPF
.--------- OUTPUT
Figure 9.5. Output of uBNPF Tape Generator"
69


## Scan page 74

10.0 HARDWARE CONFIGURATION DETAILS
The basic wiring required for the assembler is shown in Figure 10-1. This is compatible with the PROM programming
system with two exceptions:
1. The auxilliary interrupt input (J1-1) is not used by the assembler and must b~ grounded. The PROM Programming
System software utilizes this input to initiate a teletype receive sequence. A switched selection is recommended.
2. The interrupt instruction port can be permanently wired as an RST instruction for the assembler but must be
selectable for the Bootstrap., Loader program. To satisfy both, it is recommended that switches be used to drive
inputs J1-7, 9, 18, 20, 24, 27, 38 and 40 between ground and +5V.
+5V -10V
J2-B4,86
------I J1-2,4
ASSEMBLER
MANUAL
INTERRUPT
J1-1
PROG . ..._----1 J1-11
'---..... J2-83
Optional Switch for J1-1.
TAPE
READER
CONTROL
TTY
PRINTER
TTY KEYBOARD
OR TAPE READER
J2-1,3
J1-84
J244
J2-27
J1-11
J2-83
n-18
J2-28
J1-86
J2-40
J2-37
J2-59 SIM8-01
AUX. INTERRUPT
INPUT. (This is an
exception to the
PROM programming
system.)
RESTART
INSTRUCTION
(Recommend use
of switches to
select these levels)
Figure 10.1. SIM8-01 Minimum Configuration Requirement
11.0 ASSEMBLY OF uBNPF TAPE GENERATOR"
The tape "BNPF Tape Generator" (source), tape A0850, may be used to relocate the "BNPF Tape Generator" object
code. The object code, A0849, provided has origin 013: 000: and may be changed if desired.
The assembly process described in Section 9 is applied to the source tape A0850. At Step 3 (Section 9) of the
assembly, the origin is changed to the value desired. When Steps 4 and 5 are completed, an object code for the
relocated tape generator is created. The object tape may then be loaded at the new location using the "LOAD"
command and executed using the "BEGIN" command_ (See Step 6 of Section 9).
70


## Scan page 75

APPENDIX II. MCS-8 SOFTWARE PACKAGE - ASSEMBLER
A. Assembler Specification
1.0 GENERAL DESCRIPTION
The 8008 Assembler generates object programs from symbolic assembly language instructions. Programs are written in
the assembly language using mnemonic symbols both for 8008,instruction and for special assembler operations. Symbolic
addresses can be used in the source program; however, the assembled program will use absolute addresses.
The Assembler is designed to operate from a time shared terminal with input by paper tape or directly from the terminal
keyboard. The assembled program is punched out at the terminal in BNPF format paper tape.
This routine is written in FORTRAN IV. It may be procured from Intel on magnetic tape. Alternatively, designers
may contact several nationwide timesharing services for access to the programs.
The program specifications are presented first and are followed by a user's guide for some of the timesharing'services.
1.1 Assembler Use and Operation
Source programs are written in assembly language and edited prior to assembling, using the time sharing EDITOR program.
Edited programs can then be assembled. ! The Assembler processes the source program in two passes.
The Assembler generates a symbol table from the source statement names in the first pass and checks for errors.
I n the second pass the Assembler uses the symbol table and the source program to generate both a program listing and an
absolute binary program. Error conditions are indicated in the program listing.
1.2 Symbol Usage
Symbols can represent specific addresses in memory for data and program words, or can be defined as constants. Symbols
are used as labels for locations in the program or as data storage area labels or as constants.
Expressions can be formed from a symbol combined by plus or minus operators with other symbols or numbers to
indicate a location other than that named by the symbol. Every symbol appearing as part of an operand must also
appear as a statement label or else it is not defined and will be treated as an error. Symbols that are used as labels for -
two or more statements are also in error.
1.3 Absolute Addressing
Object programs use all absolute addresses. The starting address is specified by a pseudo instruction at the beginning of
the source program. All subroutines referenced by symbol in the main program must be assembled as part of the main
program. Subroutines not assembled with the main program must be referenced by their starting addresses.
1.4 Program Addresses
Consecutive memory addresses are generated by the Assembler program counter and assigned to each source statement.
Two byte source statements are assigned two consecutive addresses and three byte source statements are assigned three
consecutive addresses.
The starting address is set by an ORG pseudo instruction at the beginning of the source program.
1.5 Output Options
The Assembler output is stored in files and can be read out in several forms under control of the time sharing EXECUTIVE.
Some of the options available are:
a. binary paper tape at the terminal;
b. card output at computer center;
c. program listing at the terminal;
d. program listing at the computer center;
e. symbol table listing at the terminal;
f. symbol table listing at the computer center.
2.0 INSTRUCTION FORMAT
The Intel Assembly program consists of a sequence of symbolic statements. Each source language statement contains a
maximum of four fields in the following order:
location field;
operation field;
operand field;
comment field.
The format is essentially free field. Fields are delimited by one or more blanks. Blanks are interpreted as field separators
in all cases, except in the comments field or in a literal character string.
71


## Scan page 76

Each statement is terminated by an end of statement mark. On punched paper tape a carriage return and a line feed punch
term inates a statement.
The maximum length of any statement is 80 characters, not including the end of statement mark. The instruction must
end prior to character 48 but the comments may extend to column 80.
2.1 Symbols
Symbols are used in the location field and in the operand field. A symbol is a sequence of one to six characters repre
senting a value. The first character of any symbol must b~ an alphabetic. Symbols are comprised of the characters A
through Z, and zero through nine.
The value of a symbol is determined by its use. In the location fie1d of a machine instruction or a data definition, the value
assigned to the symbol is the current value of the program counter. In the location field of an EQU pseudo instruction,
the value of the operand field is assigned to the symbol.
An asterisk is a special purpose symbol. It represents the location of the first byte of the current instruction. Thus if
an operand contains *-1, then the value calculated by the Assembler is one less than the location of the first byte of the
current instruction.
Examples of legal symbols:
MAT START2
MIKE Z148
TED24 RONA3Z
*
2.2 Numeric Constants
Two types of numeric constants are recognized by the,Assembler: decimal and octal. A decimal number is represented
by one to five digits (0-9) within the range of 0 to 16383. An octal number contains from one to five digits (0-7) followed
by the letter B. The range of octal numbers is 0 to 37777B.
Numeric constants can be positive or negative. Positive constants are preceded by a plus sign or no sign. Negative constants
are preceded by a minus sign. There can be no blanks between the sign and the digits. If a minus sign precedes the number,
then the complement of the binary equivalent is used.
2.3 Expressions
Expressions may occur in the operand field. The Assembler evaluates the expression from left to right and produces an
absolute value for the object code. There can be symbols and numbers in expressions separated by arithmetic operators +
and - Octal decimal numbers are acceptable. No embedded blanks are allowed within expressions.
Parentheses are not permitted in an expression. Thus terms cannot be grouped as in the expression Z-(4+ T). That expres
sion must be written as Z-4-T to be acceptable to the Assembler.
2.4 Location Field
The location field of a statement contains a symbol when needed as a reference by other statements. If a statement is not
referenced explicityly, then the location field may be blank.
The symbol must start in column 1 of the statement. That is, if a symbol is required it must be punched immediately
following the end of statement mark of the preceding statement. The Assembler therefore assumes that if column 1 is
blank, the location field of that statement does not contain a symbol.
Column 1 of the location field can also indicate that the entire line is a comment. If an asterisk occurs in column 1, then
positions 2 through 80 contain remarks about the program. These remarks have no effect on the assembled program but
do appear in the output listing.
2.5 Operation Field
The operation field must be present and is represented by a mnemonic code. The code describes a machine operation or
an Assembler operation.
The operation code follows the location field and is separated by one or more blanks from the location field. The opera
tion field is terminated by a blank or an end of statement mark when there is no operand fietd and no comment field.
Examples of machine operations:
LAB Load Register A with the contents of Register B
CPM Compare contents of A register with contents of memory location m.
Example of Assembler operation:
ORG Set program counter to specified origin
72


## Scan page 77

2.6 Operand Field
The contents and significance of the operand field are dictated by the operation code. The operand field can contain the
following:
blank
symbol
numeric
expression
data list
The operand field follows the operation code and is separated from that code by one or more blanks. The operand is
terminated by a blank or an end of statement mark if no comments follow the operand.
Examples of operands:
DANI MIKE2-MIKE4 + 1
1438 7738 + X2
1869 *~1
RON+338 AA44-228
(blank)
2.7 Comment Field
The comment field is optional. It follows the operand field and is separated from that field by at least one blank. If
there is no operand field for a given operation code, then the comment field follows the operation field. Once again at
least one blank separates the operation code and the comments. Comments must terminate on or before the 80th charac
ter position. If the comment extends beyond that position, it will be truncated on the output listing. Comments up to
the 48th character position are printed along with the source code. If comments are in positions 49 through 80, then
they are printed on the next line.
3.0 MACHINE OPERATION
Each instruction in the 8008 repertoire can be represented by a three letter mnemonic in the 8008 assembly language.
For each source statement in the assembly language (except for some pseudo instructions), the Assembler will generate
one or more bytes of object code. Source language statements use the following notation:
Label Optional statement label;
Operand One of the following:
data A number, symbol or expression used to generate the second byte of an immediate instruction.
address A number, symbol or expression used to generate the second and third bytes of a call or jump
instruction.
device
start
Comment
( )
A number, symbol or expression used to define input/output instructions to select specific devices.
A number, symbol or expression used to define a starting address after a restart instruction.
Optional comment
Information enclosed-in brackets is optional.
3.1 Move Statements- - 1 byte, or 2 bytes when operand is used.
Move instructions replace the contents of memory or of the A, 8, C, 0, E, Hand L Registers with the contents of one
of the Registers A, 8, C, 0, E, H or L or with the contents of the memory location specified by Hand L or' with an
operand from the second byte of the instr.uction. In what follows, r 1 can represent A, 8, C, 0, E, H, L, or M. r2 can
represent A, 8, C, 0, E, H, L, M or I. If r 1= M, the contents of memory are replaced by the contents of r2' If r2 = M,
the contents of r 1 are replaced by the contents of memory. If r2 = I, the contents of r 1 are replaced by the operand from
the second byte of the instruction.
Examples:
(Label) I Lr 1 r 2
Move r2 to r1'
Label LEH
Move H to E.
Label LAM
data I (Comment)
I Comment
I Comment
Load A from memory.
Label LM8 I Comment
Move 8 to memory.
73


## Scan page 78

Label LCI 062B I Comment
Load octal 062 into C.
Label LMI 135B I Comment
Load octal 135 into memory.
The contents of the sending location are unchanged after each move. An operand is required if and only if r2= 1.
3.2 Arithmetic and Logical Operation Statements - - 1 byte, or 2 bytes when operand is used.
These instructions perform arithmetic or logical operations between the contents of the A Register and the contents
of one of the Registers B, C, D, E, H or L or the contents of a memory location specified by Hand L or an operand.
The result is placed in the A Register. In what follows, r may be B, C, D, E, H 'or L, M or I. If r = M, memory location
is specified. If r = I, the operand from the second byte of the instruction is specified.
3.2.1
3.2.2
3.2.3
3.2.4
3.2.5
3.2.6
3.2.7
3.2.8
Examples:
(Label) I ADr
Add r to A .
. ( Label) I ACr
data I (Comment)
data I (Comment)
Add r to A with carry.
, (Label) I SUr
Subtract r from A.
(Label) I SBr
data I (Comment)
data - I (Comment)
Subtract r from A with borrow.
(Label) I NDr data I (Comment)
Logical AND r with A.
(Label) I X Rr data I (Comment)
Exclusive 0 R r with A.
(Label) I ORr data I (Comment)
Inclusive OR r with A.
(Label) I CPr
Compare r with A.
Label ADB
Add B to A.
Label SUM
data I (Comment)
I Comment
I Comment
Subtract the contents of the memory location
specified by Hand L from A.
Label CPI 024B I Comment·
Compare octal 024 with A.
An operand is required if and only if r = I.
3.3 Rotate Statements - - 1 byte
3.3.1 (Label) I RLC . I (Comment)
Rotate A one bit left.
74


## Scan page 79

3.3.2 (Label) RRC I (Comment)
Rotate A one bit right.
3.3.3 (Label) I RAL I (Comment)
Rotate A through the carry one bit left.
3.3.4 (Label) I RAR I (Comment)
Rotate A through the carry one bit right.
3.4 Call Statements - - 3 bytes
Call instructions are used to enter subroutines. The second and third bytes of call instructions are generated from source
program operands and are used to address the starting locations for the called subroutines. An operand is always required.
3.4.1 (Label) I CAL address I (Comment)
Call subroutine unconditionally.
3.4.2 (Label) I CTC address I (Comment)
Call subroutine if carry = 1.
. 3.4.3 (Label) I CFC address I (Comment)
Call subroutine if carry = 0
3.4.4 ( Label) I CTZ I.. address I (Comment)
Call subroutine if accumulator = O.
3.4.5 (Label) I CFZ address I (Comment)
Call subroutine if accumulator =1= O.
3.4.6 (Label) I CTP address I (Comment)
Call subroutine if accumulator parity is even.
3.4.7 (Label) I CFP address I (Comment)
Call subroutine if accumulator parity is odd.
3.4.8 (Label) I CTS address I (Comment)
Call subroutine if accumulator sign is minus.
3.4.9 (Label) I CFS address I (Comment)
Call subroutine if accumulator sign is plus.
At the conclusion of each subroutine, control returns to the address "Label + 3".
3.5 Jump Statements - - 3 bytes
·Jump instructions are used to alter the normal program sequence. The second and third bytes of jump instructions are
generated from source program operands and are used as the address of the next instruction. An operand is always
required.
3.5.1 (Label) JMP address I (Comment)
Jump to address unconditionally.
3.5.2 ( Label) I JTC address I (Comment)
Jump to address if carry = 1.
3.5.3 (Label) I JFC address I (Comment)
Jump to address if carry = O.
75


## Scan page 80

3.5.4 (Label) JTZ address I (Comment)
Jump to address if accumulator = O.
3.5.5 (Label) I JFZ I address I (Comment)
Jump to address if accumulator =1= O.
3.5.6 ( Label) I JTP I address I(Comment)
Jump to address if accumulator parity is even.
3.5.7 (Label) I JFP I address I (Comment)
Jump to address if accumulator parity is odd.
3.5.8 (Label) I JTS I address I(Comment)
Jump to address if accumulator sign is minus.
3.5.9 (Label) I JFS I address I(Comment)
Jump to address if accumulator sign is plus.
3.6 Return Statements - - 1 byte
Return instructions are used at the end of subroutines to return control to the address following the call instruction that
entered the subroutine. In what follows, assume a subroutine was called as shown:
MAIN CAL SUB RTN I Comment
3.6.1 (Label) RET I (Comment)
Return unconditionally to "MAIN + 3"
3:6.2 (Label) I RTC I (Comment)
Return to "MAl N + 3" if carry = 1.
3.6.3 (Label) I RFC I (Comment)
Return to "MAl N + 3" if carry = O.
3.6.4 (Label) I RTZ I (Comment)
Return to "MAIN + 3" if accumulator = O.
3.6.5 (Label) I RFZ I (Comment)
Return to "MAIN + 3" if accumulator =1= O.
3.6.6 (Label) I RTP I (Comment)
Return to "MAI N + 3" if accumulator parity is even.
3.6.7 (Label I RFP I (Comment
Return to "MAIN + 3" if accumulator parity is odd.
3.6.8 (Label) I RTS I (Comment)
Return to "MAIN + 3" if accumulator sign is minus.
3.6.9 (Label) I R FS I (Comment)
Return to "MAIN + 3" if accumulator sign is plus.
76


## Scan page 81

3.7 Input/Output Statements - - 1 byte
These instructions are. used to input or output data, one byte at a time, between the A Register and the external.device
selected by the operand. An operand is always required.
3.7.1 (Label) I IN P I device (Comment)
Inputs one byte of data from device to the
A Register.
3.7.2 (Label) lOUT device (Comment)
Outputs one byte of data from the A Register
to device.
The device operand must have a value between 0 and 7 for input instructions and between 10 and 37 octal for output
instructions.
3.8 Increment/Decrement Statements - - 1 byte
These instructions are used to in~rement by one or decrement by one any of the registers r. I n what follows, r can
represent B, C, D, E, H or L. Increment and decrement operations affect the accumulator conditions zero, parity and
sign, but not carry.
3.8.1
3.8.2
Example:
(Label) I. INr
Add 1 to r.
(Label) I DCr
Subtract 1 from r
Label INB
Add 1 to B.
3.9 Halt Statement - - 1 byte
The halt instruction is used to stop the 8008 processor.
(Label) I H LT
3.10 Restart Statement - - 1 byte
(Comment)
(Comment)
(Comment)
(Comment)
The restart instruction is used in conjunction with an interrupt signal to start the 8008 after a halt. The program counter
is set to a starting address equal to the operand multiplied by octal 10. A start operand is required which may have a
value from 0 to 7.
(Label) RST start (Comment)
3.11 Load Address Statement - - 4 bytes
This instruction is used to load Hand L with a memory address and is simply an assembly language convention equivalent
to the two separate instructions LHI and LLI. An operand is required.
(Label) I SHL ,I address I {Comment)
4.0 PSEUDO INSTRUCTIONS
The purpose of pseudo instructions is to direct the Assembler, to define constants used by the object code, and define
values required by the Assembler. The fol,lowing is a list of pseudo operations.
ASB Define paper tape output
ORG Define origin of program
eou Define symbol value for Assembler
DEF Define constants for object code
DAD Define two byte address
77


## Scan page 82

4.1 Program Origin
The program origin can be defined by the user by an ORG pseudo operation. If no ORG statement is defined, the origin
is assumed to be zero. The origin can be redefined whenever necessary by including an ORG statement prior to the
section of code wh ich starts at a specific program location.
The format of the ORG statement is:
ORG n I (Comment)
The operand n can be a number symbol, or an expression. If a symbol is used it must be predefined in the code.
Example of the ORG statement:
LAB
LCD
ORG 1000B
SAM LCD
ORG 5000B
SALLY DEF
END
1,4, 777B, 7000B
4.2 Equate Symbol
Instruction starts in LOC 0000
I nstruction stored in LOC 1000
Data starts in LOC 5000
A symbol can be given a value other than the one normally assigned by the program location counter by using the EQU
pseudo operation. The symbol contained in the location field is given the value defined by the operand field.
The EQU statement does not produce a machine instruction or data word in the object code. I t merely assigns a value to
a symbol used in the source code.
Format of the EQU statement:
Symbol I EQU operand (Comment)
The operand may contain a numeric, a symbol, or an expression. Symbols which appear in the operand must be pre
viously defined in the source code.
All fields are required except for the comment field, which is always optional.
Example of EQU statements:
TELET EQU 4
MAGT2 EQU 2
MAGT6 EQU 6
SAM EQU 1000B
INP TELET
LAB
CALL SAM
OUT MAGT2
4.3 Define Constant
Constant data values can be defined using the DEF pseudo statement. The data values are placed in sequential words in
the object code. If a symbol appears in the location field, it is associated with the firstdata word. That symbol can be
then used to reference the defined data.
Format of the DEF statement:
(Symbol) I DEF data list (Comment)
The data list consists of one or more terms separated by'commas. There can be no embedded blanks in the data list
(except in a literal character string). The;terms can be octal or decimal numerics, literal character strings, symbols or
expressions.
78


## Scan page 83

A literal character string is enclosed in single quote marks ('). It can contain any ASCII ~haracters, including blanks.
The internal BCD S bit codes corresponding to the given characters are stored in sequential bytes, one character per
byte.
Octal and decimal numbers are stored one per byte in binary.
Octal numbers must be in the range 0 to 377B:
Decimal numbers must be in the range 0 to 255.
Two's complements are stored for minus numbers.
The program counter is incremented by one for each numeric term in the data string and by n for each literal string of n
characters.
Examples of data strings:
MESSl
MESS2
MASKS
4.4 Define Address
DEF
DEF
DEF
DEF
'SYMBOL TABLE OVERFLOWED', Y-2, SUB2
'LITERAL STRING 1', 'LITERAL STRING 2'
77B, 177B, 130B, LABEL 3, X + 3 Required masks
24, 133, 37B, 99, 232, 'ERROR' Required constants
Program addresses, defined by alphabetic symbols, are stored as data by the DAD pseudo operation. The 16 bit address
is stored in sequential bytes; the first byte contains the S least significant bits and the second byte contains the S most
significant bit of the address.
Format of the DAD statement:
(Symbol) DAD data list (Comment)
The data list consists of one or more symbols separated by commas. There can be no embedded blanks in the data list.
The program counter is incremented by two for each symbol in 'the data list.
Examples of DAD statements:
LINK
ERRSUB
DAD
DAD
DAD
SUB 1, SUB2, SUB3
ER RORX Print Errors
SOCTAL, SPECM, SYMBOL, SEXPR, SLIT
4.5 End of Source
The end of the source code statements is defined with the END pseudo statement. The END operation code generates
no object code; it merely signals to the Assembler that there is no more source code.
Format of the END statement:
END (Comment)
Note that no symbol is allowed in the location field of the END statement.
4.6 Assembler Paper Tape Output
The format of the paper tape output is defined by the ASB pseudo output. The operand specifies the format with" the
following mnemonic codes.
F1601- 1601 format described in Intel Data Catalog.
FSOOS- FSOOS Format (This logic is not included in the Assembler but the position of the code is described
in the PAPER Subroutine.)
The entire SO character statement is written on the paper tape file as the first record. It is used to describe the contents
of the paper tape. If no ASB pseudo operation appears, then format F1601 is assumed and a string of asterisks appear
on. the paper tape file as the first record.
Examples of ASB statements:
ASB F 1601 Keyboard Code
ASB F1601 Data Transmission Code
79


## Scan page 84

5.0 ERRORS
Various types of errors can be detected by the Assembler. Message is emitted following the statement which contains
the error. The·error messages and their meanings follow.
$ERROR$llLEGAL CHARACTER X
The special charact~r X (such as $, / . , ) appears in the statement (not in the comment) or perhaps a required
operand field is missing.
$ERROR$ MULTIPLY DEFINED SYMBOL XXXXXX
The symbol XXXXXX has been defined more than one time.
$ERROR$ UNDEFINED SYMBOL XXXXXX
The symbol XXXXXX has been used but never defined.
$ERROR$ILLEGAL NUMERIC CONTAINS CHARACTER X
An octal number includes an megal digit (such as 8 or 9) or the numeric contains non numeric characters.
$ERROR$ILLEGAL OPCODE XXX
The operation code XXX is not one of the acceptable mnemonics.
$ERROR$ MISSING OPERAND FIELD
No operand found for an operation code which requires one.
$ERROR$ILLEGAL VALUE = YYYYYY, MAXIMUM = XXXXXX
The numeric value of an octal or decimal number of an expression has overflowed its limit.
XXXXXX= 377B for 1 byte operands or data word
XXXXXX= 37777B for 2 byte operands
XXXXXX=
XXXXXX=
37B
7
for output device numbers
for input devic€! numbers
YYYYYY= given operand value
$ERROR$ILLEGALSYMBOL
A location field contains a symbol that has more than six characters or that does not start with an alphabetic ..
$ERROR$ MISSING LABEL
The label, which is required by the EQU pseudo operation, is missing.
$ERROR$ SYMBOL TABLE OVERFLOW, MAXIMUM = XXXXXX
Too many symbols in source program to fit into allocated symbol table.
$ERROR$ LINE OVERFLOW, MAXIMUM = XXXX
Input line exceeds 48 characters; or missing carriage return.
$ERROR$ERRONEOUSLABEL
Opcodes END and ORG may not have a label.
$ERROR$ILLEGAL ORIGIN XXXXXX is less than XXXXXX
Value of new origin is less than current program count.
$ERROR$ I LLEGAL OPERAND
DAD opcode requires symbolic operand
6.0 SYSTEM OPERATION
Source programs may be entered directly from the terminal keyboard or through a paper tape reader into a file. The user
can then edit the source program by calling the EDITOR routine. After editing, the user calls and runs the ASSEMBLER
routine.
6.1 Output Control
At the conclusion of the Assembly process, the user can request the following output:
Local binary object tape
Remote binary object tape
Local program listing
Remote program listing
Local source statement listing
Remote source statement listing
Local symbol table listing
Remote symbol table listing
Remote card object deck
80


## Scan page 85

6.2 Binary Output
The formatted object code is punched out on request in sequence on 8 level paper tape.
6.3 Program Listing
The printout of the program listing will have the following format:
Columns
1-5
6-7
8-10
11
12-14
15
16-18
19
20-22
23-24
25-72
Location (octal) of first byte of object code
Blank
First byte object code word in octal
Blank
Second byte object code word in octal
Blank
Third byte object code word in octal
Blank
Fourth byte object code word in octal
Blank
First 48 characters of source statement
B. Tymshare User's Guide for Assembly
This section contains the operating procedure for the Tymshare PDP-10 version of the assembler. Information on
manipulation and editing of .files iscontained in the TYMEX and EDITOR reference manuals distributed by Tymshare.
The assembly language is described in Section A of this appendix. In addition to the standard features, the Tymshare
PDP-10 version of the assembler permits the use of tabs in place of blanks (outside ASCII string constants}, simpUfying
formatting of the assembly listings.: (IITabs" are set in every eighth column in the PDP-10 system.)
To use the assembler, the user must create an assembly language source file on the disk. This file may not contain line
numbers. The file name consists of one to five characters with the file name extension ".DAT".
To start the assembly, type :
RUN (UPL) ASM8 ..J
in either the TYMEX or PDP-10 mode. The assembler will request the input (source) file name. The user replies by
typing the file name exclusive of the .DAT file name extension. For example, if the source file is named SRC.DAT, the
reply is SRC,.). '
When the assembly is complete, the assembler will type a stop message and return to the monitor. Output files from the
assembler may then be listed or punched on the user's terminal.
Three output files are produced by the assembler:
contains the assembly listing
contains the 1601/1701 object tape
LOGOU.DAT
LOGBI.DAT
LOGMI.DAT contains intermediate pass code (this file may be deleted to reduce storage charges)
The output from the assembler is described in Section A of this appendix. Section F contains an example of the assembly
language listing.
C. General Electric User's Guide for Assembly
This section contains the operating procedure for the General Electric version of the assembler. I nformation on manipu
lation and editing of files is contained in the COMMAND SYSTEM and EDITING COMMANDS reference manuals dis-'
tributed by General Electric. The assembly language is described in Section A of this appendix.
To use the assembler, the user must create an assembly language source file on the disk. This file may not contain line
numbers. The file name consists of one to eight characters. Output files for the assembler must already exist or be
created before starting the assembler. The files referenced are LOGOUT, LOGMID, and LOGBIN. All of these files are
sequential ASCII. No password is permitted for any assembler file.
81


## Scan page 86

To start the assembler, type:
OLD ASM8,
When the program prints "READY", type:
RUN,
The assembler will request the input file name. The user replies by typing the source file name of the file to be assembled.
When the assembly is complete, the assembler will type a stop message and return to: the monitor. Output files from the
assembler may then be listed or punched on the user's terminal.
Three output files are produced by the assembler:
contains the assembly listing
contains the object tape
LOGOUT
LOGBIN
LOGMID contains intermediate pass code (this file may be deleted to reduce storage charges)
The output from the assembler is described in Section A of this appendix. Section D contains an example of the
assembly language listing (leading zeroes are suppressed by the General Electric version of the assembler).
D. Sample Program Assembly
S rMBOL VALUE
1: MIJL 00000
£I: MUL000 00013
:5: HUL001 00025
4: U,",UL 00036
5: UMULS 000140
6: J"1UL00 00042
7: UMULi1'l 00054
8: 01 V 30061
9: 01V00~ 00076
10: GIV001 00110
111 01 V002 00140
12: UJIVS 00144
13: UDIV 00146
14: 'J!lIVe0 00151
15: UOIvel 00173
16: ONEG 11:0204
LOC OBJECT CODE SOURCE STATEMENTS
== ==:= == == == ==:= == == == == =::= =: == == =<1: == == == =a as =1:
00000
00000
0011100
(l0000
'lI11l00kJ
00000
0011100 250
00001 340
00002 222
00003 160 013 000
00e06 150 013 000
a0011 320
"0012 "40
00013 l50
00014 223
00015 160 025 "00
00020 150 025 0"0
0"023 330
00024 164i1'
~:0025 304
00026 032
00027 106 036 0"'"
00032 142 204 000
00035 007
00036
0003()
00036
00k!36
00036
000:36
,00036
00"36
00036 1Il16 000
00040 046 011
03042 302
00043 032
• MUL • SIGNED INTEGER MUL TlPLY
• CALL: ARGUMENTS IN C I 0
• EXITI HI ORDER PRODUCT IN B
• LO ORDER PRODUCT INC
• REGSI A,B,C.O,E, AND fLAGS ALTEREO
• TIMEI 1074 TO 14911 MICROSECONDS (8I1BIt)
HUL XRA 1) COUNT ANO NEGAH:
LEA NEGAT IVE ARGUMENTS
WC -
JTS HULIJII0
JTZ HULIII0il
LCA
INE
HUL000 XRA
SUO
JTS ,",UL0fU
JH MULIII01
LOA
INE
HUL001 LAE 2) MOvE COUNT "00 ~
RAR TO CARRY .
CAL UMUL 3) CALL I UMSI ION ED
CTC ONEG "UL TI PL '1". If" CAMMY
RET NEGATE RESULT I EX IT
• UHUL - UNSIGNED INTEGER MULTIPLY .
• CALLI ARGUMENTS IN C & 0
• EX IT I H I ORDER PRODUCT IN 8
. LO ORDER PRODUCT INC
• REGSI A,B,0L, AND fLAGS EXCEPT CARRY ALTERED
• TI ME I 890 TO 11311 MICROSECONDS (1S11I8)
• UHULS • MULTI-PRECISION MULTIPLy'ENTRY
(BIC IS C • 0 • B) ,
UHUL LBI II
UMULS LEI 9
UHUU,II LAC 1) ROUTE CARRY INTO
RAN PRODUCT • M~L!I~Ll.EIC
82


## Scan page 87

~1i'i0 44 320 LCA SHARED REGI STER,
~i1I045 041 DCE I'ORCING NEXT"LSI:!
01.1046 12153 RTi! TO CARRY
021047 301 LAB 2) EXIT II' 8TH ITERATION
000521 101!1 054 00(11 JI'C UMUL 01 3) I I' STEP (1) :SET CARRY
illil053 203 ADD ADD MUL TlPLlCAND TO
eo0~54 032 UMUL01 RAR PRODUCT
210055 310 LBA 4) ROTATE HOST S IGNI FICA
012112156 104 042 000 JMP UMUL00 PRO~CT AND GO T~ ( 1)
121121061 • 01 V - SIGNED INTEGER DIVIDE
00061 • CA LL I HI ORDER DIV IDEND IN B
0:l1061 LO ORDER DIVIDEND IN C
0.,061 DIVISOR IN 0
00061 • EX IT I QUOTIENT IN C
00061 REMA INDER IN B
00061 OVERI'LOW I'LAG IN CARRY (CY"0 a >UV)
1210061 • REGS: A.B.C.O.E. AND I'LAGS ARE ALTEREe
00061 • TI ME I 922 TO 1416 MICROSECONDS (1101118)
00061 250 01 V XRA 1) COUNT AND NEGATE
0012162 340 LEA NEGAl IV E ARGUMENTS
00063 221 SUB
00064 160 076 01210 JTS 01 V000
:30067 150 076 000 JTi! DIV.000
tHl072 040 lNE
1110073 106 204 12100 .CAL DNEG
00076 250 01 V000 XRA
00077 223 SUD
00100 160 110 000 JTS !:II V001
0011113 150 110 000 JTi! DIV001
00106 3:!0 LOA
00107 040 INE
1110110 304 DIV001 LAE 2) HOVE COUNT MOD ~
00111 11)32 RAR TO CARRY
00112 106 146 000 CAL UDIV 3) CALL 'UDIV'
00115 032 RAR ExtT WITH C~ RY
00116 340 LEt. ,. £I I I' OVERI'LOW
£10117 25£1 XRA OCCURRED
00120 262 DRC
00121 063 RTS
00122 301 LAB
00123 223 SUD
00124 003 RI'C
00125 250 XRA 4) I I' CARR Y WA S
00126 264 ORE SET IN STEP (2)
011127 120 140 000 JF'S 01 V£l02 NEGATE QUOTIENT
0~132 250 XRA AND REMAINDER
001;n 222 SUC
00134 320 LCA
00135 25£1 XRA
00136 221 SUB
00137 310 LBA
''Hl14(11 0 06 200 01 V002 LA I 200B 5) SET CARRY AND
00142 022 RAL EXIT
00143 00? RET
00144 • UDIV - UNSIGNED INTEGER DIVIDE
00144 • CALL: HI ORDER DIVIDEND IN B
00144 LO ORDER DIVIDEND IN C
00144 DIVISOR IN 0
00144 • EX IT : QUOT lENT IN C
0£'144 . REMA INDER IN B
00144 NOTE: OVERF'LOW IF' B >= D
0121144 • REGS: A.B.C.E, AND I'LAGS EXCEPT CARRY AI. TERED
00144 • T! ME: 724 TO 1298 MICROSECONDS (80"S)
00144 • UDIVS - SINGLE pRECISION DIVIDEND EN!!oIY
00144 016 l~ UD IVS LB I 0
00146 046 :lIll UDIV LEI 9
0015121 301 I.AB
00151 310 UO IV00 LBA
00152 302 LAC 1) ROTATE CARRY INTO .
00153 022 RAL o IV IDENO - (,IUOTiENT
0!!1154 320 LCA SHARED REGI iiTER·;"
00155 041 OCE FORCING NEXt ·HSB
00156 150 173 000. JTi! UOIV01 TO CARRY
00161 301 LAB 2) ROTATE MSB INTO
00162 022 RAI. HI O!olDER QI,IOIIEN!
0.,163 223 SUD 3) SUBTRACT DI·VISORI IF'
00164 100 151 000 JF'C UD IV00 I.ESS THAN HI ORDER QI,J
00167 203 ADD GO TO (1)
01'l170. 104 151 000 JMP UDIV0J!l ELSE ADD IT BACK
00173 022 UDI Vill RAI. AND GO TO (1)
00174 340 I.EA 4) COHPI.E~ENT QUOT lENT
00175 006 377 LAI 377B AND EXIT
00177 252 XRC
00200 320 LCA
00201 304 I.AE
00202 032· RAR
00203 007 RET
00204 • DNEG - DOUBLE PRECISION NEGATE
00204 • CALLI HI ORDER IN B
00204 1.0 ORDER IN C
00204 • EX IT I HI ORDER IN B
0021il4 LO ORDER IN C
00204 • REGS I A,B,C, AND F'I.AGS ARE ALTERED
00204 • TI ME: 76 HICROSECONDS (8008)
0021114 • NOTEI -32768 CANNOT BE NEGATED
00204 250 DNEG XRA
00205 222 SUC
00206 320 I.CA
00207. 006 000 LA I
00211 231 SBB
00212 310 LBA
00213 007 RET.
00214 END
83


## Scan page 88

APPENDIX III. MCS-8 SOFTWARE PACKAGE - SIMULATOR
A. Introduction
This Appendix describes the use of a FORTRAN IV program called INTERP/8. This program provides a software simu
lation of the INTEL 8008 CPU, along with execution monitoring commands to aid program development for the MCS-8.
INTERP/8 accepts machine code produced by the INTEL 8008 Assembler, along with execution commands from a time
sharing terminal, card reader, or disk file. The execution commands allow manipulation of the simulated MCS-8 memory
and the 8008 CPU registers. I n addition, operand and instruction breakpoints may be set to stop execution at crucial
points in the program. Tracing features are also available which allow the CPU operation to be monitored. INTERP/8
provides symbolic reference to storage locations as well as numeric reference in various number bases. The command
language is described in the paragraphs which follow.
B. Basic Elements
All input to INTERP/8 is "free form". Numbers, symbolic names, and special characters may be placed anywhere within
the input line (see margin commands in Section D). Comments may be interspersed in the input, but must be enclosed
within the bracketing symbols 1* and * /.
1. Numbers. Numeric input to INTERP/8 can be expressed in binary, octal, decimal or hexadecimal. The letters B, 0,
a, 0, and H follow!ng the integer number indicates the base, as shown below:
Number Value
11011B 11011 2
280 2810
330 338
330 338
lCH lC 16
28 28 10
A decimal number is assumed if the base is omitted. Note that although 0 is allowed to indicate octal integers, a is also
permitted to avoid confusion with the integer O. Note that the leading digit of a hexadecimal number must be one of
the digits 0, 1, ... ,9. Thus, EF216 must be expressed as OEF2H.
On output, I NTERP/8 indicates octal integers with a and omits the 0 on decimal values. The base used on output de
faults to decimal, but may be changed by the user. (See the BASE command in Section C,)
2. Symbolic Names .. Symbolic names are strings of contiguous alphabetic and numeric characters not exceeding 32
characters in length. The first character must be alphabetic. Valid symbolic names are:
SYMBOLICNAME
X3
G1G2G3
LONGSTR INGOFCHARACTERS
3. Special Characters. The special characters recognized by INTERP/8 are: $ = • / ( ) + - ' * ,. All other special charac
ters are replaced by a blank.
C. I NTE RP /8 Commands
The commands available in INTERP/8 are summarized briefly below. Full detaHs of each command are given in following
paragraphs.
Command Purpose
LOAD
GO
INTER
TIME
CYCLE
TRACE
REFER
ALTER
CONV
DISPLAY
SET
BASE
PUNCH
END
Causes symbol tables and code to be loaded into the simulated MCS-8 memory.
Starts execution of the loaded 8008 code.
S,imulates an 8008 interrupt.
Displays time used in the 800B simulation.
Allows the simulated CPU to be stopped after a given number of cycles.
Enables tracing feature when particular portions of the program are executed.
Causes the CPU simulation to stop when a particular storage location is referenced.
Causes the CPU simulation to stop when the contents of a particular memory location is altered.
Displays the values of numbers converted to the various number bases.
Displays memory locations, CPU registers, symbolic locations, and 10 ports.
Allows the values of memory locations, CPU registers, and 10 ports to be altered.
Allows the default number base used for output to be changed.
Causes output of machine code in BPNF format.
Terminates execution of an 8008 program.
84


## Scan page 89

The commands NOTRACE, NOREFER, and NOAL TEA-are also defined. These commands negate the effects of TRACE,
REFER, and ALTER, respectively. In all cases, the commands may be abbreviated (but not misspelled!). These abbre
viations are indicated with the command description.
Commands are typed anywhere on the input line, with as many commands on a line as desired. The symbol n." must
follow each command.
The end of data for the execution of INTERP/8 is indicated by a "$EOF" starting in column 1 of the last card.
1. Range-Lists. Many of the INTERP/8 commands accept a "range-list" as an' operand. Tracing, for example, can be
enabled for a specific range of addresses in the program. The range-list specifies a sequence of contiguous addresses in
memory, or a range of numeric values to which the command is applied.
In its simplest form, a range-list is a number (binary, octal, decimal, or hexadecimal), or it may be a pair of numbers
separated by the symbol "TO~" Thus, valid range-lists are:
10
630
50 TO 630
OFH TO 110011118.
A range-list, however, can also reference a symbolic location, with or without a numeric displacement from the location.
Suppose, for example, the symbols START and INCR appear at locations 10 and 32 in the source program. Valid range
lists involving these symbols are:
START (Same as 10)
START +6 (Same as 16)
START -1018 (Same as 5)
10 TO INCR (Same as 10 TO 32)
START+3 TO
INCR-2 (Same as 13 TO 30)
The range-list !'Day also contain a reference to the current value of the program counter of the simulated 8008 CPU. The
symbol "*,, represents this value. If the value of the program counter is 16, for example, the following is a valid range
list:
START TO * (Same as 10 TO 16)
The exact use of the range-list is illustrated with the individual commands.
2. Notation. The following notation is used to describe the INTERP/8 command structure. Elements enclosed within
br~ces { and} are optional, while elements enclosed within the brackets [and] are alternatives, where .at least one
alternative must be present.
A range-list, for example, can be specified as:
range.,.element { TO range-element}
where a range-element is defined as:
[;::~c-name {[~ ~~~::~]}J
*
As mentioned previously, command names can always be abbreviated. The required portion of the command is under
lined in the command description. The symbol "TO" in the range list can be abbreviated as "T."· Thus, the range
list above can be redefined as:
range-element {10 range-element} .
Finally, the ellipses" ... " indicate a list of indefinite length.
The commands are given alphabetically in the following paragraphs starting with a prototype statement using the above
notation. A brief description is then given, followed by examples.
3.[AL TER ] range list {, range-list, range-list, ... , range-list} .
NOALTER
The ALTER command is an operand breakpoint command which causes the execution of the 8008 CPU to stop when
ever an attempt is made by the CPU to store values into a memory location specified in the range-list. When the break
point is,encountered, INTERP/8 prints ALTER x, where x is the value of the program counter. Execution can be
started again with the GO, RUN, or INTER commands. Examples of the command are:
ALTER 0
ALTER OTO 10
ALTER 10 T INCR.
ALTER START + 2 TO INCR - OAH
AL 5, START, X2, 7 T 10, INCR-3
85


## Scan page 90

4. ~ASE1[!El)
This command causes the INTERP/8 system to use the number base specified by the second argument when printing
results. This command has no effect on the number bases which are acceptable in the input.
5. CONY range-list{ ,range-list, range-list, ... , range-list} .
The conversion command prints the values of the numbers specified in the range-list in binary, oct,al, decimal, and hexa
decimal forms. Examples are:
CONY 23
CONV*.
CON 10 TO START + 3
CO 10,30,280, 1101B T 33H
6. CYCLE Number
The cycle command causes a breakpoint to occur when the CPU cycle count reaches its current value plus the number
specified in the cycle command (see the GO command, also).
7. QISPLAY displ~y element { , display-element, ... , display-element} .
The display command causes the values of memory locations, symbolic names, CPU registers, and 10 ports to be printed.
The output form of these values is determined by the current default base (see the BASE command). The width of the
output line determines the output formatting (see the $WIDTH command of Section D).
In its simplest form, a display-element can be one of the 8008 CPU registers:
CY (carry) D
Z (zero) E
PS (entire program stack)
PSO
S (sign) H PS 1 (program stack elements)
P (parity) L
A HL (H&L) PS 7
B SP (program stack pointer)
C PC (program counter)
In this case, valid DISP,LAY commands are:
DISPLAY CY
DISP CY, Z, H, HL.
D P, A, PS O.
A display-element can also be the symbol CPU, in which case all registers are displayed.
The values latched into the 10 ports can be displayed by using a display element of the form:
PORT range-list
The ports specified in the range-list (between 0 and 31) are printed. Examples are:
DISPLAY PORT 0
DI PO 3, 1'0 5, PORT 5 TO 8, PO 1001B
The contents of the symbol table can be examined by using a display-element of the form:
SYMBOLS {[SymbO~ic-nameJ}
number
The form
DISPLAY SYMBOLS.
prints the entire symbol table, while the form
DISPLA¥ SYMBOLS number.
responds with the symbolic name (± a numeric displacement) which is closest to the address specified by the number.
Examples are:
DISP SY.
DI SY OFFH, SY 32
If the symbol "*" is used in the command, the symbolic location closest to the current program counter is printed.
In this case, the display-element takes the form
The values contained in memOlrY[_=O~~~'~OC~:T~~t~Oln)s can also be displayed.
MEMORY range-list
86


## Scan page 91

The range of elements printed is specified in the range-list, while the form of the elements in the display is controlled by
the command CODE (decoded instructions) or one of the number bases. If the form is omitted, the default number base
is used in the display (see the BASE command). Valid DISPLAY commands are:
DISPLAY MEMORY 20.
DISP MEM 20 TO 30H.
01 M START T START+5.
01 MEM 0 TO 30 CODE.
o MOT 30 0, M 40 TO INCR+l0 OCT.
The various display-elements may be mixed in a single DISPLAY command.
S. END.
The END command reinitializes the INTERP/S system. If another program is ~ubsequently loaded into memory, all
break and trace points are reset. Otherwise, the currently loaded program may be rerun with all break and trace
points remaining.
9. go { [:umber] } .
The- GO command causes the execution of the loaded program to begin. In the case that a break point was previously
encountered, the e~ecution continues through the breakpoint. If the GO is followed by a *, the breakpoint addresses
are printed as they are encountered, but the SOOS CPU does not halt until completion. If the GO is followed by a number,
the effect is exactly the same as
CYCLE number. GO.
10. INTER {number {number { number}} }.
The INTER command simulates the SOOS interrupt system. The numbers which follow the INTER command correspond
to an instruction and its operands which will be "jammed" into the instruction register. If no instructions follow the
INTER command, the instructions from the last interrupt are used. If no previous command has been specified, a LAA
(NOP) instruction is used. The INTER command causes the simulated execution to continue. Examples are:
INTER.
INT.
INTER 00010101B (this is an RST 200).
11. LOAD number { number} .
The LOAD command reads the symbol table and SO OS machine code into the simulated memory. The form
LOAD number.
reads only the machine code from the file specified by number (see file numbering in Section D). The form
LOAD number number.
reads the symbol table from the file specified by the first number and the machine code from the second file. The symbol
table is in the form produced by the SOOS assembler (i.e., the first part of the listing file), and the machine cod,e is in
"BNPF" format (see PROM programming specifications in the INTEL Data Catalog). This format is also produced by
the INTEL SOOS assembler. The end of the coqe file is indicated by a 11$" appearing in the input. INTERP/S responds
to this command by printing the number of locations used by the program. Examples are:
LOAD 1.
LOAD 6 7.
12. [REFER ] range-list {, range-list, ... , range-list}.
NOREFER
This command is similar to the ALTER command except that a breakpoint occurs whenever any reference to the memory
location takes place. Thus, an instruction fetch, an operand fetch, or an operand store all cause a breakpoint when this
command is used. Examples are:
REFER 10.
RE 10 TO 300.
REF 5, 7, START TO START + 5, 710.
NOREF 0 TO 10.
13. RUN.
The RUN command has exactly the same effect as the command GO * .
14. ~ET. set-element { , set-element, ... , set-element} .
The SET command allows memory locations, CPU registers, and 10 ports to be set to specific values. The register names
described under the 0 ISPLA Y command can be used in the set-element:
. [number] register = *
87


## Scan page 92

The value of the specified register is set to the number following the "=" or to the value of the program counter if "*,,
is specified. Thus, valid commands are:
SET Z = 0
SE A = 3, B ::: 770, PS 0 = OEEH.
S HL = 2S.
A set-element can also be the symbol "CPU" in which case all registers are set to zero, including the simulated SOOS timer.
Examples are:
SET CPU.
S CP, PC = 25.
The values of 10 ports can also be set by using a set-element of the form
PORT range-list = number {number number ... number}
In this case, the 10 ports specified in the range-list are set to the list of numbers following the "=". If more ports are
spevified than there are numbers in the list, the numbers are reused starting at the beginning. Examples are:
SET PORT 5 = 10.
SET PO 6 TO S = 1 23
S PO 10 TO 13 = 7702.
S PO S = 10B, PO 12 = 13H, PO 300 = 16.
The values contained in memory locations can be altered directly by using a set element of the form
M.EMORY range-list = number { number ... number}
As in the case of 10 ports, the memory locations are filled from the list to the right of the equal sign, with numbers
being reused if the list is exhausted. Examples of this command are:
SET MEMORY 0 = O.
S MEM 0 TO 50 = O.
The SET command does not change break or trace points which are in effect.
S M START TO START +5 = 11111oo0B 220 33H.
As in the DISPLAY command, set-elements of each type may be intermixed:
SET CP, CY=O, M 5 = 10, PO 6=12, PC = 30.
15. TIME.
The TIME command causes INTERP/S to print the number of states used by the simulated SOOS CPU since the last
LOAD, END, or SET CPU command.
16. [TRACE J I' {I' I' } NOTRACE range- 1st , range- 1st, ... , range- 1st .
The TRACE command causes the INTERP/S system to print the CPU register contents and the decoded instruction
whenever an instruction is fetched from the memory region specified in the range-list. The form of the elements in the
trace is defined by the current default base (see BASE command). The trace shows the register contents and operation
code before the instruction is executed. The resu It of the operation is found in the next line of the trace, or through
the DISPLAY CPU command.
A heading showing the various columns in the trace is printed after each tenth line of the trace. Examples of the TRACE
command are:
TRACE 0 TO 100.
TR START TO START + 111 B.
NOtRACE START, INCR, FOUND TO FOUND+3, 70.
17. PUNCH range list { number} .
The PUNCH command causes the specified region of the simulated memory to be output in the BPNF format. If the
number is present, the code is written into the corresponding INTERP/S output file; otherwise the currently defined
file is used. Examples are:
PUNCH 0 TO OFFH.
PU START TO FINISH.
D. I/O Formatting Commands
INTERP/S has a generalized I/O formatting interface which is somewhat dependent upon the installation. In general,
a number of files are defined by file numbers (not necessarily corresponding externally to FORTRAN unit numbers).
These file numbers correspond to devices as follows:
88


## Scan page 93

INTERP/8 No. Device
1 User's Console
2 Card Reader
3 Paper Tape
4 Magnetic Tape
5 Magnetic Tape
6 Disk
7 Disk
INTERP/8 No. Device
1 User's Console
2 Printer
3 Paper Tape
4 MagnetiC Tape
5 Magnetic Tape
6 Disk
7 Disk
INPUT
PDP-10 Device
TTY 5
CDR 2
PAP 6
MAG 16
DEC9
DISK 20
DISK 21
OUTPUT
PDP-10 Device
TTY5
PTR 3
PAP 7
MAG 17
DEC 10
DISK 22
DISK 23
TYMSHARE
File Name
FOH20.DAT
FOR21.DAT
File Name
fOR22.DAT
FOR23.DAT
GE
File Name
LOGOUT
LOGBIN
Disk 4>1-
Disk 4>2
I/O functions are controlled through "$" commands which may be interspersed throughout the input.
Any input line with a "$" in column one, followed by a non-blank character is considered an I/O command. The card is
then scanned for an "=" foll.owed by a decimal integer. The character following the "$" and the integer value affect the
I/O formatting functions as follows:
Control Meaning
$COUNT = n Start the output line count at the value n.
$DELETE = n Delete all characters after column n of the output
$EOF = 1 End-of-file on this device
$1 NPUT = n Read subsequen input from file number n
$LEFT = n Ignore character positions 1 through n-1 of the input.
$OUTPUT = n Write sUbsequent output to file number n.
$PRI NT = n Controls listing of the output. If n = 0, input lines are not printed;
otherwise input is echoed.
$RIGHT = n Ignore all character positions beyond column n of the input.
$TERMINAL =n INTERP/8 assumes conversational usage if n = 1; otherwise batch
$WIDTH =n
processing is assumed.
This command sets the width of the output line. Note that this affects
the format of the DISPLAY MEMORY command.
Initial Value
1.
120
o
1
o
80
1 '
72
The default values shown above assume conversational use with a teletYpe or similar device. The defaults can easily be
changed by recompiling the INTERP/8 program.
In the case of controls which take on only 0 or 1 values (e.g., $PRINT, $TERMINAL, and $EOF), the equal sign and
decimal number may be omitted. The value of the control is complemented in this case.
E. Error Messages
ERR 0 R M E 5 SAG E S
EXECUTION ERRORS
1 PROGRAM COUNTER STACK OVERFLOW
2 PROGRAM COUNTER STACK UNDERFLOW
3 PROGRAH COUNTER OUTSIDE SIMULATED MCS-B MEMORY
4 ~E~ORY REFERENCE I,
COMMAND MODE ERRORS
1 REFERENCE OUTSIOE SIMULATED MCS-8 MEMORY
2 INSUFFICIENT SPACE REMAINING IN SIMULATED MCS-8 MEMORY
3 END-Or-rILE ENCOUNTERED BEFORE EXPECTED
4 I~PUT FILE NUMBER STACK OVERFLOW (MAX 7 INDIRECT REFERENCES)
5 UNUSED
89


## Scan page 94

10 10 FORMAT COMMAND ERROR (TOGGLE HAS VALUE OTHER THAN 0 OR 1)
11 UIIJUSED
13 INVALID SEARCH PARAMETER IN OISPLAY SYMBOL COMMAND (MUST BE
SYMBOLIC NAME. ADDRESS. OR.)
14 DISPLAY SYMBOLS COMMAND INVALID SINCE NO SYMBOL TABLE EXISTS
15 UNUSED
16 UNRECOGNI~ED COMMAND OR INVALID FORMAT IN COMMAND MODE
17 MISSING. OR EXTRA CHARACTERS FOLLOWING COMMAND
18 LOWER BOUND EXCEEDS UPPER BOUND OR IS LESS THAN ~ERO
IN RANGE LIST
19 THE FORMAT OF THE SYMBOL TABLE IS INVALID (MUST BE A
SE~UENCE OF THE FORM N SY AD. WHERE N IS AN INTEGER.
SY IS THE SYMBOLIC NAME. AND AD IS THE AODRESS (IN OCTAL»
20 INVALlI) CHARACTER IN MACHINE CODE FILE.
21 UNUSED
F. Examples
22 UNRECOGNI~ED DISPLAY ELEMENT OR INVALID DISPLAY FORMAT
23 SYMBOLiC NAME NOT FOUND IN SYMBOL TABLE
24 INVALID ADDRESS OR NO SYMBOL TABLE PRESENT' IN DISPLAY SYMBOL
COMMAND
25 OUTPuT DEVICE WIDTH TOO NARROW FOR DISPLAY MEMORY COMMAND
(USE SWIDTH = N 10 FORMAT COMMANO TO INCREASE WIDTH)
26 INVALID RADIX IN MEMORY DISPLAY COMMAND (MUST BE CODE. BIN.
OCT. OR DEC)
27 UNRECOGNI~EQ SET ELEMENT IN SET COMMAND
28 MISSING SET LIST IN SET COMMANO
29 INVALID SET LIST OR SET VALUE IN SET COMMAND
30 MISSING OR MISPLACED ~ IN SET COMMANO
31 MISSING PROGRAM STACK ELEMENT ~UMBER IN SET PS N
COMMAND
32 INVALID INTERRUPT CODE SPECIFICATION (EITHER MORE THAN THREE
BYTES. OR ELEMENT EXCEEDS 255)
Two sample INTERP/S executions are given in this section which illustrate the commands available with the INTERP/S
system. The first example illustrates the basic commands. A simple program is constructed in the simulated MCS-S
memory. This program is then executed, showing the use of break and trace points. The second execution shows the
use of symbol tables and SOOS code which is produced by the INTEL SODS assembler. In each case, the actual commands
which initiate the INTERP/S system may vary from installation to installation .
• R INT6
B£.GIN
1* ThIS IS All; EXAMPLE OF THE USE OF THE HlTERP/!! SYSTE.t' .•
IN THIS EXAt'PLE. TRE BASIC CCtl:MANDS WILL BE DEMOSTRATEL
.ND A SIMPLE PRCGRAY. WILL SE CCNSTRUCTtt rl~t EXEcrTlD *1
1* TH£. NUMBER CONVERSIOr, C~I':~·At:I.i IS USED FIRST .1
CCt.lV 10.
1010S 12Q 10 An
CON 10Q.
10008 10Q 8 8n
CON 3 TO 8.
118 3Q 3 3H
100B 4Q 4 4H
UJJ B 5Q 5 511
110B 6Q 6 6H
11IB 7Q 7 7H
1000B 10Q B 8h
/* NEXT, THE VAP.IOUS DISPLAY AND SET con·Al\:DS ARl DE"'CI\STRATEL *1
I)ISPLAY CPU.
CYZSP ABC ° E H L HL SP ?S0
*0000*000.*0110 *000*0011*0/0 *11011 *000 *0011l1l0 "'"011l*00Ie 0
DISP A,D,HL.
A .. II
D .. II
liL • 0
DIS PORT 4. PS 0. MEM 5.
P4-0
PSIl .. II
/* MEMORY LOCATIO., 5 WAS NOT DISPLAYED SINCE NO PRCGRAt' HAS m:u;
LOADED *1
SET Ii • 5. L-10Q. DISP CPU.
SET OK
CYZSP A 8 C 0 E H L HL SP PS0
110110 Ilile Ilee ee0 000 eIl0.805*008*01288 1100 00000
1* NOTE THAT THE ELEMEN~S WHICh HAVE CHANGED SINCE THE LAST UISPLAY
ARE PRECEDED BY AN ASTLRISK *1
SET HL • 0EEFH. DIS CPo
90
SET OK
CYZSP A a C 0 E H L HL SP pse
.Iee 110 000 eee 8ee 0Ile*1l14*239*03823 .e. lee00
CONV 83823.
1Il1l111elll18 7357Q 3823 EEFH
1* NOW CHANGE THE DEFAULT N~Ma£R BASE TO HEXADECIMAL */
BASE HEX. DISP CPU.
HEX BASE OK
CYZSP A a C 0 E H L HL SP PSI
e •• e eeH ~8H 80H 8eli ellH 0EH EFH IlEEFH 00H 00'01i
1* THEN CHANGE BASE TO OCTAL *1
BASE oc. DI CPo
OCT BASE OK
CYZSP ABC D E H L HL SP PS0
110110 0eeo 000Q 01100 000Q 000Q 016Q 357Q 07357Q 080Q 0eee00,
1* r-.OW PLACE A S1I',PLE PROGRAM INTO MEMORY STARTlt,G AT LOCATION 10.
TJIlS PROGRAM WILL ALTER THE VALUE OF MEMORY CELL 200 BY ADDII\G
TO THE CURRENT VAU\U\LUE OF THE CELL. 11\ SYMBOLIC FORM. TPE p~o-
GRAM IS AS FOLLOWS ... LHI 0. LLI 200. l..l:lM. INS. LtlB. HLT.
THE LOAD opmATION BELOW IS A 'DUMMY' OPERATICt; so THAT n:r-:cnv IS
INITIALIZED PRO~ERLY. *1
LOAD I.
0Q LOAD OK
DISPLAY MEMORY 10 TO 20.
00012Q 000Q 000Q 000Q 000Q 000Q 000Q eB0Q 000Q 000Q 000Q 000Q
BASE DEC.
DEC BASE. OK
SET MEM 10 TO 20 • 00101110B I'" THIS IS LliI II *1
00110110B 2311l 1* LlI 200 *1
11001111B I'" LBM *1 000010008 1* INS *1
1III1001B 1* LMB *1 0 1* HLT *1
SET OK
01 ME 10 TO 20.


## Scan page 95

... 18 .46 •• 0 054 211 207 188 249 .81 0_6 101 054
DI M I. TO'28 CODE.
8801. LHl~"H LLl,C8H LaM INa LHB HLT LHl,.IH LLI
I" NOTE THAT THE • I· SEPARATES ELEtIUITS WHICH ARE _PART OF THE
SAME I~STRUCTION (THE SECON -D AND THIRD BYTES ARE ltJ HEX) .. ,
COIN 0C8H.
11 •• II •• S 318Q 28. C8K
I" WE CA~ NOW EXECUTE TH E PROGRAM BY SETTI~q THE PROGRAM CCU~TLR
TO LOCATION 18 "I
SET PC-I.8. DI· CPo
SET OK
CYZSP A 8 C D E H L HL SP PSI
88 •• 8 ..... 8 •••••• ,. 114 239 .3823 ....... ,18
SET OK
GO.
tILT CYCLE 56
DI CPU.
CYZSP ABC 0 E H L ilL SP pse
ee00 000"081 888 818 880"888*208*e0200 800.8e817
01 HEM 2.0.
88288 811
1* MEMORY LOCATION 210 HAS BEEN INCREMNTED -- NOV TURN ON THE
TRACE AND EXECUTE THE PROGRAM AGAIN .,
TRACE 0 TO 10 •• GO.
TRACE OK
•• 88 1.8 8'1 •••• 18 I ••• 80 288 8.208 808 88811
liLT
liLT CYCLE 61
'* CPU MUST FIRST BE INITIALIZED TO ZERO .1 SET CPU. GO.
SET OK
80 •• 8...... 101 8.. 888 0,8.,81"0888. 000 .. 80088
HLT
Ht.T CYGI.E 4
DI CPU.
CYZ5P ABC D E H L HL SP PSI
•••• ••• ea. ••• ••• 00. 088 ••• "88, ••• ..888
I. FORGOT TO SET PC - 18, TR' AGAI~ ./ SET CPU. PC-10. GO.
SET OK
•••• , •• '88 '.8 '8' •• , •• , .88 ,88.8 888.88818
LHI •
•••• • 88 ••••••• 88 8" 8.8 88. 08111 181*88012
LLI 211
•••••• , I •••••••• 8 •••••• 2.,.,82,8 .e8*11814
1.8"
8", •• e.8" 8 ••••••• , .,. 28 •• 82.e ••••••• 15
INB
88., e.,* •• 2 18 •••••••••• 2 •• "2e, ,.1*.8816
LM8
.... 181 '82 ... II. I •••• 8 2 •••• 281 ." ..... , 1
HLT
tILT CYCU; 4'
1* NOW TRY THE SAME EXECUTION WITH THE TRACE ENABLED OVER ONLY
PART OF THE PROGRAM *1
NOTRACE • TO I ••• TRACE 12 TO ._ •• ,.
TRACE OK
TRACE OK
SET CPU, PC-I •• -GO.
SET OK
8e0e 080*00e 008 000 000 008*000*00000 000*00012
LLI 20e
le00 08e e0e 808 100 188 e80 .. 200*e0200 0e0*80014
91
LBM
*0001 •• ' •• 83 888 000 000 080 200 00200 000*00017
JiLT
HLT CYCLE 4e
/* SWITCH BACK TO FULL TRACE .. / TR 0 TO 100.
TRACE OK
DISP _MEM 288.
88288 883
1* NOW RUN THE CPU FOR ONLY A FEW INSTRUCTIONS AT A TIME. l~ THIS
VAY THE EXECU TI0~ ~N BE MO~ITOREO EASILY .. /
GO 2.
GO OK
CYZSP ABC 0 E H L HL SP PS0
.el. 818 0e3 880 080 080 ee8 200 002e0 888 00017
tILT
HLT CYCLE 44
SET CPU~ pC-Ie. GO 2.
siT OK
GO OK
*008e .el •• e8 el0 80e 0e0 e01.010*e ••• 0 0ee*00810
LNI 8
lei. I •• ee8 ee8 ee. e00 08. e00 0e088 880 .. 00012
LLI 201
CYCLE AT 14
DI CPU.
CYZSP ABC D E H L HL SP PS0
101e .81 088 8., ,.0 III 110*28e*08200 800*e1014
GO 1.
GO OK
e001 lee 80e eee ell le0 el0 208 80200 000 80014
LBH
CYCLE AT 15
01 CPU.
CYZSP ABC D E H L HL SP PS0
18el Ile.0e3 .11 eel 8e8 118 208 81288 188.e0015
GO * •
8eee 81e 813 I •••• e e81 108 281 88281 ee8 00e15
INB
Ilee 008.,e4 lei I ••• 81 8e0 2el 80280 000"00016
LMB
0000 000 004 000 810 e00 030 200 00200 000*00817
HLT
tILT CYCLE 40
01 CPU.
CYZSP ABC D E H L HL SP PS0
0800 800 884 000 0e8 000 008 200 00200 000 00017
1* WE CAN SET BREAK POINTS IN THE CODE SO THT\T\AT EXECUTION STOPS
WHEN A PARTICULAR INSTRUCTION IS FETCHED. */
SET CPU.PC-II. TR 8 TO le0. REFER 12 TO 14 •
SET OK
TRACE OJ<
REFER OK
GO.
*0888 e8e*088 ee8 800 e80 001.800*88080 000*00818
LHI e
0e00 e80 e00 III ell 80e 888 81e 080e8 818*e8812
LLI 208
REFER AT 12
01 CPU.
CYZSP ABC D E H L HL SP PS0
8ee8 8ee 08e 011 eel lee 080 880 .'0'. 800 e8el2
1* THE EXECUTION CAN ALSO BE STOPPED WHEN THE PROGPAM REFERS
TO KEMORY LOCA!I


## Scan page 96

REFER 2.1. NOTRACE • TO I". SET cpu,pc-Ie. GO.
REFER OK
THAC&- OK
SET OK
RUER AT 14
DI CPU.
CYZSP ABC D E H L HL SP PS8
•• ,. ,.1 leI e ••••• Ie •••• *2 ••• el21. 81e ••• e14
01 HEM 14 CODE.
ell14 LBH
GO 1. 01 CPo
GO OK
CYCLE AT 15
CYZSP A 8 C D E H L HL SP PSI
Ille lee •• 15 III ••••••• ee 21. al21. 818 ••• ,15
,. THIS SHOWS THE VALUE FETCHED FROM LOCATION 21 ••
THE PROGRAM ON A STORE INTO LOCATION 2e. AS WELL ./
NOREF 2ee. ALTER 288. SET CP# PC-II. GO.
REFER OK
ALTER OK
SET OK
ALTER AT 16
DI CPU.
CYZSP ABC D E H L HL SP PS0
•• e01 e0'."6 e •• 108 .00 e •• 2.' ee2e. 8.,.e0,16
o M 16 co.
.1016 LMB
WE CAN STOP
,. THE REGISTER DUMP SHOVS THAT 6 WILL BE STORED AT LOCATION 200.
EXAMINE LOCATION 2.e, RUN THE KACHINE FOR ONE CYCLE. AND EXAMINE
THE CELL AGAIN .,
DI HEM 2 ••• GO 1. DI
01211 ,.5
GO OK
CYCLE AT 11
112.. 886
MEM 2ee.
,. NOV GET A COMPLETE MEMORY DUMP IN SINARY ./
01 ~ • TO 177Q SIN.
11"" ," •••• ,S .8.8.e •• B 8el ••••• 8 IIIIII.8S e.e81e81B IIIIIIIIS
... e6 ••• ,1 ••• 8 1 •• 8 ••• IB •••••••• S •••• e.8IB e.l.1118S Ileee.leB
1 •• 12 .8118118B 11.81 •• aa 11 •• 111IS 8"81.8.S 11111881B •• 08.000B
8ee18 .ll.111.S ••••••• 88 •• 11811.B ''' •• ,.,8 1888881.B el ••• I.e8
.8824 •••• 88 •• S •••• 88.8S •••••••• B •• e ••••• a 88.88.8IB •• 88.8.8B
'.198 •••• 888.S •••••••• 8 8' ••• 11.8 .8.888 •• 8 88 ••••• 88 .18.e.818
•• 2'4 .... ee •• 8 ••• 888.'S •••••••• B •• 8 ••••• S 8 ....... 8 8.8.e888B
.851' •• 8.88 •• B ••••• 8 •• 8
,. AND THEN PUNCH THE CODE 8ETWEEN LOCATIONS 18 AND 28 (WE WILL USE
THE CONSOLE AS THE OUTPUT DEVICE ) .,
••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••• •••••••• 8 BMI ..... ....,. SNNN .... NNY 8NNPUPPPIIIP' BNNNNNNNNF
BII1NPPNPPHF BPPNNPNNNF BI'I'N1IIPP!'P' BNNNNPNt.lNF
16 BP!'PPI'NNPF BNNNNNtlNNF BNNPNPPPNP' BNNNNNNNNF
BNNPPNPPNF 8NNNNNNNNF BNNNNNNNNF BNNNNNNNNF
••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••• ........
END.
SEOF'
CPU TI"E. 12.93 ELAPSED TIMEI 46112.13
NO EXECUTION ERRORS DETECTED
THIS EXAMPLE SHOWS A COMPLETE ASSEMBLY AND INTERP'8 EXECUTION
TYPE AS"J.DAT
• SAMPLE "CS-8 PROGRAM <PAGE 47 OF 8888 MANUAL)
START LLI 218
LHI 8
LOOP LAM
CPI 46
JTZ FOUND
CAL INCR
LAL
CPI 228
.JF'Z LOOP
FOUND RET
I NCR INL
RF'Z
INK
RET
END
.R ASH8
PLEASE TYPE INPUT FlLE NAME
ASMI
1e.8 INTEL ASSEMBLER
CPU TIME. 3 •. 72 ELAPSED TIME. 9.73
110 EXECUT 1011 ERRORS DETECTED
EXIT
tC
92
.RENAME FORI •• DAT • 'J,.OGOU.DAT# 'OR21.DAT. LOG81.DAT
FILES RENAMED.
LOGOU .DAT
LOGBI.DAT
~TYPE FOR2I!I.DAT
SYMBOL VALUE
11 START 888'8
21 LOOP 81884
31 FOUND ... 23
41 INCR 1111824
•••••••••••••••••••••••• tC
fC
.TYPE DORfU
TYPE FOR21 .DAT
•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••• •••••••• •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••• ••••••••
8 8NNPPNPPNF 8PPNNP~NNF' BN~PNPPPNf BN~NNN~NNF
BPPNNNPPPF BNNPPPPNNF BNNPNPPPNF BNPPNPNNNF
8 BNNNPNNPPT 8NNNNNN~NF BNPNN~PPN' BNNNPNPNNF
SNNNNNNNNF BPPN~~PNF BNNPPPPN~' 8PPNPPPNNF
16 BNPNNPNN~7 8NNNNNPNNF BNNNNNNNNF BNNNNNPPPF'
BNNPPNNNNF BNNNNPNPPf BN~~NPNNNF BNNNNNPPPF
24 B~NNNNNNNF BNNNNNNNNF BNNNNNNNNF BNNNNNNNNF
SNNNNNNNNF BNNNNNNNNF 8NNNN~~NNT BN~NNNNNNF
32 8NNNNNNNNF ~NNNNNNNNF BN~tC
THE CODE FILE MUST BE TBRMINATED BY A $ IN THE INPUT -- USE TECO
TECO fOR21 .DAT


## Scan page 97

*., 32 SS
..,UTSS
32 BJlNNN., .. tIF BNIolIiNNtolMtIF BNNIINNNNtIF BNt.lNNNNtoiNF
• R Ir.<T8
LOADING
LOADER I "K CORE
EXECUTIOt.l
BEGI~
1* THE SYMBOL TABLE ANt> CODE VILL NOW Bi; LOADED *1
LOAD 6 7.
32 LOAD OK
DJ SYMBOLS.
""""""g "0000 0"00K START
""0004Q """8~ 10"4H LOOP
80"023Q 0"819 1113H FOUND
00""24Q 01.28 ""14H I NCR
01 SYMBOL LOOP.
"e"e'4Q 88884 ""04H LOOP
01 SYMBOL :EAP.
(00'21) ERROR 23 NEAR ZAP
'* ERROR MESSAGE HAS LINE WMBER ERROR WMBER AND ITEM IN ERROR. IN
THIS CASE. THE SYMBOL COULl) NOT BE FOUND '5 THE TABLE *1
01 SY 13H.
FOUND
DI SY 12H.
FOUNO-I
DI SY 8.
LOOP.4
01 SY *.
STA."lT
1* NOW TAKE A LOOK AT MEMORY IN HEXADECIMAL AND IN C~DE FORY~T *1
01 HEM 0 TO 100 HEX. MEM 0 TO 100 CODE.
00000 368 C8R 2ER 10H C1H 3eH 2EH 68H 13H 88H 46H 14H "0H C6H 3CH DCH
00016 48H 04H 0eH 01H 308 0BH 28H 07H 08H 00H 00H e0H 0eH 00H 08H 00H
00032 08H 00K 80H '0K 8eK 00H 80H e8H 88H 00H 00H 00H 80H 08H 00H 00H
00096 0'H '0H 00K 10H .0H
00088 LLI~caH LHI.0"H LAM CPI.2EH JTZ.13H."0H-CAL.14H.00H LAL CPI,OCH
00016 JFZ.84H.08U RET INL RFZ INK RET HLT 8LT HLT HLT 8LT HLT HLT HLT
08032 HLT HLT HLT HLT HLT KLT HLT HLT HLT HLT HLT HLT HLT HLT HLT HLT
00096 RLT HLT HLT HLT HLT
1* THIS PROG~ SEARCHES FOR A 46 STARTING AT LOCATION 200 IN
KEMORY. WE VILL START BY PLACING A SEQUENCE OF WMOERS IN THESE
LOCATIONS *'
SET MEM 200 TO 210 a 43 46 48 28H 1111"0'B. 01 HEM 200 TO 210.
93
SET OK
00200 043 046 048 032 12" 843 046 048 032 120 043
1* GET A COMPLETE TRACE OF THE PROGRAM *1 TR 9 TO 9100 •
TRACE OK
GO.
CYZSP ABC 0 E H L HL SP PS0
*0000*000*000*000*000*000*000*000*000"0*0'0*00000
1.1.1 2.S
.... .08 8.0 000 000 8'0 001*210*.0200 0 •• *00002
LHI 0
8'0" 0S" 8.. 080 00. 000 000 200 00200 000*00004
LAM
08.'.043 .88 008 088 08S,080 288 88288 808*00005
CPI .6
*1018 843 0.0 00. 88. 888 888 280 00288 08"*.8881
4ITZ 19
III. 143 011 100~'. 888 88. 280 802.8 "8 • .e881.
CAl. 28
1.11 '43 ••• 888 ••• 80. 00e 280 88280*001*00013*88828
INL
*1811 .43 8" 0.8 •• , 81. 8.0*201*80281 801 01013*08821
RFZ
1111 843 '.8 188 880 088 080 281 802"1*'00 00813
LAL
1011$201 080 080 000 000 000 201 00201 000*00014
CPI 22O·
CYZSP A B C D' E H L HL SP PS0
1011 201 80O 800 000 O00 000 201 00201 000*00816
JFZ 4
1011 201 ""0 "00 008 "00 000 201 00201 000*0"804
LAM
1011*046 000 000 0"8 880 000 201 00201 800*00005
CPI 46
*0181 846 008 080 008 108 000 201 00201 000*"0007
JTZ 19
0101 046 088 "I" 800 80O 000 201 00201 080*00019
RET
EXECUTION ERROR 2 AT 22
/* THE ERROR OCCURS BECAUSE THE PROGRAM TERMINATES WITH A RET
'RATHER THAN A HLT. FIX TH E INSTRUCTION IN MEl'lORY *1
01 MEl'l 19.
00019 007
01 M"'"'El'l 19 COD.
"0019 RET
SET M 19 s 0. DI MEM 19 CO.
SET OK
00019 HU
NOTR 0 TO 100. SET CPU. GO.
TRACE OK
SET QK
HLT CYCLE 111
01 CPU.
CYZSP ABC D E H 1. HL SP PSI
8.8. 846 888 .8. 0.8 ••• I" 2 •• 88281 888 "0819
~* THE PROGRM TERHUIATES CORRECTLY AFTER 111 MACHllIE STATES *1
TIME.
TIME-II 1
/* SET SELECTIVE BREAK POINTS */


## Scan page 98

REF START. INCa.l, LOOP. SET CPU. GO.
HUla OK
SET OK
REFER AT •
DI Sy ••
START
G.
REFER AT 4
01 SY .. GO.
LOOP
REFER AT 21
DI SY -. GO.
INCR+I
REFER AT' 4
D SY.
0000010 18888 1800H START
0000040 00.04 8084H LOOP
0000230 08819 0013H FOUND
0000240 .0020 0014H INCR
NOREF START TO INCR+S.
REFER OK
/_ SET SELECTIVE TRACE POINTS (TRACE AND REFER POINTS CAN bE
IN EFFECT
AT THE SAME TIME. 11" DESIRED) -/
TR START. LOOP. FOUND. R~FER FOUND. GO.
TRACE OK
REFER OK
_1011_201 000 000 000 000 01118 2.1 8.201 000*00004
LAM
_,,.01*046 ... ••• • 1 • " .. ••• 2111 08a.1 810-80819
HLT
REFER AT 19
01 CPo
CYZSP A B C 0 E H L HL SP PSI
I/JIII 846 .. I 8 •• eee ••• ee. all 80201 080 ••• 19
SET CPo GO.
94
SET OK
.a00IUfJIIl 1.1 18. .ee 888 IIIJIh,e,...,801 11 .. , ....
LLI 28.
eeelll III 8Ie eee aee 80e ae.,.211.eI2.1 " ... Ii.e. LAM
.le.h211 I" eee eee Ila 0."*20 .... 201 11188 ate04
LAM
.1111111.e46 e •• eee eel • •• eee 2.1 11281 ., .. 18119
HI.T
REYER AT 19
GO.
1111 '46 1118 H. 1.1 ell .88 2., •• 281 e.8 81819 HLT
HLT C;YCU 11"7
/. THE ONLY REMAINING COMMANDS TO ILLUSTRATE ARE HTHE SET AND
IDISPLAY
PORTS COMMANDS .,
01 PORT 4.
P4-8
01 PORT 4. PO 3. PO "7 TO leQ.
P4-,
P3-0
P7-0 P8-fIl
01 PO 2f1l TO 2S.
P2B-. P21-0 P22-' P23-. P24-1 PiS-.
SET PORT S - IlelllflleB. PO 18H • SSO.
SET OK
01 POR S TO 17.
PS-204 P6-0 P7.e P8-e P9-1 PI'-I PII-' P12-0 P13-1 PI4-' P1S-0
P16:45 P
17"0
END.
SEOF'


## Scan page 99

APPENDIX IV
TELETYPE MODIFICATIONS
The SIMB-01 microcomputer systems and associated software have been designed for interface to a
model ASR 33 teletype wired in accordance with the following description.
The ASR 33 teletype must receive the following internal modifications and external connections:
Internal Modifications
1. The current source resistor value must be changed to 1450 ohms; This is accomplished by moving a
single wire. (See Figures 5 and 6.)
2. A full duplex hook-up must be created internally. This is accomplished by moving two wires on a
terminal strip. (See Figures 4 and 6.) .
3. The receiver current level must be changed from 60mA to 20mA. This is accomplished by moving a
s~ngle wire. (See Figures 4 and 6.)
4. A relay circuit must be introduced into the paper tape reader drive circuit. The recommended circuit
consists of a relay, a resistor, a capacitor and suitable mounting fixture. An alternate circuit utilizes
a thyractor for suppression of inductive spikes. This change requires the assembly of a small "vector"
board with the relay circuit on it. It may be mounted in the teletype by using 'two tapped holes in
the mounting plate shown in Figure 1. The relay circuit may then be added without alteration of
the existing circuit. (See Figures 2, 3, and 6.) That is, wire "A", to be connected to the brown wire
in Figure 2, may be spliced into the brown wire near its connector plug. The "line" and "local" wires
must then be connected to the mode switch as shown. Existing reader control circuitry within the
teletype need not be altered.
External Connections
1. A two-wire receive loop must be created. This is accomplished by the connection of two wires between
the teletype and the "SIM" board in accordance with Figure 6.
2. A two-wire send loop similar to the receive loop must be created. (See Figure 6.)
3. A two-wire tape reader loop connecting the reader control relay to the "SIM" board must be
created. (See Figure 6.)
Figure 1. Relay Circuit (Alternate)
95


## Scan page 100

Figure 2. Distributor Trip Magnet Figure 3. Mode Switch (Rear View)
Figure 4. Terminal Block Figure 5. Current Source Resistor
96


## Scan page 101

(J
,---
I I[
ITJ}
~,
I 12-0J<. LI ___ -'
I W~Ee:LOCI::. 3002101A.B L ______ _
I
I
I
I
-.J
ALTE.lC::fJ A. TE 'I2.E.Lt:. Y C \12.C.UIT
",=>EE ~Ic" I
o
~~-----+----4----~--------~
w
~
a u S5
tJOTE..o;:,', Ut-JLC.~ OT~IL...~\lJt":.E:. SPL<:'l~le:.D
Q:> CW!::>TOME:"-' E."-TE..I2.I..JA.L.. COI..JI..JE.<:..TIO ..... ",
IT:>- Iil:. ..... "" W'T"' ..... D"""I_lE.O LI"-1E:? g<:.PeE..-:;,E.....,T~
CU<OTO\.l\£:.e e.~UII2';::D 1-010 Dl FleA.,'? ..... "50.
1M IS INTERNAL MODIFICATION
EC IS EXTERNAL CONNECTION
MODE
SWITCH
MOUNT
REED
RELAY
CAPACITOR ---1>-------'
CURRENT
o
SOURCE ---1----1 ~ ~ ~ I
RESISTOR DOG 0
POWER -----1----1 f t; ®
SUPPLY
VIO '20 ""a...
;::'Ueee:NT ",=>OUec.e: IZE'::>I':>TOI2.
~EE 1"1.::,,·5
~'~ ,r-~-+--- e,1...I(; BI...~
_ f----~(~~==t==-:v.J;:I-l~T:---....:::..:=-=----------(, r,;1~~ 111'1 A..C
Wi-IT W
Figure 6. Schematic
I
~EY BOAQD
PQUJTEI2 UNIT
DISTeIBuTORi'
TI2IP MA6"-JET
A."=:'5EMBLY
o
i-t10DE 'SWITCH
(FRONT" VIEw)
"",ce: ~Ic... :!>
TAPE
'KEADEI2
TERMI NA L --+-C~==::J
STRIP ~~i------~------------------------------------~------~-J
TOP VIEW
TELETYPE MODEL 33TC
Figure 7. Block Diagram
97


## Scan page 102

APPENDIX V. PROGRAMM'ING EXAMPLES
A. Sample Program to Search A String Of Characters I n Memory Locations 200-219 For A Period
MNEMONIC OPERAND
Start: LLI 200
LHI 0
Loop: LAM
CPI "" •
JTZ Found
CAL INCR
LAL
CPI 220
JFZ Loop
Found: RET
INCR: INL
RFZ
INH
RET
EXPLANATION BYTES
Load L with 200
Load H with 0
Fetch Character from
Memory
Compare it with period
If equal go to return
Call increment H&L
subroutine
Load L to A
Compare it with 220
If unequal go to loop
Return
Increment L
Return if not zero
Increment H
Return
101·103
INITIALIZE
H & L TO 200
104
2
2
2
3
3
1
2
3
104 FETCH CHARACTER
.----_.. FROM MEMORY
IH 110 L ADDRESS)
LOCATION
100
101
102
103
104
105
106
107
108
109
110
111
112
113
114
115
116
117
118,
119
60
61
62
63
Subroutine to Search for Period.
98
ROM CODE COMMENT
00110110
11001000 (200)
00101110
00000000 (0)
11000111 ASC II
00111100 ASC II
00101110 (. )
01101000
01110111 (119) 00000000
01000110
00111100 (60)
00000000
11000110
00111100
11011100 (220)
01001000
01101000 (104) 00000000
00000111
00110000
00001011
00101000
00000111
(.)


## Scan page 103

B. Teletype and tape Reader Control Program (A0800)
BEGIN LAl 1
OUT 12B
XRA
OUT 138
CAL TAPE
..iMP BECIN
TAPE LAI I
OUT 138
CAL TTYDI
TTY HLT
CAL TTYD2
XRA
OUT 13B
I~P OB
LCI 255
XRC
OUT 128
LEI 2118
TTYl~ CAL TTYDl
INP OB
LCI 255
}(HC
OUT 12B
RAR
LAB
RAR
L8A
I~E
..JFZ TTYI:-.J
LA8
OUT 11 B
SUI 128
LBA
CAL TTYDI
LAI 1
OUT 128
RET
TTYD1 LDI 115
ST IND
JFZ ST
RET
TTYD2 LDI 186
ST2 IND
JFZ STa
RET
END
SUPPRESS TTY
OUTPUT 2
CLEAR AC
OUTPUT 3 - TAPE READER CO'JTROL
CALL FOR TAPE READER CONT. RT·
TAPE READER ENABLE CODE
OUTPUT 3 - ENABLE TAPE READER
TAPE READER CO~TROL DELAY
WAIT FOR TTY START PULSE
TTY' DELAY - 4.468 ~SEC.
TAPE READER ~ISAELE CODE
OUTPUT 3. DISABLE TAPE READER
I~PUT O. READ START PULSE
CO~PLEMENT TTY START PULSE
EXCLUSIVE-OR .REC. C
OUTPUT 2. OUTPUT START PUCSE
TTY rATA SAMPLING COUNTER
TTY DELAY - 9.01~ MSEC.
READ TTY DATA I'JPUT
COMPLEMENT TTY DATA
OUTPUT 2. TTY DATA OUT
ST'JRE TTY DATA
LOAD TTY DATA TO REC. B
LOAD AC TO REG. B
E = E + 1
JUMP IF ZERO FIF IS NOT SET
LOAD REG. B TO AC
OUTPUT 1. TTY CHARACTER
REMOVE PARITY BIT
STORE TTY INPUT DATA
SUPPRESS TTY
9.012 MSEC. DELAY
D = D ... 1
4.468 MSEC. DELAY
D = D ... 1
C. Memory Chip Select Decodes and
Output Test Program (A0801)
BEG Il'J LAI 15
OUT lOB
OUT liB
OUT 12B
OUT 13B
OUT I11B
OUT 15B
OUT 16B
OUT 17B
CAL DELAY
CAL DELAY
CAL DELAY
CAL DELAY
XRA
OUT lOB
OUT llB"
OUT 12B
OUT 13B
OUT IIIB
OUT 15B
OUT 16B
OUT 17B
LCI 2110
1.1.1 2528
LHI 0
CSTEST LAH
OUT lOB
LAL
OUT liB
XRA
LMA
LOAD 15 TO AC
WRITE TO OUTPUT 0
CLEAR AC
LOAD 2~O TO REG. C
LOAD 25~B(OCTAL) TO REC. C
LOAD 0 TO REC. H
LOAL' H TO AC
LOAD ,_ TO AC
CLEAR AC
WRITE AC TO ME~ORY
99
CAL DELAY
CAL DEl.AY
INH H • H _+ I
INC C • C +1
.JFl. CSTEST
.JMP BEGI~
DELAY LDI 0 LOAD 0 TO REe. D
Dl IND D • D ... 1
JFZ Dl
RET
END
D. RAM Test Program· (A0802)
BEGIN LAI 0
OUT 108
OUT lIB
OUT 12B
OUT 138
L81 8
LCI 0
LHI 8
1.1.1 0
l.Ml XRA
LM2 LMA
INL
CPL
JFZ LM2
HJH
LAI 12
CPH
JFZ LMI
LHI B
REPT4 LAB
OUT lOB
REPT3 LLC
LAC
OUT 13B
LAI 255
LMA
CPM
JFZ ERROR
REPT2 LAH
OUT 108
HEPTS XRA
INL
CPL
JTZ HEPTI
LAL
OUT liB
XRA
CPM
.,WZ ERROR
JMP REPTS
REPTI INH
LAI 12
CPH
JTZ CONT
XRA
CPM
JFZ mROR
JMP REPT2
CO~T LHB
XRA
INC
CPC
JFZ REPT3
INS
LHB
LAI 12
CPB
JFZ REPT4
JMP BECIN
ERROR LAI 240
ADS
OUT lOB
LAL
OUT liB
LAM
OUT 128
LAC
OUT 138
HLT
E~D
LOAD 0 T·) AC
WRITE TO OUTPUT 0
WRITE TO OUTPUT 1
WRITE TO OUTPUT 2
WRITE TO OUTPUT 3
LOAD 8 TO REC~ B
LOAD 0 TO REe. C
LOAD 8 TO REC H
LOAD 0 TO REe. I.
CLEAR AC
LO~D AC TO MEMORY
1. = 1. + 1
AC - L
JUMP IF AC I S· !\JOT ZERO
H = H + 1
LOAD 12 TO AC
AC-H
JU~P IF AC IS ~OT ZERO
LOAD REC. B TO AC
LOAD REe. C TO L
LOAD REe. C TO AC
LOAD 255 TO AC
LOAD AC TO MEMORY
AC-M
JUMP IF AC IS ~OT ZERO
LOAD REC. H TO AC
CLEAR AC
1. = L ... 1
AC ... 1.
JUMP IF AC=O
LOAD REe. 1. TO AC
CLEAR AC
AC-M
JU~P IF AC IS NOT ZERO
H = H +
LOAD REC. E TO H
C • C +
AC - C
B = B ...
LOAD REe. P TO H
AC-B
LOAD 240 TO AC
AC=AC+B
LOAD REC. 1. TO ~C
LOAD MEMORY TO AC
LOAD REG. C TO AC


## Scan page 104

E. Bootstrap Loader Program
(Intel Tape Numbers A0860, A0861, A0863, Nov. 16, 1972)
o
o 6
2 85
3 168
87
5 0
6 68 206
9
9
9
9
i
1 B7
12 0
13 30 194
15 24
16 72 15 0
19 168
20 87
21 85
22 38 248
24 70 55 0
27 65
28 44 255
30 85
31 26
32 193
33 26
34 200
35 32
36 72 24 0
39 193
40 36 127
42 200
43 70 55 0
ta6 6 I
48 85
49 7
50 192
51 192
52 192
53 192
54 192
55
55
55
55 30 121
57 24
58 72 57 0
61 7
62
62
62
62 199
63 20 48
65 200
66 49
67 199
68 20 48
70 224
71 104 82 0
74 r, 10
76 129
77 200
78 33
79 68 71 0
82 49
113 199
84 20' 48
86 224
117 104 98 0
90 6 lOa
92 129
93 200
94 33
95 68 87 a
98 7
99
99
99
99 46 11
101 54 241
103 22 0
105 193
106 20 100
108 96 115 0
111 16
112 68 106 0
115 14 100
In 129
118 200
119 6 48
121 130
122 248
123 22
125 193
126 20 10
128 96 135
ORG a
BECl:-l LAl 1
OUT 12S
XRA
OUT 138
EADER CONTROL
HLT
JMP START
*
SUPPRESS TTY
OUTPUT 2
CLEAR AC
OUTPUT 3 - TAPE R
*TELETYPE TAPE READER II. I/O CO'lTROL
* TAPE LAI 1
E CODE
OTJT 138
TAPE READER
TTY HLT
T PULSE
C.
ST2
LDI 194
I:-lD
JFZ ST2
XRA
I.E CODE
OUT 13B
TAPE READER
OUT 12B
START PULSE
LEI 2ta8
COUNTER
TTYIN CAL TTYDI
SEC.
UT
TA
A OUT
REG. 8
INP 08
XRI 255
OUT 12B
RAR
LAB
RAR
LBA
INE
JFZ TTYIN
15 NOT SET
LA8
ATA
*
NDI 127
LBA
CAL TTYDI
LAI 1
OUT 128
RET
LAA
LAA
LAA
LAA
LAA
*TTY DELAY - 8.7 MSEC.
'" TTYDI
ST
'"
LDI 121
IND
JFZ ST
RET
*8CD TO BINARY CONVERSION
* BCDBIN LAM
SUI AS
LBA
DCL
LAM
SUI 48
LEA
. BBI JTZ BB2
IJAI 10
ADS
L<'A
DCE
JMP SSI
BB2 DCL
LAM
SUI 48
LEA
B83 JTZ 8E4
LAI lOa
ADB
LEA
DCE
JMP 8B3
BB4 RET
* *BINARY TO BCD CONVERSION
'" 8INBCD LHI II
LLI 241
BNBD LCI a
LAB
BDI SUI 100
JTC BD2
INC
JMP BDI
802 LEI 100
8
ADB
L8A
LAI 48
ADC
LMA
LCI
LA8
8D3 SUllO
JTC BD4
T4PE RE4DER E'lePL
OUTPUT 3 - E'l"lBI.E
WAIT FOR TTY STAR
TTY DELAY - 4 !'ISE
TA?E READER DI Sl>,B
OUTPUT 3, ~ISABLE
OUTPUT 2, OUTPUT
TTY DATA SAMPLING
TTY DELAY - 8.7 M
READ TTY DATA INP
CO!'lPLEMENT TTY DA
OUTPUT 2, TTY OAT
STORE TTY ~TA
LOAD TTY DATA TO,
LOAD AC TO REG. 8
E .. E + 1
JUMP I F ZERO F IF
LOAD REG. 8 TO AC
REMOVE PARITY BIT
STORE TTY INPUT D
SUPPRESS TTY
1II0P
f!.7 MSEC. DELAY
D-D+I
LOAD LSD TO A
AC-AC-A8
LOAD A TO B
1. .. 1.-1
LOAD M TO A
A-A-A8
LOAD A TO E
IF A-O JUMP
AC"10
AC .. AC+B
LOAr: AC TO REC. S
E-E-I
L=L-I
LOAD M TO A
A=A-48
LOAD A TO E
AC-l00
AC=AC+B
LOAD AC TO REG. B
E=F-l
CLEAR REG. C
AC-AC-IOO
JUMP IF AC<IOO
C .. C+I
LOAD 100 TO REC.
AC=AC+8
LOAD AC TO REG. B
A-A+48
A-A+C
LOAD A TO MEMORY
CLEAR REC. C
LOAD B TO A
AC=AC-10
JUMP IF AC<10
100
131 16
132 68 126 0
135 14 10
137 129
138 200
139 6 A8
141 130
142 A8
143 248
144 6 48
IA6 129
147 48
148 248
1'19 7
150
150
150
150 22 253
152 70 55 0
155 16
156 72 152 0
159 168
160 85
161 22 248
163 70 55 0
166 193
167 85
168 26
169 200
170 6 0
172 26
173 129
174 200
175 16
176 72 163 0
179 70 55 0
182 6
184 85
185 7
186
186
186
186 lA 141
188 70 ISO 0
191 111 138
193 70 ISO 0
196 7
197
197
197
197 lA 191
199 70 150 0
202 7
203
203
203
203 70 166 0
206 lA 194
208 70 ISO 0
211 70 12 0
21A 249
215
216
216
216
216 70 186 0
219 14 193
221 70 150 0
224 70 186 0
227 22 253
229 70 12 0
232 48
233 2A9
234 16
235 72 229 0
236
239
239
239
239 70 9 0
242 6 66
2AA 165
245 72 239 0
248 46 11
250 SA 255
252 6 2116
254 248
255 70 9 0
258 SA 250
260 6 80
262 185
263 lOll AO
266 6 7f1
268 185
269 104 49
272 6 66
274 185
275 104 2A8 0
278 6 127
INC
JMP BD3
8D4 LBI 10
ADB
L8A
LAI A8
ADC
INL
LMA
LAl 48
ADB
INL
LMA
RET
'" *TTY OUT!'UT ROUTI NE
TTYOUT LCI 253
TTYO CAL TTYDI
C.
I:-lC
JFZ TTYO
XRA
OUT 12B
LCI 248
TTYI CAL TTYDI
MSEC.
RY
ZERO
MSEC.
LA8
OUT 128
RAR
L8A
LAI 0
RAR
ADB
LBA
INC
JFZ TTYI
CAL TTYDI
C .. C+1
B .. 10
AC"AC+B
LOAD AC TO REC B
A=A+48
A-A+C
L"L+l
LOAD A TO M
A=A+48
A=A+8
1. .. 1.+1
LOAD A TO M
RETUR~
C=253
DELAY - 9.012 MSE
C=C+I
TTY START PULSE
REG C=2118
TTY DELAY ~ 9.012
LOAD DATA TO e.c
OUTPUT DATA
STORE DATA 1:.1 CAR
LOAD A TO P
AC = 0
RESTORE Dl>,TA BIT
RESTORE DAT4
STORE
C=C+l
JUMP I F AC I S ~O T
TTY DELAY - 9.012
LAI 1 A-A+ 1
OUT 12B SUPPRESS TTY
RET
'" *CARRIAGE RETURN & LINE FEED
* CRLF LSI 215B CARRIACE RETURN -
CR
LF
'"
CAL TTYOUT
LBI 212B
CAL TTYOUT
RET
.ERROR SICNAL
'" ERROR L81 277B
*
CAL TTYOUT
RET
*TYPE B AND I DENTI FY RAl'! BANK
* ADRESH CAL CRLF
NPUT
MORY
*
L8I 302B
CAL TTYOUT
CAL TTY
LMB
RET
TYPE CR
LINE FEED - 1.1"
TYPE 1.1"
(1)
TYPE (1)
LOAD (B)
TYPE <1On
CALL FOR TTY K8 I
STORE INPUT IN ME
.TYPE A AND IDENTIFY I~ITIAL AND FHIAL LOCATIO:-l
* ADRESL CAL CRLF
LBI 301B
CAL TTYOUT
ADI GAL CRLF
LCI 253
AD2 CAL TTY
NPUT
TO M
ZERO
*
INL
LMB
INC
JFZ AD2
RET ..
*DATA IWUT ROUTINE
'" DATAIN CAL TAPE
CB)
LAI 102B
CPB
JFZ DATAIN
DATAl LHI 11
1.1.1 255
LAI 248
LMA
NTR
DATA2 GAL TAPE
LLI 250
ATA
LAI 120B
CPB
JTZ PDATA
LAI 116B
CPB
JTZ NDATA
LAI 102B
CPS
JTZ DATAl
T INSTRCTION
LAI 177B
LOAD CA)
TYPE CA)
C=253
CALL FOR TTY KS I
1."1.+1
LOAD TTY KP. INPUT
C=C+ I
JUMP IF C IS NOT
READ TAPE
LOAD (8)
SEARCH FOR (B)
JUMP IF IT IS ~OT
H=11
1.=255
DATA BIT COU'fTER
STORE DATA BIT CO
READ TAPE
MEMORY LOC. FOR "
l.OAD (P)
SEARCH FOR (P)
IF (P) STORE (I)
LOAD (1'1)
SEARCH FOR (N)
IF eN) STORE (0)
LOAD <B)
SEARCH FOR <B)
IF CB) DELETE LAS
LOAD <RO)


## Scan page 105

2$0 185
281 72 34
284 70 90
287 682-S5 0
290 70 98 1
293 68 89
296 6 1
298 26
299 199
300 18
301 248
302 68 53
305 168
306 199
307 18
308 248
309 54 255
311 207
312 8
313 249
314 72 255 0
317 70 9 0
320 6 70
322 185
323 104 88
326 6 66
328 185
329 104 248 0
332 6 127
334 185
335 72 34
338 70 90
341 68 255 0
344 168
345
346
346
346
346 192
347 192
348 192
349 192
350 192
351 192
352 192
353 7
354
354
354
354 14 160
356 70 150 0
359 14 198
361 70 150 0
364 14 197
366 70 150 0
369 70 186 0
372 54 253
374 207
375 70 '99 0
378 38 253
380 49
381 49
382 199
383 4 128
385 200
386 70 150 0
389 48
390 32
391 72 126
394 6
396 7
397
397
397
397 46 11
399 54 240
401 70 203 0
404 70 216 0
407 70 224 0
410 70 186 0
413 54 246
415 70 62 °
418 209
419 49
420 70 62 0
423 49
424 199
425 20 48
427 4 8
429 54 252
431 248
432 48
433 249
434 48
435 250
CPS
JFZ FI'IEROR
T
CAL RUBOUT
OUTINE
JMP DATAl?
FI'IEROR CAL FORl"AT
RROR ROUTlm
JI'IP OATAEN
PDATA LAI 1
(1)
RAR
LAM
RAL
LMA
JMP DATA3
NDATA XRA
Y
LAM
RAL
LMA
DATA3 LLI 255
LSM
I!IIB
TER
LMS
JFZ DATA2
ZERO
FDATA CAL TAPE
UT
IS (n
LAI 106S
CPB
JTZ DATA4
LAI 102B
CPS
JTZ DATAl
UCTION IF IT IS (S>
LAI 177B
CPB
JFZ FMEROR
(RO>
CAL RUBOUT
TINE
JMP DATA2
DATA4 XRA
Y
DATAEN RET
* *RUBOUT ROUTINE
* RUBOUT LAA
*
LAA
LAA
LAA
LAA
LAA
LAA
RET
*FORMAT ERROR ROUTINE
* FORMAT LBI 240B
CAL TTYOUT
LBI 306B
CAL TTYOUT
LBI 305B
CAL TTYOUT
LISTA CAL CRLF
PRINTA LLI 253
LBI'.
CAL BINBCD
LEI 253
DCL
DCL
FMl LAM
o
*
ADI 128
LBA
CAL TrYOUT
INL
INE
JFZ FMl
LAt 1
RET
SEARCH FOR RUBOUT
JUMP IF NOT RUBOU
CALL FOR RWOUT R
CALL FOR FORMAT E
REPLACE (P> WITH
ROTATE RIGHT
ROTATE LEFT
CLEAR AC AVU CARR
ROTATE LEFT
LOAD /'! TO B
INC DATA BIT COUN
JUMP IF B IS NOT
CALL FOR TAPE I NP
LOAD(n
SEARCH FOR (F>
STORE DATA IF IT
LOAD CB)
SEARCH FOR (B>
DELETE LAST INSTR
LOAD (RO)
SEARCH FOR (RO)
JUMP IF IT IS NOT
CALL FOR (RO) ROU
CLEAR AC AND CARR
NOP
LOAD esp>
TYPE esp>
LOAD cn
TYPE en
LOAD eE)
TYPE (E)
L:253
LOAD MEMORY TO B
BIN TO BCD CONV
E .. 253
L:L-l
L"L-l
LOAD MSD TO AC
AC-AC+12~
LOAD AC TO B
TYPE BCD LOCATION
E=E+l
JUMP IF E IS NOT
FORMAT ERROR FLAG
*ENTER ADDRESS AND CONVERT THEM INTO BINARY REP.
* ENTERA LHt 11
LLI 240
ENTERH CAL ADRESH
ENTERL CAL ADRESL
RESS
SS
Y
ARY
M
CAL ADI
CAL CRLF
LLI 246
CAL BCDSIN
LCB
DeL
CAL BCDBIN
DeL
LAM
SUI 48
ADI 8
LLI 252
LMA
INL
LMB
ES IN M
INL
LMC
H-l1
L:240
ENTER BANK NO.
ENTER INITIAL ADD
ENTER FI NAL ADDRE
L~246
FINAL ADRES-BINAR
LOAD S TO C
L:L-l
INITIAL ADRES-BIN
L"L-l
AC-M
AC-AC-48
AC-AC+8
L-252
STORE SA:m NO IN
L:L+l=253
STORE INITIAL ADR
L .. L+1-254
STORE FINAL ADRES
436 7
437
437
437
437 46 11
439 51.1 252
441 223
442 48
443 199
444 81,
445 240
446 235
447 7
448
448
448
448 46 11
450 54 254
452 199
453 49
454 191
455 104 205
458 215
459 16
460 250
461 7
462
462
462
462 70 186 0
465 14 170
467 70 150 0
470 70 12 0
473 '6 84
475 185
476 104 3 2
479 6 69
481 185
482 104 31 2
485 6 82
487 185
488 104 6 2
491 6 67
493 185
494 104 77 2
497 6 76
499 185
500 104 94 2
503 6 80
505 185
506 104 181 2
509 70 197 0
512 68 206 I
515
515
515
515 70 141 1
518 70 23,9 0
521 26
522 96 206
525 54 250
527 215
528 70 181
531 194
532 83
533 248
534 70 192 1
537 104 206 1
540 68 6 2
543 46 11
545 54 240
547
547
547
547
547 70 203 0
550 70 186 0
553 199
554 20 48
556 4 8
558 23'2
559 6 8
561 189
562 104 0
565 6 9
567 189
568 104 0 9
571 6 10
573 189
574 104 0 10
577 6 11
579 189
, 580 104 0 11
583 70 197 0
586 68 206 1
589 46 11
591 S4 252
593 223
594 24
595 251
596 48
597 168
598 248
599 48
600 6 255
602 248
603 68 6 2
101
IN M
RET
*SET ADDRESS. TO 1101 P.MI
* SETMA LHI 11
OUT 0
*
LLI 252
LDM
INL
LAM
OUT lOB
LLA
LHD
RET
*ADDRESS CHECKI NC
* ACHECK LHI 11
TO AC
LLI 254
LAM
DeL
CPM
JTZ CHECK
LCI'!
INC
LMC
CHECK RET
* *PROGRAM BEG I NS
* START CAL CRLF
NPUT
*
LBI 252B
CAL TTYOUT
CAL TTY
LAI 124B
CPS
JTZ TAPEIN
LAI 105B
CPB
JTZ EXECUT
LAI 122B
CPS
JTZ READIN
LAI 103B
CPS
JTZ CONTIN
LAI 114B
CPB
JTZ LISTIN
LAI 120B
CPB
JTZ PROGRM
CAL ERROR
JMP START
*LOAD DATA INPUT TO 1101 RAM
* TAPEIN CAL ENTERA
READIN CAL DATAIN
OUTINE
S
RY
EXECUT
BANKO
BANK 1
BANK2
BANK3
RAR
JTC START
LLI 250
LCM
CAL SETMA
LAC
OUT liB
LMA
CAL ACHECK
JTZ START
JMP READIN
LHI 11
LLI 240
EQU 4000B
EQU 4400B
EQU 5000B
EQU 5400B
CAL ADRESH
CAL CRLF
1.AM
SUI 48
ADI 8
LHA
LAI 8
CPH
JTZ BANKO
LAI 9
CPH
JTZ BANKI
LAI 10
CPH
JTZ BANK2
LAI 11
CPH
JTZ BANK3
CAL ERROR
JMp START
CONTIN LHI 11
LLI 252
LDM
IND
LMD
INL
XRA
LMA
INL
LAI 255
LMA
JMP READHll
H:l1
L:~5?
BANK NO TO r>
L:L+l=253
INIT ADR TO E
!JRITE ADDRESS TO
LOAD AC TO L
D TO H : BANK :-10
H:lt
L:~511
LOAD FI:-lAL ADRF.S.
L:1.-1 =fl"i3
COMPAP.EHIF-IH
JUMP IF AF-AI:O
LOAD AI TO AC
AI=AI+\
LOAD A I TO MEMORY
B:2528
TYPE C*)
CALL FOR TTY KB I
LOAD (T) TO AC
AC-8
JUMP IF AC-B:O
AC .. \05B, (E)
AC-B
JUMP IF AC-B:O
AC=122B, ('R)
AC-B
JUMP IF AC-B:O
AC .. \03B, ec)
AC-B
JUMP IF AC-B=O
AC=114B. (1.)
AC-B
JUMP IF AC-B=O
AC:120B, CP)
AC-B
JUMP IF AC-B:O
TYPE (7)
ENTER ADDRESS
READ TAPE INPUT R
CHECK FOR FE FLAC
JUMP IF CARRY=1
L=250
LOAD MEMORY TO C
SET MEMORY ADDRES
LOAD DATA TO MEMO
COMPARE AF AND AI
JUMP IF A:O
READ INPUT DATA
H:l1
L=?40
BANK 0 LOCATION
BANK t LOCATION
BANK 2 LOCATION
BANK 3 LOCATION
ENTER BANK NO
LOAD MEMORY TO AC
AC-AC-48
AC=AC+8
LOAD AC TO H
AC .. S
AC=AC-H
JUMP IF ACeO
D"o+l
BA!'rt{aSANK+ 1
L-L+l
CLEAR AC
INITIAL ADRESzO
FINAL ADRES:255


## Scan page 106

606 * R·=4
606 *PROM LISTING ROUTINE' 690 68 109 J!'IP LIST!
606 * 693
'" 606 46 11 LISTIN LHI 11 H"'II 693 "'PROM PROCF.AMMEF.
608 54 240 LLI 240 L-240 693 * 610 70 148 CAL ENTERL ENTER INITIAL & I' 693 70 141 PEOCP'~ CAL ENTERlI E:'JTFR ME:-IORY AGDR
INAL ADR. ES5
613 70 186 0 LISTER CAL CRLF 696 54 255 PCI LLI 255 REPROCRAM CO:'JTR.
616 54 251 LLI 251 L=251 698 6 253 LAI 2'53 PC=?'"i:l
618 6 252 LAI 252 NO. OF INSTR. PER 700 246 Lf'.A LOAD AC TO fY:F:"':Oi'Y
LINE 701 14 141 LBI 2158 CAF.RIACF RETUP.:'J
620 248 LMA LOAD AC TO MEMORY 703 70 150 CAL TTYOUT
621 70 116 LISTI CAL PRINTA PRINT ADDRESS 706 70 181 PC2 CAL 5ET"1'1 SET ACDRFS5 TO 17 624 14 160 LBI 240B LOAD [SP] 02
626 70 150 0 CAL TTYOUT PRINT [SP] 709 6 255 LA! 255 COMPLEMENT I'lPUT
629 14 194 LBI 302B LOAD [E] CATA
631 70 150 0 CAL TTYOUT PRINT [B] 711 175 XF.!o' LOAD DATA TO AC
634 54 253 1.1.1 253 1.=253 712 83 OUT 118 '.~P.ITE DATA TO OUT
636 199 LAM LOAD AI TO AC
637 81 OUT lOB OUTPUT AI TO OUT 713 6 LA! 4 AC=4. DELAY
0 715 67 OUT 13E PROCP.AM PULSE ENA
638 38 248 LEI 248 READ DELAY/DATA E BLE
IT CONTR 716 38 197 LEI 197 E=197. DELAY - 52 640 67 INP IB READ INPUT FROM 1 o M5EC.
702 718 70 55 0 PC4 CAL TTYDI DELAY - 8.672 MSE
641 18 LIST2 HAL C.
642 54 249 LLI 249 1.-249 721 32 INE E"'E+I
644 248 LMA SAVE INPUT DATA 722 72 206 JFZ PG4 JUMP IF E IS NOT
645 96 144 2 JTC PRI1<lTP PRINT [P] IF CARR
Y=1 725 6 0 LAI 0 AC=O
648 14 206 LBI 316E LOAD [1'1] 727 87 OUT 13E DISABLE PROCRA[Y' P
650 70 150 0 CAL TTYOUT PRINT (N] ULSE
653 68 149 2 JMP LIST3 728 45 RST 5 DELAY APPROXI. 9
656 14 208 PRINTP LEI 320B LOAD CP] MSEC
658 70 150 o - CAL TTYOUT PRHIT [P] 729 67 INP 18 READ DATA FROM 17
661 199 LIST3 LAM LOAD DATA TO AC 02
662 32 INE E=E+l 730 191 CPM COMPARE DATA
663 72 129 2 JFZ LIST2 JUMP IF E IS NOT 731 104 246 JTZ PC5 JUf'.P I I' COMPARED
0 734 14 164 LEI 244E LOAD ($]
666 14 198 LBI 306B LOAD [I'] 736 70 150 0 CAL TTYOUT PR[IIH!-]
668 70 150 0 CAL TTYOUT PRINT (1'] 739 46 II LHI II
671 14 160 LSI 240B LOAD [SP] 741 54 255 LLI 255
673 70 150 0 CAL TTYOUT PRINT CSP] 743 207 LEM
676 70 192 I CAL ACHECK AF - AI 744 8 INB
679 104 206 1 JTZ START 745 249 LME LOAD B TO MEMORY
682 54 251 1.1.1 251 LOAD LINE CONTR. 746 72 194 2 JFZ PC2
TO AC 749 70 197 0 CAL ERROR PRINT [?]
684 215 LCM LOAD MEMORY TO C 752 70 113 I CAL LISTA PRI"lT ADDRESS
665 16 INC C=C+l 755 68 206 1 JMP START
666 250 LMC 758 70 192 I PC5 CAL ACHECK
687 lOll 101 2 JTZ LISTER Jl~P IF LINF CO'lT 761 104 206 I JTZ START
764 68 164 JMP PCI CO"lTlNUE PRCC. "IE
XT INSTR.
767 END
102


## Scan page 107

APPENDIX VI
inteilecM8
Bare Bones 8
and
Microcomputer
Modules
The widespread usage of low-cost microcomputer systems is made pos
sible by I ntel's development and volume production of MCS-8 micro
computer sets. To make it easier to use these sets, Intel now offers
complete 8-bit modular microcomputer development systems called
Intellec 8.
The Intellec modular microcomputers provide a flexible, inexpensive,
and simplified method for developing OEM systems. They are self
contained, expandable systems complete with central processor, mem
ory, I/O, crystal clock, power supplies, standard software, and a control
and display console.
The major benefit of the I ntellec modular microcomputers is that ran
dom access memories (RAMs) may be used instead of read-only-mem
ories (ROMs) for program storage. By using RAMs, program loading
and modification is made much easier. In addition, the Intellec front
panel control and display console makes it easier to monitor and debug
programs. What this means is faster turn-around time during develop
ment, enabling you to arrive at that finished system sooner.
The Intellec 8 Eight-Bit Microcomputer Development System. The
Intellec 8 is a microcomputer development system designed for applica
tions which require 8-bit bytes of data to perform either binary arith
metic manipulations or logical operations. The Intellec 8 comes com
plete with power supplies, display and control panel, and finished cabi
net. It can directly address upto 16k 8-bit bytes of memory which can
be any mix of ROMs, PROMs, or RAMs. The Intellec 8 is designed
around the I ntel' 8008 central processor chip. There are 48 instructions
including conditional branching, binary arithmetic, logical, register-to
register, and memory reference operations. I/O channels provide eight
8-bit input ports and twenty-four 8-bit output ports - all completely
TTL compatible. The unit has interrupt capability and a two-phase
crystal clock that operates at 800 kHz providing an instruction cycle
time of about 12.5JLs.
Bare Bones 8. The Bare Bones8 has the same capability as the Intellec
8 only it does not include the power supplies, front panel, or finished
cabinet .. It is designedas a rack-mountable version.
The I ntellec 8 system comes with a standard software package which
includes a system monitor, resident assembler, and text editor. The
programmer can prepare his program in mnemonic form, load it into the
Intellec 8, edit and modify it, then assemble it and use the monitor to
load the assembled program.
Other development tools for the Intellec 8 include a PL/M compiler,
cross assembler, and simulator designed to operate on large scale general,
purpose computers. PL/M, a new high-level language, has been develop
ed as an assembly language replacement. A PL/M program can be writ
ten in less than 10% of the time it takes to write that same program in.
assembly language without loss of machine efficiency.
Standard Microcomputer Modules. Microcomputer Modules, standard
cards that can be purchased individually so that the designer can develop
his system with as little or as much as he needs, are also available.
Additional CPU, Memory, Input/Output, PROM Programmer, Universal
Prototype, and other standard modules provide developmental support
. and systems expansion capability.
103


## Scan page 108

•
I • Intellec 8/ Bare Bones 8
MCS-8 MICROCOMPUTER DEVELOPMENT SYSTEMS
• Intellec 8 (imm8-80A): Complete Microcomputer
Development System
Central Processor Module
RAM Memory Modules (8192 x 8)
Input/Output Module (TTL compatible)
PROM Memory Module (4k x 8 capacity;
1k Resident System Monitor included)
PROM Programmer Module
Control Console and Display
Power Supplies and Cabinet
• Bare Bones 8: MCS-S System without power
supplies, cabinet, or control console
• Standard Software
Resident Assembler} Requires
System Monitor Text Editor Sk of RAM
The I ntellec 8 is a complete microcomputer development
system for MCS-8 microcomputer systems. Its modular
design allows the development of any size MCS-8 system,
and it has built-in features to make this task easier than
it has ever been before.
The basic Intellec8 (imm8-80A) consists of six microcom
puter modules (CPU, 2-RAM, PROM, I/O and PROM pro
grammer), power supplies, and console and displays in a
small compact package. The heart of the system is the
imm8-82 Central Processor Module. It is built around
Intel's 8008-1, an 8-bit CPU on a chip. It contains all
necessary interface to control up to 16k of memory, eight
8-bit input ports, twenty-four 8-bit output ports, and to
respond to real time interrupts.
The I ntellec 8 has 9k bytes of memory in its basic con
figuration and may be expanded up to a maximum of
16,384 bytes of memory. Of the basic 9k bytes of mem
ory, 8192 bytes are random access read/write memory
located on the imm6-28 RAM Memory Modules and are
addressed as the lower 8k of memory. This memory may
be used for both data storage and program storage. The re
maining 1024 bytes of memory are located on the imm6-26
PROM Memory Module and addressed as the upper 1280
bytes of the 16k memory. This portion of memory is a
system monitor in five 1702A PROMs. Eleven additional
sockets are available on the imm6-26 for monitor or pro
gram expansion. Control for the PROM Programmer
Module (imm6-76) is included with the monitor for system
control.
PROM memory modules and RAM memory modules may
be used in any combination to make up the 16k of direct
ly addressable memory. Facilities are built into these
modules so that any combination of RAM and ROM or
PROM may be mixed in 256 byte increments.
Input and output in the Intellec 8 is provided by the
imm8-60 I/O module. It contains four 8-bit input ports,
and four 8-bit output ports. In addition it contains a
universal asynchronous transmitter/receiver chip as well
as a teletype driver, receiver, and reader control. Bit serial
communication using only the teletype drivers, receivers,
and the I/O port, is also possible with this module.
The universal asynchronous transmitter receiver chip may
104
• 9k bytes of Memory (expandable to 16,3S4 bytes
- I ntellec 8)
III 5k bytes of Memory (expandable to 16,384 bytes-
Bare Bones 8)
• Direct Access to Memory and I/O
• Four 8-bit input ports (expandable to eight)
• Fou.r 8~bit output ports (expandable to twenty-four)
• Universal Asynchronous Transmitter Receiver for
serial communications interface
• Real time interrupt capability
• Crystal controlled master system clock
operate at either 110 baud for standard teletype inter
face or 1200 baud for communication with a high speed
CRT terminal. Additional I/O modules, imm8-60, and
output modules, imm8-62, can expand the I/O capability
of the I ntellec 8 to eight input ports and twenty-four
output ports, all TTL compatible.
An interrupt line and an 8-bit interrupt instruction port
is built into the imm8-82 Central Processor Module. When
an interrupt occurs, the processor executes the instruction
which is present at the interrupt instruction port. In the
Intellec 8, both the interrupt line and the interrupt instruc
tion port are connected to the console. The processor
may be interrupted by depressing the switch labeled I NT,
and the interrupt instruction is entered in the ADDRESS/
INSTRUCTION/DATA switches.
Additional module locations are available in the Intellec 8
so the user may develop his own custom interface using
the imm6-70 Universal Prototype Module. All necessary
control signals, data, and address buses are present at the
connectors of the unused module locations for this ex
pansion. When memory, liO, and custom interfaces are
added to the I ntellec 8, care should be taken not to ex
ceed the built-in power supply capability.
Every I ntellec 8 comes with three basic pieces of software,
the systems mon itor, a resident program located in the
upper 1280 bytes of memory, a symbolic assembler and
a text editor. The resident systems monitor allows the
operator to punch and load tapes, display and alter mem
ory, and execute programs.
With the PROM Programmer Module, 1702A PROMs may
be programmed and verified under control of the system
monitor.
The text editor is a paper tape editor to allow the oper
ator to edit his source code before assembly. The assem
bler takes this source tape and translates it into object
code to run on the I ntellec 8 or any MCS-8 system.
The I ntellec 8 microcomputer development system is also
available in a Bare Bones 8 version. In this version the
power supply, chassis, console, and display are removed
leaving the user a compact rack mountable chassis to
imbed in his own system.


## Scan page 109

•
I
SYST
4 INPUT
PORTS
4 OUTPUT
PORTS
TELETYPE OR
HIGH SPEED
COMMUNICATIONS
INTERFACE
4 INPUT
PORTS
4 OUTPUT
PORTS
TELETYPE OR
HIGH SPEED
COMMUNICATIONS
INTERFACE
Intellec 8/ Bare Bones 8
EMS BLOCK DIAGRAM DISPLAY
/').
::::::~
I 32 DATA LINES
A
32 DATA LINES
....
/1
SERIAL
....
I 32 DATA LINES
A
32 DATA Lll\tfS
"I
/1
SERIAL
"I
AND CONTROL
SWITCHES
",A:l.
~
A
K INTERRUPT INSTRUCTION BUS
CPU "I FRONT PANEL
immS-S2 A
~
CONTROL LOGIC
K CONTROL BUS
v' ....
/
D'
DATA FROM MEMORY
I -
"--- MEMORY ADDRESS BUS/OUTPUT DATA
DATA TO MEMORY
DATA FROM MEMORY
!I. MEMORY A
) MODULE ( RAM OR PROM v " imm6-2S imm6-26
DATA TO MEMORY ~ ,/
• ANY COMBINATION TO
:J i i
• MAX 16k OF MEMORY : r:::;: •
DATA FROM MEMORY
"\
MEMORY A MODULE-
K ./ RAM OR PROM v
imm6-2S imm6-26
"I
DATA TO MEMORY "\ -v
DATA INPUT BUS MEMORY ADDRESS BUS/OUTPUT DATA
" > v
I NPUT/
OUTPUT OUTPUT
MODULE MODULE 64 DATA LINES
immS-60 immS-62
-)
v
(MEMORY ADDRESS BUS/OUTPUT:DATA:>
.~ I
CONTROL BUS
, l -)
v
INPUT/
OUTPUT OUTPUT
MODULE MODULE 64 DATA LINES
immS-60 immS-62
"\ (A MEMORY ADDRESS BUS/OUTPUT~ V " V
105
!I.
v
.....
v
S
OUTP UT
TS POR
S
OUTP UT
TS POR


## Scan page 110

inter Intellec 8
INTELLEC 8 CONTROL CONSOLE AND DISPLAY
The Contro l Console direct s and monito rs all activi t ies of t he
Intellec 8. Complete processor status, machine cycle condi·
tions and operational control of all processor act ivity are
provided , and additio nal contro ls facili tat ing p rogram de·
bugging and hardwa re checko ut a re includ ed on t he contr ol
console.
• STATUS is a di splay of th e operat ing mode of t he pro·
cessor .
1. RUN indicates the processor is running.
2. WAIT indicates the processor is waiting for memory or 110 to
be available.
3. HALT indicates the processor is in a stopped state .
4 . HOLD indicates an 1/0 or memory access is in progress from
the Control Console (occurs wit h WAIT or HALT).
5 . SEARCH COMPL indica tes the processor has executed instruc
tions until the search address and pass CQunter settings have
been reached. ISee LOAD PASS 26, and SEA RCHWA IT 331
6. ACCESS R EQ indicates an 110 or memory access is pending
from the Control Console.
7. INT REO indicates an interrupt is pending from the Con trol
Console (see INT 381.
B. INT DISABLE not applicable.
106
• CYCLE provides continuous display of the processor 's
machine cycle status.
9. FETCH indica tes the current machine cycle is fetch ing an
instruction from memory .
10. MEM indicates the processor is executing a memory read (peR)
or memory write (PCW) cycle, or, under manual control, a
direct access to memory is in progress.
11 . 1/ 0 indicates the processor is executing an I/O read or write
cycle (PCC) or, under manual control, a direct access to I/ O is
in progress.
12. DA indicates a direct access to memory or I/ O is in progress.
13. READ / INPUT indicates a memory or input read operation is
in progress.
14. WRITE /OUTPUT indicates a memory or out put write operation
is in progress.
15. INT indicates an interrupt cycle is in progress.
16. STACK not applicable .
• ADDRESS is a display of memory and I/ O address.
17. INDICATORS 14·15 not applicable.
18. INDICATORS 0-13 are a display of the address of mem ory
being accessed during a Fetch, Read, Write, or during manual
MEM ACCESS.
19. INDICATDRS 9· 1 3 are a display of the 110 address during an \
input , an output, or during a manual I/O ACCESS .


## Scan page 111

Intellec 8
• INSTRUCTION/DATA is a display of the instruction
or data .
2O.lNDICATORS ()'7 are a display of the instruction or data
between the processor and memory or 1/0 .
• REGISTER / FLAG DATA is the display of the proces·
sor data bus during executions of an instruction (dis·
play is dependent upon instruction being executed).
21.INOICATORS 0·7 are a display of the contents of the CPU data
bus when the instruction is executed . In the case of move
instructions . the contents of the source register is displayed .
Flags C, P, Z, and S are a special case. The flag status appears
in the lower four bits, only when an input instruction is
executed .
• ADDR ESS/DAT A These eight switches provide entry
of address or data for manual or SENSE operation of
the processor (see SENSE 3D) .
22. MEM ADDRESS HIGH The upper six bits of memory address
for direct access or search operations are entered here.
23.1/0 ADDRESS The five bit I/O address for monual I/O ACCESS
is entered here.
24. SENSE DATA Data to be input during a SENSE mode
operation is entered here (see SENSE 30) .
• ADDRESS / INSTRUCTION DATA These eight
switches prov ide entry of data , address, and instruc·
tions during manual or inte rrupt operation of the
prucessor,
25. MEM ADDRESS LOW The lower eight bits of memory address
for direct access or search mode operation are entered here .
INT INST During an interrupt cycle the interrupt instruction is
fetched from here (see I NT 38).
DATA Data for deposit to memory or an output port during
manual operation is entered here {see DEP 36. and OEP AT
HLT37J .
PASS COUNT Data to be loaded into the pass count register is
entered here (see LOAD PASS 26.1.
• ADDRESS CONTROL These four switches control
addressing of memory and I/ O and loading of the
search address during manual operation of the proces·
sor.
26. LOAD PASS Loads pass count into pass count register (PASS
COUNT is the numbe r of times the processor will iterate
through the search address during a search operat ion before in·
dicating SEARCH COMPLETE (see SEARCH·WAIT 33 and
SEARCH COMPL 5 J
27 . DECR decrements the loaded address by one (see LOAD 29) .
28 .I NCR increments the loaded address by one (see LOAD 29 ).
29 , LOAD loads contents of address high and low into memory
access register for manual direct access to memory or search
mode operation (see MEM ACCESS 32 . and SEARCH·WAIT
331.
• MODE These five switches select the processor's mode
of operation,
30. SENSE causes the process or to input data from the SENSE
DATA switches during execution of an input instruction insteacl
of the addressed input port (see SENSE DATA 24 I.
31 . 1/0 ACCESS provides accesS to any input port and control of
any output port when the processor is in a WAIT mode.
32 . MEM ACCESS allows access to and control of any location in
memory when the processor is in the WAIT mode.
33. SEARCH·WAIT provides for execution of a program to a
specific location, where the processor enters a wait mode and
displays current system conditions.
34 .WAIT causes the proc essor to go into a manual WAIT mode .
• CONTROL These five switches provide operator con·
trol of the proce ssor.
35. STEP /CONT provides single step execution of a program while
the processor is in a WAIT mode or continuation of a program
from the SEARCH COMPLETE condition .
36. DEP deposits an a·bit word to memory or output during a
memory or 1/0 access operation (see OATA 25).
37 . DEP AT HL T deposits an a·bit word to a selected memory 10'
eation or output automatically during a progr am med HALT
(see DATA 25 J.
38.INT causes the processor to execute an interrupt cycle, fetching
the interrupt instruction from the INT INST switches (see INT
INST 25 J.
39 . RESET causes processor to begin execution of program at
memory location zero by resetting program counter to zero .
All other registers remain unchanged .
• POWER and PROM PROGRAMMING
107
40. PRGM PROM PWR Power switch for high voltage used
with PROM programmer.
41 . POWER Key operated main power switch
42. PRGM PROM Zero insertion force socket for 1602A or
1702A PROM to be programmed


## Scan page 112

in~r~ ______ ln_te_lIe_C_8_/_B_a_re_B_o_ne_S_8 ______ 111111
SYSTEMS SOFTWARE
The Intellec 8 and Bare Bones 8 Microcomputer Development Systems come with
three pieces of software: Resident System Monitor, Text Editor and Symbolic
Assembler. The Text Editor and Assembler are supplied on paper tape and are
loaded with the System Monitor.
SYSTEM MONITOR
• Loads and punches paper tape
• Displays and alters contents of memory
• Fills memory with constants
• Executes programs in memory
• Moves blocks of data in memory
• Programs 1602A or 1702A PROMs
The System Monitor is contained in five 1702A PROMs
and is assigned to the upper 1280 words of memory,
leaving the lower 15k of memory for program and data
storage. This executive software allows the operator to
load and punch BNPF or hexadecimal format tapes, dis
play and alter memory, load constants to memory, move
blocks of RAM memory, and execute user programs.
The System Monitor is extended by the control software
for the imm6-76 programmer module, which gives the
monitor the ability to program 1602A to 1702A PROMs
as well as being able to load memory from already pro
grammed PROMs for duplication and verify the contents
of PROMs against master tapes.
TEXT EDITOR
• Edits symbolic data from paper tape with data from
operator's terminal
• Edited output is available via paper tape
• Appends text to editor input buffer
• Moves pointer to any desired location
• Finds and inserts or substitutes strings
• Deletes lines selectively
The Text Editor allows the operator to edit his source
code, making corrections and additions. He may append
code, delete code, locate strings, insert strings, substitute
strings and output edited code via paper tape. The text
editor runs on a minimum I ntellec 8 system with teletype
I/O. (Requires a minimum of 8k x 8 of RAM.)
108
ASSEMBLER
• Standard symbolic assembler
• Input via prepunched paper tape
• Output in 8008 object code
The Symbolic Assembler is a multiple pass type. During
Pass 1 the assembler reads the source code from the paper
tape and generates a symbol table for later use. During
Pass 2 the assembler generates the assembly listing. Also
at this time, any detectable errors such as undefined jumps
or missing symbols are indicated by a diagnostic printout
on the teletype. Pass 3 may now be run. It generates
object code, and punches it on paper tape. [Requires a
minimum of 8k x 8 of RAM.]
DEVELOPMENT SUPPORT:
PL/M COMPILER, ASSEMBLER and SIMULATOR
In addition to the standard software available with the
Intellec 8, Intel offers a PL/M compiler, cross assembler,
and simulator written in FORTRAN IV and designed to
run on any large scale computer. These routines may be
procured directly from Intel, or alternatively, designers
may contact a number of nation-wide computer time
sharing services for access to the programs. The output
from both P L/M and the MCS-8 Assembler may be run
directly on the I ntellec 8 Microcomputer Development
System.
PL/M Compiler: PL/M is a high level procedure-oriented
systems language for programming the Intel MCS-8 micro
computer. The language retains many of the features of
a high-level language, without sacrificing the efficiencies
of assembly language. A significant advantage of this
language is that PL/M programs can be compiled for either
the Intel 8008 or future Intel 8-bit processors without
altering the original program.
Assembler: The MCS-8 Assembler generates object codes
from symbolic assembly language instructions. It is de
signed to operate from a timeshared terminal.
Simulator: The.MCS-8 Simulator, called INTERP/8, pro
vides a softw9re simulation of the Intel 8008 CPU, along
with execution monitoring commands to aid program
development for the MCS-S.


## Scan page 113

intP'.!e~r ___ lnt_e_lIe_C_8_/ B_a_re_Bo_n_es_8-.:.-__ _
Word Size:
Memory Size:
Instruction Set:
Machine Cycle Time:
System Clock:
I/O Channels:
Interrupt:
SYSTEMS SPECIFICATIONS
Data: 8 bits
Instruction: 8, 16, or 24 bits
9k bytes I ntellec 8/5k bytes Bare Bones
expandable to 16k bytes
48, including: conditional branching,
binary arithmetic, logical, register-to
register and memory reference
operations
12.511s
Crystal controlled at 800kHz ±0.01%
4 expandable to }
8 input ports TTL
4 expandable to Compatible
24 output ports
Single Level
Weight:
Standard Software:
Support Software:
30 lb.
System Monitor
Resident Assembler
Text Editor
PL/M comPiler} written in
Cross Assembler FORTRAN IV
Simulator
STANDARD SYSTEMS and OPTIONAL MODULES
Intellec 8 (imm8-80A) Standard System includes the following
Modules and Accessories:
• Central Processor Module
• Input/Output Module
• PROM Memory Module
• RAM, Memory Modules (Two)
• Chassis with Mother. Board
• Control and Display Panel
• Finished Cabinet
• Standard Software:
System Monitor
Resident Assembler
Direct Access to Memory: Standard via control console •. Power Suppl ies Text Editor
• PROM Programming Module
Bare Bones 8 (imm8-81) Standard System includes the following
Modules:
Memory Cycle Time: ll1S
Operating Temperature:
DC Power Supplies:
(standard Intellec 8)
DC Power Requirement:
AC Power Requirement:
(standard Intellec 8)
Physical Size:
OOC to 55°C
Vee = 5V, Icc = 12A*
Voo = -9V, 100 = 1.8A *
VGG = -12V, IGG = 0.06A
Vee = 5V± 5%, Icc = 11 A max.,6A typo
Voo = -9±5%, 100 = lA max., 0.5A typo
VGG = -12V±5%, IGG ~ 0.03A max., 0.016A typo
• Central Processor Module
• Input/Output Module
• PROM Memory Module
• RAM Memory Module
• Chassis (rack mountable
with Mother Board)
• Standard Software:
System Monitor
Resident Assembler *
Text Editor *
*Requires a minimum of
8k of RAM'
60Hz, 115 VAC, 200 Watts
*Larger power supplies may be required for
expanded systems.
Optional Modules available for the Intellec 8 and Bare Bones 8:
Intellec 8: 7" x 17 1/8" x 12 1/4"
(table top only)
Bare Bones 8: 63/4" x 17" x 12"
(suitable for mounting in standard
R ETMA 7" x 19" panel space)
• Additional I/O or Output Modules
• Additional RAM Memory Modules
• Universal Prototype Module
• Module Extender
• Rack mounting kit for I ntellec 8
The standard Intellec 8 comes with the modules
shown. Expansion capability of both 110 and
Memory to a full MCS-8 system is provided by
using open locations on the motherboard.
BUS INTERFACE
FRONT PANEL CONTROLLER
CPU
RAM 3
RAM'l
RAM 1
RAM 0
PROM 3 OUT 3
PROM 2 OUT 2
PROM 1 ~/01 PROM 0 1/00
CUSTOM INTERFACE MAY BE USED <C..------PROM, PROGRAMMER MODULE
IN ANY OF THESE LOCATIONS
Intellec 8 and Bare Bones 8 Module Assignments
109


## Scan page 114

•
I Microcomputer Modules
imm 8-82 CENTRAL PROCESSOR MODULE
• Complete Central Processor Module with
system clocks, interface and control for
memory, I/O ports, and real time interrupt
• The heart of this module is Intel's 8008-1
processor on a chip - p-channei silicon gate
MOS
• 48 instructions, data oriented
• Accumulator and six working registers
• Direct addressing of up to 16,384 bytes of
memory. (PROM, ROM, or RAM)
• Directly addresses eight input ports and
twenty-four output ports
• Subroutine nesting to seven levels
• Real time interrupt capability
• Direct memory access capability
• Interface to memory, I/O and interrupt ports
through separate TTL buses
• Two phase crystal clock - 800 kHz
• 12.5~s instruction cycle
The imm8-82 Central Processor Module is a complete 8-bit parallel central processor unit. It contains complete'
control for interface to memory and I/O. Thi's is the main module in I ntel's I ntellec ™ 8 systems.
The imm8-82 is bu ilt around Intel's 8008-1 CPU on a chip. I t executes 48 instructions including conditional
branching, register to register transfers, arithmetic, logical and I/O instructions. Six 8-bit registers and an 8-bit
accumulator are provided. Subroutines may be nested to seven levels. Real time interrupt capability is provided
and the processor may directly address up to 16,384 bytes of memory.
The imm8-82 has a fourteen bit TTL compatible memory address bus, an 8-bit data output bus and an 8-bit
memory data input bus. Memory read and write signals and the wait request signal provide interface at TTL
levels to any type of memory (including PROM, ROM, and RAM). Asynchronous interface to slower speed
memories (access> 1 J1s) is provided by the wait request signal. This causes the processor to wait for memory
response to a read or write command.
The Central Processor Module directly addresses up to eight 8-bit input ports and twenty-four 8-bit output ports.
The 5-bit I/O address is contained in the upper byte of the memory address bus. Addresses 0 through 7 are
defined as input ports, and 8 through 31 as output ports. Control signals, I/O cycle, I/O in and I/O out, define
the I/O cycle and its function. An 8-bit data output bus and an 8-bit data input bus, both TTL compatible,
provide data channels in and out of the processor module.
Real time interrupt capability and direct memory access capability complete the list of functional features for
the imm8-82. During an interrupt, the Central Processor Module responds to the instruction presented at the
8-bit interrupt instruction port. Unless the main program flow is altered by the interrupt instruction, the exe
cution will continue where it left off before processing the interrupt. Eight bits of data including sign, carry,
zero and parity flags are latched on a separate bus during the execution portion of most instructions.
The direct memory access capability allows an alternate source to access memory or I/O while temporarily sus
pending processor operation. At the end of this alternative access to memory, the processor may return to nor
mal program execution.
All system timing is derived from a two phase crystal clock running at 800kHz. This gives a machine cycle time
of 12.5J1s ± 0.01 % and provides an accurate ti ming source for software delay loops and other timing requirements.
Central Processor Module
110


## Scan page 115

i·nte~I~ ________ M_ic_r_o_c.....;..o_m.-.:..p_u_te-r-M-o-d-u-le-s--_________ 1iIIIiIIIJIj1 .' ill" 1
111" ..
Central Processor Module Specifications
Word Size:
Central Processor:
Instruction: 8, 16, or 24 bits
Data: 8 bits
8008-1 CPU, 8 bit accumula'tor, six
8-bit registers, subroutinp nesting to
seven levels, interrupt capability,
. asynchronous operation with memory
Instruction Set: 48 including conditional branching,
binary arithmetic, logical operations,
register-to-register transfers, and I/O
Memory Addressing: Any combination of PROM, ROM and
RAM up to 16,384 bytes
Memory Interface: Address: 14·bits TTL latching bu~
Data: 8-bit TTL bus to and from
memory
I/O Addressing: Input: Eight 8-bit input ports
Output: twenty-four 8-bit latching
output ports
I/O Interface: 8-bit TTL compatible buses to and from
CPU. 8-bit TTL latched bus with
execution data including flags (sign,
parity, zero, and carry information)
immS-S2 Block Diagram
{
(lNTACK) T~
1'2
ST;;~ f3
T3A
(HALT ACK) STOP
(WAIT ACK) WAIT
System Clock:
Connector:
Board Dimensions:
Operating Temp:
DC Power
Requirements:
Su pport Software:
Crystal controlled, 800kHz ± 0.01%
Processor cycle time: 12.5~s
Dual 50-pin on 0.125 in. centers.
Connectors in rack must be positioned
on 0.5 in. centers min.
Wirewrap PIN C800100 from SAE
PIN VPB01 C50EOOA 1
from CDC
6.18 in. x 8.0 in. x 0.062 in. Board to
be on 0.5 in. centers minimum
OoC to +55°C
Vee = +5V ± 5%,
Icc = 2.2A max, 1.0A typical
Voo = -9V ± 5%,
100 = 0.06A max., 0.03A typical
PL/M Compiler } Written in
Cross Assembler FORTRAN IV
Simulator
~ ~~~~~~OM (MDI 0.7)
r--+- ....... DATA MUX ~ ~~~~NST (II 0-7)
INPUT PORT
DATA (IN 0-7)
{
(PCR) MEM READ CYC
INTCYC
PROCESSOR (PCW) MEM WRITE CYC
CYCLE BUS (PcC) i70CYC
(PCI) FETCH CYC
CONTROL
LOGIC
r-------------r--+--------------------+----------------~~~~CA}CPUCLOCK
~------------r--.------------------~-+--------------~~61 BUS OUT
~----------_.--~------------------~~------------~~0
{
WAIT REO ----..
CPU HOLD REO ----..
CTL fN'fREQ ----..
BUS. HALT INT REO----"
IN JAM ENBL ----..
RAM MOD ENBL ----..
PROM MOD ENBL
READY
INTERRUPT
STATE LINES
SYNC
BUS CTL
I/O IN
I/O OUT
DBIN
DB OUT
BUS BUSY
R!W
i=iQIDAcj(
INT REO LTH
8008 CPU 8
ADDRESS CONTROL
BUS
DRIVER
CYCLE CODING (CCO, CC1)
INTERFACE
CONTROL
SIGNALS
111
}
MEMORY
ADDRESS (MAD 0-13)
(CCO)
(CC1)
t-_____ .....,_8~ .. ~~~~~~ (DB 0-7)
REG/FLAG
LATCH
T40 (S)
T41 (2)
T42 (P)
T43 (C)
T44
T45
T46
.T47


## Scan page 116

•
I Microcomputer Modules
imm6-28 RAM MEMORY MODULE
• 4096 8-bit bytes per module
• Static memory, no clocks required
• Interfaces with the imm8-82 8-bit
Central Processor Module
• Single +5V power supply
• Low power requirements
• For use in expansion of Intellec 8 systems to 16k
bytes of memory
• Built-in decoding of module select for expansion
to 65k bytes of memory
The imm6-28 RAM Memory Module is a standard 4k x 8 memory module designed for use with the Intellec 8
Microcomputer Development System. This module contains address and data buffers, read/write timing circuits
and is implemented with Intel's 2102 1 k x 1 static RAM. Although the basic memory module is 4096 x 8, con
figurations as small as 1024 x 8 are also available.
The imm6-28 RAM Memory Module is used with the MCS-8 Micro Processor in configurations of up to 16k bytes
of memory (4 modules). The imm8-82 Central Processor Module directly interfaces with the imm6-28 RAM
Memory Module with all module select decoding done directly on the connector. This allows an imm6-28 to be
moved to any location within the 16k of memory without making any changes in the module. This bui.lt-in
decoding allows additional expansion of memory by bank switching.
RAM Memory Module
112


## Scan page 117

i~~e ____ ~ _________ M_ic~r_o_c_o_m~p_u_te_r_M __ O~d~ul~e~s __________ ~IIIIIII~I"·.··M·_
RAM Memory Module Specifications
Memory Size:
Word Size:
Memory Expansion:
Cycle Time:
Interface:
Capacity:
4k bytes
8 bits
To 65k bytes (16 modu les)
1J,Ls
TTL compatible inputs; open collector outputs (positive true logic)
4096 bytes
Connector: Dual 50-pin on 0.125 in. centers. Connectors in rack must be positioned on 0.5 in. centers min.
Wirewrap PIN C800100 from SAE
PIN VPB01C50EOOAl from CDC
Board Dimensions:
Operating Temperature:
6.18 in. x 8.0 in. x 0.062 in. Board to be on 0.5 in. centers minimum.
OOC to 55°C
DC Power Requirement: Vee = +5V ± 5%, lee = 2.5A max., 1.25A typical
imm6-28 'Block Diagram
RM
BYTE 1
BYTE 2
DBo ---- ___ ~
DB, ---- ___ ~
DB2 ---- ___ ~
DB3 -------~
DB4----- ..
DBs -------~
DB6----- ..
DB7 -------~
DATA TO
MEMORY
MAD 12
MAD 12
MAD 13
MAD 13 -
MAD 14
MAD 14
READ!
WRITE
CONTROL
t
INPUT
BUFFER
MAD 15
MODULE
----- •• ~I SELECT
LOGIC
MAD 15
MS12
MS13
MS 14 .
f4-
I
MODULE SELECT
MEMORY ARRAY
4096 x 8
ADDRESS BUFFER
I
OUTPUT
BUFFER
MAD 0 MAD 1 MAD 2 MAD 3 MAD 4 MAD 5 MAD 6 MAD 7 MAD 8 MAD 9 MAD 10 MAD 11
MS15
MEMORY ADDRESS
RAM
MOD ENBL
ADR STB
113
MOO
MD1
MD2
MD3
MD4
MD5
MD6
_ .. MD7
DATA FROM
MEMORY


## Scan page 118

•
I • Microcomputer Modules
imm6-26 PROM MEMORY MODULE
• Provides sockets for up to sixteen PROMs
(4096 x 8)
• Static memory, no clocks required
• I nterfaces with imm8-82 8-bit Central
Processor Module
• Accepts Intel 1602A or 1702A PROMs or
1302 ROMs
• Logic to allow any mix of PROM in 256 byte
(8-bits) increments with RAM to 16k when used
with the imm8-82 8-bit Central Processor Module
• Built in decoding of module select for expansion
to 65k of memory
The imm6-26 PROM Memory Module may be used with the imm8-82 8-bit Central Processor Module for non
volatile program storage. Each PROM Memory Module has sockets for from one to sixteen of Intel's 1602A or
1702A PROMs. In addition, the 1302 mask programmed ROM may be used in place of the PROMs in OEM
applications.
The PROM Memory Module is used for program storage and look-up-tables with the MCS-8 8-bit Micro Proces
sor. It interfaces directly with the imm8-82 Central Processor Module and may be used with the imm6-28 RAM
Memory Module in any combination to 16k bytes. Special control logic on the imm6-28 module allows any mix
of PROM and RAM in a system in 256 byte increments.
For memories larger than 4k bytes, decoding on the module allows addressing of up to sixteen imm6-28 modules
for a total of 65k bytes of memory. The decoding is accomplished on the module connector. Any imm6-26
may be plugged in to any memory module connector. /
PROM Memory Module
114


## Scan page 119

•
I Microcomputer Modules
PROM Memory Module Specifications
Memory Size:
Word Length:
Memory Expansion:
4k bytes
8 bits
To 65k bytes (16 modu les)
Interface:
Capacity:
TTL compatible inputs; open collector outputs (positive true logic)
256 to 4096 bytes in 256 byte increments
Connector: Dual 50-pin on 0.125 in. centers. Connectors in rack must be positioned on 0.5 in. centers min.
Wi rewrap PIN C800100 from SAE
PIN VPBOl C50EOOA 1 from CDC
Board Dimensions:
Operating Temperature:
6.18 in. x 8.0 in. x 0.062 in. Board to be on 0.5 in. centers miQimum.
OOCto 55°C
DC Power Requirement: Vee = +5V ±5%
Voo =-9V ±5%
(1)Board loaded with all 16 PROMs.
imm6-26 Block Diagram
MADO---------- •• ~I
MAD1----------~
MAD 2 ---------~
MAD3---------- •• ~1 ADDRE~
MAD 4 BUFFER
MAD5----------~
MAD6----------~~
MAb7---------- •• ~1
MAD8----------~
MAD9--------- .... ~1
MAD10--------- ..... ~1
MAD 11---------~
CHIP
SELECT
LOGIC
I
MEMORY
ARRAY
256 x 8
TO
4096 x 8
MODULE SELECT
lee = 1.6A max., 1.lA typical-(1)
100 = 1.6A max., 1.0A typical(1)
,8 ~ DATA
7 BUFFER
1------......--- ... MDO
I--------I~ MDl
J-------I~ MD2
J-------I~~ MD3
J-------I~ MD4
I--------I~ MD5
J-------I~ MD6
-..------- ... MD7
DATA FROM
MEMORY
MAD12---------~
MAD 12 ... ----------1
MAD13---------~
MAD 13 ... ----------1
MAD 14 --------- .... ~I
MAD 14 ... ----------1
L-_____________________________________ • RAM MOD ENBL
MODULE
MAD 15--------- ..... ~1 SELECT
MAD 15 - LOGIC
MS 12 --------- .....
MS 13 --------- ..... ~I
MS14---------~~
MS 15 ----------II .. ~.
PROM MOD _____________ ----l+
EKiBL
115
I


## Scan page 120

Microcomputer Modules
-...
immS-60 INPUT/OUTPUT MODULE
• Four 8-bit input ports and four 8-bit latching output ports
• TTL compatible
• Interfaces directly with imm8-82 Central Processor Module
• TeletYpe asynchronous transmitter/receiver and controls on board
• Transmission rates of 110 or 1200 baud
• Crystal clock for asynchronous transmitter/receiver
• Capable of high speed serial communications to 9600 baud
The imm8-60 I/O Module provides four 8-bit TTL compatible input ports and four 8-bit" TTL compatible latch
ing output ports. It interfaces directly with the imm8-82 Central Processor Module. Built-in decoding on the
board provides for expansion of I/O to the maximum with the addition of one imm8-60 and two imm8-62 Out
put Modules (eight input ports and twenty four output ports).
For more efficient use of the imm8-82 Central Processor, an asynchronous transmitter receiver is included in the
module. This frees the processor of time-consuming bit manipulation during bit serial data transmission. The
transmitter receiver operates at either 110 or 1200 baud and by alteration of the basic clock frequency, data
rates to 9600 baud may be obtained. The module contains drivers and receivers for connection to a teletype.
These may be used with the asynchronous transmitter receiver or directly with I/O ports for bit serial transmis
sion and reception of teletype data.
The module is configured with all common control signals bused to the module on the PC connector, while all
I/O signals are available at the ribbon connectors on the top of the module.
I/O Module
116


## Scan page 121

i~~~· _______________ M~'i~c_ro~c~o~m~p~ut_e_r_M_o~d~u=l~e~s __ --------~I111111~ .• ·.·M·~····
1/0 Module Specifications
Word Size:
Capacity:
1/0 Interface:
Serial Communication Rate:
8 bits
Four 8-bit input ports, four 8-bit output ports
Input ports: TTL compatible (complement Data In)
Output ports: TTL compatible (complement Data Out)
Communications Interface:
Direct: TTL compatible input and output
TTY: 20mA TTY interface with discrete transmitter and receiver
TTY RDR Control: Discrete relay interface
Crystal controlled to 110 or 1200 baud
Connector: Dual 50-pin on 0.125 in. centers. Connectors in rack must be positioned on 0.5 in. centers min.
Wirewrap PIN C800) 00 from SAE
PIN VPB01 C50EOOA 1 from CDC
Ribbon Type PIN 3417 from 3M
Board Dimensions:
Operating Temperature:
6.18 in. x 8.0 in. x 0.062 in. Board to be on 0.5 in. centers minimum.
OoC to 55°C
DC Power Requirement: Vee = +5V ± 5%, lee = 0.820A max., 0.478A Typical
Voo = -9V ± 5%, 100 = 0.080A max., 0.050 Typical
VGG = -12V ± 5%, IGG = 0.030A max., 0.016A Typical
imm 8-60 Block Diagram
FROM TTY TTY
RECEIVER
SERIAL
DATA IN
-
~
PARALLEL DATA OUT ,8
(RECEIVED DATA) ,
CRYSTAL
CLOCK
SERIAL
DATA OUT
COMMUNICATIONS
INTERFACE PARALLEL DATA IN
-~-"'9"""~-"" (TRANSMITTED DATA)
J
TTY TO TTY
~ TRANSMITTER
TTY RDR TO READER
8 CONTROL RELAY
STATUS OUT ... '"
DATA FROM CPU
ADDRESS BUS
,
CONTROL BUS
I
PORT
SELECT
,
L J
FOUR {]::: ~ ': 8-BIT ---f/--- ..... - .... ~I
INPUT PORT 2 8
PORTS ----~~------~~
PORT 3',8
----~,--------~~
4
..... 1--
INPUT
MUX
----
,8 ,
t
,8 PORT 0
,8 PORT 1
, OUTPUT
LATCHES ,8 PORT 2
',8 PORT 3
,
,8 DATA TO CPU
,
117
J FOUR SBIT OUTPUT
PORTS


## Scan page 122

•
I Microcomputer Modules
immS-62 OUTPUT MODULE
• Eight 8-bit Latching Output Ports
• Interfaces Directly with imm8-82 CPU Module
• Decoding for Expansion to Full Output Complement
• TTL Compatible
The imm8-62 Output Module provides eight 8-bit latching output ports for direct interface with the imm8-82
CPU Module. Each port is individually addressable, and all outputs are TTL compatible. The module address
includes decoding for expansion to a full complement of 24 output ports. This may be accomplished by using
two imm8-60 I/O Modules and two imm8-62 Output Modules. All output signals are available through a ribbon
connector at the top of the module.
Output Module
118


## Scan page 123

Microcomputer Modules
Output Module Specifications
Word Size: 8-bits
Capacity: Eight 8-bit latching output ports
Interface: TTL compatible (complement Data Out)
Connector: Dual 50-pin on 0.125 in. centers. Connectors in rack must be positioned on 0.5 in. centers min.
Board Dimensions:
Operating Temperature:
DC Power Requirement:
Wirewrap PIN C800100 from SAE
PIN VPB01C50EOOA1 from CDC
Ribbon Type PIN 3417 from 3M
6.18 in. x 8.0 in. x 0.062 in. Board to be on 0.5 in. centers minimum.
OoC to 55°C
Vee = +5V ± 5%, lee = 0.840A max., 0.420A typical
imm8-62 Block Diagram
/8
/8 ,
DATA FROM CPU ;
,8
• /8 ,
,8 ,
OUTPUT
LATCHES ,8 ,
,8 ,
,8 ,
,8 ,
ADDRESS BUS ,5
t , OUTPUT
PORT
CONTROL BUS SELECT
119
-
PORT 0
POR'f1
PORT2
PORT 3 EIGHT
~ ~~~~UT
PORT 4 PORTS
PORT 5
PORT 6
PORT 7
-


## Scan page 124

•
I
®
Microcomputer Modules
imm6-76 PROM PROGRAMMER MODULE
• High speed programming of Intel's
1702A or 1602A PROM
• Direct interface with Intel's Intellec 8
Microcomputer Development System
• All necessary timing and level
shifting included
• Complete software necessary for use
included with Intellec 8 system monitor
The imm6-76 PROM Programmer Module provides all necessary hardware and software to add PROM program
ming capability to the Intellec 8 microcomputer development system.
The module has been designed to slip into the I ntellec 8 and provides all connections to the zero insertion force
socket on the front panel. All required timing and level shifting is accomplished on the module utilizing the high
voltage power supply already located in the Intellec 8.
Software to control programmer operation is included as part of the Intellec 8 system monitor. This software
is specifically written for the Intellec 8 and allows both programming and verification of 1602A and 1702A
PROMs. In addition, the contents of any PROM may be listed or unloaded into memory for duplication.
The imm6-76 may also be used as a stand alone PROM programmer with toggle switches or with another com
puter providing data address and control signals.
CONTROL
INTERFACE
ADDR (0·7)
ADDR CTL
CS (0·3)
STAT (0·3)
DATA IN (0·7)
DATA OUT (0·7)
DATA OUT CTL
DA T A OUT ENBL
DATA IN cn
DATA IN ENBL
;4
14
(
-
imm6-76 Block Diagram
,8
•
ADDRESS
; BUFFERS /8
AND ,
LEVEL
SHIFTERS Vees
-
5/ CONTROL BUS
,
GND POWER
Vee •
SUPPLY
PROGRAM REGULATOR
PULSE Voo • TIMING BUFFERS
Vp AND LEVEL
SHIFTERS
;8
Vecs
/1 8
DATA
BUFFERS J 8 AND
LEVEL
,
SHIFTERS
ADR OUT
(0·7)
PRGM
Voo IGND
VBB TO PROM
VGG
CS
DATA (0·7)
PROM Programmer Module Specifications
System Interface:
Control Software:
Connector:
Board Dimensions:
Operating Temperature:
DC Power Requirements:
All inputs and outputs are TTL compatible and available at the ribbon connector at the top of the
module. Control for either "True" or "False" data is provided. Direct interface to Intellec 8.
Included in the Intellec 8 executive monitor.
Dual 50-pin on 0.125 in. centers. Connectors in rack must be positioned on 0.5 in. centers min.
Wi rewrap PIN C800100 from SAE
PIN VPB01C50EOOA 1 from CDC
Ribbon Type PIN 3417 from 3M
6.18 in. x 8.0 in. x 0.062 in. Board to be on 0.5 in. centers min.
OOC to+550C
Vcc = +5V ± 5%, Icc == 0.8A max., 0.5A typical
\bo = -9V ± 5%,100 = 0.1 A max., 0.08A typical
Vp = +50V, Ip = 1.0A max.
120


## Scan page 125

•
I
®
Microcomputer Modules
imm6-70 UNIVERSAL PROTOTYPE MODULE
• Provides breadboard capability for developing
custom interfaces
• Capacity for 60 16-pin or 14-pin sockets or 24
24-pin sockets
• Standard size of all microcomputer modules • All power is bused on board. Pins on PC
connector and pins to individual sockets are
uncommitted for maximum flexibility • 3M 40 pin ribbon connector on top of module
provides direct I/O connections
• Will accept standard wirewrap sockets with 0.1 in.
x 0.3 in. or 0.1 in. x 0.6 in lead spacing
The imm6-70 Universal Prototype Module is a standard size microcomputer module with power buses which in
terface with the I ntellec 8. It provides a standard format for prototyping both customer interface and system
. control. I/O interface is provided through ribbon-type connectors on top of the module.
The module will accept dual in-line packaged components having pin center-to-center dimensions of 0.100 inch
by 0.300 inch or 0.100 inch by 0.600 inch. These parts should be mounted in standard wirewrap sockets.
Universal Prototype Module
Universal Prototype Module Specifications
Capacity:
Connector:
Board Dimensions:
60 16-pin or 14-pin sockets or 24 24-pin sockets. Standard wirewrap sockets with pins on
0.100 in. by 0.300 in. centers or 0.100 in. by 0.600 in. centers. Board spacing dependent on
components and sockets used.
Dual 5(}pin on 0.125 in. centers.
Wirewrap PIN C800100 from SAE
PIN VPB01C50EOOA 1 from CDC
Ribbon Type PIN 3417 from 3M
6.18 in. x 8.0 in. x 0.062 in. Board to be on 0.5 in. centers minimum.
121


## Scan page 126

•
I Microcomputer Modules
imm6-72 MODULE EXTENDER
• Allows any module to be extended for ease of
debugging, testing, and maintenance
• Standard dual 50-pin configuration for use with
all microcomputer modules
The imm6-72 Module Extender is designed to be used with the Intellec 8 system. It allows the operator to ex
tend any module out of the cage for servicing while maintaining all electrical connections.
Connector:
Board Dimensions:
Module Extender
Module Extender Specifications
Dual 50-pin on 0.125 in. centers. Connectors in rack must be positioned on 0.5 in. centers min.
Wirewrap PIN CBOO100 from SAE
PIN VPB01C50EOOA1 from CDC
,Extending connector is mounted on board.
6.18 in. x B.O in. x 0.062 in. Board to be on 0.5 in. centers minimum.
122


## Scan page 127

123


## Scan page 128

WESTERN
u.s. SALES AND MARKETING OFFICES
U.S. MARKETING HEADQUARTERS
3065 Bowers Avenue
408/246-7501, TWX: 910-338-0026
Telex: 34-6372
-Santa Clara, California 95051
NATIONAL SALES MANAGER
Hank O'Hara
3065 Bowers Avenue
408/246-7501, TWX: 910-338-0026
Telex: 34-6372
·Santa Clara, California 95051
U.S. REGIONAL SALES MANAGERS' OFFICES
William T. O'Brien
MID-AMERICA
Mick Carrier
NORTHEAST
James Saxton
MID·ATLANTIC
Hank Smith
17291 Irvine Blvd., Suite 262
714/838-1126, TWX: 910-595-1114
*Tustin, California 92680
13333 N. Central Expressway
Suite 110
2141234-1109, TWX: 910-867-4763
*Dallas, Texas 75231
2 Militia Drive, Suite 4
617/861-1136, Telex: 92-3493
*Lexington, Massachusetts 02173
30 South Valley Road
215/647-2615, TWX: 510-668-7768
*Paoli, Pennsylvania 19301
ARIZONA
Sales Engineering, Inc.
7155 E. Thomas Road, No.6
602/945-5781, TWX: 910-950-1288
Scottsdale 85252
CALIFORNIA
Intel Corp.
3065 Bowers Avenue
408/246-7501, TWX: 910-338-0026
·Santa Clara 95051
Intel Corp.
17291 Irvine Blvd., Suite 262
714/838-1126, TWX: 910-595-1114
·Tustin 92680
Earle Associates, Inc.
4433 Convoy Street, Suite A
714/278-5441, TWX: 910-335-1585
San Diego 92111
COLORADO
Intel Corp.
1341 South lima St.
303/755-1335
* Aurora 8001 0
CANADA
Multilek, Inc.
4 Barran Street
613/825-4695
Ottawa, Ontario K2C 3H2
·Direct Intel Office
DENMARK
John Johansen
Intel Office
FLORIDA
Semtronic Associates, Inc.
P.O. Box 1449
305/771-0010
Pompano leach 33061
Semtronic Associates, Inc.
685 Chelsea Road
305/831-8233
Longwood 32750
ILLINOIS
Mar-Con Associates, Inc.
4836 Main Street
312/675-6450
Skokie 60076
MARYLAND
Barnhill and Associates
1931 Greenspring Drive
301/252-5610
Timonium 21093
Barnhill and Associates
P.O. Box 251
301/252-5610
Glen Arm 21057
MASSACHUSETTS
Intel Corp.
2 Militia Drive, Suite 4
617/861-1136, Telex: 92-3493
-Lexington 02173
Datcom
7A Cypress Drive
617/273-2990
Burlington 01803
u.S. SALES OFFICES
MICHIGAN
Sheridan Associates, Inc.
33708 Grand River Avenue
313/4773800
Farmington 48024
MINNESOTA
Intel Corp.
800 Southgate Office Plaza
5001 West 78th Street
612/835-6722
°Bloomington 55437
E.C.R., Inc.
5280 W. 74th Street
612/831-4547, TWX: 910-576-3153
Minneapolis 55435
MISSOURI
Sheridan Associates, Inc.
110 S. Highway 140, Suite 10
314/837-5200
Florissant 63033
NEW JERSEY
Addem
Post Office Box 231
516/567-5900
Keasbey 08832
NEW YORK
Ossmann Components Sales Corp.
395 Cleveland Drive
716/832-4271
Buffalo 14215
Addem
37 Pioneer Blvd.
516/567-5900
Huntington Station, L.I. 11746
NEW YORK (Continued)
Ossmann Components Sales Corp.
280 Metro Park
716/442-3290
Rochester 14623
Ossmann Components Sales Corp.
1911 Vestal Parkway E.
607/785-9949
Vestal 13850
Ossmann Components Sales Corp.
132 Pickard Building
315/454-4477
Syracuse 13211
Ossmann Components Sales Corp.
411 Washington Avenue
914/338-5505
Kingston 12401
NORTH CAROLINA
Barnhill and Associates
6030 Bellow Street
919/787-5774
Raleigh 27602
OHIO
Sheridan Associates. Inc.
10 Knollcrest Drive
513/761-5432, TWX: 810-461-2670
Cincinnati 15237
Sheridan Associates, Inc.
7800 Wall Street
216/524-8120
Cleveland 44125
Sheridan Associates, Inc.
Shiloh Bldg., Suite 250
5045 North Main Street
513/277-8911
Dayton 45405
EUROPEAN MARKETING OFFICES
FRANCE ENGLAND GERMANY
PENNSYLVANIA
Vantage Sales Company
21 Bala Avenue
215/667-0990
Bala Cynwyd 19004
Intel Corp.
30 South Valley Road
215/647-2615, TWX: 510-668-7768
*Paoli, Pennsylvania 19301
Sheridan Associates, Inc.
4268 North Pike,
North Pike Pavilion
412/373-1070
Monroeville 15146
TENNESSEE
Barnhill and Associates
206 Chicasaw Drive
615/928-0184
Johnson City 37601
TEXAS
Evans and McDowell Associates
13333 N. Central Expressway
Room 180
214/238-7157, TWX: 910-867-4763
Dallas 75222
VIRGINIA
Barnhill and Associates
P.O. Box 1104
703/846-4624
Lynchburg 24505
WASHINGTON
SD.R2 Products and Sales
14040 N.E. 8th Street
206/747-7424, TWX: 910-443-2305
Bellewe 98007
Keith Chapple . Erling Holst
Vester Farimagsgade 7
45-1-115644, Telex: 19567
OK 1606 Copenhagen V
Bernard Giroud
Intel Office
Cidex R-141
(1) 677-60-75, Telex: 27475
94-534 Rungis
I ntel Office
Broadfield House
4 Between Towns Road
771431, Telex: 837203
Cowley, Oxford
I ntel Office
Wolfratshauserstrasse 169
798923, Telex: 5-212870
D8 Munchan 71
AUSTRALIA
AJ. Ferguson (Adelaide) PTY. Ltd.
125 Wright Street
51-6895
Adelaide 5000
AUSTRIA
Bacher Elektronische Gerate GmbH
Meidlinger Haupstrasse 78
0222-9301 43, Telex: (01) 1532
A 1120 Vienna
BELGIUM
Inelee Belgium S.A.
Avenue Val Duchesse, 3
(02) 60 00 12, Telex: 25441
8-1160 lrux.lles
INTERNATIONAL DISTRIBUTORS
DENMARK GERMANY NETHERLANDS
Scandinavian Semiconductor Alfred Neye Enatachnik GmbH Inelco N.V_
Supply A/S Schillerstrasse 14 Weerdestein 205
20, Nannasgade 041 06/612-1, Telex: 02-13"590 Postbus 7815
Telex: 19037 2085 Quickborn-Hamburg 020441666, Telex: 12534
DK-2200 Copenhagen N Amsterdam 1011
FINLAND ISRAEL NORWAY
Havulinna Oy Telsys Ltd_ Nordisk Elektronik (Norge) A/S
P_O_ Box 468 54, labotinsky Road Mustads Vei 1
90-61451, Telex: 12426 25 2839, Telex: TSEE-IL 333192 602590, Telex: 16963
SF 00100 H.lsinki 10 Ramat - Gan 52 464 Oslo 2
FRANCE ITALY SOUTH AFRICA
Tekelec Airtronic Eledra 3S Electronic Building Elements
Cite des Bruyeres Via Ludovico da Viadana 9 P.O. Box 4609
Rue Carle Vernet (02) 86-03-07 78-9221, Telex: 30181 SA
626-02-35, Telex: 25997 20122 Milano Pretoria
92 Selfes
ORIENT MARKETING OFFICES
JAPAN
ORIENT MARKETING
HEADQUARTERS
Y. Magami
t ntel Japan Corp.
Kashara Building
1-6-10 Uchikanda, Chiyoda-Ku
03-2955441, Telex: 781-28426
Tokyo 101
124
ORIENT DISTRIBUTORS
JAPAN
Pan Elektron Inc.
No. 1 Hig3shikata-Machi
045-471-8321, Telex: 781-4773
Midori-Ku, Yokohama 226
SWEDEN
Nordisk Elektronik AB
Fack
08-24-83-40, Telex: 10547
S-103 Stockholm 7
SWITZERLAND
Industrade AG
Gemen!.trasse 2
Postcheck 80 - 21190
01-60-22-30, Telex: 56788
8021 Zurich
UNITED KINGDOM
Walmore Electronics Ltd.
11-15 Betterton Street
Drury Lane
01-836-Q201, Telex: 28752
London WC2H 9BS


## Scan page 129

WEST
ARIZONA
Hamilton/Avnet Electronics
2615 South 21st Street
602/275-7851
Phoenix 85034
Cramer/Arizona
2816 N. 16th Street
602/263-1112
Phoenix 85006
CALIFORNIA
Hamilton/Avnet Electronics
• 340 E. Middlefield Road
415/961-7000
Mountain View 94041
Cramer/San Francisco
720 Palomar Avenue
408/739·3011
Sunnyvale 94086
Hamilton Electro Sales
10912 W. Washington Blvd.
213/870-7171
Culver City 90230
Cramer/Los Angeles
17201 Daimler Street
714/979-3000
Irvine 92705
Hamilton/Avnet Electronics
8817 Complex Drive
714/279-2421
San Diego 92123
Cramer/San Diego
8975 Complex Drive
714/565-1881
San Diego 92123
COLORADO
Cramer/Denver
5465 E. Evans Place at Hudson
303/758-2100
Denver 80222
Hamilton/Avnet Electronics
5921 N. Broadway
303/534-1212
Denver 80216
NEW MEXICO
Cramer/New Mexico
137 Vermont, N.E.
505/265-5767
Albuquerque 87108
Hamilton/Avnet Electronics
2450 Baylor Drive S.E.
505/765-1500
Albuquerque 87117
OREGON
Almac/Stroum Electronics
8888 S.W. Canyon Road
503/292-3534
Portland 97225
UTAH
Cramer/Utah
391 W. 2500 South
801/487-3681
Salt Lake City 84115
Hamilton/Avnet Electronics
647 W. Billinis Road
801/262-8451
Salt Lake City 84115
WASHINGTON
Hamilton/Avnet Electronics
13407 Northrup Way
206/746-8750
Bellevue 98005
Almac/Stroum Electronics
5811 Sixth Avenue South
206/763-2300
Seattle 98108
Cramer/Seattle
5602 Sixth Avenue South
206/762-5755
Seattle 98108
u.s. DISTRIBUTORS
MID-AMERICA
ILLINOIS
Cramer/Chicago
1911 South Busse Road
312/593-8230
Mt. Prospect 60056
Hamilton/Avnet Electronics
3901 North 25th Avenue
312/678-6310
Schiller Park 60176
KANSAS
Hamilton/ Avnet Electronics
37 Lenexa Industrial Center
913/888-8900
Lenexa 66215
MICHIGAN
Sheridan Sales Co.
33708 Grand River Avenue
313/477-3800
Farmington 48204
Cramer/Detroit
13193 Wayne Road
313/425-7000
Livonia 48150
Hamilton/Avnet Electronics
12870 Farmington Road
313/522-4700
Livonia 48150
MINNESOTA
Cramer/Bonn
7275 Bush Lake Road
612/941-4860
Edina 55435
Hamilton/Avnet Electronics
2850 Metro Drive
612/854-4800
Minneapolis 55420
Industrial Components, Inc.
5280 West 74th Street
612/831-2666
Minneapolis 55435
MISSOURI
Sheridan Sales Co.
1I0 South Highway 140, Suite 10
314/837-5200
Florissant 63033
Hamilton/Avnet Electronics
392 Brookes Drive
314/731-1144
Hazelwood 63042
OHIO
Cramer/Tri-States, Inc.
666 Redna Terrace
513/771-6441
Cincinnati 45215
Hamilton/Avnet Electronics
118 West Park Road
513/433-0610
Dayton 45459
Sheridan Sales Co.
10 Knollcrest Drive
513/761-5432
Cincinnati 45237
Cramer/Cleveland
5835 Harper Road
216/248-7740
Cleveland 44139
Sheridan Sales Co.
7800 Wall Street
216/524-8120
Cleveland 44125
Sheridan Sales Co.
Shiloh Bldg., Suite 250
5045 North Main Street
513/277-891I
Dayton 45405
TEXAS
Cramer Electronics
2970 Blystone
214/350-1355
Dallas 75220
Hamilton/Avnet Electronics
4445 Sigma Road
214/661-8661
Dallas 75240
Hamilton/Avnet Electronics
1216 West Clay
713/526-4661
Houston 77019
WISCONSIN
Cramer /Wisconsin
430 West Rawson
414/764-1700
Oak Creek 53154
125
NORTHEAST
CONNECTICUT
Hamilton/Avnet Electronics
643 Danbury Road
203/762-0361
Georgetown 06829
Cra mer/Connecticut
36 Dodge Avenue
203/239-5641
North Haven 06473
MARYLAND
Cramer/EW Baltimore
922-24 Patapsco Avenue
301/354-0100
Baltimore 21230
Cramer/EW Washington
16021 Industrial Drive
301/948-0110
Gaithersburg 20760
Hamilton/Avnet Electronics
7255 Standard Drive
301'/796-5000
Hanover 20176
MASSACHUSETTS
Cramer Electronics, Inc.
85 Wells Avenue
617/969-7700
Newton 02159
Hamilton/Avnet Electronics
185 Cambridge Street
617/273-2120
Burlington 01803
NEW J~RSEY
Hamilton Electro Sales
218 little Falls Road
201/239-0800
Cedar Grove 07009
Cramer/New Jersey
No.1 Barrett Avenue
201/935-5600
Moonachie 07074
Hamilton/Avnet Electronics
113 Gaither Drive
East Gate I ndustria I Park
609/234-2133
Mt. Laurel 08057
Cramer/Pennsylvania, Inc.
7300 Route 130 North
609/662-5061
Pennsauken 081I0
NEW YORK
Cramer/Binghamton
3220 Watson Boulevard
607/754-6661
Endwell 13760
C ra mer/Rochester
3000 Winton Road South
716/275-0300 .
Rochester 14623
Cramer/Syracuse
6716 Joy Road
315/437-6671
East Syracuse 13057
Hamilton/Avnet Electronics
6400 Joy Road
315/437-2642
Syracuse
13057
Cramer/Long Island
29 Oser Avenue
516/231-5600
Hauppauge, L.1. 11787
Hamilton/ Avnet Electronics
70 State Street
516/333-5800
Westbury, L.1. 1I590
PENNSYLVANIA
Sheridan Sales Co.
4268 North Pike
North Pike Pavilion
412/373-1070
Monroeville 15146
SOUTHEAST
ALABAMA
Cramer/EW Huntsville, Inc.
2310 Bob Wallace Avenue
205/539-5722
Huntsville 35805
FLORIDA
Cramer/EW Hollywood
4035 North 29th Avenue
305/923-8181
Hollywood 33020
Hamilton/Avnet Electronics
4020 North 29th Avenue
305/925-5401
Hollywood 33021
Cramer/EW Orlando
345 North Graham Avenue
305/894-1511
Orlando 32814
GEORGIA
Cramer/EW Atlanta
3923 Oakcliff Industrial Court
404/448-9050
Atlanta 30340
Hamilton/Avnet Electronics
6700 Interstate 85 Access Road
404/448-0800
Norcross 30071
NORTH CAROLINA
Cramer Electronics
938 Bllrke Street
919/725-8711
Winston-Salem 27102
CANADA
BRITISH COLUMBIA
, L.A. VARAH Ltd.
2077 Alberta Street
604/873-3211
Vancouver 10
ONTARIO
Cramer/Canada
920 Alness Avenue, Unit No.9
Downsview
416/661-9222
Toronto 392
Hamilton/Avnet Electronics
6291 Dormain Rd., No. 19
416/677-7432
Mississauga
Hamilton/Avnet Electronics
880 Lady Ellen Place
613/725-3071
Ottawa
QUEBEC
Hamilton/Avnet Electronics
935 Monte De liesse
514/735-6393
St. Laurent, Montreal 377


## Scan page 130

Ordering Information
1. The 8008 (CPU) is available in ceramic only and should be
ordered as C8008 or C8008-1 .
2. SIM8-01 Prototyping System
This MCS-8 system for program development provides complete
interface between the CPU and ROMs and RAMs. 1702A elec
trically programmable and erasable ROMs may be used for the
program development. Each board contains one 8008 CPU,
1 k x 8 RAM, and sockets for up to eight 1702As (2k x 8 PROM).
This system should be ordered as SIM8-01 (the number of
PROMs should also be specified).
3. Memory Expansion
Additional memory for the 8008 may be developed from indivi
dual memory components. Specify RAM 1101, 1103, 2102;
ROM 1702, 1302.
4. MP7-03 ROM Programmer
This is the programmer board for the 1702A. The 1702A control
ROMs used with the SIM8-01 for an automatic programming
system are specified by pattern numbers A0860, A0861, A0863.
5. MCB8-tO System Interface and Control Module
The MCB8-1 0 is a complete chassis which provides the intercon
nection between the SI M8 -01 and MP7 -03. I n addition, the
MCB8-10 provides the 50Vrms power supply for PROM program
ming, complete output display, and single step control capability
for program development.
6. Bootstrap Loader
The same control ROM set used with the PROM programming
system is used for the bootstrap loading of programs into RAM
'and execution of programs from RAM. Specify 1702A PROMs
programmed to tapes A0860, A0861 , and A0863.
Packaging Information
126
7. SIM8 Hardware Assembler
Eight PROMs containing the assembly program plug into the
SIM8-01 prototyping board permitting assembly of all MCS-8
software. To order, specify C1702A/840 set.
8. PL/M Compiler Software Package
Programs for the MCS-8 may now be developed in a high level
language and compiled to 8008 machine code. This program is
written in FORTRAN IV and is available via time sharing service
or directly from Intel.
9. MCS-8 Cross Assembler and Simulator Software Package
This software program converts a list of instruction mnemonics
into machine instructions and simulates the execution of instruc
tions by the 8008. This program is written in FORTRAN IV
and is aVailable via time sharing service or directly from Intel.
10. Intellec 8
The Intellec 8, Bare Bones 8, and microcomputer modules must
be specified individually by product code.
imm8-80A Intellec 8 (complete table top system)
imm8-81 Bare Bones 8 (complete rack mountable system)
imm8-82 Central Processor - includes 8008-1 CPU crystal
clock and interface logic
imm6-26 PROM Memory - includes sockets for sixteen
1702A PROMs
imm6-28 RAM Memory - 4k x 8 static memory
imm8-60 Input/Output - 4 input and 4 output ports
imm6-76 1702A PROM programmer and control software
imm6-70 Universal prototype module
imm6-72 Module extender
CERAMIC PACKAGE OUTLINE
AL TERNATE PIN =1 IDENT.
(IF NO NOTCH AT END OF PKG.I -""
.050 i_ .2!'.!l---..l
MAX.! .310 I
*=fIii ! , -*- .200 MAX. ' I
j l~ i
~ ~ ~ ~TYP.-/!- 15
0
MAX.-1 \-.060 .012


## Scan page 131

MCS-8 T.M Instruction Set
INDEX REGISTER INSTRUCTIONS
The load instructions do not affect the flag flip-flops. The increment and decrement instructions affect all flip-flops except the carry.
MINIMUM
MNEMONIC STATES
REQUIRED
lSI
1:lILrM 181
LMr
(31l.rI (81
LMI (91
INr (51
OCr (51
INSTRUCTION CODE
~ 0 6 0 5 0 4 0 3 ~ 0 1 DO
1 1
1 1
1 1
o 0
B B
o 0
B B
o 0
o 0
D D D
DOD
1 1 1
ODD
B B B
1 1 1
B B B
ODD
ODD
S S S
1 1 0
B B
1 1
B B B
000
o 0 1
DESCRIPTION OF OPERATION
Load index register r 1 with the content of index register r2.
Load index register r with the content of memory register M.
Load memory register M with the content of index register r.
Load index register r with data B ... B.
Load memory register M with data B ... B.
I ncrement the content of index register r Ir f AI.
Decrement the content of index register r (r I AI.
ACCUMULATOR GROUP INSTRUCTIONS
The result of the ALU instructions affect all of the flag flip-flops_ The rotate instructions affect only the carry flip-flop.
AOr (51 1 0 0 0 0 S S S Add the content of index register r, memory register M, or data
ADM (SI 1 0 0 0 0 1 1 B ... B to the accumulator. An overflow (carryl sets the carry
ADI lSI 0 0 0 0 0 1 0 flip-ilop.
B B B B B B B B
I-_A::::C::::r __ -+-_..!(:::51_---if--..:..1~0 __ 0=__0=__1:.......__=S__=S__=S__1 Add the content of index register r, memory register M, or data
I--.:...:.AC::::M.:.:....-_-+-_..!(S:::'_---if--..:..1 ~0 __ 0=__0=_1:.......--.:1___,:1---=-1__1 B .. ,B to the accumulator with carry. An overflow (carryl
ACI (SI 0 0 0 0 1 1 0 0 sets the carrv II ip-flop.
B B B B B B B B
I-_S~U:::r __ -+-_..!(:::51_---if--..:..~O __ O=__1.:......:0=____=S__=S__=S__1 Subtract the content of index register r, memory register M, or
1--~~~:::~=----+--..!::::::----if--..:..~--~=--:':""":~=----':--':---=---1 :t:a t~e' ';';r~yf;~;f:::.accumulator. An underflow (borrowl
B B B B B B B
SBr (51 1 0 o 1 1 S S S
SBM (SIlO 0 1 1 1 1 Subtract the content of index register r. memory register M. or data
I-.....:::.:SB:::I=----+--..!(:::SI-........:f--..:..O~O--O"---.:....l "":"';--"":"""":0---':--1 data B ... B from the accumulator with borrow. An underflow
B B B B B B (borrowl sets the carry flip-flop.
I-....:N.:.:O:::.r __ +_-.!.:(5:::.1----!....:...1 ...:0"---_1~0:........::0:........__=S__=S~S_lCompute the logical AND of the content of index register r,
I-....:N.:.:O:::.M::.....-_+_-.!.:(S:::.I----!....:...1 ...:0"---_1~0:........::0:........___,:1---=-1~1_l memory register M. or data B ... B with the accumulator.
NOI (SI 0 0 1 0 0 1 0 0
B B B B B B B B
I--'Xc:..:R..:.:r __ +-_c:..:(5:::.1_---1-'-1_0"____1:........::0::........:1_......::;.S......::;.S--=.S-ICompute the EXCLUSIVE OR of the content of index register
1-....:~..:.::..:.:~:.:.....--+--..:.:~:::.:----!-0.:..1 _~=---::........::~:........::::...-........;.:........;.~~~-lr. memory register M. or data B ... B with the accumulator.
B B B B B B B B
I--....:O:::.R..:.:r __ +-_.!.:(5:::.'_---1-'-1...:0"---_1:........::1:........::0:..............:::.S......:::.S--=.S-ICompute the INCLUSIVE OR of the content of index register
I--....:O:::.R..:.:M::.....-_+-_.!.:(S::!.I_---1-'--=-_-'1:........::1:........::0:........-=.1---=-1~-Ir, memory register m, or data B ... B with the accumulator.
ORI lSI 1 0 0
B B B B B
I-~CP~r __ -+-_..!15:::1 __ f--..:..l~0_....:...1_1.:........1:........__=S:........::S__=__1Compare the content of index register r. memory register M,
I--_C:::.;Pc..:.M"---_-+-_...!.(S:::I __ ~1......:::.0--'-1 _1.:........1:""""--':::"""":-='-I0r data B ... B with the accumulator. The content of the
CPI (SI 0 0 1 1 accumulator is unchanged.
B B B B B B B
RLC (51 o 0 0 0 0 o 1 0 Rotate the content of the accumulator left.
RRC (51 o 0 0 0 o 1 0 Rotate the content of the accumulator right.
RAL (51 o 0 0 1 1 0 Rotate the content of the accumulator left through the carry.
RAR (51 o 0 0 1 1 1 0 Rotate the content of the accumulator right through the carry.
PROGRAM COUNTER AND STACK CONTROL INSTRUCTIONS
(4IJMP (111
(5) JFc (9 or 111
JTc (90r 11)
CAL (111
CFc 19 or 111
CTc (9 or 111
RET (51
RFc (3 or 5)
RTc (3 or 5)
RST (51
o 1
~~
X X
o C4C3
B2 B2B2
B3 B3 B3
o 1 X X X
~B2 B2B2B2
X X B3B3B3
o 0 X X X
o 0
1 0 0 Unconditionally jump to memory address B3 ... B3B2 ... B2.
B2 B2 B2
B3 B3 B3
o 0 0 Jump to memory address B3 ... B3B2 ... B2 if the condition
B2 B2 B2 flip-flop c is false. Otherwise. execute the next instruction in sequence.
133 B3 B3
o 0 0 Jump to memory address B3 ... BJ82 ... B2 if the condition
~ ~ ~ flip-flop c is true. Otherwise. execute the next instruction in sequence.
B3 B3 B3
1 1 0 Unconditionally call the subroutine at memory address B3 ...
B2 ~ ~ BJ82 ... B2. Save the current address (up one level in the stack).
B3 B3 B3
o 1 0 Call the subroutine at memory address B3 ... B3B2 ... B2 if the
~ ~ B2 condition flip-flop c is false, and save the current address (up one
B3 B3 B3 level in the stack.! Otherwise, execute the next instruction in sequence.
o 1 0 Call the subroutine at memory address B3 ... B3B2 ... B2 if the
~ ~ ~ condition flip-flop c is true. and save the current address (up one
B3 B3 B3 level in the stackl. Otherwise, execute the next instruction in sequence.
1 1 1 Unconditionally return (down one level in the stackl.
o 1 1 Return (down one level in the stackl if the condition fl ip-flop c is
false. Otherwise, execute the next instruction in sequence.
o 0 1 C4 C3 0 1 1 Return (down one level in the stackl if the condition flip-flop c is
true. Otherwise, execute the next instruction in sequence.
o 0 A A A 1 0 1 Call the subroutine at memory address AAAOOO (up one level in the stackl.
INPUT/OUTPUT INSTRUCTIONS
(S) o 1
(61 o 1
MACHINE INSTRUCTION
o 0 M M M 1 Read the content of the selected input port (MMMI into the
accumulator.
R R M M M 1 Write the content of the accumulator into the selected output
port (RRMMM, RR 1001.
(41 0 0 0 0 0 0 0 X Enter the STOPPED state and remain there until interrupted.
H L T (41 1 1 1 1 1 1 1 1 Enter the STOPPED state and remain there until interrupted.
NOTES:
(1) SSS = Source Index Register } These registers. r" are designated A(accumulator-OOOI, .-nfel"
DOD = Destination Index Register B(001l, C(010), 0(011). E(l00I, H(1011, LlllOl.
(21 Memory registers are addressed by the contents of registers H & L.
(3) Additional bytes of instruction are designated by BBBBBBBB.
(41 X = "Don't Care".
(5) Flag flip-flops are defined by C4C3: carry 100-overfiow or underflowl, zerO (Ol-result is zero), sign (10-MSB of result is "1"1,
parity (ll·parity is evenl.


## Scan page 132

r
I
I
intel" Microcomputers. FIrst from the beginning.
I
L ____ IN_T_E_L CORPORATION • 3065 B::_5 _A~:~a:_C_la_ra_. _~lif._O_rn __ i_a. _9_5_05_' __ - _(.4_0 .... 8 ... ' .... 2 ... _4.6_.-.7_ .. 5 ... 0._' ..... __ ._ .. _______ . .J
lfi19l4/Printed in U.S.A./MCS·056·0574/25K
