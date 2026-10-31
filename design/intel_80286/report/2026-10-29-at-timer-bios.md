# IBM AT BIOS with connected 8254 — 2026-10-29

## Follow-up: both channel-1 bit tests

Extended the connected run to `F000:027B`, after the BIOS's second timer test
has observed every channel-1 count bit low. The first checkpoint at
`F000:0258` and its `BL=FFh` assertion are still required; the second requires
`BL=00h` and timer-read values whose bitwise AND is zero. The complete
`run_software.sh` passed again with source hashes checked before and after:

| READY policy | Virtual timer half-period | CPU states | Timer reads | Result |
| --- | ---: | ---: | ---: | --- |
| Always ready | 3 fixture ticks | 197,002 | 15 | Both timer tests and Unicorn CPU comparison pass |
| Periodic stalls | 5 fixture ticks | 1,245,575 | 131,086 | Both timer tests and Unicorn CPU comparison pass |

Unicorn receives the captured I/O inputs and checks CPU CS:IP, defined flags,
registers, segments and data transactions at every retirement. It does not
independently validate the 8254. No physical timing, full POST or boot is
claimed. The work directory is `work/at_timer_software_20261029_04/`:

- `run_software.log`: `791BDFEDF2138C13E4C153FB552C74C38D2E234C42BD47B05C7BB7C86E0F67B3`.
- `at_timer_bios/inputs.sha256`: `09E86FC67205D35D105D76C199652BC2027A06419A659A5955C9234AA3519FBE`.
- `at_timer_bios/build.log`: `DEFB7D6021CD1287129C80D51FF690BD3B9FB418778F9FAB8CF419D110653C8A`.
- `at_timer_bios/obj/Vintel_80286_at_fixture`: `165D396DFE750BC9F28E59DFF0E51959D1EA0391DA190411960746146518CC2A`.
- `at_timer_bios/trace_wait0_half3.txt`: `F29C6D6E956820C000D9CB3B6831784FD28BD5873EFA443253C0D9A1F83FBC48`.
- `at_timer_bios/trace_wait1_half5.txt`: `B3F7AB56D9FD211361A53852EACAA524819C789D01F4DF57373F572CB025F335`.
- `at_timer_bios/oracle_wait0_half3.log`: `1B9A0600F72E1B826DEB5EFAD266692FF71DCD8858BBBA7FB0A2AA73A4D0C3EC`.
- `at_timer_bios/oracle_wait1_half5.log`: `C0505334D36A0A597CE057FD47A5DEC435C513F40C3D747641537F977D16E51A`.

The initial `F000:0258` checkpoint and its separate evidence are retained below.
The follow-up was posted and read back in
[issue comment 6490338942](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6490338942).

## Result

Connected the 80286 byte-transaction model to the existing 8254 RTL through
the [AT timer adapter](../spec/ibm_at_timer_fixture.md). The fixture routes
accepted I/O on ports `40h`–`43h` to the timer and supplies its read value to
the CPU; other ports retain a simple stored-byte model. The original IBM AT
REV1 BIOS now reaches `F000:0258`, immediately after the channel-1 all-bits-on
timer test. The fixture checks the observed timer inputs OR to `FFh` and the
BIOS's resulting `BL` is `FFh` at that exact instruction. CPU RTL did not
change in this step.

Two virtual-clock scenarios passed, each followed by a Unicorn 2.1.4 CPU
comparison of every retired instruction's CS:IP, defined FLAGS, registers,
segments and data transactions. Captured I/O read bytes are supplied to Unicorn;
this independently checks CPU execution with those inputs, not 8254 fidelity.
Instruction-fetch bus timing and exact fetch transactions are not compared.

| READY policy | Timer half-period in fixture ticks | CPU states | Timer reads | Result |
| --- | ---: | ---: | ---: | --- |
| Always ready | 3 | 196,889 | 3 | BIOS checkpoint and CPU comparison pass |
| Stalled periodically | 5 | 1,245,453 | 131,073 | BIOS checkpoint and CPU comparison pass |

These are two combinations, not an exhaustive READY/clock matrix. The core's
simulation tick is not qualified as a physical 6 MHz 80286 clock; these clock
choices are fixture assumptions and do not establish IBM AT timing. The long
polling loop in the second combination is captured rather than skipped.

## Reproduction and evidence

The existing historical software entry point now includes both connected-timer
scenarios. In `ai-hw-engineer:latest` the command below exited 0, including
the earlier checksum, helper, IRQ8 and system-register regressions:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/at_timer_software_20261029_03 \
  sh design/intel_80286/scripts/run_software.sh
```

The pinned IBM ROM is acquired and SHA-256 checked by the existing preparation
script. Unicorn is pinned to 2.1.4. The combined model used Verilator 5.052
with `-Wall`, g++ 15.2.0 and Python 3.14.4. Its `inputs.sha256` binds the ROM,
CPU and timer RTL, adapter, fixture, runner and oracle scripts; all entries
matched when the run finished. Files below are in the ignored work directory:

- `run_software.log`: `28BAFC0BC3E260BC0405D9BE3E0823DBACE5E054B7336AC3A937D4EC05DEE2BA`.
- `at_timer_bios/inputs.sha256`: `A0A047946C07B49B4B91EBAE26CDEF1A407EF37889CD07D3537A5D8BDEF53192`.
- `at_timer_bios/build.log`: `6C22B1E9962A88E472098F36CE4F44B76E7CD38012B787CD327940E5FCC356B2`.
- `at_timer_bios/obj/Vintel_80286_at_fixture`: `5BD86146E0160E6683949571CDFE3507573AACF7A6EBB453280936E4D69596B0`.
- `at_timer_bios/trace_wait0_half3.txt`: `961879D053647BC79A50F58C980AA277C98E426B681582D208E747E7BF9B9621`.
- `at_timer_bios/trace_wait1_half5.txt`: `7E2C4AB779B0F274F9BE09307983407EBC158BA4140018D1789535AE1A8F13A6`.
- `at_timer_bios/oracle_wait0_half3.log`: `BC9EE83094811C4BE60811D36C01A1406426C8E426E21F754E419B8D211E7F06`.
- `at_timer_bios/oracle_wait1_half5.log`: `4C424E13FC5F6F12BD72542F9DC9D61D16E80060CAFD677EF971B5F7EBEBD02D`.

## Boundaries

The fixture supplies zeroed RAM, ROM aliases and static non-timer port bytes;
INTR and NMI are held inactive. It has no refresh latch/DMA, PIC, keyboard,
disk or full platform model. The initial run stopped at the first timer-test
success; the follow-up stops after the second, before the remaining board tests
and POST. The timer is the repository RTL, not an
independent timing oracle. Full POST/boot, OS/2 CPGREP on RTL, physical timing,
current-source connected-core formal, and whole-CPU acceptance remain open.

The checkpoint was posted and read back in
[issue comment 6490277004](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6490277004).
