# AMD Am9518 Data Ciphering Processor — Specification

Reconstruction target: AMD Am9518 Data Ciphering Processor (DCP), an NBS/DES
block-cipher peripheral introduced as part of AMD's Am9500 peripheral family.

First introduced: **1980**. AMD's 1980 Am9500 Peripheral Products Interface
Guide contains the Am9518 as a two-page "ADVANCED DATA" preliminary datasheet
(PDF pages 134–135 of the bitsavers scan), which dates the part to 1980. The
final datasheet (AMD document 00618B, printed pages 2-461 through 2-478) pairs
the Am9518 with the AmZ8068 in the AMD MOS Microprocessors and Peripherals
databook. No exact launch month is asserted.

## Primary sources

- [1980 AMD Am9500 Peripheral Products Interface Guide](https://www.bitsavers.org/components/amd/_dataBooks/1980_AMD_Am9500_Peripheral_Products_Interface_Guide.pdf),
  PDF pages 32–33 (AmZ8002/8085A interfaces) and 134–135 (preliminary
  Am9518 datasheet: distinctive characteristics, connection diagram, block
  diagram).
- **AMD Am9518/AmZ8068 datasheet**, AMD doc 00618B (printed pages 2-461 …
  2-478; scan cached from a distributor archive, see
  `references/README.md`): pin descriptions, register/command/status/mode
  definitions, command descriptions, DC and switching characteristics,
  switching waveforms, pipelined dual-port timing, application interfaces.
- [1985 AMD Peripheral Processor Interface Guide](https://www.bitsavers.org/components/amd/_dataBooks/1985_Peripheral_Processor_Interface_Guide.pdf),
  PDF pages 39–54 (80186/8086/8088/80286 interfaces, AMD's tested 8086
  interface program with its published expected cipher text), 127–129 (Z80
  interface, address-latch/data-transfer cycle protocol), 141 (8085
  interface).
- NBS FIPS PUB 46 (1977) — the Data Encryption Standard algorithm the DCP
  implements ("National Bureau of Standards Data Encryption Standard … in
  accordance with standards specified in the Federal Information Processing
  Data Encryption Standards Publication 46", datasheet p. 2-465).
- NBS FIPS PUB 81 (1980) — DES modes of operation; the 8-bit Cipher Feedback
  construction implemented by the DCP.

An independent functional oracle is used for verification: the third-party
`pyDes` implementation cross-checked against OpenSSL's legacy-provider DES on
every generated vector, plus AMD's own published interface-test vector
(documented below). See `plans/testplan.md` and `scripts/generate_vectors.py`.

## Device summary

The DCP encrypts and decrypts 64-bit blocks with the NBS DES algorithm. It
exposes three 8-bit ports — Master (MP0-7 with MCS, MR/W, MDS, MAS, MFLG),
Slave (SP0-7 with SCS, SDS, SFLG) and Auxiliary (AUX0-7 with ASTB, AFLG) —
plus a PAR parity output, a C/K control/key mode input and a TTL CLK input
(datasheet p. 2-461 connection diagram, p. 2-463/2-464 pin descriptions).

- Cipher modes (mode register M6M5): 00 Electronic Code Book (reset default),
  01 Cipher Feedback (8-bit CFB), 10 Cipher Block Chain (CBC), 11 reserved
  (datasheet p. 2-468 Figure 5).
- Port configurations (M3M2): 00 Dual Port, Master Encrypted/Slave Clear;
  01 Dual Port, Master Clear/Slave Encrypted (default); 10 Single Port,
  Master Only; 11 reserved (Figure 5). M4 selects encrypt (1) / decrypt (0);
  M1M0 unused.
- Registers (datasheet p. 2-466/2-467 and p. 2-468/2-469): Command (8-bit
  write-only), Status (8-bit read-only), Mode (read/write), Input Register
  (64-bit write-only, "push down storage"), Output Register (64-bit
  read-only, "pop-up storage"), M/K Key Register (64-bit, Auxiliary-port
  load only), E Key and D Key registers (64-bit each), IVE and IVD
  initializing-vector registers (64-bit each).
- Timing contract (datasheet p. 2-477 Figures DF001290/DF001300): a block is
  written in 8 clocks (one byte per clock), the algorithm unit starts when
  the input register completes, the input flag for the next block activates
  5 clocks later, the algorithm finishes 18 clocks after it started, the
  output flag activates 5 clocks after that, and 8 clocks remain to unload
  the result (39 clocks first block, 18 clocks steady state). This matches
  the throughput formula T = 8·f/(N+5) MB/s of the 1985 interface guide
  (PDF page 53) and the quoted >1.3 Mbyte/s (Am9518) / >1.7 Mbyte/s (AmZ8068)
  at their maximum clock rates.

## Master port (Multiplexed Control Mode, C/K = LOW)

Register addressing follows datasheet p. 2-467 Figure 1; MP1/MP2 and MCS are
latched on the rising edge of MAS (p. 2-463 MCS/MAS pin descriptions):

| C/K | MP2 | MP1 | MR/W | MCS | Register addressed |
|-----|-----|-----|------|-----|--------------------|
| 0   | X   | 0   | 0    | 0   | Input Register (write) |
| 0   | X   | 0   | 1    | 0   | Output Register (read) |
| 0   | 0   | 1   | 0    | 0   | Command Register (write) |
| 0   | 0   | 1   | 1    | 0   | Status Register (read) |
| 0   | 1   | 1   | X    | 0   | Mode Register (read/write) |
| X   | X   | X   | X    | 1   | No register accessed |
| 1   | X   | X   | 0    | 0   | Input Register (write) |
| 1   | X   | X   | 1    | 0   | Output Register (read) |

MP0 is the low-order bit; data and key bytes are entered most-significant
byte first (p. 2-463). Write data is sampled on the rising edge of MDS
(parameters 47/48: 160 ns setup, 25 ns hold); read data is driven while MCS,
MR/W and MDS are low (parameter 49: 150 ns data / 300 ns status access).
The three-state master-port outputs are enabled only when MCS is low, MR/W
is high and MDS is low (p. 2-463 MP0-MP7 description).

Hardware reset occurs whenever MAS and MDS are LOW simultaneously (pulse
width ≥ 1 clock, reset-to-control release ≤ 50 ns, parameters 5/6); the DCP
is "reset to ECB mode and all flags inactive" (p. 2-463 MAS description).
After any reset the DCP ignores commands for approximately five clock cycles
(p. 2-466).

## Status register (datasheet p. 2-468 Figure 4)

| Bit | Name | Meaning |
|-----|------|---------|
| S7  | Start/Stop | 1 = a Start command is entered; 0 otherwise |
| S6  | CP — Command Pending | 1 while a Load/Read transfer or its internal ciphering is in progress |
| S5  | BSY — Busy | 1 while the algorithm unit is encrypting/decrypting |
| S4  | LPAR | 1 = one or more even-parity key bytes since last reset/Load-Key command |
| S3  | PAR | 1 = most recent parity-checked key byte had even (bad) parity |
| S2  | AFLG | 1 = Auxiliary Port expects key bytes |
| S1  | SFLG | 1 = Slave Port flag active |
| S0  | MFLG | 1 = Master Port flag active |

The PAR, AFLG, SFLG and MFLG output pins are active low and reflect the
corresponding status bits (p. 2-464 PAR description, p. 2-468 text). AUX2
(BSY) and AUX3 (CP) drive low while BSY=1 / CP=1 in Direct Control Mode.

## Flag-to-register association (datasheet p. 2-469 Figure 6)

| M4 | M3M2 | Input Register flag | Output Register flag |
|----|------|---------------------|----------------------|
| 0 (decrypt) | 00 (Master Enc, Slave Clear) | MFLG | SFLG |
| 0 | 01 (Master Clear, Slave Enc) | SFLG | MFLG |
| 0 | 10 (Single Port) | MFLG | SFLG |
| 1 (encrypt) | 00 | SFLG | MFLG |
| 1 | 01 | MFLG | SFLG |
| 1 | 10 | MFLG | SFLG |

An input-assigned flag activates when a Start command is entered and the
input register is not full, and is forced inactive when any other command is
entered; it deactivates while the register is full and reactivates five
clocks after the algorithm unit begins processing (p. 2-477 timing diagram).
An output-assigned flag activates whenever the output register is not empty.
In Single Port configuration MFLG tracks the input flag and SFLG tracks the
output flag (p. 2-468 text, p. 2-465/2-466).

## Command set (datasheet p. 2-467 Figure 2, descriptions p. 2-469/2-470)

| Code | Command |
|------|---------|
| 91 | Load Clear M Key through Auxiliary Port |
| 81 | Load Clear E Key through Auxiliary Port |
| 92 | Load Clear D Key through Auxiliary Port |
| 11 | Load Clear E Key through Master Port |
| 12 | Load Clear D Key through Master Port |
| B1 | Load Encrypted E Key through Auxiliary Port |
| B2 | Load Encrypted D Key through Auxiliary Port |
| 31 | Load Encrypted E Key through Master Port |
| 32 | Load Encrypted D Key through Master Port |
| 85 | Load Clear IVE through Master Port |
| 84 | Load Clear IVD through Master Port |
| A5 | Load Encrypted IVE through Master Port |
| A4 | Load Encrypted IVD through Master Port |
| 8D | Read Clear IVE through Master Port |
| 8C | Read Clear IVD through Master Port |
| A9 | Read Encrypted IVE through Master Port |
| A8 | Read Encrypted IVD through Master Port |
| 39 | Encrypt with Master Key |
| 41 | Start Encryption (forces M4=1) |
| 40 | Start Decryption (forces M4=0) |
| C0 | Start (uses current M4) |
| E0 | Stop |
| 00 | Software Reset |

Command Pending (S6) is set by every command whose execution transfers data
to or from a non-addressable register — all Load and Read commands — and
returns to 0 after the eight bytes have moved (immediately for clear
transfers, after transfer+decrypt for encrypted loads, after encryption for
Read-Encrypted). The three Start commands, Stop and Software Reset never set
CP (p. 2-467).

- **Key loads**: eight bytes are written through the selected port (Master
  loads use the Input Register address) most-significant byte first. Each
  byte is odd-parity checked with the least significant bit as parity
  (p. 2-464 PAR description); PAR/S3 reflect the most recent byte and LPAR/S4
  latches any error until reset or the next Load-Key command. Encrypted key
  bytes are routed through the Input Register, decrypted with the Electronic
  Code Book algorithm, then parity checked and loaded; CP stays 1 through the
  decryption and BSY is 1 during it (p. 2-469/2-470). The M (master) key can
  be loaded in the clear only, through the Auxiliary Port (p. 2-466).
- **Encrypted session keys** are decrypted under the M/K key register:
  "The M Key … is used only to encrypt session key for transmission to
  remote DES equipment and to decrypt session keys received from such
  equipment" (p. 2-465). Encrypted IVs are decrypted under the D Key
  register, "the right vector bytes are decrypted using the overriding (D)
  Key and the Electronic Code Book algorithm" (p. 2-470 Load Encrypted IVE).
- **Read Clear IVE/IVD** (8D/8C): each IV register appears as eight bytes of
  FIFO storage; the first byte is available 6 clocks after the command;
  CP stays 1 until the eighth byte is read (p. 2-470).
- **Read Encrypted IVE/IVD** (A9/A8): encrypt the selected IV register with
  the E Key under ECB and place the result in the Output Register for the
  host to read; BSY during encryption, CP until the eighth byte is read.
- **Encrypt with Master Key** (39): eight bytes written to the Input
  Register are ECB-encrypted under the M Key into the Output Register;
  CP/Busy sequence the three phases (p. 2-470).
- **Start Encryption / Start Decryption / Start**: set S7=1 and activate the
  port flags associated with the Input Register. 41/40 override M4; C0 keeps
  it (p. 2-470). Data then flows per the mode/flag association.
- **Stop** (E0): clears S7, deactivates the input flag, inhibits input
  loading; an operation in progress finishes and output data stays readable
  (p. 2-470).
- **Software Reset** (00): same effect as hardware reset — mode register to
  ECB / Dual Port Master Clear Slave Encrypted, all flags inactive
  (p. 2-470). Reset sources (p. 2-465/2-466): software reset, hardware
  (MAS·MDS low), writing the Mode Register (which does not then reset the
  mode register itself), or aborting any command.

## Key and IV semantics

- Every key byte: 7 data bits (bits 8…2 of the byte, MSB side) plus 1 parity
  bit (bit 1, the LSB); odd parity required (p. 2-464).
- Eight bytes are entered most-significant byte first on all ports (p. 2-463,
  2-464).
- AMD's published 8086 interface test (1985 guide PDF pages 53–54) loads the
  key bytes 80 01 01 01 01 01 01 01, i.e. effective key 8000000000000000
  after dropping LSB parity bits, and expects cipher text 95A8D72813DAA94D
  for plaintext 0000000000000000. Both pyDes and OpenSSL reproduce this
  vector for standard DES, which validates the byte order, parity-bit
  position and algorithm implementation together.
- ECB/CBC ciphering reads the E Key register when M4=1 and the D Key
  register when M4=0 (p. 2-465 "Multiple Key Registers"); the D Key register
  exists "to decrypt cipher text" without a reload.
- CBC maintains the chaining value in IVE (encrypt chain) and IVD (decrypt
  chain); CBC "also provides an error extension characteristic in protecting
  against fraudulent data insertions and deletions" (p. 2-465). IVE/IVD are
  two separate 64-bit registers used "for Cipher Feedback and Chained Block
  ciphering methods. One initializing Vector register (IVS) is used for data
  encryption … the other (IVD) during decryption" (p. 2-469).
- 8-bit CFB "generates a pseudorandom binary stream which is then
  exclusive-OR'd with the clear data to form the cipher text. The cipher
  text is then fed back to form a portion of the next DES input. The DCP
  implements 8-bit Cipher Feedback (CFB) by making all 64 bits of the IV
  available with only 8 bits being one byte wide" (p. 2-465).

## Algorithm unit

DES as specified in FIPS PUB 46: initial permutation, 16 rounds
(expansion, key-mixing, eight S-boxes, P permutation), final permutation;
key schedule PC-1, 16 rotations (1,1,2,2,2,2,2,2,1,2,2,2,2,2,2,1) and PC-2.
Decryption uses the D Key register with the round-key sequence reversed —
the standard property that DES decryption equals encryption with subkeys in
reverse order. The RTL implements one DES round per clock, 18 clocks per
block (initial-permutation load + 16 rounds + final-permutation store),
matching the datasheet's 18-clock algorithm window (p. 2-477) and the 1985
guide's "5 = internal operation time (5 clocks per block)" staging overhead.

## Auxiliary port

- Multiplexed Control Mode (C/K low): AUX0-7 are a key-byte input port;
  AUX0 is the low-order bit and the parity bit; bytes enter MSB first
  strobed by ASTB (p. 2-464). The M Key can enter only here. AFLG activates
  on an Auxiliary key command, stays low for all eight bytes and goes
  inactive at the leading edge of the eighth ASTB (p. 2-464 AFLG
  description, timing parameters 61-67).
- Direct Control Mode (C/K high): AUX5-S/S (start/stop), AUX6-E/D
  (encrypt/decrypt and key-register select), AUX7-K/D (key/data), AUX2-BSY
  and AUX3-CP are direct control/status pins (p. 2-464, Figure 3 on p. 2-467):
  raising S/S with E/D high/low issues Start Encryption/Decryption, lowering
  it issues Stop; raising K/D selects Load Clear E or D Key through the
  Master Port (E/D high = E key), lowering it ends the key-load command;
  master-port access is limited to the Input/Output registers (p. 2-463).

## Slave port

The slave port carries the register flagged to it by Figure 6. Tri-state
outputs drive only while SCS and SDS are low, SFLG is 0 and the internal
configuration assigns output to the slave port; SP0 is the low-order bit;
data moves MSB first; SCS is not latched and may be tied low permanently
(p. 2-464). Write data is sampled on SDS rising edges, read data is driven
while SDS and SCS are low.

## Variant differences

- **Am9518 vs AmZ8068** (same datasheet, p. 2-472/2-473): AC timing only.
  Am9518: clock cycle ≥ 320 ns, high/low width ≥ 150 ns; AmZ8068: ≥ 250 ns /
  ≥ 115 ns. Several output-delay maxima are faster on the AmZ8068 (e.g.
  BSY low 400→300 ns, read access 300→200 ns, flag low 300→230 ns, MAS width
  115→80 ns, address setup 90→55 ns, strobe recovery 160→125 ns, PAR valid
  250→200 ns). The interface guide additionally quotes clock-max figures of
  2.3 MHz (Am9518) and 3-4 MHz (AmZ8068/Am9568) under 8086 bus timing
  constraints. The RTL is a synchronous functional reconstruction; it does
  not reproduce nanosecond AC parameters, and exposes a single CLK. A
  parameter documents the target variant.
- **Am9568**: a faster interface variant of the DCP family documented in the
  1985 guide (PDF pages 46–51): direct MRD/MWR strobes and MALE address
  strobe with C/K tied high, TWA 40 ns, clock max 3-4 MHz. It is outside
  this design's scope; documented here for variant completeness.
- 1980 preliminary datasheet lists a "Slave Direct (Slave Only)" port
  configuration which became "Reserved" (M3M2=11) in the final datasheet;
  the final encoding is authoritative and the RTL treats 11 as reserved.

## Assumption ledger

Every behavior below is not explicitly pinned by the sources; each entry is
implemented as documented here and exercised by the verification suite.

1. **A1 — Reset mode value**: the datasheet states reset sets "Electronic
   Code Book cipher type, and Dual Port Configuration with Master Port
   clear, Slave Port encrypted" but not the Encrypt/Decrypt bit. Implemented:
   mode register = 8'h04 (M4=0 decrypt orientation, M3M2=01, M6M5=00,
   M1M0=0).
2. **A2 — Key/IV register state after reset**: not specified. Implemented:
   key and IV registers retain their contents across reset (only flag and
   command state reset); the host normally reloads keys after reset anyway.
3. **A3 — Strobe synchronization**: the datasheet requires MDS rising edges
   synchronous to the CLK falling edge (parameter 45: clock-low to MDS-high
   = 0 … TWL-100 ns) and asynchronous-sampling tolerance elsewhere.
   Implemented: MAS/MDS/SDS/ASTB are sampled through a two-flop synchronizer
   and rising edges are acted on at the next rising CLK edge; the host
   testbench aligns strobe rising edges to the CLK falling edge as the
   hardware requires.
4. **A4 — Read data timing**: parameter 49 (150 ns data / 300 ns status
   access) is asynchronous. Implemented: read data is driven on the CLK
   edge after MDS/MR/W/MCS are observed low, and held until MDS rises.
5. **A5 — CFB key register and alignment**: the datasheet does not state
   which key register feeds CFB or the shift direction. Implemented per
   FIPS 81 8-bit CFB: the algorithm unit always computes the encryption
   function; the chaining register shifts left by one byte, the outgoing
   (most significant) byte of the DES output XORs the data byte and the
   cipher byte feeds back into the least significant end. The key register
   is selected by M4 exactly as in ECB/CBC (E for encrypt sessions, D for
   decrypt sessions); loading the same key into both registers reproduces
   standard interoperable CFB in both directions. Alternative reading
   (always the E register) noted; externally distinguishable only when the
   two registers differ.
6. **A6 — CBC chaining direction**: implemented per FIPS 81: encrypt
   Cn = E(Pn ⊕ Cn-1) seeded from IVE; decrypt Pn = D(Cn) ⊕ Cn-1 seeded from
   IVD; the chain register of the active direction updates to the latest
   cipher block. The register role (IVE tracks the encrypt chain, IVD the
   decrypt chain) follows the IVS/IVD naming on p. 2-469.
7. **A7 — Encrypted-key deciphering key**: decrypted under the M/K key
   register (p. 2-465 quote); encrypted-IV loads under the D key register
   (explicit on p. 2-470). The key-load text (p. 2-469) names only "the
   Electronic Code Book algorithm"; the M-key quote pins it for session
   keys.
8. **A8 — Reserved command codes and mode encodings**: M6M5=11, M3M2=11 and
   command codes outside Figure 2 are not defined by the datasheet.
   Implemented: ignored (no state change, no status effect).
9. **A9 — Illegal command reporting**: no status bit for illegal commands
   exists in the final Figure 4 (the 1980 preliminary listed an ILICM bit
   that the final part dropped). Implemented: no illegal-command state.
10. **A10 — Reads of write-only registers and writes to full registers**:
    reading the Input Register or writing the Output Register is not
    defined; implemented as reads of the Output/Status/Mode registers only
    (per Figure 1) and, for writes to a full input register, "the Input
    Register will disregard the attempt; no data in the register will be
    destroyed" (p. 2-468). Reading an empty output register leaves the bus
    in three-state (p. 2-469).
11. **A11 — "Approximately five clock cycles" command blackout after
    reset**: implemented literally as five clock cycles during which command
    writes are ignored.
12. **A12 — Parity checking of IV bytes**: PAR/LPAR semantics are defined
    for key bytes ("Key bytes are considered to contain seven bits of key
    information and one parity bit"). Clear IV loads (85/84) are IV data,
    not key bytes. Implemented: parity is checked only on key-byte loads
    (91/81/92/11/12/B1/B2/31/32 and Direct-mode key entry); IV loads and all
    data blocks bypass the parity checker.
13. **A13 — Start before key load / re-Start**: Start while S7=1 re-arms the
    session (flags reactivate); chaining registers keep their current
    values. Stop then Start restarts with the current chain values unless
    new IVs are loaded.
14. **A14 — Byte-lane conventions for the key registers**: the effective DES
    key is the 56 bits remaining after dropping the LSB of each byte; AMD's
    published vector (above) validates the combined byte order + parity
    interpretation against real silicon behavior.
15. **A15 — Start realigns the input register**: the datasheet does not
    state whether bytes left in the input register before a Start persist.
    Implemented: Start flushes the input-register byte count so blocks are
    always aligned to the session.
16. **A16 — Aborting a command**: entering a new command while a previous
    command sequence is still executing ("aborting any command", p. 2-466)
    performs the internal reset sequence with the default mode register;
    the newly written byte is not executed (the DCP is busy resetting).
17. **A17 — Input-flag quiescence**: the datasheet fragments "SFLG will go
    active whenever the Input Register is not full, once any of the Start
    commands has been entered" (p. 2-464) and the pipelined timing diagram
    (in-flag active at clock 13 while the algorithm runs) suggest a plain
    "not full" rule; AMD's published interface test instead expects status
    80H (MFLG inactive) after a single block has been ciphered and fully
    drained with the session still started. Implemented: the input-assigned
    flag is active only while the session is progressing — chip active
    (algorithm running, result staging, output data pending, or partial
    input bytes held) AND input register not full AND no command active.
    This reproduces AMD's status byte exactly and stays active during
    pipelined operation.

## Out of scope

- Nanosecond AC parameters and clock-rate limits (functional reconstruction
  only; see A3/A4 and the variant table).
- The Am9568 interface variant.
- Direct Control Mode interlock minutiae beyond Figure 3's documented
  sequences (S/S, K/D, E/D transitions, mutual-exclusion rule and the
  C/K-transition rule are implemented as described on p. 2-464).
- Power-up internal reset pulse timing (a power-on reset pulse is expected
  from the host, as with the real part's VCC-threshold reset).
