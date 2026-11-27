// 80387 architectural regression for intel_8087 built with VARIANT=2.
//
// Independent oracle: the build host's x87 FPU. Every differential case runs
// the *same instruction bytes* on the host (through a small generated code
// stub) and on the RTL, from the same control word and register stack, and
// compares registers, tags, status flags (IE..PE, SF, C0..C3, TOP) and any
// stored memory. The 80387 defined the IEEE 754 x87 behaviour that later
// IA-32 FPUs kept; classes where the 387 manual leaves the result
// implementation-specific (transcendental values, partial FPREM/FPREM1
// reductions) are excluded from bit comparison, as the spec's ledger (A1)
// requires.
#include "Vintel_8087.h"
#include "verilated.h"
#include <algorithm>
#include <array>
#include <cfloat>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <map>
#include <random>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/mman.h>
#include <vector>

static_assert(LDBL_MANT_DIG == 64, "needs a real x87 extended-precision host");
using Ext = std::array<uint8_t, 10>;
static uint64_t checks = 0;
static void require(bool ok, const std::string &s) {
    ++checks;
    if (!ok) throw std::runtime_error(s);
}
static std::string hex(const uint8_t *p, size_t n) {
    std::ostringstream s;
    for (size_t i = n; i-- > 0;) s << std::hex << std::setw(2) << std::setfill('0') << unsigned(p[i]);
    return s.str();
}
static std::string hex(const Ext &v) { return hex(v.data(), 10); }
static Ext encoded(uint16_t se, uint64_t mant) {
    Ext v{};
    std::memcpy(v.data(), &mant, 8);
    std::memcpy(v.data() + 8, &se, 2);
    return v;
}
static Ext bits(long double x) { Ext v{}; std::memcpy(v.data(), &x, 10); return v; }

