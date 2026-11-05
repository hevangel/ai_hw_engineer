// Host harness for the PDP-8 front panel and console.
//
// Line protocol on stdin/stdout, used by host/server.py.  Every observable
// value comes from the RTL; the host only drives panel switches, the console
// wires and the paper-tape reader, and reads lamps and trace signals.
//
//   STATE                 -> one JSON object with lamps and console flags
//   SW <octal>            set the switch register
//   KEY <name>            pulse a panel key (load_addr examine deposit start
//                         stop cont step)
//   DEPOSIT <octal> <octal>  load-address + deposit one word
//   EXAMINE <octal>       load-address + examine, returns the displayed word
//   LOAD <octal> <octal>  debug load port (bootstrap helper)
//   RUN <cycles>          run until halted or the cycle budget expires
//   RESET                 master clear and start
//   KBD <byte>            queue one keyboard character
//   TAPE <hex>            replace the paper-tape image
//   TTY                   drain the printer output (returns hex)
//   PTP                   drain the punch output (hex)
//   WAVE <n>              last n trace samples as JSON
#include "Vpdp8_top.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>
#include <deque>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {

Vpdp8_top dut;
std::deque<uint8_t> keyboard;
std::deque<uint8_t> tape;
std::string tty_log;
std::string ptp_log;

struct Sample {
  int pc, ac, ma, mb, ir, run, link, ion;
};
std::deque<Sample> waves;
constexpr size_t kMaxWave = 512;

int octal(const std::string& text) { return static_cast<int>(std::stoul(text, nullptr, 8)); }

void settle() { dut.eval(); }

void tick() {
  dut.clk_i = 1;
  settle();
  dut.clk_i = 0;
  settle();
  if (dut.tty_valid_o) tty_log.push_back(static_cast<char>(dut.tty_data_o));
  if (dut.ptp_valid_o) ptp_log.push_back(static_cast<char>(dut.ptp_data_o));
  if (dut.kb_take_o && !keyboard.empty()) keyboard.pop_front();
  waves.push_back({dut.lamp_pc_o, dut.lamp_ac_o, dut.lamp_ma_o, dut.lamp_mb_o, 0,
                   dut.lamp_run_o, dut.lamp_l_o, dut.lamp_ion_o});
  if (waves.size() > kMaxWave) waves.pop_front();
}

void drive_console() {
  dut.kb_valid_i = keyboard.empty() ? 0 : 1;
  dut.kb_data_i = keyboard.empty() ? 0 : keyboard.front();
  dut.ptr_valid_i = tape.empty() ? 0 : 1;
  dut.ptr_data_i = tape.empty() ? 0 : tape.front();
  if (dut.ptr_take_o && !tape.empty()) tape.pop_front();
}

void clear_pulses() {
  dut.key_load_addr_i = 0;
  dut.key_examine_i = 0;
  dut.key_deposit_i = 0;
  dut.key_start_i = 0;
  dut.key_stop_i = 0;
  dut.key_cont_i = 0;
  dut.key_step_i = 0;
  dut.eval();
}

void pulse(int which) {
  clear_pulses();
  switch (which) {
    case 0: dut.key_load_addr_i = 1; break;
    case 1: dut.key_examine_i = 1; break;
    case 2: dut.key_deposit_i = 1; break;
    case 3: dut.key_start_i = 1; break;
    case 4: dut.key_stop_i = 1; break;
    case 5: dut.key_cont_i = 1; break;
    default: dut.key_step_i = 1; break;
  }
  for (int i = 0; i < 4; ++i) { drive_console(); tick(); }
  clear_pulses();
  for (int i = 0; i < 4; ++i) { drive_console(); tick(); }
}

std::string hex_string(const std::string& data) {
  static const char* digits = "0123456789abcdef";
  std::string out;
  out.reserve(data.size() * 2);
  for (unsigned char byte : data) {
    out.push_back(digits[byte >> 4]);
    out.push_back(digits[byte & 0xf]);
  }
  return out;
}

std::string state_json() {
  std::ostringstream out;
  out << "{"
      << "\"pc\":" << dut.lamp_pc_o << ","
      << "\"ac\":" << dut.lamp_ac_o << ","
      << "\"ma\":" << dut.lamp_ma_o << ","
      << "\"mb\":" << dut.lamp_mb_o << ","
      << "\"display\":" << dut.lamp_display_o << ","
      << "\"link\":" << int(dut.lamp_l_o) << ","
      << "\"ion\":" << int(dut.lamp_ion_o) << ","
      << "\"run\":" << int(dut.lamp_run_o) << ","
      << "\"sw\":" << int(dut.sw_i) << ","
      << "\"kbd\":" << int(dut.kb_ready_o) << ","
      << "\"tty\":" << int(dut.tty_valid_o) << ","
      << "\"tapeLen\":" << tape.size() << ","
      << "\"keyboard\":" << keyboard.size()
      << "}";
  return out.str();
}

