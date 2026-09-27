# Busicom 141-PF virtual calculator

The original five-ROM firmware runs on the reconstructed Intel MCS-4 chips.
The browser provides physical keys, switches, printer drum and paper tape.

## Run

From the repository root, using the rebuilt tool image:

```sh
docker run --rm -p 127.0.0.1:8081:8080 -v "$PWD:/workspace" \
  -e BUSICOM_BACKEND=verilator ai-hw-engineer:latest \
  sh /workspace/system/busicom_141pf/scripts/run_system.sh
```

Open <http://localhost:8081/>. For addition, enter `5 + 6 + =` to print `11`.
The drum shows rotating type; the answer is on the tape.

`BUSICOM_BACKEND=xezim` is the script default. Native compilation can be enabled
with `XEZIM_JIT=1 XEZIM_AOT=1`. Verilator provides a faster interactive panel.
`BUSICOM_PORT` selects the internal HTTP port; `BUSICOM_SPIN` defaults to 1481.
Build outputs are separated by backend and port. Wait for startup to finish.

## Manual and replay

- [Readable manual](spec/reference/Unicom_141P_manual.md)
- [Original OCR extraction](spec/reference/Unicom_141P_manual_ocr.md)
- [All 42 examples in JSON](spec/reference/Unicom_141P_examples.json)
- [Replay format and instructions](spec/reference/README.md)
- [Regression results and five scan/ROM differences](report/manual_regression.md)
- [Specification](spec/spec.md), [implementation plan](plans/implementation_plan.md)
- [Historical report](report/final_report.md)

In the panel, select **Load included examples**, choose an example and expected
results profile, then **Run**. You can also load an edited JSON file.

Headless replay against an already running app, from this system directory:

```sh
python3 scripts/replay_manual.py --url http://127.0.0.1:8081 \
  --profile recovered-rom --report work/manual-results.json
```

Omit `--profile` to compare literally with the scanned manual. The five known
differences remain failures in that strict mode. Both runners compare actual
ROM-driven printer output, retaining exact decimal strings and duplicate lines.
