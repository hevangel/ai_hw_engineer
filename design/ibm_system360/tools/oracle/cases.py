"""Shared data for the S/360 differential runner.

Each case is a tiny program image placed at 0x100, optional extra data words at
absolute addresses, and the number of retired instructions to run before the
state is compared.
"""

CASES = [
    dict(name="la_lr", note="LA then LR",
         words=[0x41300234, 0x18230000], steps=2),
    dict(name="ar_cc", note="AR sets CC 2",
         words=[0x41100005, 0x41200003, 0x1A120000], steps=3),
    dict(name="sr_neg", note="SR sets CC 1",
         words=[0x41100003, 0x41200005, 0x1B120000], steps=3),
    dict(name="ltr_zero", note="LTR of zero sets CC 0",
         words=[0x41100000, 0x12110000], steps=2),
    dict(name="add_overflow", note="A overflows to 0x80000000, CC 3",
         words=[0x58400200, 0x5A400204], steps=2,
         data={0x200: 0x7FFFFFFF, 0x204: 0x00000001}),
    dict(name="cmp_signed", note="CR across the 32-bit boundary",
         words=[0x58100200, 0x41200001, 0x19120000], steps=3,
         data={0x200: 0x80000000}),
    dict(name="mvc_tm", note="MVI then TM with the all-ones mask",
         words=[0x92C10208, 0x91C00208], steps=2),
    dict(name="tr", note="TR through a two-byte table",
         words=[0xDC010200, 0x03000000], steps=1,
         data={0x200: 0x0001FFFF, 0x300: 0x10203040}),
    dict(name="mvn", note="MVN takes only the numerics",
         words=[0xD1000200, 0x02040000], steps=1,
         data={0x200: 0xC1000000, 0x204: 0x35000000}),
    dict(name="mr", note="MR product across a register pair",
         words=[0x41400006, 0x58300200, 0x1C240000], steps=3,
         data={0x200: 0xFFFFFFF9}),
    dict(name="divide", note="DR quotient and remainder",
         words=[0x41600000, 0x4170002A, 0x4180002A, 0x1D680000], steps=4),
    dict(name="ex", note="EX ORs the R1 mask byte into the subject MVI",
         words=[0x41200040, 0x41100220, 0x44200210], steps=3,
         data={0x210: 0x92001000}),
    dict(name="shift", note="SLA by one",
         words=[0x41200005, 0x8B200001], steps=2),
    dict(name="pack", note="PACK zoned 1234 to packed",
         words=[0xF2330210, 0x02000000], steps=1,
         data={0x200: 0xF1F2F3F4, 0x210: 0}),
    dict(name="unpk", note="UNPK packed 12345 to zoned",
         words=[0xF3420210, 0x02000000], steps=1,
         data={0x200: 0x12345C00, 0x210: 0}),
    dict(name="mvo_shift", note="MVO shifts left one nibble in place",
         words=[0xF1220200, 0x02000000], steps=1,
         data={0x200: 0x12345C00}),
    dict(name="zap_cp", note="ZAP then CP across different signs",
         words=[0xF8210210, 0x0200F921, 0x02100202], steps=2,
         data={0x200: 0x123C456D, 0x210: 0}),
    dict(name="ap_sp", note="AP then SP with different signs",
         words=[0xFA210210, 0x0200FB21, 0x02100200], steps=2,
         data={0x200: 0x456C123D, 0x210: 0x00123C00}),
    dict(name="ap_overflow", note="AP overflow completes with CC 3 when masked",
         words=[0xFA100215, 0x02000000], steps=1,
         data={0x200: 0x1C000000, 0x214: 0x00999C00}),
    dict(name="mp_dp", note="MP then DP quotient and remainder",
         words=[0xFC200210, 0x0200FD20, 0x02100200], steps=2,
         data={0x200: 0x2C2C0000, 0x210: 0x00123C00}),
    dict(name="cvb_cvd", note="CVB then CVD round trip",
         words=[0x41D00210, 0x4F70D000, 0x4E70D000], steps=3,
         data={0x210: 0x00000000, 0x214: 0x0025594C}),
    dict(name="ed_basic", note="EDIT 1,23.456 with leading-zero suppression",
         words=[0xDE090200, 0x021041F0, 0x010A07FF], steps=2,
         data={0x200: 0x4020206B, 0x204: 0x20204B20, 0x208: 0x20000000,
               0x210: 0x0123456C}),
    dict(name="ed_negative", note="EDIT keeps the indicator on for a D sign",
         words=[0xDE050200, 0x021041F0, 0x010A07FF], steps=2,
         data={0x200: 0x40202020, 0x204: 0x21000000, 0x210: 0x01234D00}),
    dict(name="ed_zero", note="EDIT of all-zero digits fills and gives CC 0",
         words=[0xDE050200, 0x021041F0, 0x010A07FF], steps=2,
         data={0x200: 0x40202020, 0x204: 0x21000000, 0x210: 0x00000C00}),
    dict(name="edmk_fields", note="EDMK marks each field's first significant digit",
         words=[0xDF060200, 0x021041F0, 0x010A07FF], steps=2,
         data={0x200: 0x20202022, 0x204: 0x20202100, 0x210: 0x012C045D}),
    dict(name="edmk_starter", note="significance starter forces the indicator without a mark",
         words=[0xDE020200, 0x021041F0, 0x010A07FF], steps=2,
         data={0x200: 0x40202100, 0x210: 0x0C000000}),
]

