# System README template

Use the following outline for `system/<system_name>/README.md`. Replace the
placeholders with the system's verified behavior and sourced history.

Every system README must include a **Web interface and waveform** section.
For systems with a web panel and waveform capture, commit a real browser
screenshot to `assets/web-interface-waveform.jpg` inside the system folder.
Show the front panel and a populated waveform viewer together. Capture after
a representative boot, program, or user operation; state the exact phase
(including a blank display during POST), capture length, and how to reproduce
it. Use readable signal names and exclude browser chrome and unrelated tabs.
Refresh the screenshot when the interface changes.

If a panel exists without waveform capture, save `assets/web-interface.jpg`
and explicitly state that no waveform is shown. If there is no web interface,
state why a screenshot is unavailable. Do not add a broken image link or a
mockup that implies an unimplemented feature works.

```markdown
# <System name>

<Function, important chips, and current implementation status.>

<First-introduced year, historical significance, and source links. State
uncertain historical dates explicitly.>

## Web interface and waveform

![<System name> web interface with captured <CPU/bus> signals](assets/web-interface-waveform.jpg)

<What software or operation is shown, capture length, and any visible limits.>
<Steps to reproduce the interface state and capture.>

## Run

<Launch command from the repository root, container image, port mappings,
local browser URL, required firmware, and initial user actions.>

## Verification and boundaries

<Verification command, real-software regressions, results, and known limits.>

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Verification report](report/final_report.md)
```

Include only links to documents that actually exist in the system folder.
Replace the screenshot image and caption with the explicit availability note
described above when a web panel or waveform capture is not implemented.
