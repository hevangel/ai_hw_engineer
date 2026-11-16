// IBM Personal Computer AT keyboard (84 keys) on the keyboard connector's
// open-collector clock and data lines. Header-only, so that the batch POST
// runner can use it as well as the web simulator.
//
// Sources:
//   [TR]  IBM PC AT Technical Reference, March 1984 (1502494), Section 4
//         "Keyboard", printed pages 4-3 to 4-16 (PDF pages 117-130).
//   [KBD] A. Tarpai, commented disassembly of the AT keyboard's own 8048
//         firmware 1503099 (external/halicery/8042/8048_AT_INTERN.TEXT):
//         command handling (R2 mode bits), transmit/receive line handling,
//         FIFO and typematic.
//   [KBC] The same author's disassembly of the 8042 firmware 1503033
//         (external/halicery/8042/8042_1503033.TXT): the timing the
//         keyboard controller expects on T0 (clock) and T1 (data).
//
// Line convention: tick() receives the level of each line as the keyboard
// sees it (the wired AND of the system's and the keyboard's drivers) and
// clk_out()/data_out() are the keyboard's own drivers, 1 = released.
//
// Time base: tick() is called once per processor clock; clocks_per_us
// converts the timing below into processor clocks. On this board the
// keyboard talks only to the 8042, whose machine cycle is 15 processor
// clocks (the board's real 6 MHz ratio, ASSUMPTION AT1), so the system
// passes 6 clocks per microsecond: the keyboard keeps its real ratio to the
// 8042 (ASSUMPTION AT20).
#pragma once
#include <algorithm>
#include <cstdint>
#include <deque>
#include <string>
#include <vector>

class AtKeyboard {
public:
    // ASSUMPTION AT21: [TR] gives no clock frequency. Each clock phase
    // lasts 40 us (12.5 kHz). [KBC] requires a whole byte within 1024 8042
    // cycles of its first falling edge (timer reload E0h, 32 cycles per
    // count; 2.56 ms at 6 MHz) and each bit of a host transmission within
    // 160 cycles (reload FBh), so any period below about 230 us works.
    static constexpr unsigned kHalfClockUs = 40;
    // ASSUMPTION AT21: lines continuously idle (clock and data high) for
    // 100 us before the keyboard starts a transmission, and a stable
    // request-to-send (clock high, data low) for 100 us before it starts
    // clocking a host byte in. [TR] 4-15 requires the system to hold the
    // clock low for more than 60 us before a request-to-send.
    static constexpr unsigned kIdleUs = 100;
    static constexpr unsigned kRtsUs = 100;
    // ASSUMPTION AT22: [TR] 4-4 gives the power-on reset as 300 ms to 9 s
    // and the BAT as 600 to 900 ms; the model uses the minimum of each.
    // After a Reset command only the BAT runs.
    static constexpr unsigned kPorMs = 300;
    static constexpr unsigned kBatMs = 600;
    static constexpr uint8_t kDefaultTypematic = 0x2c;   // [KBD] 0100: 500 ms, 10 per second

    explicit AtKeyboard(unsigned clocks_per_us = 6) : us_(clocks_per_us) { power_on(); }

    // Power applied: POR, then BAT, then AA (when the interface allows).
    void power_on() {
        reset_state();
        rx_log_.clear();
        tx_log_.clear();
        sent_ = received_ = aborted_ = resets_ = 0;
        last_sent_value_ = last_received_ = -1;
        std::fill(physical_.begin(), physical_.end(), false);
        state_ = State::kBat;
        wait_ = clocks_ms(kPorMs + kBatMs);
    }

    // One processor clock. clk/data: line levels as the keyboard sees them.
    void tick(bool clk, bool data) {
        if (repeat_key_ >= 0 && !(mode_ & 0x80) && --repeat_wait_ == 0) typematic();
        switch (state_) {
        case State::kBat:
            if (--wait_ == 0) {
                // [KBD] 0132-0136: defaults, FIFO cleared, scanning enabled,
                // then the completion code.
                mode_ = 0;
                typematic_ = kDefaultTypematic;
                fifo_.clear();
                sensed_.assign(128, false);
                sync_keys();
                reply(0xaa);
                state_ = State::kIdle;
                stable_ = 0;
            }
            return;
        case State::kResetWait:
            // [KBD] 00B5-00BB: after the ACK of Reset, wait for the clock
            // to be released; a request-to-send then means a new command.
            if (clk && !data) { begin_receive(); return; }
            if (clk && data) {
                reset_state();
                state_ = State::kBat;
                wait_ = clocks_ms(kBatMs);
                ++resets_;
            }
            return;
        case State::kIdle:
            idle(clk, data);
            return;
        case State::kSend:
            send(clk);
            return;
        case State::kReceive:
            receive(clk, data);
            return;
        }
    }

