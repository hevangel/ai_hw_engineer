// 4-bit counter with enable and synchronous reset. The expected output is the same
// as the VHDL counter corpus case, so NVC and SystemC are checked against one
// independent Python model (../../../nvc/corpus/counter/reference.py).
#include <systemc>
#include <iostream>

using namespace sc_core;
using namespace sc_dt;

SC_MODULE(counter) {
  sc_in<bool> clk;
  sc_in<bool> rst;
  sc_in<bool> en;
  sc_out<sc_uint<4> > q;

  sc_uint<4> count;

  SC_CTOR(counter) : count(0) {
    SC_METHOD(step);
    sensitive << clk.pos();
    dont_initialize();
  }

  void step() {
    if (rst.read()) {
      count = 0;
    } else if (en.read()) {
      count = count + 1;
    }
    q.write(count);
  }
};

SC_MODULE(stimulus) {
  sc_in<bool> clk;
  sc_out<bool> rst;
  sc_out<bool> en;
  sc_in<sc_uint<4> > q;

  SC_CTOR(stimulus) {
    SC_THREAD(run);
  }

  void tick(int n) {
    for (int i = 0; i < n; ++i) {
      wait(clk.posedge_event());
      wait(1, SC_NS);
      std::cout << "t=" << static_cast<unsigned long long>(sc_time_stamp() / sc_time(1, SC_NS))
                << " rst=" << rst.read() << " en=" << en.read()
                << " q=" << q.read().to_uint() << std::endl;
    }
  }

  void run() {
    rst.write(true);
    en.write(false);
    tick(2);
    rst.write(false);
    en.write(true);
    tick(18);
    en.write(false);
    tick(2);
    rst.write(true);
    tick(1);
    std::cout << "COUNTER DONE" << std::endl;
    sc_stop();
  }
};

int sc_main(int, char**) {
  sc_clock clk("clk", sc_time(10, SC_NS), 0.5, sc_time(5, SC_NS), true);
  sc_signal<bool> rst("rst"), en("en");
  sc_signal<sc_uint<4> > q("q");

  counter dut("dut");
  dut.clk(clk);
  dut.rst(rst);
  dut.en(en);
  dut.q(q);

  stimulus stim("stim");
  stim.clk(clk);
  stim.rst(rst);
  stim.en(en);
  stim.q(q);

  sc_trace_file* tf = sc_create_vcd_trace_file("counter");
  tf->set_time_unit(1, SC_NS);
  sc_trace(tf, clk, "clk");
  sc_trace(tf, rst, "rst");
  sc_trace(tf, en, "en");
  sc_trace(tf, q, "q");

  sc_start();
  sc_close_vcd_trace_file(tf);
  return 0;
}
