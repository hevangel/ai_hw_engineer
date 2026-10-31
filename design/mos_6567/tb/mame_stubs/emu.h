// Minimal MAME framework services for compiling the unchanged, pinned MAME
// mos6566.cpp/.h (BSD-3-Clause, Curt Coder) as an independent oracle.
// Authored in this project. Only behavior the oracle needs is provided:
// memory reads go to harness callbacks, the bitmap records pixel writes,
// callbacks record line levels and the scheduler/save/timer services are
// inert. No VIC-II behavior is implemented here.
#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <utility>
#include <vector>

#define ATTR_COLD
#define ATTR_FORCE_INLINE inline
#define FUNC(x) nullptr
#define NAME(x) x
#define STRUCT_MEMBER(array, member) array
#define TIMER_CALLBACK_MEMBER(name) void name(int32_t param)

typedef uint32_t offs_t;
typedef int64_t attoseconds_t;
typedef uint32_t u32;
typedef uint8_t u8;

enum endianness_t { ENDIANNESS_LITTLE, ENDIANNESS_BIG };

// Same contract as MAME's BIT(): bit n of x, in the type of x.
template <typename T, typename U> constexpr T BIT(T x, U n) { return (x >> n) & T(1); }

struct rgb_t {
    uint32_t value = 0;
    constexpr rgb_t() = default;
    constexpr rgb_t(uint8_t r, uint8_t g, uint8_t b) : value((uint32_t(r) << 16) | (uint32_t(g) << 8) | b) {}
    constexpr operator uint32_t() const { return value; }
};

struct XTAL {
    double hz;
    constexpr explicit XTAL(double v) : hz(v) {}
    constexpr XTAL operator/(int d) const { return XTAL(hz / d); }
};

struct attotime {
    attoseconds_t atto = 0;
    static const attotime zero;
    constexpr attotime() = default;
    constexpr explicit attotime(attoseconds_t a) : atto(a) {}
    constexpr attoseconds_t as_attoseconds() const { return atto; }
    bool operator>=(const attotime &o) const { return atto >= o.atto; }
    attotime operator-(const attotime &o) const { return attotime(atto - o.atto); }
};
inline const attotime attotime::zero{};

struct rectangle {};
class machine_config {};
class device_t;
typedef const void *device_type;

// Pixel writes from output_stage are forwarded to the harness.
struct bitmap_rgb32 {
    uint32_t sink = 0;
    // The harness returns storage that receives the written pixel value.
    std::function<uint32_t &(int, int)> on_write;
    uint32_t &pix(int row, int col) { return on_write ? on_write(row, col) : sink; }
};

struct screen_device {
    void register_screen_bitmap(bitmap_rgb32 &) {}
};
inline void copybitmap(bitmap_rgb32 &, const bitmap_rgb32 &, int, int, int, int, const rectangle &) {}

struct address_map_entry {
    address_map_entry &ram() { return *this; }
};
struct address_map {
    address_map_entry entry;
    address_map_entry &operator()(offs_t, offs_t) { return entry; }
};
struct address_map_constructor {
    template <typename... T> address_map_constructor(T &&...) {}
};
struct address_space_config {
    template <typename... T> address_space_config(T &&...) {}
};
typedef std::vector<std::pair<int, const address_space_config *>> space_config_vector;

// Display memory: the harness installs the read functions.
template <int Width, int A, int B, endianness_t E>
struct memory_access {
    struct specific {
        std::function<uint8_t(offs_t)> reader;
        uint8_t read_byte(offs_t address) { return reader ? reader(address) : 0xff; }
    };
};
struct address_space {
    template <typename T> void specific(T &) {}
};

// Output lines record their latest level; read callbacks query the harness.
struct devcb_write_line {
    int level = -1;
    template <typename T> explicit devcb_write_line(T &) {}
    int bind() { return 0; }
    void operator()(int state) { level = state; }
};
struct devcb_write8 {
    int value = -1;
    template <typename T> explicit devcb_write8(T &) {}
    int bind() { return 0; }
    void operator()(offs_t, uint8_t data) { value = data; }
};
struct devcb_read8 {
    std::function<uint8_t(offs_t)> reader;
    uint8_t fallback;
    template <typename T> devcb_read8(T &, uint8_t value) : fallback(value) {}
    int bind() { return 0; }
    uint8_t operator()(offs_t address) { return reader ? reader(address) : fallback; }
};

struct emu_timer {
    void adjust(const attotime &, int32_t = 0) {}
};

struct cpu_device {
    void set_unscaled_clock(uint32_t, bool = false) {}
    void adjust_icount(int) {}
    void abort_timeslice() {}
};
struct finder_base {
    static constexpr const char *DUMMY_TAG = "";
};
template <class T>
struct required_device {
    T device;
    template <typename... A> required_device(A &&...) {}
    template <typename U> void set_tag(U &&) {}
    T *operator->() { return &device; }
};

struct running_machine {
    attotime time() const { return attotime(); }
    bool side_effects_disabled() const { return false; }
};

class device_t {
public:
    device_t(const machine_config &, device_type, const char *, device_t *, uint32_t clock)
        : m_clock(clock) {}
    virtual ~device_t() = default;
    uint32_t clock() const { return m_clock; }
    running_machine &machine() { return m_machine; }
    const running_machine &machine() const { return m_machine; }
    template <typename T> void save_item(T &&) {}
    template <typename... T> emu_timer *timer_alloc(T &&...) { return &m_timer; }
    attotime cycles_to_attotime(uint64_t) const { return attotime(); }
    attotime local_time() const { return attotime(); }

protected:
    virtual void device_start() {}
    virtual void device_reset() {}

private:
    uint32_t m_clock;
    running_machine m_machine;
    emu_timer m_timer;
};

class device_memory_interface {
public:
    using space_config_vector = ::space_config_vector;
    device_memory_interface(const machine_config &, device_t &) {}
    virtual ~device_memory_interface() = default;
    virtual space_config_vector memory_space_config() const = 0;
    bool has_configured_map(int) const { return false; }
    address_space &space(int) { return m_space; }

private:
    address_space m_space;
};

class device_video_interface {
public:
    device_video_interface(const machine_config &, device_t &) {}
    virtual ~device_video_interface() = default;
    screen_device &screen() { return m_screen; }

private:
    screen_device m_screen;
};

class device_execute_interface {
public:
    device_execute_interface(const machine_config &, device_t &) {}
    virtual ~device_execute_interface() = default;
    void set_icountptr(int &) {}

protected:
    virtual void execute_run() = 0;
    virtual uint64_t execute_clocks_to_cycles(uint64_t clocks) const noexcept { return clocks; }
    virtual uint64_t execute_cycles_to_clocks(uint64_t cycles) const noexcept { return cycles; }
};

#define DECLARE_DEVICE_TYPE(Type, Class) extern const device_type Type;
#define DEFINE_DEVICE_TYPE(Type, Class, Short, Full) const device_type Type = #Short;
