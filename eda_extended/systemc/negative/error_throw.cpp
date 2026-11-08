// SC_REPORT_ERROR throws by default. Uncaught inside sc_main it must end the program
// with a nonzero status.
#include <systemc>
#include <iostream>

int sc_main(int, char**) {
  std::cout << "before error" << std::endl;
  SC_REPORT_ERROR("extended-eda", "intentional error report");
  std::cout << "after error" << std::endl;
  return 0;
}
