# Am27xx family-level verification scripts

## Scripts overview

This directory contains family-level verification scripts that can be used across all member chips in the Am27xx series.

### Common scripts
- `run_formal.sh` - Family formal verification
- `run_sim.sh` - Family simulation test suite
- `run_all.sh` - Complete family verification pipeline
- `run_synth.sh` - Family synthesis verification

### Member-specific scripts
Each member chip should have its own script directory for chip-specific verification tasks.

## Family verification approach

The family verification approach emphasizes:
1. Common infrastructure shared across all members
2. Member-specific test cases and coverage requirements
3. Scalable verification methodology that grows with the family
4. Shared resources where possible (simulators, formal tools)

## Usage

Run `scripts/run_all.sh` for complete family verification. Individual member scripts can be run separately for focused testing.