void reset_machine() {
  dut.rst_n_i = 0;
  dut.sw_i = 0;
  clear_pulses();
  for (int i = 0; i < 6; ++i) { drive_console(); tick(); }
  dut.rst_n_i = 1;
  for (int i = 0; i < 6; ++i) { drive_console(); tick(); }
}

void load_word(int address, int data) {
  dut.load_we_i = 1;
  dut.load_addr_i = address & 0xfff;
  dut.load_data_i = data & 0xfff;
  drive_console();
  tick();
  dut.load_we_i = 0;
  drive_console();
  tick();
}

}  // namespace

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  dut.clk_i = 0;
  dut.rst_n_i = 0;
  dut.sw_i = 0;
  dut.load_we_i = 0;
  dut.load_addr_i = 0;
  dut.load_data_i = 0;
  dut.kb_valid_i = 0;
  dut.kb_data_i = 0;
  dut.ptr_valid_i = 0;
  dut.ptr_data_i = 0;
  clear_pulses();
  for (int i = 0; i < 6; ++i) tick();
  dut.rst_n_i = 1;
  for (int i = 0; i < 6; ++i) tick();

  std::string line;
  while (std::getline(std::cin, line)) {
    std::istringstream in(line);
    std::string command;
    in >> command;
    if (command == "STATE") {
      std::cout << state_json() << std::endl;
    } else if (command == "SW") {
      std::string value;
      in >> value;
      dut.sw_i = octal(value);
      dut.eval();
      std::cout << state_json() << std::endl;
    } else if (command == "KEY") {
      std::string name;
      in >> name;
      int which = -1;
      if (name == "load_addr") which = 0;
      else if (name == "examine") which = 1;
      else if (name == "deposit") which = 2;
      else if (name == "start") which = 3;
      else if (name == "stop") which = 4;
      else if (name == "cont") which = 5;
      else if (name == "step") which = 6;
      if (which < 0) {
        std::cout << "{\"error\":\"unknown key\"}" << std::endl;
        continue;
      }
      pulse(which);
      std::cout << state_json() << std::endl;
    } else if (command == "DEPOSIT") {
      std::string address, data;
      in >> address >> data;
      dut.sw_i = octal(address);
      pulse(0);
      dut.sw_i = octal(data);
      pulse(2);
      std::cout << state_json() << std::endl;
    } else if (command == "EXAMINE") {
      std::string address;
      in >> address;
      dut.sw_i = octal(address);
      pulse(0);
      pulse(1);
      std::cout << state_json() << std::endl;
    } else if (command == "LOAD") {
      std::string address, data;
      in >> address >> data;
      load_word(octal(address), octal(data));
      std::cout << state_json() << std::endl;
    } else if (command == "RUN") {
      int budget = 20000;
      in >> budget;
      int used = 0;
      while (used < budget) {
        drive_console();
        tick();
        ++used;
        if (!dut.lamp_run_o && used > 4) break;
      }
      std::cout << state_json() << std::endl;
    } else if (command == "RESET") {
      reset_machine();
      std::cout << state_json() << std::endl;
    } else if (command == "KBD") {
      int value = 0;
      in >> value;
      keyboard.push_back(static_cast<uint8_t>(value & 0xff));
      std::cout << state_json() << std::endl;
    } else if (command == "TAPE") {
      std::string hex;
      in >> hex;
      tape.clear();
      for (size_t i = 0; i + 1 < hex.size(); i += 2)
        tape.push_back(static_cast<uint8_t>(std::stoi(hex.substr(i, 2), nullptr, 16)));
      std::cout << state_json() << std::endl;
    } else if (command == "TTY") {
      std::cout << hex_string(tty_log) << std::endl;
      tty_log.clear();
    } else if (command == "PTP") {
      std::cout << hex_string(ptp_log) << std::endl;
      ptp_log.clear();
    } else if (command == "WAVE") {
      int count = 64;
      in >> count;
      size_t start = waves.size() > static_cast<size_t>(count) ? waves.size() - count : 0;
      std::ostringstream out;
      out << "{\"pc\":[";
      for (size_t i = start; i < waves.size(); ++i) out << (i == start ? "" : ",") << waves[i].pc;
      out << "],\"ac\":[";
      for (size_t i = start; i < waves.size(); ++i) out << (i == start ? "" : ",") << waves[i].ac;
      out << "],\"link\":[";
      for (size_t i = start; i < waves.size(); ++i) out << (i == start ? "" : ",") << waves[i].link;
      out << "],\"run\":[";
      for (size_t i = start; i < waves.size(); ++i) out << (i == start ? "" : ",") << waves[i].run;
      out << "]}";
      std::cout << out.str() << std::endl;
    } else if (command == "QUIT") {
      break;
    } else {
      std::cout << "{\"error\":\"unknown command\"}" << std::endl;
    }
  }
  dut.final();
  return 0;
}
