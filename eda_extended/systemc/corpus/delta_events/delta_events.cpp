// Evaluate/update (delta cycle) and event notification semantics, IEEE 1666 section 4.
// Only one process prints, so the output does not depend on the unspecified order
// in which processes run inside one delta cycle.
#include <systemc>
#include <iostream>

using namespace sc_core;

SC_MODULE(delta_demo) {
  sc_signal<int> s;
  sc_event delta_ev;
  sc_event lost_ev;

  SC_CTOR(delta_demo) : s("s") {
    SC_THREAD(run);
  }

  static unsigned long long ns() {
    return static_cast<unsigned long long>(sc_time_stamp() / sc_time(1, SC_NS));
  }

  void run() {
    s.write(1);
    // A signal write takes effect in the update phase: the old value is still visible.
    std::cout << "A s=" << s.read() << std::endl;
    wait(SC_ZERO_TIME);
    std::cout << "B s=" << s.read() << std::endl;
    const sc_dt::uint64 after_b = sc_delta_count();

    delta_ev.notify(SC_ZERO_TIME);
    wait(delta_ev);
    std::cout << "C delta_since_B=" << (sc_delta_count() - after_b)
              << " t=" << ns() << std::endl;

    delta_ev.notify(5, SC_NS);
    wait(delta_ev);
    std::cout << "D t=" << ns() << std::endl;

    // An immediate notification with no waiting process is lost.
    lost_ev.notify();
    wait(10, SC_NS, lost_ev);
    // The lost notification did not wake the thread: it resumed only at the timeout.
    std::cout << "E t=" << ns() << std::endl;

    // A pending later notification is replaced by an earlier one.
    delta_ev.notify(20, SC_NS);
    delta_ev.notify(2, SC_NS);
    wait(delta_ev);
    std::cout << "F t=" << ns() << std::endl;
    std::cout << "DELTA DONE" << std::endl;
    sc_stop();
  }
};

int sc_main(int, char**) {
  delta_demo d("d");
  sc_start();
  return 0;
}
