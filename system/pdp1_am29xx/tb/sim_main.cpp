// Host harness for the PDP-1 Am29xx machine.
//
// Two modes share one core:
//   * batch:  --image FILE --trace FILE [--max-micro N] [--tw N] [--ss N]
//             runs from reset and writes one line per retired instruction
//             for the external-oracle diff.
//   * server: line commands on stdin, one JSON object per line on stdout,
//             used by the web front panel and the system tests.
//
// A microcycle is one full clock period: the rising edge updates the glue
// registers and the Am2910, the transparent slice latches read during the high
// phase, and the slice RAM writes on the low phase.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <array>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include "Vpdp1_am29xx.h"
#include "verilated.h"
#if VM_TRACE_FST
#include "verilated_fst_c.h"
#endif

namespace {

constexpr int kMemWords = 4096;

struct Machine {
  Vpdp1_am29xx *top = nullptr;
  VerilatedContext *ctx = nullptr;
  std::deque<unsigned> tape;
  std::deque<unsigned> keys;
  std::vector<std::string> trace_lines;
  std::vector<std::array<int, 3>> plots;
  std::vector<unsigned> tty_codes;
  unsigned micro = 0;
  unsigned long long total_micro = 0;
#if VM_TRACE_FST
  VerilatedFstC *tfp = nullptr;
#endif

  void clock_cycle() {
    top->clk_i = 1;
    top->eval();
    top->clk_i = 0;
    top->eval();
    micro++;
    total_micro++;
  }

  void reset() {
    top->rst_n_i = 0;
    top->resume_i = 1;
    for (int i = 0; i < 4; i++) clock_cycle();
    top->rst_n_i = 1;
    top->resume_i = 0;
    clock_cycle();
  }

  void load_word(unsigned addr, unsigned word) {
    top->host_addr_i = addr & 0xfff;
    top->host_wdata_i = word & 0x3ffff;
    top->host_we_i = 1;
    clock_cycle();
    top->host_we_i = 0;
  }

  unsigned read_word(unsigned addr) {
    top->host_addr_i = addr & 0xfff;
    top->eval();
    return top->host_rdata_o & 0x3ffff;
  }

  void feed_io() {
    top->tape_valid_i = !tape.empty();
    top->tape_data_i = tape.empty() ? 0 : tape.front();
    top->kbd_valid_i = !keys.empty();
    top->kbd_data_i = keys.empty() ? 0 : keys.front();
    if (top->tape_pop_o && !tape.empty()) tape.pop_front();
    if (top->kbd_pop_o && !keys.empty()) keys.pop_front();
  }

