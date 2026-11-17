// Diskette drives and decoded media for the IBM PC AT diskette adapter
// (src/at_diskette_adapter.sv), for the batch runner and the web simulator.
//
// Two drives on the adapter's cable. Each is a high-capacity (1.2 MB, 80
// cylinders, 360 rpm) or a double-density (360 KB, 40 cylinders, 300 rpm)
// drive, the two types the REV1 BIOS supports (DSKETTE listing, PDF 227-228:
// "320/360K DISKETTE DRIVES AND 1.2M DISKETTE DRIVES SUPPORTED"; the BIOS
// knows no 720 KB or 1.44 MB format). A drive holds a raw sector image
// (.img): 1,228,800 bytes (1.2 MB: 80 x 2 x 15 x 512) or 368,640 bytes
// (360 KB: 40 x 2 x 9 x 512); 327,680 bytes (320 KB, 8 sectors) is also
// accepted.
//
// What a drive does here (ASSUMPTION AT34 in the specification):
//   - The medium is decoded sectors (AT3): one ID per sector with its
//     C/H/R/N (N = 2, 512 bytes), sectors 1..SPT in order, no CRC errors and
//     no deleted marks. The disk turns while its motor bit is set and a
//     medium is inserted; it is at speed at once (no spin-up time).
//   - An ID and its data field can be read only when the adapter's data
//     rate matches the medium in that drive: 1.2 MB medium in a 1.2 MB drive
//     at 500 kbit/s, 360 KB medium in a 1.2 MB drive at 300 kbit/s (360 rpm),
//     360 KB medium in a 360 KB drive at 250 kbit/s (Technical Reference PDF
//     612 and the BIOS's media table). At any other rate the controller sees
//     index pulses but no ID. A 1.2 MB medium cannot be read in a 360 KB
//     drive. A 360 KB medium in a 1.2 MB drive has its tracks at the even
//     head positions (48 against 96 tracks per inch); at an odd position no
//     ID is readable.
//   - Timing: a revolution, a byte and the gaps are counted in processor
//     clocks at clocks_per_second (the adapter's CLK_HZ; AT27). The index
//     pulse is one clock at the start of a revolution; ID k (k = 0..SPT-1)
//     comes at kIndexGapBytes + k * (revolution - kIndexGapBytes) / SPT byte
//     times, and its data field starts kIdToDataBytes byte times later.
//   - Track 0 is head position 0. A step pulse moves the selected drive's
//     head one position (direction 1 = inward), within 0..cylinders+3.
//   - Diskette Change: active from power-on and after a medium is inserted
//     or removed; cleared by a step pulse to the selected drive while a
//     medium is inserted (the behaviour the BIOS relies on to reset the line,
//     DSKETTE listing PDF 227 "ATTEMPT TO RESET DISK CHANGE LINE").
//   - Write protect is the image's read-only flag.
//   - Write and format store the controller's bytes into the image at the
//     sector being written; format stores the filler byte of each formatted
//     sector whose C/H/R/N fits the image geometry.
#pragma once
#include <array>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>

namespace at_diskette {

enum class DriveType { None, HighCapacity, DoubleDensity };

// Lines from the adapter, sampled once per processor clock.
struct AdapterLines {
    unsigned select = 0;     // one-hot: bit 0 drive A, bit 1 drive B
    unsigned motor = 0;      // bit 0 drive A, bit 1 drive B
    bool step = false, direction = false, head = false;
    unsigned rate = 0;       // 0 = 500, 1 = 300, 2 = 250 kbit/s
    bool active = false, writing = false, formatting = false;
    bool sector_begin = false, tx_valid = false;
    uint8_t tx_byte = 0, sector_r = 0;
};

// Lines to the adapter for the next clock.
struct DriveLines {
    bool track0 = false, write_protect = false, change = false;
    bool index = false, header = false;
    uint8_t c = 0, h = 0, r = 0, n = 0;
    bool byte_valid = false;
    uint8_t byte = 0;
    bool end = false, slot = false;
};

struct Drive {
    DriveType type = DriveType::None;
    std::vector<uint8_t> image;
    bool read_only = false;
    bool changed = true;      // power-on state of the change line
    bool dirty = false;
    unsigned position = 0;    // head position (cylinder of the drive)
    uint64_t angle = 0;       // clocks since the last index
    // Geometry of the inserted medium.
    unsigned cylinders = 0, sectors = 0;
    bool high_density_medium = false;

