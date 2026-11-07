// A port left unbound is an elaboration error reported when simulation starts.
#include <systemc>
#include <iostream>

using namespace sc_core;

SC_MODULE(needs_binding) {
  sc_in<bool> in;
  SC_CTOR(needs_binding) {}
};

int sc_main(int, char**) {
  needs_binding m("m");
  sc_start(1, SC_NS);
  std::cout << "simulation started" << std::endl;
  return 0;
}
