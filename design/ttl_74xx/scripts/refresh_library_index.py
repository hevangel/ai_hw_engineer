#!/usr/bin/env python3
"""Refresh public catalog tables and the RTL file list from the manifest."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
entries=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
for chip in entries:
    chip.setdefault('specification',f"spec/chips/{chip['module']}.md")
def clean(value):
    return str(value).replace('|','/').replace('\n',' ')
readme=root/'README.md'
text=readme.read_text(encoding='utf-8').split('## Chip index')[0]
text+='## Chip index\n\n| Part | Function | First introduced | Status / specification |\n|---|---|---|---|\n'
for chip in entries:
    year=chip['introduction_year'] or 'Unknown'
    text+=f"| {chip['part_number']} | {clean(chip['description'])} | {year} | [{chip['status']}]({chip['specification']}) |\n"
readme.write_text(text,encoding='utf-8',newline='\n')
index=root.parent/'README.md'
text=index.read_text(encoding='utf-8').split('## Extended numbered 74-series catalog')[0]
text+='## Extended numbered 74-series catalog\n\nAll entries are in the shared [ttl_74xx](ttl_74xx/) folder. These additional\nentries preserve unknown first-introduced years explicitly; each specification\nlinks its manufacturer source and implementation status.\n\n| Year | Chip | Function | Design / status |\n|---|---|---|---|\n'
for chip in entries:
    if chip['number']<=299:
        continue
    year=chip['introduction_year'] or 'Unknown'
    text+=f"| {year} | {chip['part_number']} | {clean(chip['description'])} | [{chip['status']}](ttl_74xx/{chip['specification']}) |\n"
index.write_text(text,encoding='utf-8',newline='\n')
sources={'design/ttl_74xx/src/alu_74181.sv'}
sources.update('design/ttl_74xx/'+chip['rtl'] for chip in entries if chip['status']=='implemented')
(root/'files.f').write_text('\n'.join(sorted(sources))+'\n',encoding='utf-8',newline='\n')
print(f'Refreshed {len(entries)} catalog rows and {len(sources)} RTL sources')
