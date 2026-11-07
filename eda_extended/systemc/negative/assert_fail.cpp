// sc_assert is enabled in this build (ENABLE_ASSERTIONS=ON): a false condition is fatal.
#include <systemc>
#include <iostream>

int sc_main(int, char**) {
  std::cout << "before assert" << std::endl;
  sc_assert(1 + 1 == 3);
  std::cout << "after assert" << std::endl;
  return 0;
}
