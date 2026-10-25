# Tool documentation

The tool folders contain maintained project guides, including Docker commands,
integration notes and known limitations. Refresh official reference copies
alongside those guides with:

```sh
./scripts/update_tool_docs.sh --list
./scripts/update_tool_docs.sh --tool verilator --page overview --dry-run
./scripts/update_tool_docs.sh --tool verilator
./scripts/update_tool_docs.sh
```

The updater requires Python 3.11+, Git and the Firecrawl CLI (`npm install -g
firecrawl-cli`). Authenticate with `firecrawl login` or set `FIRECRAWL_API_KEY`
in the same environment where the script runs. Firecrawl calls may consume
account credits. `--list` needs no CLI or network; `--dry-run` fetches fresh
pages and prints diffs without writing. Repeat `--tool` or `--page` to narrow
the selection. Use `--firecrawl-bin` to select an executable or wrapper.

Sources and upstream licensing links are maintained in
[`scripts/tool_doc_sources.json`](../scripts/tool_doc_sources.json). Generated
Markdown goes under `docs/<tool>/upstream/`; the updater also generates
`docs/upstream-index.md` with links to available copies. Each reference records
its source URL, licensing link, retrieval time and content hash. Unchanged
content retains its timestamp. The updater fetches and validates the entire
selection before writing; a failed request leaves existing copies untouched.
It does not delete old copies when source mappings change.

These are copies of live upstream pages, not claims about the versions pinned
in Docker. Review relevant changes and update project guides when adopting
new behavior. Preserve upstream attribution and review the linked license
terms before committing refreshed third-party documentation.

If Node reports a certificate-chain error on a system with an installed local
CA, run with `NODE_OPTIONS=--use-system-ca` on a Node version that supports it.
Keep TLS certificate verification enabled.

Offline checks:

```sh
python3 -m unittest discover -s scripts -p test_update_tool_docs.py -v
```

The [2026-10-25 EDA qualification](eda-tool-qualification.md) records positive/negative native-tool probes, the Icarus C/C++ helper fix, and the built-in browser Surfer waveform proof. Reproduce the CLI matrix with `python3 scripts/check_eda_tools.py` in the selected image.
