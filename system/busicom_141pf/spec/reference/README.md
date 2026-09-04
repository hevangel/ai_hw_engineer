# Reference material

Downloaded third-party sources used as *facts-only* references for the
141-PF reconstruction. The upstream checkouts are intentionally **not
stored in this repository** (unlicensed third-party code, and the security
scanner correctly refuses third-party minified JS in the tree); they are
kept in a sibling scratch folder (`B:/ai_hw_engineer_ref/`) and can be
re-fetched with:

```
git clone --depth 1 https://github.com/veniamin-ilmer/busicom.git
git clone --depth 1 https://github.com/veniamin-ilmer/boards.git
git clone --depth 1 https://github.com/veniamin-ilmer/chips.git
```

* `rom_141pf_combined.bin` — the authentic 1280-byte Busicom 141-PF
  firmware (5 × 256-byte 4001 masks), extracted from the emulator's
  published ROM array. Split per chip into `../../src/rom/` by
  `../../scripts/extract_rom.py`.

## Sources

* V. Ilmer, *Busicom 141-PF emulator* (board wiring, keyboard matrix,
  printer protocol) — <https://veniamin-ilmer.github.io/emu/busicom/>,
  repos above. No code reused; behaviour tables only.
* Busicom 141-PF Replication Project (firmware reverse-engineering by
  B. & B. Silverman, E. Dvorak, L. Kintli) — <https://www.4004.com>,
  project materials CC BY-NC-SA 2.5.
* IPSJ Computer Museum, *Busicom 141-PF* — history and introduction date.
