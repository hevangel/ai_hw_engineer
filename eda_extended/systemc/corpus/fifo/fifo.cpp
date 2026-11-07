// Bounded sc_fifo with a fast producer and a slow consumer.
#include <systemc>
#include <iostream>

using namespace sc_core;

SC_MODULE(fifo_demo) {
  sc_fifo<int> fifo;

  SC_CTOR(fifo_demo) : fifo("fifo", 4) {
    SC_THREAD(producer);
    SC_THREAD(consumer);
  }

  static unsigned long long ns() {
    return static_cast<unsigned long long>(sc_time_stamp() / sc_time(1, SC_NS));
  }

  void producer() {
    for (int i = 0; i < 8; ++i) {
      fifo.write(i);
      std::cout << "t=" << ns() << " wrote=" << i << std::endl;
    }
  }

  void consumer() {
    wait(20, SC_NS);
    for (int k = 0; k < 8; ++k) {
      int v = fifo.read();
      std::cout << "t=" << ns() << " read=" << v << std::endl;
      wait(10, SC_NS);
    }
    std::cout << "FIFO DONE" << std::endl;
    sc_stop();
  }
};

int sc_main(int, char**) {
  fifo_demo f("f");
  sc_start();
  return 0;
}
