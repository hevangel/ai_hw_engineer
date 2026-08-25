# Final Design Report: [CHIP_NAME]

## 1. Executive Summary

Brief summary of design status, key metrics, and sign-off readiness.

## 2. Design Overview

- Module: [CHIP_NAME]
- Version: 1.0
- Designer: AI Hardware Engineer
- Date: YYYY-MM-DD

## 3. Verification Status

### 3.1 Simulation Results

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Tests run | | | |
| Tests passed | | | |
| Line coverage | | > 95% | |
| Toggle coverage | | > 80% | |
| FSM coverage | | 100% | |

### 3.2 Formal Verification Results

| Property Set | Mode | Result |
|--------------|------|--------|
| Protocol | bmc (depth 50) | |
| Protocol | prove (pdr) | |
| Data integrity | bmc (depth 30) | |
| Reachability | cover | |

### 3.3 Lint/Synthesis

| Check | Tool | Result |
|-------|------|--------|
| Lint | Verilator --lint-only | |
| Synthesis | Yosys | |
| Area | Yosys stat | |

## 4. Known Issues

| Issue | Severity | Impact | Workaround |
|-------|----------|--------|------------|
| None | — | — | — |

## 5. Open Items

- [ ] Item 1
- [ ] Item 2

## 6. Sign-off

| Criterion | Status |
|-----------|--------|
| RTL frozen | |
| Formal clean | |
| Simulation coverage met | |
| Lint clean | |
| Synthesis clean | |

## 7. Appendix

### Resource Utilization (Yosys)

```
Paste yosys stat output here
```

### Test List

```
Paste test list here
```
