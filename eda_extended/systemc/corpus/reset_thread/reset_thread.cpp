// SC_THREAD with a synchronous reset signal. The reset is sampled when the thread
// is triggered by its clock, so a reset asserted between edges takes effect at the
// next rising edge, the thread restarts from its first statement, and local state
// is lost.
#include <systemc>
#include <iostream>

using namespace sc_core;

SC_MODULE(reset_demo) {
  sc_in<bool> clk;
  sc_in<bool> rst;

  SC_CTOR(reset_demo) {
    SC_THREAD(run);
    sensitive << clk.pos();
    reset_signal_is(rst, true);
  }

  static unsigned long long ns() {
    return static_cast<unsigned long long>(sc_time_stamp() / sc_time(1, SC_NS));
  }

  void run() {
    int n = 0;
    std::cout << "START t=" << ns() << std::endl;
    while (true) {
      wait();
      ++n;
      std::cout << "n=" << n << " t=" << ns() << std::endl;
    }
  }
};

SC_MODULE(reset_driver) {
  sc_out<bool> rst;

  SC_CTOR(reset_driver) {
    SC_THREAD(run);
  }

  void run() {
    rst.write(false);
    wait(38, SC_NS);
    rst.write(true);
    wait(12, SC_NS);
    rst.write(false);
    wait(30, SC_NS);
    std::cout << "RESET DONE" << std::endl;
    sc_stop();
  }
};

int sc_main(int, char**) {
  sc_clock clk("clk", sc_time(10, SC_NS), 0.5, sc_time(5, SC_NS), true);
  sc_signal<bool> rst("rst");

  reset_demo dut("dut");
  dut.clk(clk);
  dut.rst(rst);

  reset_driver drv("drv");
  drv.rst(rst);

  sc_start();
  return 0;
}