    bool has_medium() const { return !image.empty(); }
    unsigned max_position() const { return (type == DriveType::HighCapacity ? 80 : 40) + 3; }
    unsigned rpm() const { return type == DriveType::HighCapacity ? 360 : 300; }
    // Data rate code at which the medium in this drive reads, or -1.
    int readable_rate() const {
        if (!has_medium() || type == DriveType::None) return -1;
        if (high_density_medium) return type == DriveType::HighCapacity ? 0 : -1;
        return type == DriveType::HighCapacity ? 1 : 2;
    }
    // Medium track under the head, or -1 where no track is recorded.
    int track() const {
        if (high_density_medium || type == DriveType::DoubleDensity)
            return position < cylinders ? int(position) : -1;
        if (position & 1) return -1;
        return position / 2 < cylinders ? int(position / 2) : -1;
    }
    size_t offset(unsigned c, unsigned h, unsigned r) const {
        return ((size_t(c) * 2 + h) * sectors + (r - 1)) * 512;
    }
    void insert(std::vector<uint8_t> data, bool ro) {
        unsigned cyl, spt;
        bool hd = false;
        switch (data.size()) {
            case 1228800: cyl = 80; spt = 15; hd = true; break;
            case 368640:  cyl = 40; spt = 9; break;
            case 327680:  cyl = 40; spt = 8; break;
            default: throw std::runtime_error("unsupported diskette image size " + std::to_string(data.size()));
        }
        if (hd && type != DriveType::HighCapacity)
            throw std::runtime_error("a 1.2 MB image needs a high-capacity drive");
        image = std::move(data);
        read_only = ro;
        cylinders = cyl;
        sectors = spt;
        high_density_medium = hd;
        changed = true;
        dirty = false;
    }
    void eject() { image.clear(); changed = true; }
};

class Diskettes {
public:
    static constexpr unsigned kIndexGapBytes = 50;
    static constexpr unsigned kIdToDataBytes = 30;

    explicit Diskettes(uint64_t clocks_per_second) : hz_(clocks_per_second) {}

    std::array<Drive, 2> drive;

    static std::vector<uint8_t> read_file(const std::string& path) {
        std::ifstream f(path, std::ios::binary);
        if (!f) throw std::runtime_error("cannot open diskette image " + path);
        return {std::istreambuf_iterator<char>(f), {}};
    }
    void mount(unsigned unit, const std::string& path, bool read_only) {
        drive.at(unit).insert(read_file(path), read_only);
    }
    void save(unsigned unit, const std::string& path) const {
        std::ofstream f(path, std::ios::binary);
        const auto& img = drive.at(unit).image;
        f.write(reinterpret_cast<const char*>(img.data()), std::streamsize(img.size()));
        if (!f) throw std::runtime_error("cannot write diskette image " + path);
    }

    uint64_t media_reads = 0, media_writes = 0, ids = 0, steps = 0;

