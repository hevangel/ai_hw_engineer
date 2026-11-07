// The value returned by sc_main is the process exit status.
#include <systemc>
#include <iostream>

int sc_main(int, char**) {
  std::cout << "returning 3" << std::endl;
  return 3;
}
