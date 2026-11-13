#include "Vamd_am9513.h"
#include "verilated.h"
#include <cstdio>
#include <cassert>

static Vamd_am9513* dut;
static vluint64_t sim_time = 0;

void tick() {
    dut->clk = 0; dut->eval(); sim_time++;
    dut->clk = 1; dut->eval(); sim_time++;
}

void reset() {
    dut->rst_n = 0;
    dut->cs_n = 1; dut->rd_n = 1; dut->wr_n = 1; dut->c_d = 0;
    for (int i=0;i<5;i++) {}
    for (int i=0;i<10;i++) tick();
    dut->rst_n = 1;
    for (int i=0;i<5;i++) tick();
}

void wr_cmd(uint8_t cmd) {
    dut->c_d = 1;
    dut->cs_n = 0;
    dut->wr_n = 0;
    dut->db = cmd;
    tick();
    dut->wr_n = 1;
    dut->cs_n = 1;
    dut->c_d = 0;
    tick();
}

void wr_data(uint16_t val, uint16_t* ptr_unused) {
    dut->c_d = 0;
    dut->cs_n = 0;
    dut->wr_n = 0;
    dut->db = val;
    tick();
    dut->wr_n = 1;
    dut->cs_n = 1;
    tick();
}

uint16_t rd_data() {
    dut->c_d = 0;
    dut->cs_n = 0;
    dut->rd_n = 0;
    tick();
    uint16_t v = dut->db;
    dut->rd_n = 1;
    dut->cs_n = 1;
    tick();
    return v;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    dut = new Vamd_am9513;
    reset();

    // Set counter 1 load = 5, mode A (up, binary), arm
    // Load data pointer to counter1 mode (group1 elem0): 001_00_1 = 0b001001 = 9? dptr format ggg e b (byte). mode register elem0. dptr = (1<<3)|(0<<1)|1 = 9
    wr_cmd(9); // load data pointer
    wr_data(0x0000, nullptr); // mode: up, binary, mode A (000/000)
    // load register (elem1): dptr auto increments to load if MM14=0 (enabled by reset). But we disabled? MM14 reset 0 => increment enabled. After mode write, dptr increments to load. Write load=5
    wr_data(0, nullptr);
    // arm counter1
    wr_cmd(0x21); // ARM mask bit0

    // tick and check counting
    for (int i=0;i<3;i++) tick();
    // save
    wr_cmd(0x81); // SAVE
    // read hold via data pointer
    wr_cmd(11); // hold reg counter1? group1 elem2 => dptr 001_10_1 = 11
    uint16_t h = rd_data();
    printf("hold=%u\n", h);
    if (h != 3) { printf("FAIL expected 3 got %u\n", h); return 1; }

    printf("PASS\n");
    dut->final();
    return 0;
}