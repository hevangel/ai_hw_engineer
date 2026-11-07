// SC_REPORT_FATAL aborts the simulation: the process must exit nonzero.
#include <systemc>
#include <iostream>

int sc_main(int, char**) {
  std::cout << "before fatal" << std::endl;
  SC_REPORT_FATAL("extended-eda", "intentional fatal report");
  std::cout << "after fatal" << std::endl;
  return 0;
}
