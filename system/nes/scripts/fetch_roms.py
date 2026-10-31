#!/usr/bin/env python3
"""Fetch the freely distributed NES test ROMs (blargg, kevtris nestest and
others, as collected in christopherpow/nes-test-roms) at a pinned git
revision and verify every file against its git blob hash. Files land in
work/roms/ only; they never enter Git.

Download targets are compile-time constants validated against an explicit
scheme/host allowlist before any request is made.
"""
import hashlib
import json
import urllib.parse
import urllib.request
from pathlib import Path

REPO = "christopherpow/nes-test-roms"
REVISION = "95d8f621ae55cee0d09b91519a8989ae0e64753b"
ALLOWED_SCHEMES = {"https"}
ALLOWED_HOSTS = {"raw.githubusercontent.com"}

# (path in the archive, git blob sha1)
FILES = [
    ("apu_reset/4015_cleared.nes",
     "5874a6d6707e11e5444dee88a5d13333c14b2595"),
    ("apu_reset/4017_timing.nes",
     "6e09d03a161dfdaede36831fe638b16ea5888e48"),
    ("apu_reset/4017_written.nes",
     "816a821836096ef6109460ab79fbdc0c3c95638d"),
    ("apu_reset/irq_flag_cleared.nes",
     "e624a259dc262c7e280b112a9a6ed6b38cb5e019"),
    ("apu_reset/len_ctrs_enabled.nes",
     "df7a005661baacb6cb16ea70971a5108118ce06a"),
    ("apu_reset/works_immediately.nes",
     "2fd3f39a9545189e50ef44e595d36f76ec2537ff"),
    ("apu_test/apu_test.nes",
     "257f2278fb359409b8c47cb3767d55930f8d3c12"),
    ("blargg_apu_2005.07.30/01.len_ctr.nes",
     "60de6d946f26aead6574d49d29aed9a90eea9f70"),
    ("blargg_apu_2005.07.30/02.len_table.nes",
     "a084a14ffdb2ebc1b5a3cd5fce286a830c0e891f"),
    ("blargg_apu_2005.07.30/03.irq_flag.nes",
     "3d5cb4ed9c90dd8ecabd9861acead11c5ed138c5"),
    ("blargg_apu_2005.07.30/04.clock_jitter.nes",
     "8c45d02389136cc1adbc5f7a8cd4566b4f9589bf"),
    ("blargg_apu_2005.07.30/05.len_timing_mode0.nes",
     "1b878e672d1e4332f2525ad6f2cce9c229677789"),
    ("blargg_apu_2005.07.30/06.len_timing_mode1.nes",
     "5aea9d237eeb538eaeed38f483b1fc0a169dd13d"),
    ("blargg_apu_2005.07.30/07.irq_flag_timing.nes",
     "1ec9b88196d6a1f0b4720b7fa799dd83bb024dbf"),
    ("blargg_apu_2005.07.30/08.irq_timing.nes",
     "56f18877e6b44debe3dcfd892b0a7d9cdcc59dd8"),
    ("blargg_apu_2005.07.30/09.reset_timing.nes",
     "0ea3fc6170513b9adc78637b737dff0bc8b50c61"),
    ("blargg_apu_2005.07.30/10.len_halt_timing.nes",
     "d64a74b2dca74f657235a7276911d6f9c468c363"),
    ("blargg_apu_2005.07.30/11.len_reload_timing.nes",
     "8030fc915aa830599ee30c4a949109d742e40db3"),
    ("blargg_ppu_tests_2005.09.15b/palette_ram.nes",
     "878b32175a9f243ea84416e215132bc67f750f4e"),
    ("blargg_ppu_tests_2005.09.15b/power_up_palette.nes",
     "8964506243984a50501b4a6a11228c6abbddb80a"),
    ("blargg_ppu_tests_2005.09.15b/sprite_ram.nes",
     "dfbb613d77ee30d94234abef197caf7bce3d11e6"),
    ("blargg_ppu_tests_2005.09.15b/vbl_clear_time.nes",
     "41c2450a73ef66302e58f62b8b41cf77b95ea758"),
    ("blargg_ppu_tests_2005.09.15b/vram_access.nes",
     "301518b6c17029c32da30a480a57a26197d71fbc"),
    ("branch_timing_tests/1.Branch_Basics.nes",
     "e7f81f01d609cd3dc24ac180cf934badf1ba6952"),
    ("branch_timing_tests/2.Backward_Branch.nes",
     "6e02064a513ed50ec841815c692ae6014110e760"),
    ("branch_timing_tests/3.Forward_Branch.nes",
     "4e701b29082b0b6f61a9ecabf0f68c631fd09e15"),
    ("cpu_dummy_reads/cpu_dummy_reads.nes",
     "2682568dbdb66f1a1240b634dd6b91e601178377"),
    ("cpu_dummy_writes/cpu_dummy_writes_oam.nes",
     "3fc882ee1ea2a1326387e13f5434089a55398937"),
    ("cpu_dummy_writes/cpu_dummy_writes_ppumem.nes",
     "061f0c865df96276bff3786f1600321444f9f780"),
    ("cpu_exec_space/test_cpu_exec_space_apu.nes",
     "206be550bf2646278fa73d85c4c0afe797706071"),
    ("cpu_exec_space/test_cpu_exec_space_ppuio.nes",
     "6786dbd678b5674219928669f59b0f72e290eb77"),
    ("cpu_interrupts_v2/cpu_interrupts.nes",
     "c157e563a6a72e3ac2689362bf4e4263389e0ef7"),
    ("cpu_reset/ram_after_reset.nes",
     "cb223a0db5134a35af830f814fd60e77ebba3af8"),
    ("cpu_reset/registers.nes",
     "5408f76ec9d3e9b674ead0848aad99a78a920e6e"),
    ("cpu_timing_test6/cpu_timing_test.nes",
     "e20bca49fe76263569ec2bfde14be5d4c681b25a"),
    ("dmc_dma_during_read4/dma_2007_read.nes",
     "845d36e2b6a0ab6755eab47cec1af5cb7691a5e4"),
    ("dmc_dma_during_read4/dma_2007_write.nes",
     "68215a6a7b5e42793ce65911859a76f0f6364ffc"),
    ("dmc_dma_during_read4/dma_4016_read.nes",
     "e9cc2573afbe406ffe9f4e2c3745e2ed75712f21"),
    ("dmc_dma_during_read4/double_2007_read.nes",
     "818019438a48c625fedaa06a968c97bb38f341bd"),
    ("dmc_dma_during_read4/read_write_2007.nes",
     "4b49fd3a541f1d327ce1ec4ed0c8d948d776c1ff"),
    ("instr_misc/instr_misc.nes",
     "5db3286ae3ae9fa9d65873735bba205bb1e8f449"),
    ("instr_test-v5/all_instrs.nes",
     "d5a1b83c9fdd4bf34418ce20aee5bc36f8767fc0"),
    ("instr_test-v5/official_only.nes",
     "c92240a116f4f29f258a0f917c704ceb6cbe5ed5"),
    ("instr_timing/instr_timing.nes",
     "48e9227a1e114a12109366ff060f093a814facf3"),
    ("oam_read/oam_read.nes",
     "31d8f7571aa6271c3a145b0e040854c71456e70e"),
    ("oam_stress/oam_stress.nes",
     "a6168a8de61e535f108d9a81875a8ee9d40cc163"),
    ("other/nestest.log",
     "702610d65a6fbcf6e492435e56f4fa6cf59879e9"),
    ("other/nestest.nes",
     "fc2a88c36db9c5c2de9cca33be0e446e12007f17"),
    ("pal_apu_tests/01.len_ctr.nes",
     "b0619ce3c1208fc5ee21a07fc464a2b84c08bc49"),
    ("pal_apu_tests/02.len_table.nes",
     "60d37ce35c7c0b690e7b49c1efe41a903a18462f"),
    ("pal_apu_tests/03.irq_flag.nes",
     "81a29da57621a723abc921b42c868a11249bc39a"),
    ("pal_apu_tests/04.clock_jitter.nes",
     "b8f03398d51c71c0c28869377d1b0909dfda2f38"),
    ("pal_apu_tests/05.len_timing_mode0.nes",
     "f43e8f58c268ae9669421c3b318d4a9aab5b3ff1"),
    ("pal_apu_tests/06.len_timing_mode1.nes",
     "4c4401705436510847efca6b5e5d9082fcdeeaa9"),
    ("pal_apu_tests/07.irq_flag_timing.nes",
     "bec3b338cd0df1036cbee3b346922ff855e3f0c2"),
    ("pal_apu_tests/08.irq_timing.nes",
     "ae4b035598ee6ffa2dd7feeda4177150a487a34f"),
    ("pal_apu_tests/10.len_halt_timing.nes",
     "ae566a4742021537ace57a57ba08a5a3cbe7aa2a"),
    ("pal_apu_tests/11.len_reload_timing.nes",
     "fbb0531be83bc31603cd1179a3c1e52b2a6e0efe"),
    ("ppu_open_bus/ppu_open_bus.nes",
     "a02a15d5fef3df5c7ba593e7478cc6fcd44e7085"),
    ("ppu_read_buffer/test_ppu_read_buffer.nes",
     "980a48160c6d5006a0503375f9ff1b051cb51f05"),
    ("ppu_vbl_nmi/ppu_vbl_nmi.nes",
     "bb3743cba6209bd5c74d8d927b847b7a1b199b59"),
    ("sprdma_and_dmc_dma/sprdma_and_dmc_dma.nes",
     "8c013e38b2d1f5db422118a53205769382ba8213"),
    ("sprdma_and_dmc_dma/sprdma_and_dmc_dma_512.nes",
     "66680489744530d021859d83b7a6869b15e4bb28"),
    ("sprite_hit_tests_2005.10.05/01.basics.nes",
     "c51b7a4fcece025a37178f84035413c140cf64e5"),
    ("sprite_hit_tests_2005.10.05/02.alignment.nes",
     "6039e19e95f9e3a1cf78f14b78ac37d4979b856e"),
    ("sprite_hit_tests_2005.10.05/03.corners.nes",
     "9be851612ec437c1d13ba9ce4a6b3e3c189a6ab9"),
    ("sprite_hit_tests_2005.10.05/04.flip.nes",
     "d584ce42ff1b743ce7d0bbb1d515197917c97fb5"),
    ("sprite_hit_tests_2005.10.05/05.left_clip.nes",
     "67dd7e7218a72cacc48b934991e29f7f3eeb6461"),
    ("sprite_hit_tests_2005.10.05/06.right_edge.nes",
     "c6f5bfebda2e5256c47e79e3c70266d18e30cd60"),
    ("sprite_hit_tests_2005.10.05/07.screen_bottom.nes",
     "49d28e1a836d45134d0e8850d8dea111b2566bf8"),
    ("sprite_hit_tests_2005.10.05/08.double_height.nes",
     "cdb3e1b9c2a79f239ea7e33b9816826c140414e1"),
    ("sprite_hit_tests_2005.10.05/09.timing_basics.nes",
     "578f72064aca3a6d0ad90dcc22c3bc607f910c15"),
    ("sprite_hit_tests_2005.10.05/10.timing_order.nes",
     "cf166b7598c6bc474a1b8f7816de3579d3224546"),
    ("sprite_hit_tests_2005.10.05/11.edge_timing.nes",
     "1ace1ede81683ebf742e84d93fac3296d9e01e8d"),
    ("sprite_overflow_tests/1.Basics.nes",
     "58bd462c4232707923b5220a8f544a3e9a8a6bd1"),
    ("sprite_overflow_tests/2.Details.nes",
     "aab2afe908460ce75349c81f637e8b62a41171ea"),
    ("sprite_overflow_tests/3.Timing.nes",
     "832a7ec87b6b6b8d4a5f8152957f40466fb6f229"),
    ("sprite_overflow_tests/4.Obscure.nes",
     "0a7db6dc209ec375cf0d3f700da024999eeef4e3"),
    ("sprite_overflow_tests/5.Emulator.nes",
     "bdd961f8523f22a1fc7e87e5f1cf68a41dcb2d1c"),
    ("vbl_nmi_timing/1.frame_basics.nes",
     "8eece879f0e91ab86cb75cc543b2b10e05425c6c"),
    ("vbl_nmi_timing/2.vbl_timing.nes",
     "3a45ec89c13c370980a61f51e5dc80d6bd1977a5"),
    ("vbl_nmi_timing/3.even_odd_frames.nes",
     "535cb4473b1b7fda6f3078cd03cdc6836699b3ad"),
    ("vbl_nmi_timing/4.vbl_clear_timing.nes",
     "939f452b5b9bd2cb890f8ef22e154e51cd0ef086"),
    ("vbl_nmi_timing/5.nmi_suppression.nes",
     "5677690411baa08841fa053f42fd775683ef528e"),
    ("vbl_nmi_timing/6.nmi_disable.nes",
     "75a3a2cbb81eed5768ca9c14b07838c3c434b7d8"),
    ("vbl_nmi_timing/7.nmi_timing.nes",
     "f777a9c74b901489afdddd1ccc24d0a0cd494089"),
]


