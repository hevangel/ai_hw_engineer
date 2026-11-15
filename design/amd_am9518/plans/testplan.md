# Test Plan — AMD Am9518

## Oracles

1. **Algorithm oracle**: third-party `pyDes` implementation, every vector
   cross-checked against OpenSSL 3.x legacy-provider DES. Two independent
   external implementations must agree bit-for-bit before a vector file is
   written. `scripts/generate_vectors.py --check` re-verifies the anchors
   and regenerates `tb/vectors/`; `tb/vectors/SHA256SUMS` pins the
   committed files.
2. **Published anchors** (checked at generation time):
   - key 0000000000000000, plaintext 0000000000000000 → 8CA64DE9C1B123A7.
   - key 0123456789ABCDEF, plaintext "Now is t" (4E6F772069732074) →
     3FA40E8A984D4815.
   - **AMD's own interface-test vector** (1985 guide PDF pp. 53–54): key
     bytes 80 01 01 01 01 01 01 01 (effective 8000000000000000 after
     dropping LSB parity bits), plaintext 0000000000000000 →
     95A8D72813DAA94D. Reproducing this requires correct MSB-first byte
     order, LSB parity handling and DES — it validates the chip-level
     conventions, not just the algorithm.
3. **Formal**: `formal/*.sby` (see `plans/formal_plan.md`).

## Simulation suites (tb/amd_am9518_harness.cpp, scripts/run_sim.sh)

Each suite drives the chip at the strobe level in Multiplexed Control Mode
unless stated otherwise; every suite checks status bytes at the points the
datasheet/AMD test specify.

1. `amd_kat` — ECB known-answer set: the published anchors plus the pinned
   ECB vector file, encrypt and decrypt, through the full bus protocol:
   software reset → mode write → Load Clear E Key → parity/status checks →
   Start Encryption → 8 bytes in → Busy poll → 8 bytes out → compare →
   Stop → status checks. Also D-key decrypt of the same blocks.
2. `amd_interface_test` — AMD's published 8086 test as a directed sequence:
   exact status values 40H after the Load Clear E Key command, 00H after the
   key, 80H after reading the result, 00H after Stop; expected cipher text
   95A8D72813DAA94D; then decrypt of that cipher text back to zeros with
   the D key.
3. `cbc` — pinned CBC encrypt and decrypt sequences (random keys, IVs,
   multi-block messages) vs oracle; verifies chain progression and that
   Read Clear IVE/IVD return the current chaining values.
4. `cfb8` — pinned 8-bit CFB encrypt and decrypt byte streams vs oracle.
5. `encrypted_loads` — Load Encrypted E/D Key (31/32) with key material
   encrypted under a loaded M key via the auxiliary port; Load Encrypted
   IVE/IVD (A5/A4); Read Encrypted IVE/IVD (A9/A8); Encrypt with Master Key
   (39) — all compared against oracle-computed values.
6. `aux_key` — master-key load through the auxiliary port with ASTB strobes
   and AFLG handshake; AFLG inactive after the 8th strobe.
7. `parity` — good keys set no flags; one even-parity byte sets PAR/S3 at
   that byte, LPAR/S4 latches across the load, PAR clears on the next
   checked byte, LPAR clears on reset or new Load-Key command.
8. `modes_ports` — Figure 6 flag associations for the six non-reserved
   mode rows; single-port flow; dual-port slave-side encrypt/decrypt with
   independent master/slave streaming; Stop/in-progress semantics;
   hardware reset (MAS·MDS low) and the five-clock command blackout (A11).
9. `soak` — randomized ECB soak (pinned vectors, 128 blocks) both
   directions through master and slave paths.

## Coverage (scripts/run_coverage.sh)

Verilator coverage collection over the suites above; report reviewed for:
command decode bins (every Figure 2 opcode exercised), mode register
encodings, flag-association table rows, FIFO full/empty corners, parity
error/latched paths, hardware/software reset paths, CFB/CBC/ECB datapaths,
encrypted-load decrypt paths.

## Non-goal

Real-time bus-cycle nanosecond timing (A3/A4): the harness satisfies the
documented setup/hold relationships relationally (strobe width, MAS→MDS
separation, falling-edge-aligned rising edges) rather than by absolute ns.
