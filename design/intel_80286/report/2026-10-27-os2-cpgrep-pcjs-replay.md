# OS/2 CPGREP independent baseline — 2026-10-27

## Result

The unchanged Microsoft OS/2 SDK 1.00 `CPGREP.EXE` ran from the SDK Samples
disk in a local PCjs 80286 machine booted to the Microsoft OS/2 1.0 command
environment. From `B:\APPS\CPGREP`, the command
`CPGREP -yn fast ..\README` returned the expected line 11 containing the
uppercase text `FAST`:

```text
11: CPGREP  Protect  - A multi threaded FAST string searching
```

This establishes an independent software baseline. It does not establish RTL
execution or a 286 instruction/exception trace.

## Machine and media

- Browser automation used `playwright-cli` with headed Chrome. PCjs v2.26 was
  served from the local ignored clone under `scratchpad/pcjs/`.
- The machine configuration was
  `scratchpad/pcjs/machines/pcx86/ibm/5170/ega/2048kb/rev3/os2sdk100-nohdc.xml`:
  an IBM PC AT with an 80286 at 8 MHz and 2 MB RAM. It has no hard disk.
- Drive A booted the public **MS OS/2 1.0 (1.2M Install)** image from the
  PCjs diskette catalog. The browser fetched
  `https://diskettes.pcjs.org/pcx86/sys/os2/microsoft/1.0/MSOS210-INSTALL.json`
  successfully (HTTP 200). The setup welcome screen appeared; pressing Esc
  returned to the OS/2 command prompt without starting installation.
- Drive B remained the local SDK 1.00 Samples disk (`OS2SDK09`), loaded from
  `/tools/pc/disks/samples_sdk100.json` served by the local PCjs clone. The
  SDK disk was not uploaded to a remote emulator.

`DIR B:\APPS\CPGREP` showed `CPGREP.EXE` at 27,330 bytes. PCjs's disk file
table MD5 values match the local extracted copies for both `CPGREP.EXE`
(`ed494d1ec745bada0e777a17d3b966f9`) and `APPS\README`
(`b398d16055f8a704127ea273f1824950`).

## Reproduction and identity

After the installer returned to its command prompt, the guest commands were:

```text
B:
CD APPS
CD CPGREP
CPGREP -yn fast ..\README
```

`-n` prints matching line numbers. `-y` makes the lowercase pattern match the
uppercase `FAST` in the original sample README. The guest returned to the
command prompt after printing the match.

## Source requirements for the RTL path

The SDK C source (`scratchpad/ms_os2_sdk_1_00/extracted/samples/APPS/CPGREP/CPGREP.C`,
SHA-256 `19C2A83716FF2076011A09D32C299AC73C9AB0CAF269C26E3631D92B9FB36477`)
shows that the normal OS/2 invocation is a multi-threaded workload. It calls
`DOSGETMACHINEMODE`; when protected-mode operation is reported, it initializes
four semaphores and creates separate read and write threads. Those threads
coordinate work with semaphores and call `DOSREAD` and `DOSWRITE`. The main
path also uses the OS/2 handle-type and exit APIs. The successful `-yn`
invocation therefore depends on the OS/2 executable loader, process arguments,
file and console handles, API entry points, and thread/semaphore behavior.

The sample's `-S` option forces its synchronous-I/O path and skips creation of
the two worker threads. That is a useful diagnostic reduction with the same
executable and input bytes, but it still requires OS/2 executable loading and
the OS/2 file/console API. It does not replace the default `-yn` acceptance
command recorded above.

The current RTL top exposes a byte-oriented transaction scheduler with an
8-bit data path; it does not yet expose the 80286's native 16-bit data bus,
BHE/status, ALE, and T-state interface. This boundary is tracked in Gate 5 of
the [revised plan](../../../plans/286/2026-10-26-audit-and-revised-plan.md).
An RTL CPGREP run therefore needs both a platform plan for the loader and OS/2
services and a decision about the board/native-bus interface. A smaller
authentic protected-mode executable may provide an earlier core milestone,
while remaining distinct from CPGREP acceptance.

| Input | SHA-256 |
| --- | --- |
| Original SDK Samples image `samples.img` | `AA05AD7BD80FD3F34391959482C7FE826424B46A08B09FA8675DDDB2F70A7FDD` |
| Unchanged `CPGREP.EXE` | `AB6E7C1A9DFA5A917C1321BEF7FCBE5CCF1C7BDB326F842C40A5ABB9D1700C5E` |
| Extracted `APPS\README` fixture | `2D8D91AE00D0639035B032E742AFDAD3EBFF462762F44869C92385054BBFB89C` |

The SDK image provenance and all nine original disk hashes are recorded in
[`2026-10-25-task5-media.md`](2026-10-25-task5-media.md). A clean screenshot
of the guest commands and output is
[`images/pcjs-msos2-cpgrep-20261027.png`](images/pcjs-msos2-cpgrep-20261027.png)
(SHA-256 `59C3BDFFF8DD21DBAA01447DAB3FDFB1813D62E2BFA4D832380BEF65E0A80203`).
The 2026-10-28 Playwright CLI rerun is also captured in
[`images/pcjs-msos2-cpgrep-20261028.png`](images/pcjs-msos2-cpgrep-20261028.png)
(SHA-256 `AEF1D3602E32C3968E585D82D34BAD9CC94A6EEC990990D90DC9F841F79976E3`);
it shows the repeated command, matching line and returned shell prompt.

## Limits and next work

This used the retail Microsoft OS/2 1.0 installer/command environment, not the
pre-release OS/2 kernel distributed with SDK 1.00. The SDK sample is a family
API executable; its run here is useful independent software evidence, but no
architectural behavior is inferred from PCjs as a specification. A Playwright
CLI debugger experiment on a temporary local PCjs configuration captured this
11-instruction OS/2 wait loop after leaving the installer screen:
`STI; CALL 7412; PUSH DS; PUSH 0988; POP DS; TEST [0482],0009; JZ 743C; POP
DS; RET; TEST [0D0E],FF; JZ 7900`. This validates the emulator's instruction
history capture path. That first debugger attempt stayed at a blank display and
did not reach the command prompt. A later Playwright CLI run did reach the
prompt and reran `CPGREP -yn fast ..\README`; it returned the expected line 11
containing `FAST`, as shown in the existing screenshot above. A follow-up
history capture stopped after the utility returned and contained only the OS/2
shell wait loop, so no CPGREP instruction or exception trace has been
captured. The same executable has not run on the 80286 RTL. The previous local
hard-disk configuration's BIOS 1782 failure remains a valid historical
failure; this floppy-only route avoids that controller path.

Next, obtain an independent instruction/exception trace for a scoped
protected-mode behavior, define an RTL platform path for this workload, then
run the same executable and input bytes on the RTL. Full software acceptance
and issue #80 remain open until RTL execution and the other completion gates
are satisfied.