// ---------------------------------------------------------------- host side
// Generated stub: fninit; fldcw [rdi]; fld tbyte [rsi] (ST1); fld tbyte [rdx]
// (ST0); mov rax, r8; <instruction>; fnsave [rcx]; ret.
struct Host {
    uint8_t *code;
    Host() {
        code = static_cast<uint8_t *>(mmap(nullptr, 4096, PROT_READ | PROT_WRITE | PROT_EXEC,
                                           MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
        if (code == MAP_FAILED) throw std::runtime_error("cannot map host code stub");
    }
    void run(const std::vector<uint8_t> &insn, uint16_t cw, const Ext &st1, const Ext &st0,
             uint8_t *mem, uint8_t save[108], bool one_operand) {
        std::vector<uint8_t> c = {0xdb, 0xe3, 0xd9, 0x2f};
        if (!one_operand) c.insert(c.end(), {0xdb, 0x2e});
        c.insert(c.end(), {0xdb, 0x2a, 0x4c, 0x89, 0xc0});
        c.insert(c.end(), insn.begin(), insn.end());
        c.insert(c.end(), {0xdd, 0x31, 0xc3});
        std::memcpy(code, c.data(), c.size());
        __builtin___clear_cache(reinterpret_cast<char *>(code), reinterpret_cast<char *>(code + c.size()));
        uint16_t cwv = cw;
        auto fn = reinterpret_cast<void (*)(const void *, const void *, const void *, void *, void *)>(code);
        fn(&cwv, st1.data(), st0.data(), save, mem);
    }
};

// ----------------------------------------------------------------- DUT side
class Bench {
public:
    Vintel_8087 d;
    std::vector<uint8_t> mem = std::vector<uint8_t>(1 << 20);
    uint64_t cycles = 0;
    Bench() { d.rst_n = 0; tick(); tick(); d.rst_n = 1; tick(); }
    void tick() {
        d.clk = 0; d.eval();
        d.mem_ready_i = (cycles % 5) != 3;
        d.mem_rdata_i = mem.at(d.mem_address_o & 0xfffff);
        d.eval();
        if (d.mem_valid_o && d.mem_ready_i && d.mem_write_o) mem[d.mem_address_o & 0xfffff] = d.mem_wdata_o;
        d.clk = 1; d.eval(); ++cycles;
    }
    bool cmd(uint8_t op, uint8_t md, uint32_t addr = 0, uint32_t ip = 0x12345) {
        require(d.cmd_ready_o, "command interface not ready");
        d.opcode_i = op; d.modrm_i = md; d.address_i = addr; d.instruction_i = ip; d.cmd_valid_i = 1;
        tick(); d.cmd_valid_i = 0;
        unsigned n = 0;
        while (!d.done_o && n++ < 4000) tick();
        require(d.done_o, "instruction timeout");
        return d.unsupported_o;
    }
    void init() { cmd(0xdb, 0xe3); }
    void cw(uint16_t c) { mem[0x80] = uint8_t(c); mem[0x81] = uint8_t(c >> 8); cmd(0xd9, 0x28, 0x80); }
    void load(const Ext &x) { std::memcpy(mem.data() + 0x100, x.data(), 10); cmd(0xdb, 0x28, 0x100); }
    unsigned top() const { return (d.status_o >> 11) & 7; }
    Ext st(unsigned logical) const {
        unsigned offset = ((top() + logical) & 7) * 80;
        Ext v{};
        for (unsigned i = 0; i < 80; ++i)
            if ((d.registers_o[(offset + i) / 32] >> ((offset + i) % 32)) & 1) v[i / 8] |= uint8_t(1u << (i % 8));
        return v;
    }
};

// ------------------------------------------------------------ value classes
enum Cls { C_NORMAL, C_NEAR_ONE, C_TINY, C_HUGE, C_DENORMAL, C_PSEUDO_DENORMAL, C_ZERO, C_INF, C_QNAN, C_SNAN, C_UNSUPPORTED, C_NCLASS };
static const char *cls_name[] = {"normal", "near-one", "tiny", "huge", "denormal", "pseudo-denormal",
                                 "zero", "inf", "qnan", "snan", "unsupported"};
static Ext make(std::mt19937_64 &r, Cls c) {
    uint16_t sign = (r() & 1) ? 0x8000 : 0;
    uint64_t m = r();
    switch (r() % 6) {
    case 0: m = 0xffffffffffffffffULL; break;
    case 1: m = 0x8000000000000000ULL | (r() & 0xff); break;
    default: break;
    }
    switch (c) {
    case C_NORMAL: return encoded(sign | uint16_t(1 + r() % 0x7ffe), m | (1ULL << 63));
    case C_NEAR_ONE: return encoded(sign | uint16_t(0x3fff - 70 + r() % 140), m | (1ULL << 63));
    case C_TINY: return encoded(sign | uint16_t(1 + r() % 80), m | (1ULL << 63));
    case C_HUGE: return encoded(sign | uint16_t(0x7ffe - r() % 80), m | (1ULL << 63));
    case C_DENORMAL: { uint64_t v = (m >> (r() % 63)) & ~(1ULL << 63); return encoded(sign, v ? v : 1); }
    case C_PSEUDO_DENORMAL: return encoded(sign, m | (1ULL << 63));
    case C_ZERO: return encoded(sign, 0);
    case C_INF: return encoded(sign | 0x7fff, 1ULL << 63);
    case C_QNAN: return encoded(sign | 0x7fff, 0xc000000000000000ULL | (m & 0x3fffffffffffffffULL));
    case C_SNAN: { uint64_t v = m & 0x3fffffffffffffffULL; return encoded(sign | 0x7fff, 0x8000000000000000ULL | (v ? v : 1)); }
    default:
        switch (r() % 4) {
        case 0: return encoded(sign | uint16_t(1 + r() % 0x7ffe), m & ~(1ULL << 63)); // unnormal
        case 1: return encoded(sign | uint16_t(1 + r() % 0x7ffe), 0);                  // pseudo-zero
        case 2: return encoded(sign | 0x7fff, 0);                                       // pseudo-infinity
        default: { uint64_t v = m & 0x7fffffffffffffffULL; return encoded(sign | 0x7fff, v ? v : 1); } // pseudo-NaN
        }
    }
}
static Cls pick(std::mt19937_64 &r) {
    static const int w[C_NCLASS] = {30, 20, 8, 8, 8, 2, 6, 5, 4, 4, 5};
    int t = int(r() % 100);
    for (int c = 0; c < C_NCLASS; ++c) { if (t < w[c]) return Cls(c); t -= w[c]; }
    return C_NORMAL;
}

struct Op {
    const char *name;
    std::vector<uint8_t> bytes; // host bytes; [0..1] are the DUT opcode/ModR/M
    int mem_size;               // 0 = register form; >0 = memory operand bytes; <0 = store bytes
    bool one_operand;
    bool partial_ok;            // skip value compare when C2 reports partial reduction
};

struct Stats { uint64_t run = 0, fail = 0; std::string first; };
static std::map<std::string, Stats> stats;

static void compare(Bench &b, Host &h, const Op &op, uint16_t cw, const Ext &x1, const Ext &x0,
                    const uint8_t *operand, const std::string &label) {
    uint8_t hmem[16] = {0}, save[108];
    if (op.mem_size > 0) std::memcpy(hmem, operand, size_t(op.mem_size));
    h.run(op.bytes, cw, x1, x0, hmem, save, op.one_operand);
    b.init(); b.cw(cw);
    if (!op.one_operand) b.load(x1);
    b.load(x0);
    std::memset(b.mem.data() + 0x400, 0, 16);
    if (op.mem_size > 0) std::memcpy(b.mem.data() + 0x400, operand, size_t(op.mem_size));
    bool unsupported = b.cmd(op.bytes[0], op.bytes[1], 0x400);
    auto &s = stats[op.name];
    ++s.run;
    std::ostringstream why;
    uint16_t hsw, htw; std::memcpy(&hsw, save + 4, 2); std::memcpy(&htw, save + 8, 2);
    uint16_t dsw = b.d.status_o, dtw = b.d.tags_o;
    const uint16_t swmask = 0x7f7f; // flags, SF, C0-C3, TOP; ES and B excluded
    bool partial = op.partial_ok && (hsw & 0x0400);
    // A partial reduction leaves C0, C1 and C3 undefined (387PRM table 4-4).
    uint16_t m = partial ? uint16_t(swmask & ~0x4300) : swmask;
    // ...and the partial remainder in ST0 (and so its tag) is excluded (A1).
    uint16_t tag_skip = partial ? uint16_t(3u << (2 * ((hsw >> 11) & 7))) : 0;
    if (unsupported) why << "rejected as unsupported";
    else if ((hsw & m) != (dsw & m)) why << "sw host=" << std::hex << hsw << " dut=" << dsw;
    else if ((htw & ~tag_skip) != (dtw & ~tag_skip)) why << "tags host=" << std::hex << htw << " dut=" << dtw;
    else {
        for (unsigned i = 0; i < 8 && why.str().empty(); ++i) {
            if (((htw >> (2 * ((((hsw >> 11) & 7) + i) & 7))) & 3) == 3) continue;
            if (partial && i == 0) continue;
            Ext got = b.st(i);
            if (std::memcmp(got.data(), save + 28 + 10 * i, 10) != 0)
                why << "ST" << i << " host=" << hex(save + 28 + 10 * i, 10) << " dut=" << hex(got);
        }
        if (why.str().empty() && op.mem_size < 0 &&
            std::memcmp(hmem, b.mem.data() + 0x400, size_t(-op.mem_size)) != 0)
            why << "memory host=" << hex(hmem, size_t(-op.mem_size)) << " dut=" << hex(b.mem.data() + 0x400, size_t(-op.mem_size));
    }
    if (!why.str().empty()) {
        ++s.fail;
        if (s.first.empty())
            s.first = label + " cw=" + std::to_string(cw) + " st0=" + hex(x0) + " st1=" + hex(x1) +
                      (op.mem_size > 0 ? " m=" + hex(operand, size_t(op.mem_size)) : std::string()) + ": " + why.str();
    }
}

static void differential(Bench &b, Host &h, unsigned per_op, uint64_t seed) {
    const std::vector<Op> ops = {
        {"FADD", {0xd8, 0xc1}, 0, false, false}, {"FMUL", {0xd8, 0xc9}, 0, false, false},
        {"FSUB", {0xd8, 0xe1}, 0, false, false}, {"FSUBR", {0xd8, 0xe9}, 0, false, false},
        {"FDIV", {0xd8, 0xf1}, 0, false, false}, {"FDIVR", {0xd8, 0xf9}, 0, false, false},
        {"FADD ST1,ST", {0xdc, 0xc1}, 0, false, false}, {"FSUBP", {0xde, 0xe9}, 0, false, false},
        {"FDIVP", {0xde, 0xf9}, 0, false, false}, {"FMULP", {0xde, 0xc9}, 0, false, false},
        {"FCOM", {0xd8, 0xd1}, 0, false, false}, {"FCOMP", {0xd8, 0xd9}, 0, false, false},
        {"FCOMPP", {0xde, 0xd9}, 0, false, false}, {"FUCOM", {0xdd, 0xe1}, 0, false, false},
        {"FUCOMP", {0xdd, 0xe9}, 0, false, false}, {"FUCOMPP", {0xda, 0xe9}, 0, false, false},
        {"FTST", {0xd9, 0xe4}, 0, true, false}, {"FXAM", {0xd9, 0xe5}, 0, true, false},
        {"FCHS", {0xd9, 0xe0}, 0, true, false}, {"FABS", {0xd9, 0xe1}, 0, true, false},
        {"FSQRT", {0xd9, 0xfa}, 0, true, false}, {"FRNDINT", {0xd9, 0xfc}, 0, true, false},
        {"FSCALE", {0xd9, 0xfd}, 0, false, false}, {"FPREM", {0xd9, 0xf8}, 0, false, true},
        {"FPREM1", {0xd9, 0xf5}, 0, false, true}, {"FXTRACT", {0xd9, 0xf4}, 0, true, false},
        {"FXCH", {0xd9, 0xc9}, 0, false, false}, {"FLD ST1", {0xd9, 0xc1}, 0, false, false},
        {"FSTP ST1", {0xdd, 0xd9}, 0, false, false},
        {"FADD m32", {0xd8, 0x00}, 4, true, false}, {"FMUL m64", {0xdc, 0x08}, 8, true, false},
        {"FDIVR m64", {0xdc, 0x38}, 8, true, false}, {"FCOM m32", {0xd8, 0x10}, 4, true, false},
        {"FIADD m16", {0xde, 0x00}, 2, true, false}, {"FIDIV m32", {0xda, 0x30}, 4, true, false},
        {"FICOM m16", {0xde, 0x10}, 2, true, false},
        {"FLD m32", {0xd9, 0x00}, 4, true, false}, {"FLD m64", {0xdd, 0x00}, 8, true, false},
        {"FILD m64", {0xdf, 0x28}, 8, true, false},
        {"FST m32", {0xd9, 0x10}, -4, true, false}, {"FSTP m64", {0xdd, 0x18}, -8, true, false},
        {"FSTP m80", {0xdb, 0x38}, -10, true, false}, {"FIST m16", {0xdf, 0x10}, -2, true, false},
        {"FISTP m32", {0xdb, 0x18}, -4, true, false}, {"FISTP m64", {0xdf, 0x38}, -8, true, false},
        {"FBSTP", {0xdf, 0x30}, -10, true, false},
    };
    std::mt19937_64 r(seed);
    for (const Op &op : ops) {
        for (unsigned n = 0; n < per_op; ++n) {
            unsigned pc = (r() % 4 == 0) ? unsigned(r() % 2) * 2 : 3;  // 24/53 bits sometimes
            unsigned rc = unsigned(r() % 4);
            uint16_t cw = uint16_t(0x037f | (pc << 8) | (rc << 10));
            Cls c0 = pick(r), c1 = pick(r);
            Ext x0 = make(r, c0), x1 = make(r, c1);
            uint8_t operand[10];
            for (auto &v : operand) v = uint8_t(r());
            if (op.mem_size > 0 && r() % 2) {
                // Memory operands from the same classes, converted by the host.
                long double v; std::memcpy(&v, x1.data(), 10);
                if (op.mem_size == 4 && op.bytes[0] != 0xde && op.bytes[0] != 0xda) { float f = float(v); std::memcpy(operand, &f, 4); }
                if (op.mem_size == 8 && op.bytes[0] != 0xdf) { double f = double(v); std::memcpy(operand, &f, 8); }
            }
            if (op.name == std::string("FSCALE") && r() % 2) x1 = encoded(uint16_t((r() & 1) ? 0x8000 : 0) | uint16_t(0x3fff + r() % 20), r() | (1ULL << 63));
            compare(b, h, op, cw, x1, x0, operand, std::string(op.name) + " " + cls_name[c0] + "/" + cls_name[c1]);
        }
    }
}

// Constants observe the rounding control on the 80387 (App. C.4).
static void constants(Bench &b, Host &h) {
    for (uint8_t md : {0xe8, 0xe9, 0xea, 0xeb, 0xec, 0xed, 0xee})
        for (unsigned rc = 0; rc < 4; ++rc) {
            Op op{"FLD constant", {0xd9, md}, 0, true, false};
            compare(b, h, op, uint16_t(0x037f | (rc << 10)), Ext{}, encoded(0x3fff, 1ULL << 63), nullptr,
                    "constant " + std::to_string(md) + " rc=" + std::to_string(rc));
        }
}

static void directed(Bench &b) {
    // Initialization (387PRM 4.7): CW = 037Fh, tags empty.
    b.init();
    require(b.d.control_o == 0x037f && b.d.tags_o == 0xffff, "FINIT 037Fh");
    // FENI, FDISI and FSETPM are FNOPs (App. C.4, D item 2).
    for (uint8_t md : {0xe0, 0xe1, 0xe4}) {
        uint16_t cw = b.d.control_o;
        require(!b.cmd(0xdb, md) && b.d.control_o == cw, "FENI/FDISI/FSETPM no-op");
    }
    // FSTSW AX.
    b.init(); b.load(bits(1.0L)); b.load(bits(2.0L)); b.cmd(0xd8, 0xd1);
    b.d.opcode_i = 0xdf; b.d.modrm_i = 0xe0; b.d.cmd_valid_i = 1; b.tick(); b.d.cmd_valid_i = 0;
    bool seen = false; uint16_t ax = 0;
    for (unsigned n = 0; n < 100 && !b.d.done_o; ++n) b.tick();
    if (b.d.ax_write_o) { seen = true; ax = b.d.ax_o; }
    require(seen && ax == (b.d.status_o & 0x7fff), "FSTSW AX returns the status word");
    // Stack overflow and underflow set SF and C1 (App. C.3).
    b.init();
    for (int i = 0; i < 9; ++i) b.cmd(0xd9, 0xe8);
    require((b.d.status_o & 0x0241) == 0x0241, "stack overflow: IE, SF, C1=1");
    b.init(); b.cmd(0xd8, 0xc1);
    require((b.d.status_o & 0x0241) == 0x0041, "stack underflow: IE, SF, C1=0");
    b.cmd(0xdb, 0xe2);
    require((b.d.status_o & 0x00ff) == 0, "FCLEX clears SF");
    // ERROR# (int_o) ignores the interrupt-enable mask.
    b.init(); b.cw(0x037e); b.cmd(0xd8, 0xc1);
    require(b.d.int_o, "unmasked IE asserts ERROR# regardless of IEM");
    std::cout << "PASS 80387 directed control behaviour\n";
}

// Pointer and environment images (387PRM figures 2-5..2-8).
static void images(Bench &b) {
    struct Fmt { bool prot, wide; unsigned len; };
    for (Fmt f : {Fmt{false, false, 14}, Fmt{true, false, 14}, Fmt{false, true, 28}, Fmt{true, true, 28}}) {
        b.init();
        b.d.protected_i = f.prot; b.d.opsize32_i = f.wide;
        b.d.cs_sel_i = 0x1234; b.d.ds_sel_i = 0x5678;
        b.load(bits(3.0L));
        b.cmd(0xd8, 0x00, 0x2a0, 0x0abcdef1);   // FADD m32 records the pointers
        b.cmd(0xd9, 0x30, 0x600);               // FSTENV
        auto w16 = [&](unsigned o) { return uint16_t(b.mem[0x600 + o] | (b.mem[0x601 + o] << 8)); };
        auto w32 = [&](unsigned o) { return uint32_t(w16(o)) | (uint32_t(w16(o + 2)) << 16); };
        unsigned s = f.wide ? 4 : 2;
        require(w16(0) == 0x037f && (w16(s) & 0x3800) == ((b.d.status_o & 0x3800)) , "image CW/SW");
        if (!f.wide && !f.prot) {
            require(w16(6) == 0xdef1 && (w16(8) >> 12) == 0xc && (w16(8) & 0x7ff) == 0x000, "real16 IP/opcode");
            require(w16(10) == 0x02a0 && (w16(12) >> 12) == 0, "real16 operand");
        } else if (!f.wide && f.prot) {
            require(w16(6) == 0xdef1 && w16(8) == 0x1234 && w16(10) == 0x02a0 && w16(12) == 0x5678, "prot16 pointers");
        } else if (f.wide && !f.prot) {
            require(w16(12) == 0xdef1 && ((w32(16) >> 12) & 0xffff) == 0x0abc && (w32(16) & 0x7ff) == 0, "real32 IP/opcode");
            require(w16(20) == 0x02a0 && (w32(24) >> 12) == 0, "real32 operand");
        } else {
            require(w32(12) == 0x0abcdef1 && w16(16) == 0x1234 && ((w32(16) >> 16) & 0x7ff) == 0, "prot32 IP/CS/opcode");
            require(w32(20) == 0x2a0 && w16(24) == 0x5678, "prot32 operand");
        }
        require((b.d.control_o & 0x3f) == 0x3f, "FSTENV masks exceptions");
        b.cmd(0xd9, 0x20, 0x600);               // FLDENV restores
        require(b.d.control_o == 0x037f, "FLDENV control word");
        // FSAVE/FRSTOR round trip in this format.
        b.load(bits(-7.5L));
        auto regs = b.d.registers_o; auto tags = b.d.tags_o;
        b.cmd(0xdd, 0x30, 0x700);
        require(b.d.tags_o == 0xffff && b.d.control_o == 0x037f, "FSAVE initializes");
        b.cmd(0xdd, 0x20, 0x700);
        require(b.d.registers_o == regs && b.d.tags_o == tags, "FRSTOR restores registers and tags");
        (void)f.len;
    }
    b.d.protected_i = 0; b.d.opsize32_i = 0;
    // FLDENV uses only empty/non-empty: a "valid" tag on a zero register is
    // recomputed as zero (App. C.3).
    b.init(); b.load(encoded(0, 0)); b.cmd(0xd9, 0x30, 0x600);
    b.mem[0x604] = uint8_t(b.mem[0x604] & ~0xc0); b.mem[0x605] = b.mem[0x605];
    uint16_t tw = uint16_t(b.mem[0x604] | (b.mem[0x605] << 8));
    unsigned top = (uint16_t(b.mem[0x602] | (b.mem[0x603] << 8)) >> 11) & 7;
    tw = uint16_t(tw & ~(3u << (2 * top)));     // claim "valid" for the zero
    b.mem[0x604] = uint8_t(tw); b.mem[0x605] = uint8_t(tw >> 8);
    b.cmd(0xd9, 0x20, 0x600);
    require(((b.d.tags_o >> (2 * top)) & 3) == 1, "FLDENV recomputes non-empty tags");
    std::cout << "PASS 80387 pointer/environment images in all four formats\n";
}

// Original Intel software: the ARRSUM sequence of the 8087 numerics
// supplement (figure S-24), which the 80387 executes unchanged (App. D).
static void arrsum(Bench &b) {
    b.init(); b.mem[0x80] = 0x3e; b.mem[0x81] = 0x03; b.cmd(0xd9, 0x28, 0x80);
    for (int i = 0; i < 3; ++i) b.cmd(0xd9, 0xee);
    const std::array<float, 8> xs = {1, -2, 3.5f, 4, -5.25f, 6, 7.5f, 8};
    for (unsigned i = 0; i < xs.size(); ++i) std::memcpy(b.mem.data() + 0x1000 + i * 4, &xs[i], 4);
    for (unsigned n = unsigned(xs.size()); n > 0; --n) {
        uint16_t nn = uint16_t(n); std::memcpy(b.mem.data() + 0x900, &nn, 2);
        b.cmd(0xd9, 0x84, 0x1000 + (n - 1) * 4); b.cmd(0xdc, 0xc3); b.cmd(0xd9, 0xc0);
        b.cmd(0xdc, 0xc8); b.cmd(0xde, 0xc2); b.cmd(0xde, 0x08, 0x900); b.cmd(0xde, 0xc2);
    }
    b.cmd(0xd9, 0x18, 0xa00); b.cmd(0xd9, 0x18, 0xa04); b.cmd(0xd9, 0x18, 0xa08);
    float got[3]; std::memcpy(got, b.mem.data() + 0xa00, 12);
    float sq = 0, ix = 0, sum = 0;
    for (unsigned i = 0; i < xs.size(); ++i) { sum += xs[i]; sq += xs[i] * xs[i]; ix += float(i + 1) * xs[i]; }
    require(got[0] == sq && got[1] == ix && got[2] == sum && b.d.tags_o == 0xffff, "Intel ARRSUM on the 80387");
    std::cout << "PASS original Intel ARRSUM numeric software on the 80387\n";
}


// ------------------------------------------------- transcendentals (M2)
// Values are compared within a ULP bound (spec A1: results are not
// bit-specified); exceptional classes, flags IE/D/ZE/SF, C2, TOP and tags
// are compared exactly. The maximum observed error is reported per form.
struct TStats { uint64_t run = 0, fail = 0; double max_ulp = 0; std::string first; };
static std::map<std::string, TStats> tstats;
static double ulp_diff(const uint8_t *h, const Ext &d) {
    long double a, b; std::memcpy(&a, h, 10); std::memcpy(&b, d.data(), 10);
    if (a == b) return 0;
    int e; std::frexp(a, &e);
    long double ulp = std::max(std::ldexp(1.0L, e - 64), std::ldexp(1.0L, -16445));
    return double(std::fabs(a - b) / ulp);
}
static void trans_case(Bench &b, Host &h, const char *name, uint8_t md, const Ext &x1, const Ext &x0, double tol) {
    Op op{name, {0xd9, md}, 0, false, false};
    uint8_t hmem[16] = {0}, save[108];
    h.run(op.bytes, 0x037f, x1, x0, hmem, save, false);
    b.init(); b.cw(0x037f); b.load(x1); b.load(x0);
    bool unsupported = b.cmd(0xd9, md);
    auto &s = tstats[name]; ++s.run;
    uint16_t hsw, htw; std::memcpy(&hsw, save + 4, 2); std::memcpy(&htw, save + 8, 2);
    uint16_t dsw = b.d.status_o, dtw = b.d.tags_o;
    const uint16_t m = 0x3c47;   // IE, D, ZE, SF, C2, TOP
    std::ostringstream why;
    if (unsupported) why << "rejected";
    else if ((hsw & m) != (dsw & m)) why << "sw host=" << std::hex << hsw << " dut=" << dsw;
    else if (htw != dtw) why << "tags host=" << std::hex << htw << " dut=" << dtw;
    else for (unsigned i = 0; i < 8 && why.str().empty(); ++i) {
        if (((htw >> (2 * ((((hsw >> 11) & 7) + i) & 7))) & 3) == 3) continue;
        Ext got = b.st(i);
        const uint8_t *hv = save + 28 + 10 * i;
        uint16_t se; std::memcpy(&se, hv + 8, 2);
        uint64_t hm; std::memcpy(&hm, hv, 8);
        bool special = (se & 0x7fff) == 0x7fff || ((se & 0x7fff) == 0 && hm == 0);
        if (special) { if (std::memcmp(got.data(), hv, 10)) why << "ST" << i << " host=" << hex(hv, 10) << " dut=" << hex(got); }
        else {
            double u = ulp_diff(hv, got);
            if (u > s.max_ulp) s.max_ulp = u;
            if (!(u <= tol)) why << "ST" << i << " " << u << " ulp host=" << hex(hv, 10) << " dut=" << hex(got);
        }
    }
    if (!why.str().empty()) {
        ++s.fail;
        if (s.first.empty()) s.first = std::string(name) + " st0=" + hex(x0) + " st1=" + hex(x1) + ": " + why.str();
    }
}
static void transcendentals(Bench &b, Host &h, unsigned n, uint64_t seed, double tol) {
    std::mt19937_64 r(seed ^ 0x7ac);
    auto uni = [&](long double lo, long double hi) { return lo + (hi - lo) * (long double)(r() >> 11) / (long double)(1ULL << 53); };
    auto special = [&]() {
        switch (r() % 9) {
        case 0: return encoded((r() & 1) ? 0x8000 : 0, 0);
        case 1: return encoded(((r() & 1) ? 0x8000 : 0) | 0x7fff, 1ULL << 63);
        case 2: return encoded(0x7fff, 0xc000000000000000ULL | (r() >> 2));
        case 3: return encoded(0x7fff, 0x8000000000000000ULL | ((r() >> 2) | 1));
        case 4: return encoded(uint16_t(((r() & 1) ? 0x8000 : 0) | (0x403e + r() % 30)), r() | (1ULL << 63));
        case 5: return encoded((r() & 1) ? 0x8000 : 0, (r() >> 1) | 1);
        case 6: return encoded(uint16_t(1 + r() % 0x7ffe), r() & ~(1ULL << 63));
        default: return encoded(uint16_t(((r() & 1) ? 0x8000 : 0) | (0x3fff - 70 + r() % 140)), r() | (1ULL << 63));
        }
    };
    for (unsigned k = 0; k < n; ++k) {
        long double range[] = {0.78L, 10.0L, 1e6L, 1e18L};
        long double t = uni(-range[k % 4], range[k % 4]);
        Ext x = bits(t), y = bits(uni(-100, 100));
        if (k % 10 == 0) x = special();
        for (uint8_t md : {0xfe, 0xff, 0xfb, 0xf2})
            trans_case(b, h, md == 0xfe ? "FSIN" : md == 0xff ? "FCOS" : md == 0xfb ? "FSINCOS" : "FPTAN", md, y, x, tol);
        Ext ax = bits(uni(-1e3, 1e3) * std::pow(10.0L, int(r() % 7) - 3)), ay = bits(uni(-1e3, 1e3) * std::pow(10.0L, int(r() % 7) - 3));
        if (k % 8 == 0) ax = special(); else if (k % 8 == 1) ay = special();
        trans_case(b, h, "FPATAN", 0xf3, ay, ax, tol);
        trans_case(b, h, "F2XM1", 0xf0, y, bits(uni(-1, 1)), tol);
        trans_case(b, h, "FYL2X", 0xf1, y, bits(std::fabs(uni(1e-6, 1e6))), tol);
        trans_case(b, h, "FYL2XP1", 0xf9, y, bits(uni(-0.29L, 0.29L)), tol);
    }
}
int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    unsigned per_op = argc > 1 ? unsigned(std::stoul(argv[1])) : 2000;
    uint64_t seed = argc > 2 ? std::stoull(argv[2], nullptr, 0) : 0x803871987ULL;
    try {
        Bench b;
        Host h;
        directed(b);
        images(b);
        arrsum(b);
        constants(b, h);
        differential(b, h, per_op, seed);
        double tol = argc > 3 ? std::stod(argv[3]) : 8.0;   // ULP bound
        transcendentals(b, h, per_op / 4 + 1, seed, tol);
        uint64_t run = 0, fail = 0;
        for (auto &s : stats) {
            run += s.second.run; fail += s.second.fail;
            std::cout << (s.second.fail ? "MISMATCH " : "MATCH    ") << std::left << std::setw(14) << s.first
                      << " " << s.second.run - s.second.fail << "/" << s.second.run;
            if (s.second.fail) std::cout << "  first: " << s.second.first;
            std::cout << "\n";
        }
        uint64_t trun = 0, tfail = 0;
        for (auto &t : tstats) {
            trun += t.second.run; tfail += t.second.fail;
            std::cout << (t.second.fail ? "TRANS-MISMATCH " : "TRANS-MATCH    ") << std::left << std::setw(9) << t.first
                      << " " << t.second.run - t.second.fail << "/" << t.second.run << "  max " << t.second.max_ulp << " ulp";
            if (t.second.fail) std::cout << "  first: " << t.second.first;
            std::cout << "\n";
        }
        std::cout << "TOTAL transcendental " << trun - tfail << "/" << trun << " within tolerance\n";
        fail += tfail;
        std::cout << "TOTAL differential " << run - fail + tfail << "/" << run << " match; " << checks
                  << " directed checks; " << b.cycles << " cycles\n";
        return fail ? 1 : 0;
    } catch (const std::exception &e) {
        std::cerr << "FAIL: " << e.what() << "\n";
        return 2;
    }
}