    // One processor clock. `in` is what the adapter drives during this
    // clock; the result is what the drives drive for the next one.
    DriveLines tick(const AdapterLines& in) {
        DriveLines out;
        // Every drive whose motor is on and which holds a medium turns.
        for (unsigned u = 0; u < 2; u++) {
            Drive& d = drive[u];
            if (d.type == DriveType::None || !d.has_medium() || !(in.motor & (1u << u))) continue;
            const uint64_t rev = hz_ * 60 / d.rpm();
            if (++d.angle >= rev) d.angle = 0;
        }
        const int sel = (in.select & 1) ? 0 : (in.select & 2) ? 1 : -1;
        // Step pulses reach the selected drive.
        if (in.step && !old_step_ && sel >= 0) {
            Drive& d = drive[sel];
            if (d.type != DriveType::None) {
                ++steps;
                if (in.direction) { if (d.position < d.max_position()) ++d.position; }
                else if (d.position) --d.position;
                if (d.has_medium()) d.changed = false;
            }
        }
        old_step_ = in.step;
        if (sel < 0 || drive[sel].type == DriveType::None) { field_ = Field(); return out; }
        Drive& d = drive[sel];
        out.track0 = d.position == 0;
        out.write_protect = d.has_medium() && d.read_only;
        out.change = d.changed;
        const bool spinning = d.has_medium() && (in.motor & (1u << sel));
        if (!spinning) { field_ = Field(); return out; }
        const uint64_t rev = hz_ * 60 / d.rpm();
        if (d.angle == 0) out.index = true;
        const int rate = d.readable_rate();
        const int trk = d.track();
        const unsigned head = in.head ? 1 : 0;
        const uint64_t byte_clocks = hz_ * 8 / (rate == 0 ? 500000 : rate == 1 ? 300000 : 250000);
        const bool readable = rate >= 0 && unsigned(rate) == in.rate && trk >= 0;

        // Format: after each ID the controller publishes (sector_begin), a
        // data field of write slots follows.
        if (in.sector_begin && in.formatting) {
            field_ = Field();
            field_.on = true;
            field_.format = true;
            field_.unit = unsigned(sel);
            field_.c = trk;
            field_.h = head;
            field_.r = in.sector_r;
            field_.next = 2 * byte_clocks;
            field_.spacing = byte_clocks;
        }
        if (in.sector_begin && !in.formatting && field_.on) {
            // A write data field: the sector the controller matched.
            field_.r = in.sector_r;
        }
        // IDs.
        if (readable && !in.formatting) {
            const uint64_t gap = kIndexGapBytes * byte_clocks;
            const uint64_t slot = (rev - gap) / d.sectors;
            if (d.angle >= gap && (d.angle - gap) % slot == 0 && (d.angle - gap) / slot < d.sectors) {
                const unsigned k = unsigned((d.angle - gap) / slot);
                out.header = true;
                out.c = uint8_t(trk);
                out.h = uint8_t(head);
                out.r = uint8_t(k + 1);
                out.n = 2;
                ++ids;
                field_ = Field();
                field_.on = true;
                field_.unit = unsigned(sel);
                field_.c = trk;
                field_.h = head;
                field_.r = k + 1;
                field_.next = kIdToDataBytes * byte_clocks;
                field_.spacing = byte_clocks;
            }
        }
        // The data field following the last ID (or format ID).
        if (field_.on && field_.unit == unsigned(sel)) {
            if (--field_.next == 0) {
                field_.next = field_.spacing;
                if (field_.count < 512) {
                    if (in.writing || field_.format) out.slot = true;
                    else if (readable) {
                        out.byte_valid = true;
                        out.byte = d.image[d.offset(field_.c, field_.h, field_.r) + field_.count];
                        ++media_reads;
                    }
                    ++field_.count;
                } else {
                    if (!in.writing && !field_.format) out.end = true;
                    field_.on = false;
                }
            }
        }
        // Bytes the controller writes (one per slot, on the clock after it).
        if (in.tx_valid && field_.unit == unsigned(sel) && field_.c >= 0 && field_.written < 512) {
            const unsigned r = field_.r;
            if (!d.read_only && r >= 1 && r <= d.sectors && unsigned(field_.c) < d.cylinders) {
                d.image[d.offset(field_.c, field_.h, r) + field_.written] = in.tx_byte;
                d.dirty = true;
                ++media_writes;
            }
            ++field_.written;
        }
        return out;
    }

private:
    struct Field {
        bool on = false, format = false;
        unsigned unit = 0;
        int c = -1;
        unsigned h = 0, r = 0, count = 0, written = 0;
        uint64_t next = 0, spacing = 0;
    };
    uint64_t hz_;
    bool old_step_ = false;
    Field field_;
};

}  // namespace at_diskette
