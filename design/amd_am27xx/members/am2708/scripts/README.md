# Am2708 family scripts

This directory contains Am2708-specific verification scripts for the AMD Am27xx series.

## Scripts

### Core verification
- `run_sim.sh` - Run Am2708 simulation tests
- `run_formal.sh` - Run Am2708 formal verification
- `run_synth.sh` - Run Am2708 synthesis
- `run_all.sh` - Complete Am2708 verification pipeline

### Support scripts
- `generate_test_vectors.py` - Generate test vectors for programming verification
- `check_timing.py` - Analyze timing characteristics
- `verify_data_integrity.py` - Verify data integrity after programming

## Usage

```bash
# Run complete verification pipeline
./scripts/run_all.sh

# Run individual verification steps
./scripts/run_sim.sh
./scripts/run_formal.sh
./scripts/run_synth.sh
```

## Test scenarios

The scripts support the following test scenarios:

1. **Basic read/write operations** - Verify memory read and write functionality
2. **Programming sequence** - Test JEDEC programming commands
3. **Erase verification** - Test UV erase cycle timing
4. **Timing analysis** - Verify timing constraints and setup/hold requirements
5. **Error conditions** - Test error handling and failure modes
6. **Data integrity** - Verify data retention after programming

## Dependencies

- Verilog simulator (Icarus Verilog or equivalent)
- Formal verification tools (SymbiYosys or equivalent)
- Synthesis tools (Yosys or equivalent)
- Python 3.x for support scripts