  void step_cycle() {
    feed_io();
    clock_cycle();
    if (top->dpy_stb_o) {
      plots.push_back({(int)top->dpy_x_o, (int)top->dpy_y_o, (int)top->dpy_int_o});
      if (plots.size() > 20000) plots.erase(plots.begin(), plots.begin() + 10000);
    }
    if (top->tty_stb_o) {
      tty_codes.push_back((unsigned)top->tty_data_o & 0x3fff);
      if (tty_codes.size() > 4000) tty_codes.erase(tty_codes.begin(), tty_codes.begin() + 2000);
    }
  }
};

std::string json_state(Machine &m) {
  char buf[512];
  std::snprintf(buf, sizeof(buf),
                "{\"pc\":%u,\"ac\":%u,\"io\":%u,\"ir\":%u,\"mb\":%u,\"ma\":%u,"
                "\"ov\":%u,\"halted\":%u,\"illegal\":%u,\"microaddr\":%u,\"sbsEnb\":%u,"
                "\"sbsPending\":%u,\"flags\":%u,\"microcycles\":%llu,"
                "\"coreCycles\":%u}",
                (unsigned)m.top->pc_o, (unsigned)m.top->ac_o, (unsigned)m.top->io_o,
                (unsigned)m.top->ir_o, (unsigned)m.top->mb_o, (unsigned)m.top->ma_o,
                (unsigned)m.top->ov_o, (unsigned)m.top->halted_o,
                (unsigned)m.top->illegal_o, (unsigned)m.top->microaddr_o,
                (unsigned)m.top->sbs_enb_o,
                (unsigned)m.top->sbs_pending_o, (unsigned)m.top->flag_o,
                (unsigned long long)m.total_micro, (unsigned)m.top->core_cycles_o);
  return buf;
}

bool load_hex(Machine &m, const std::string &path, std::string &err) {
  std::ifstream in(path);
  if (!in) {
    err = "cannot open " + path;
    return false;
  }
  std::string line;
  int loaded = 0;
  while (std::getline(in, line)) {
    if (line.empty() || line[0] == '#' || line[0] == ';') continue;
    std::istringstream iss(line);
    unsigned addr = 0, word = 0;
    if (!(iss >> std::oct >> addr >> word)) {
      err = "bad image line: " + line;
      return false;
    }
    m.load_word(addr, word);
    loaded++;
  }
  return loaded > 0 || (err.clear(), true);
}

void run_cycles(Machine &m, unsigned long cycles) {
  for (unsigned long i = 0; i < cycles; i++) {
    m.step_cycle();
    if (m.top->trace_o) {
      char buf[256];
      std::snprintf(buf, sizeof(buf), "%04o %06o %06o %06o %o %02o %llu\n",
                    (unsigned)m.top->trace_pc_o & 0xfff,
                    (unsigned)m.top->trace_ir_o & 0x3ffff,
                    (unsigned)m.top->trace_ac_o & 0x3ffff,
                    (unsigned)m.top->trace_io_o & 0x3ffff,
                    (unsigned)m.top->trace_ov_o & 1,
                    (unsigned)m.top->trace_pf_o & 0x3f,
                    (unsigned long long)m.top->trace_micro_o);
      m.trace_lines.emplace_back(buf);
    }
    if (m.top->halted_o) break;
  }
}

}  // namespace

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Machine m;
  m.ctx = new VerilatedContext;
  m.ctx->commandArgs(argc, argv);
  m.top = new Vpdp1_am29xx{m.ctx};

  std::string image, trace_path;
  unsigned long max_micro = 400000;
  unsigned tw = 0, ss = 0;
  bool batch = false;

  for (int i = 1; i < argc; i++) {
    std::string a = argv[i];
    if (a == "--image" && i + 1 < argc) image = argv[++i];
    else if (a == "--trace" && i + 1 < argc) trace_path = argv[++i];
    else if (a == "--max-micro" && i + 1 < argc) max_micro = std::strtoul(argv[++i], nullptr, 0);
    else if (a == "--tw" && i + 1 < argc) tw = std::strtoul(argv[++i], nullptr, 8);
    else if (a == "--ss" && i + 1 < argc) ss = std::strtoul(argv[++i], nullptr, 8);
    else if (a == "--batch") batch = true;
  }

  m.top->tw_i = tw & 0x3ffff;
  m.top->ss_i = ss & 0x3f;
  m.top->tape_valid_i = 0;
  m.top->kbd_valid_i = 0;
  m.top->sbs_req_i = 0;
  m.top->host_we_i = 0;
  m.top->rst_n_i = 0;
  m.top->resume_i = 0;
  m.top->eval();
  m.reset();

  if (!image.empty()) {
    std::string err;
    if (!load_hex(m, image, err)) {
      std::cerr << err << "\n";
      return 1;
    }
    m.reset();
  }

  if (batch) {
    run_cycles(m, max_micro);
    if (!trace_path.empty()) {
      std::ofstream out(trace_path);
      for (auto &line : m.trace_lines) out << line;
    }
    std::printf("%s\n", json_state(m).c_str());
    std::printf("TRACES %zu\n", m.trace_lines.size());
    std::cout.flush();
    return 0;
  }

  std::string line;
  while (std::getline(std::cin, line)) {
    std::istringstream iss(line);
    std::string cmd;
    iss >> cmd;
    if (cmd.empty()) continue;
    if (cmd == "STATE") {
      std::cout << json_state(m) << "\n";
    } else if (cmd == "RUN" || cmd == "STEP") {
      unsigned long n = 1;
      iss >> n;
      if (cmd == "RUN") {
        run_cycles(m, n);
      } else {
        unsigned long done = 0;
        size_t before = m.trace_lines.size();
        while (done < n) {
          m.step_cycle();
          if (m.top->trace_o) {
            char buf[256];
            std::snprintf(buf, sizeof(buf), "%04o %06o %06o %06o %o %02o %llu\n",
                          (unsigned)m.top->trace_pc_o & 0xfff,
                          (unsigned)m.top->trace_ir_o & 0x3ffff,
                          (unsigned)m.top->trace_ac_o & 0x3ffff,
                          (unsigned)m.top->trace_io_o & 0x3ffff,
                          (unsigned)m.top->trace_ov_o & 1,
                          (unsigned)m.top->trace_pf_o & 0x3f,
                          (unsigned long long)m.top->trace_micro_o);
            m.trace_lines.emplace_back(buf);
            done++;
          }
          if (m.top->halted_o) break;
        }
        (void)before;
      }
      std::cout << json_state(m) << "\n";
    } else if (cmd == "RESUME") {
      m.top->resume_i = 1;
      m.step_cycle();
      m.top->resume_i = 0;
      std::cout << json_state(m) << "\n";
    } else if (cmd == "CYCLES") {
      unsigned long n = 1;
      iss >> n;
      for (unsigned long i = 0; i < n; i++) {
        std::printf("C %04o %06o %06o %06o %06o %o %06o %05o %08o %o\n",
                    (unsigned)m.top->microaddr_o,
                    (unsigned)m.top->pc_o, (unsigned)m.top->ir_o,
                    (unsigned)m.top->ac_o, (unsigned)m.top->io_o,
                    (unsigned)m.top->ov_o, (unsigned)m.top->dbg_d_o,
                    (unsigned)m.top->dbg_y_o,
                    (unsigned)m.top->dbg_uc_o);
        m.step_cycle();
      }
      std::cout << json_state(m) << "\n";
    } else if (cmd == "TW") {
      unsigned value = 0;
      iss >> std::oct >> value;
      m.top->tw_i = value & 0x3ffff;
      std::cout << json_state(m) << "\n";
    } else if (cmd == "SS") {
      unsigned value = 0;
      iss >> std::oct >> value;
      m.top->ss_i = value & 0x3f;
      std::cout << json_state(m) << "\n";
    } else if (cmd == "RESET") {
      m.reset();
      std::cout << json_state(m) << "\n";
    } else if (cmd == "LOAD") {
      std::string path;
      iss >> path;
      std::string err;
      bool ok = load_hex(m, path, err);
      std::cout << (ok ? "{\"ok\":true}" : "{\"ok\":false,\"error\":\"" + err + "\"}") << "\n";
    } else if (cmd == "EXAMINE") {
      unsigned addr = 0;
      iss >> std::oct >> addr;
      std::cout << "{\"addr\":" << addr << ",\"word\":" << m.read_word(addr) << "}\n";
    } else if (cmd == "DEPOSIT") {
      unsigned addr = 0, word = 0;
      iss >> std::oct >> addr >> word;
      m.load_word(addr, word);
      std::cout << "{\"ok\":true}\n";
    } else if (cmd == "KEY") {
      unsigned key = 0;
      iss >> std::hex >> key;
      m.keys.push_back(key & 0x3ffff);
      std::cout << "{\"ok\":true}\n";
    } else if (cmd == "KEYCLEAR") {
      m.keys.clear();
      std::cout << "{\"ok\":true}\n";
    } else if (cmd == "TAPE") {
      std::string path;
      iss >> path;
      std::ifstream in(path);
      unsigned word = 0;
      int count = 0;
      while (in >> std::oct >> word) {
        m.tape.push_back(word & 0x3ffff);
        count++;
      }
      std::cout << "{\"ok\":true,\"words\":" << count << "}\n";
    } else if (cmd == "TAPECLEAR") {
      m.tape.clear();
      std::cout << "{\"ok\":true}\n";
    } else if (cmd == "WAVE") {
#if VM_TRACE_FST
      unsigned long n = 4000;
      iss >> n;
      std::string path;
      iss >> path;
      if (path.empty()) path = "system/pdp1_am29xx/work/waveform.fst";
      if (m.tfp) { m.tfp->close(); delete m.tfp; m.tfp = nullptr; }
      m.tfp = new VerilatedFstC;
      m.top->trace(m.tfp, 5);
      m.tfp->open(path.c_str());
      m.reset();
      for (unsigned long i = 0; i < n; i++) {
        m.step_cycle();
        m.ctx->timeInc(1);
        m.tfp->dump(m.ctx->time());
      }
      m.tfp->close();
      std::printf("{\"ok\":true,\"cycles\":%lu,\"path\":\"%s\"}\n", n, path.c_str());
#else
      std::printf("{\"ok\":false,\"error\":\"FST tracing not compiled\"}\n");
#endif
    } else if (cmd == "EVENTS") {
      std::string out = "{\"plots\":[";
      for (size_t i = 0; i < m.plots.size(); i++) {
        char buf[64];
        std::snprintf(buf, sizeof(buf), "%s[%d,%d,%d]", i ? "," : "",
                      m.plots[i][0], m.plots[i][1], m.plots[i][2]);
        out += buf;
      }
      out += "],\"tty\":[";
      for (size_t i = 0; i < m.tty_codes.size(); i++) {
        char buf[16];
        std::snprintf(buf, sizeof(buf), "%s%u", i ? "," : "", m.tty_codes[i]);
        out += buf;
      }
      out += "]}";
      m.plots.clear();
      m.tty_codes.clear();
      std::cout << out << "\n";
    } else if (cmd == "TRACEDUMP") {
      std::cout << "{\"count\":" << m.trace_lines.size() << "}\n";
    } else if (cmd == "QUIT") {
      break;
    } else {
      std::cout << "{\"error\":\"unknown command\"}\n";
    }
    std::cout.flush();
  }

  m.top->final();
  delete m.top;
  delete m.ctx;
  return 0;
}
