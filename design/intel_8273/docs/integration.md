# Connecting the 8273 functional core

All bus and serial pins are sampled on `clk`. Supply single-cycle `tx_tick`
on the physical TxC falling edge, `rx_tick` on RxC rising edge and
`tx_sample_tick` on TxC rising edge. Serial-mode bit 1 selects `tx_sample_tick`
for reception; bit 2 selects the TxD line internally. These distinct strobes
retain Intel's transmit/change versus receive/sample ordering without derived
RTL clocks. Synchronize external asynchronous signals in a board wrapper.

For clock recovery, assert `clk32_tick` at 32 times nominal baud and route
`dpll_tick` to `rx_tick`. Enable NRZI and send preframe sync to establish phase.
The dedicated regression sweeps all 32 initial phases at 31, 32 and 33 ticks
per transmitted bit, using the ordinary sixteen-transition preframe sequence.
It establishes functional recovery for those cases; it does not establish the
original chip's complete analog/noise or baud-rate envelope.

Bus reads/writes are qualified by opposite inactive strobes. Hold address, data
and selects throughout a transfer; one byte is accepted per low strobe even
when stretched. Separate input/output/output-enable signals replace tri-state
pins. In a DMA transfer DACK selects the data latch, independent of CS/address.
DACK alone drops the request but does not consume the byte. The subsequent RD
or WR edge transfers it. A consumed Rx latch continues driving its stored value
throughout RD, allowing the 8237 to assert memory write later in its bus cycle.

DMA transfers information bytes in buffered mode, or A/C plus information in
unbuffered mode. The controller handles all flags, stuffed bits and FCS. Configure
8237 channels for memory-to-device Tx and device-to-memory Rx. Observe a byte's
RD/WR handshake before changing DACK; the core has one host data latch per direction.
Service latency is bounded by the serial byte interval, including arbitration.

Non-DMA mode uses TxINT/RxINT for byte requests when the corresponding IRA bit
is zero. Software still asserts the appropriate DACK and data read/write strobe.
Completion results persist until all bytes are read. Receive completion is
published after the final data latch has been read, so it cannot hide the final
non-DMA byte request. Reissue DMA buffer configuration as required by the host;
a successful frame leaves the receiver enabled until idle/error/disable.

The [full-duplex test](../tb/tb_dma_link.sv) uses four real 8237 channels: 0 Tx A,
1 Rx B, 2 Tx B, 3 Rx A. A memory model supplies reads and commits writes on
`transfer_valid`. It checks both payloads, buffer guards, exact transfer count,
four terminal counts and both controllers' CRC and A/C results. No completed-frame
or byte-level cable abstraction is involved.
