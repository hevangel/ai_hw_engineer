# Verilator Multithreading

Source: [veripool.org/guide/latest/verilating.html](https://veripool.org/guide/latest/verilating.html)

## Enabling Multithreading

```bash
verilator --binary --threads 4 top.sv
```

## Thread Modes

| `--threads` Value | Behavior |
|-------------------|----------|
| `1` | Single-threaded model; libraries are thread-safe (allows multi-instance) |
| `N` (N >= 2) | Model runs on N threads; eval() provides one, model creates N-1 |

## Threading Rules

- The thread calling `eval()` must be the same thread that constructed the model (the "eval thread")
- Global operations (save, trace) must be done by the "main thread"
- eval thread and main thread can be the same (common case)
- Don't oversubscribe CPU cores — performance degrades badly

## Thread Affinity (Performance)

```bash
# Find physical cores on same socket
egrep 'processor|physical id|core id' /proc/cpuinfo

# Run with NUMA affinity
numactl -m 0 -C 0,1,2,3 -- ./obj_dir/Vtop

# Disable automatic affinity
export VERILATOR_NUMA_STRATEGY=none
```

For AMD EPYC/Ryzen with multiple L3 clusters, bind threads within a single L3 cluster using `lstopo`.

## DPI Thread Safety

| `--threads-dpi` | Behavior |
|-----------------|----------|
| `pure` (default) | Pure DPI imports assumed thread-safe |
| `all` | All DPI imports assumed thread-safe |
| `none` | No DPI imports assumed thread-safe |

## Library/Feature Compatibility

| Feature | Thread Safety |
|---------|--------------|
| `--coverage` | Fully thread-safe |
| DPI imports | Depends on `--threads-dpi` |
| `--savable` | Not multithreaded; eval thread only |
| `--sc` (SystemC) | Not thread-safe; eval = main thread |
| `--trace-vcd` | Main thread only for construction/calls |
| `--vpi` | Main thread only (VPI not designed for MT) |

## `$display`/`$stop`/`$finish`

These are delayed until end of `eval()` to maintain ordering between threads. Additional tasks may complete after `$stop`/`$finish`.

## Best Practices

1. Start with `--threads 2` and measure; more threads have diminishing returns
2. Use `--prof-exec` to see actual CPU usage
3. For small designs, single-threaded is often faster
4. Large designs with independent modules benefit most
5. Consider hierarchical verilation to separate independent blocks
