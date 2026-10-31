from pathlib import Path
BASE = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\scripts')
patches = {
 'run_authored_boot.sh': ('    src/apple_ii_rev0_authored.sv tb/tb_rev0_boot.sv',
                          '    src/apple_ii_rev0_authored.sv tb/apple_ii_refresh_check.sv tb/tb_rev0_boot.sv'),
 'run_reference_boot.sh': ('    board/reference_cpu_socket.sv board/a2_mos6502_reference.sv tb/tb_rev0_boot.sv',
                           '    board/reference_cpu_socket.sv board/a2_mos6502_reference.sv \\\n    tb/apple_ii_refresh_check.sv tb/tb_rev0_boot.sv'),
 'run_timing_sim.sh': ('        src/apple_ii_rev0_authored.sv tb/tb_rev0_boot.sv',
                       '        src/apple_ii_rev0_authored.sv tb/apple_ii_refresh_check.sv tb/tb_rev0_boot.sv'),
}
for name, (old, new) in patches.items():
    p = BASE / name
    t = p.read_text()
    assert t.count(old) == 1, f'{name}: {t.count(old)}'
    p.write_text(t.replace(old, new), newline='\r\n')
    print('patched', name)
