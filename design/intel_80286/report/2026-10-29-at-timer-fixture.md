# IBM AT timer fixture — 2026-10-29

IBM's March 1984 5170 technical reference, pages 1-8 through 1-10
([PDF pages 26–28](https://bitsavers.org/pdf/ibm/pc/at/1502494_PC_AT_Technical_Reference_Mar84.pdf#page=26)),
was visually reviewed with Playwright CLI. It identifies the 8254-2 and the
timer clocks, gates, IRQ0, refresh and speaker connections. Screenshots are
retained in ignored `work/at_timer_source_20261029_01/`:

- `manual_page26.png`: `54EABC8126024BB469B69A5E33755AA7B990792E00EA9E0E605D839CD3CC3572`.
- `manual_page27.png`: `2EAC53069306821D68D6457890FB69229A70D9970E5986AF8A658E245CEE754C`.
- `manual_page28.png`: `F557824A6B8AED8CAB6883FB4676DF07337D88B1ABF8741E48EF6D4579C07BA8`.

Added an adapter around the existing 8254 model for canonical I/O ports
`40h`–`43h`, with independent timer clocks and bus strobes qualified by the
accepted READY handshake. A standalone test programs channel 1 in mode 2,
holds a write stalled before acceptance, holds a read stalled while the timer
counts, latches and reads the expected count, and checks that port `44h` is
not decoded by this fixture. It does not instantiate the CPU.

`INTEL_80286_WORK_DIR=/work/design/intel_80286/work/at_timer_fixture_20261029_02 sh design/intel_80286/scripts/run_at_timer_fixture.sh`
passed in `ai-hw-engineer:latest`, using Verilator 5.052 with `--timing -Wall`.
Evidence under the selected ignored work directory has these SHA-256 hashes:

- 8254 RTL: `A970ABACAF133A4988886B362CE44A080173AEB858D816F0E2D90056ACD777E1`.
- Adapter: `ACD28DA59C1631F6132DCBCEF259A68D8A8DE91887CB8629BEC9609E1505AB7A`.
- Testbench: `C7026714D5B5800FD19D24545316CEF563F3E42D7ACB0F97D4F7A7BCDF28F43F`.
- Script: `AB62DC226B9BB3491E1C59A537CDED9123148CAD9AF28675F6C491F66563EEB7`.
- `at_timer_fixture/build.log`: `FA0A07AB3EED4CCF4FE4CAA11C7DD38557FAEC770B6E92FAE8847CF956B714CC`.
- `at_timer_fixture/sim.log`: `93EF789E62DA8A9002010C2D6B430F770DEC26FA74100107E958DB7B3D436916`.
- `at_timer_fixture/obj/Vintel_80286_at_timer_tb`: `86EB923E8B84EE73ABA45693DEA015BD0A4DECC060261097DFA6CE5CA6B40407`.

The [fixture contract](../spec/ibm_at_timer_fixture.md) records its clock and
address-decode assumptions. A later [connected BIOS run](2026-10-29-at-timer-bios.md)
reaches the first channel-1 timer-test success with the 80286 and 8254 RTL.
Other timer modes at the adapter boundary, full POST/boot, real
board timing, refresh/PIC integration, current-source whole-core formal and
overall 80286 acceptance remain open.

The issue checkpoint was posted and read back in
[comment 6490068444](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6490068444).