    // A key changed. code: the key's scan code set 2 make code ([TR] 4-12,
    // 84-key keyboard; one byte, F7 = 83h and SysRq = 84h).
    void key(uint8_t code, bool make) {
        if (code >= 0x80 && code != 0x83 && code != 0x84) return;
        if (physical_[index(code)] == make) return;
        physical_[index(code)] = make;
        if (!(mode_ & 0x80)) sense(code, make);
    }

    bool clk_out() const { return clk_out_; }
    bool data_out() const { return data_out_; }
    uint8_t leds() const { return leds_; }          // bit 0 Scroll, 1 Num, 2 Caps ([TR] 4-9)
    bool scanning() const { return !(mode_ & 0x80) && state_ != State::kBat; }
    uint8_t typematic_byte() const { return typematic_; }
    uint64_t bytes_sent() const { return sent_; }
    uint64_t bytes_received() const { return received_; }
    uint64_t aborted() const { return aborted_; }
    uint64_t resets() const { return resets_; }
    unsigned queued() const { return unsigned(fifo_.size() + replies_.size()); }
    int last_received() const { return last_received_; }
    const std::vector<uint8_t>& received_log() const { return rx_log_; }
    const std::vector<uint8_t>& sent_log() const { return tx_log_; }
    int last_sent() const { return last_sent_value_; }
    const char* state_name() const {
        switch (state_) {
        case State::kBat: return "bat";
        case State::kResetWait: return "reset-wait";
        case State::kIdle: return "idle";
        case State::kSend: return "send";
        case State::kReceive: return "receive";
        }
        return "?";
    }

private:
    enum class State { kBat, kResetWait, kIdle, kSend, kReceive };
    struct Reply { uint8_t byte; int action; };   // action: command to run once sent, or -1

    unsigned us_;
    State state_ = State::kBat;
    uint64_t wait_ = 0;
    bool clk_out_ = true, data_out_ = true;
    // [KBD] register R2 in command mode: bit 7 scanning stopped, bit 6 a
    // parameter byte is awaited, bit 2 disabled by F5, bit 1 the awaited
    // parameter is the ED option byte.
    uint8_t mode_ = 0;
    uint8_t typematic_ = kDefaultTypematic, leds_ = 0;
    uint8_t last_sent_ = 0xaa;     // [KBD] 01C9: last byte sent, for Resend
    int last_sent_value_ = -1, last_received_ = -1;
    // Scan code FIFO ([TR] 4-3): 16 entries plus the overrun position.
    // Bit 8 marks a break, sent as F0h then the code ([KBD] 007A-008A).
    std::deque<uint16_t> fifo_;
    std::deque<Reply> replies_;
    std::deque<bool> physical_ = std::deque<bool>(128, false);
    std::deque<bool> sensed_ = std::deque<bool>(128, false);
    int repeat_key_ = -1;
    uint64_t repeat_wait_ = 0;
    // Transfer state.
    uint8_t byte_ = 0;
    unsigned bit_ = 0, phase_ = 0;
    uint64_t stable_ = 0;
    bool sending_reply_ = false;
    uint64_t sent_ = 0, received_ = 0, aborted_ = 0, resets_ = 0;
    std::vector<uint8_t> rx_log_, tx_log_;   // the last 64 bytes each way since power-on
    static void log(std::vector<uint8_t>& v, uint8_t b) { if (v.size() == 64) v.erase(v.begin()); v.push_back(b); }

    uint64_t clocks_ms(unsigned ms) const { return uint64_t(ms) * 1000 * us_; }
    static unsigned index(uint8_t code) { return code == 0x83 ? 0x02 : code == 0x84 ? 0x7f : code; }
    static uint8_t code_of(unsigned i) { return i == 0x02 ? 0x83 : i == 0x7f ? 0x84 : uint8_t(i); }

    void reset_state() {
        clk_out_ = data_out_ = true;
        mode_ = 0x80;   // no scanning during the BAT
        typematic_ = kDefaultTypematic;
        leds_ = 0;      // [KBD] 0000: all indicators off
        fifo_.clear();
        replies_.clear();
        sensed_.assign(128, false);
        repeat_key_ = -1;
        stable_ = 0;
    }

    void reply(uint8_t byte, int action = -1) { replies_.push_back({byte, action}); }