def fetch(url):
    parts = urllib.parse.urlsplit(url)
    if parts.scheme not in ALLOWED_SCHEMES or parts.hostname not in ALLOWED_HOSTS:
        raise SystemExit(f"download target rejected by allowlist: {url}")
    request = urllib.request.Request(url, headers={"User-Agent": "ai-hw-engineer"})
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def blob_sha1(content):
    # SHA-1 here is the git blob-object identity format (not a security
    # primitive): it pins the exact archived file. SHA-256 goes in the
    # manifest.
    return hashlib.sha1(f"blob {len(content)}\0".encode() + content).hexdigest()


def main():
    work = Path(__file__).resolve().parents[1] / "work" / "roms"
    work.mkdir(parents=True, exist_ok=True)
    manifest = []
    for path, blob in FILES:
        target = work / path
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or blob_sha1(target.read_bytes()) != blob:
            quoted = urllib.parse.quote(path)
            target.write_bytes(fetch(f"https://raw.githubusercontent.com/{REPO}/{REVISION}/{quoted}"))
        content = target.read_bytes()
        if blob_sha1(content) != blob:
            raise SystemExit(f"pinned archive blob mismatch: {path}")
        manifest.append({"file": path, "bytes": len(content),
                         "sha256": hashlib.sha256(content).hexdigest()})
    (work / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"NES test ROMs verified: {len(FILES)} files at {REPO}@{REVISION[:12]}")


if __name__ == "__main__":
    main()