# Note: interruption-entry cases are not in this set. The emulator performs the
# interruption inside step(), which makes 'N retired instructions' a different
# stopping point than on the RTL; comparing interruption entry needs an
# event-aligned driver and is tracked as follow-up work.


def build_image(case):
    """Return the word list for the case.

    The image starts at address 0x000 and the program words are placed at
    0x100, so cases can also load the PSW areas at 0x28/0x68 and handler code.
    """
    data = {0x100 + 4 * i: w for i, w in enumerate(case["words"])}
    data.update(case.get("data", {}))
    count = max(data) // 4 + 1
    words = [0] * count
    for addr, value in data.items():
        words[addr // 4] = value
    return words


def parse_dump(path):
    state = {"psw": 0, "gpr": {}, "mem": {}}
    for line in open(path, encoding="utf-8").read().splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "psw":
            state["psw"] = int(parts[1], 16)
        elif parts[0] == "gpr":
            state["gpr"][int(parts[1])] = int(parts[2], 16)
        elif parts[0] == "mem":
            state["mem"][int(parts[1], 16)] = int(parts[2], 16)
    return state


def psw_fields(value):
    word0 = (value >> 32) & 0xFFFFFFFF
    word1 = value & 0xFFFFFFFF
    return {
        "sysMask": (word0 >> 24) & 0xFF, "key": (word0 >> 20) & 0xF,
        "P": (word0 >> 16) & 1, "W": (word0 >> 17) & 1,
        "intCode": word0 & 0xFFFF,
        "ilc": (word1 >> 30) & 3, "cc": (word1 >> 28) & 3,
        "progMask": (word1 >> 24) & 0xF, "ia": word1 & 0xFFFFFF,
    }


def compare(rtl, ref, ignore_cc=False):
    problems = []
    a, b = psw_fields(rtl["psw"]), psw_fields(ref["psw"])
    for field in ("ia", "cc", "ilc", "progMask", "sysMask", "P", "W"):
        if field == "cc" and ignore_cc:
            continue
        if a[field] != b[field]:
            problems.append(f"psw.{field}: rtl={a[field]:#x} ref={b[field]:#x}")
    for i in range(16):
        ra, rb = rtl["gpr"].get(i, 0), ref["gpr"].get(i, 0)
        if ra != rb:
            problems.append(f"gpr{i}: rtl={ra:#010x} ref={rb:#010x}")
    for addr in sorted(set(rtl["mem"]) | set(ref["mem"])):
        ra, rb = rtl["mem"].get(addr), ref["mem"].get(addr)
        if ra != rb:
            problems.append(f"mem[{addr:#05x}]: rtl={ra:#010x} ref={rb:#010x}")
    return problems