    // [TR] 4-7: delay (1 + bits 6-5) x 250 ms; period (8 + A) x 2^B x
    // 4.17 ms, A = bits 2-0, B = bits 4-3.
    uint64_t typematic_delay() const { return clocks_ms(250) * (1 + ((typematic_ >> 5) & 3)); }
    uint64_t typematic_period() const {
        return uint64_t(4170) * us_ * (8 + (typematic_ & 7)) * (1u << ((typematic_ >> 3) & 3));
    }

    // ASSUMPTION AT23: a key change is sensed at once (no matrix scan time,
    // debounce or triple sense).
    void sense(uint8_t code, bool make) {
        const unsigned i = index(code);
        if (sensed_[i] == make) return;
        sensed_[i] = make;
        push(uint16_t(code | (make ? 0 : 0x100)));
        if (make) {
            repeat_key_ = code;          // [TR] 4-4: only the last key pressed repeats
            repeat_wait_ = typematic_delay();
        } else if (repeat_key_ == code) {
            repeat_key_ = -1;            // [KBD] 035D: the repeating key was released
        }
    }

    // Scanning resumed: report what changed while it was stopped ([KBD]
    // keeps its matrix map, so the next scan reports the difference).
    void sync_keys() {
        for (unsigned i = 0; i < 128; i++)
            if (physical_[i] != sensed_[i]) sense(code_of(i), physical_[i]);
    }

    void push(uint16_t entry) {
        // [TR] 4-3: the 17th code is replaced by the overrun code 00h, and
        // further codes are lost.
        if (fifo_.size() < 16) fifo_.push_back(entry);
        else if (fifo_.size() == 16) fifo_.push_back(0x00);
    }

    // [KBD] 022B-0239: a repeat is queued only when the FIFO is empty, and
    // the counter is reloaded with the rate either way.
    void typematic() {
        if (fifo_.empty()) fifo_.push_back(uint16_t(repeat_key_));
        repeat_wait_ = typematic_period();
    }

    void idle(bool clk, bool data) {
        if (clk && !data) {
            // Request-to-send ([TR] 4-15).
            if (++stable_ >= uint64_t(kRtsUs) * us_) begin_receive();
            return;
        }
        if (!clk || !data) { stable_ = 0; return; }   // inhibited
        if (++stable_ < uint64_t(kIdleUs) * us_) return;
        if (!replies_.empty()) {
            byte_ = replies_.front().byte;
            sending_reply_ = true;
        } else if (!(mode_ & 0x80) && !fifo_.empty()) {
            const uint16_t e = fifo_.front();
            byte_ = (e & 0x100) ? 0xf0 : uint8_t(e);
            sending_reply_ = false;
        } else {
            return;
        }
        state_ = State::kSend;
        bit_ = 0;
        phase_ = 0;
        wait_ = uint64_t(kHalfClockUs) * us_;
        data_out_ = false;   // start bit, valid before the first falling edge
    }

    // Keyboard to system ([TR] 4-14, 4-15; [KBD] 0183-01CD): 11 bits, data
    // set while the clock is high, the system reads it on the falling edge.
    void send(bool clk) {
        const uint64_t half = uint64_t(kHalfClockUs) * us_;
        if (phase_ == 0) {
            // Clock released. A low line now is the system pulling it:
            // contention aborts the byte before the rising edge of the
            // tenth clock ([TR] 4-15). The first clock after the release
            // still shows the keyboard's own drive.
            if (!clk && wait_ < half && bit_ <= 9) { abort_send(); return; }
            if (--wait_) return;
            clk_out_ = false;
            phase_ = 1;
            wait_ = half;
            return;
        }
        if (--wait_) return;
        clk_out_ = true;
        if (bit_ == 10) { finish_send(); return; }
        ++bit_;
        data_out_ = bit_value();
        phase_ = 0;
        wait_ = half;
    }

    bool bit_value() const {
        if (bit_ >= 1 && bit_ <= 8) return (byte_ >> (bit_ - 1)) & 1;
        if (bit_ == 9) return !parity(byte_);    // odd parity over data + parity
        return true;                              // stop bit
    }
    static bool parity(uint8_t b) { return __builtin_popcount(b) & 1; }

    void abort_send() {
        clk_out_ = data_out_ = true;
        ++aborted_;
        state_ = State::kIdle;
        stable_ = 0;   // the byte stays queued and is sent again
    }

    void finish_send() {
        data_out_ = true;
        state_ = State::kIdle;
        stable_ = 0;
        ++sent_;
        last_sent_value_ = byte_;
        log(tx_log_, byte_);
        if (byte_ != 0xfe) last_sent_ = byte_;   // [KBD] 01C3: FE is not remembered
        if (sending_reply_) {
            const int action = replies_.front().action;
            replies_.pop_front();
            if (action >= 0) run(uint8_t(action));
        } else {
            uint16_t& e = fifo_.front();
            if (e & 0x100) e &= 0xff;   // F0 sent; the code follows
            else fifo_.pop_front();
        }
    }

    // System to keyboard ([TR] 4-15, 4-16; [KBD] 0152-0181): the keyboard
    // clocks 10 bits, sampling data while the clock is high, then pulls
    // data low and gives the 11th clock as the acknowledge.
    void begin_receive() {
        // [KBD] 0049, 0146: a pending reply whose transmission the system
        // pre-empted is discarded ([TR] 4-13: ACK is discarded).
        replies_.clear();
        state_ = State::kReceive;
        bit_ = 0;
        byte_ = 0;
        phase_ = 1;
        clk_out_ = false;
        wait_ = uint64_t(kHalfClockUs) * us_;
        rx_parity_ = rx_stop_ = false;
    }

    bool rx_parity_ = false, rx_stop_ = false;

    void receive(bool clk, bool data) {
        const uint64_t half = uint64_t(kHalfClockUs) * us_;
        if (phase_ == 1) {                 // clock low
            if (--wait_) return;
            clk_out_ = true;
            phase_ = 0;
            wait_ = half;
            return;
        }
        if (bit_ < 11 && !clk && wait_ < half) {
            // ASSUMPTION AT24: the system holding the clock low during a
            // receive ends it; the byte is ignored.
            clk_out_ = data_out_ = true;
            ++aborted_;
            state_ = State::kIdle;
            stable_ = 0;
            return;
        }
        if (--wait_) return;
        ++bit_;                              // sample at the end of the high time
        if (bit_ <= 8) byte_ |= uint8_t(data) << (bit_ - 1);
        else if (bit_ == 9) rx_parity_ = data;
        else if (bit_ == 10) { rx_stop_ = data; data_out_ = false; }   // acknowledge
        if (bit_ == 11) {
            data_out_ = true;
            state_ = State::kIdle;
            stable_ = 0;
            ++received_;
            last_received_ = byte_;
            log(rx_log_, byte_);
            command(byte_, rx_stop_ && (parity(byte_) != rx_parity_));
            return;
        }
        clk_out_ = false;
        phase_ = 1;
        wait_ = half;
    }

    // [KBD] 0011-00CA and [TR] 4-5 to 4-9.
    void command(uint8_t b, bool ok) {
        if (!ok) { reply(0xfe); return; }               // parity or stop error: Resend
        if (b == 0xfe) { reply(last_sent_); return; }   // Resend
        if (b == 0xee) {                                // Echo
            if ((mode_ & 0x80) && (mode_ & 0x02)) mode_ = 0;
            mode_ &= 0x84;
            reply(0xee);
            return;
        }
        if (b >= 0xed) {
            if ((mode_ & 0x80) && (mode_ & 0x02)) mode_ = 0;   // cancels a pending ED
            reply(0xfa, b);
            return;
        }
        // Not a command: the parameter of ED or F3, or invalid.
        if (!(mode_ & 0x80) || !(mode_ & 0x40)) { reply(0xfe); return; }
        if (mode_ & 0x02) {
            leds_ = b & 7;
            mode_ &= uint8_t(~0x02);
        } else {
            if (b & 0x80) { reply(0xfe); return; }   // [KBD] 0032
            typematic_ = b;
        }
        mode_ &= uint8_t(~0x40);
        if (!(mode_ & 0x04)) mode_ &= 0x7f;
        if (!(mode_ & 0x80)) sync_keys();
        reply(0xfa);
    }

    // A command whose ACK has been sent ([KBD] jump table 00ED-00FF).
    void run(uint8_t b) {
        const bool was_stopped = mode_ & 0x80;
        switch (b) {
        case 0xed: mode_ = uint8_t((mode_ & 0x84) | 0xc2); break;
        case 0xf3: mode_ = uint8_t((mode_ & 0x84) | 0xc0); break;
        case 0xf4: mode_ = 0; fifo_.clear(); break;
        case 0xf5: mode_ = 0x84; typematic_ = kDefaultTypematic; fifo_.clear(); break;
        case 0xf6: typematic_ = kDefaultTypematic; fifo_.clear(); mode_ &= 0x84; break;
        case 0xff: state_ = State::kResetWait; clk_out_ = data_out_ = true; return;
        default: break;   // F7-FD and EF-F2: no operation
        }
        if (mode_ & 0x80) repeat_key_ = -1;
        else if (was_stopped) sync_keys();
    }
};
