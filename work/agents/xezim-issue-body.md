## Summary

A function whose formal has a packed range that does not start at zero returns `x` when it bit-selects that formal with a loop variable. The function body is legal SystemVerilog and every index is inside the declared range.

`ref_direct` below reads `a[i]` from `input logic [12:1] a`. `ref_mask` is the same predicate written with masks over a `[11:0]` formal. They must agree on every input.

## Testcase

Save as `nonzero_formal_bitselect.sv`, then:

```
xezim --simulate --sv2017 -s nonzero_formal_bitselect nonzero_formal_bitselect.sv
```

```systemverilog
`timescale 1ns/1ps
// Bit-select of a function formal whose packed range does not start at zero.
//
// Two functions implement the identical 12-bit threshold-comparator rule.
//   ref_direct : formal declared [12:1], reads a[i] with a loop variable
//   ref_mask   : zero-based formal, evaluated with masks
// They are the same predicate over the same 12 bits, so every comparison below
// must pass. Directed checks cover the vectors that are reported failing; the
// exhaustive check covers all 65536 assignments of {p, a}.
//
// Command line:
//   xezim --simulate --sv2017 -s nonzero_formal_bitselect nonzero_formal_bitselect.sv

module nonzero_formal_bitselect;
    int errors = 0;

    // failing form: non-zero-based packed formal, variable bit-select in a loop
    function automatic logic ref_direct(input logic [3:0] p, input logic [12:1] a);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= p) m &= (a[i] == 1'b0);
            else        m &= (a[i] == 1'b1);
        return ~m;
    endfunction

    // same rule, zero-based formal, mask form
    function automatic logic ref_mask(input logic [3:0] p, input logic [11:0] b);
        logic [11:0] low;
        low = (p >= 12) ? 12'hFFF : ((12'h001 << p) - 12'h001);
        return ~(((b & low) == 12'h000) && ((b & ~low) == (12'hFFF & ~low)));
    endfunction

    task automatic check(input string name, input logic [3:0] p,
                         input logic [12:1] a, input logic expected);
        logic got;
        got = ref_direct(p, a);
        if (got === expected) begin
            $display("PASS %-24s p=%0d a=%b got=%b", name, p, a, got);
        end else begin
            $display("FAIL %-24s p=%0d a=%b got=%b expected=%b", name, p, a, got, expected);
            errors++;
        end
    endtask

    initial begin
        // Directed checks: the vectors that are reported failing.
        check("nonzero-p0-...110", 4'd0,  12'b111111111110, 1'b1);
        check("nonzero-p0-...111", 4'd0,  12'b111111111111, 1'b0);
        check("nonzero-p1-...100", 4'd1,  12'b111111111100, 1'b1);
        check("nonzero-p1-...101", 4'd1,  12'b111111111101, 1'b1);
        check("nonzero-p1-...110", 4'd1,  12'b111111111110, 1'b0);
        check("nonzero-p2-...000", 4'd2,  12'b111111111000, 1'b1);
        check("nonzero-p2-...100", 4'd2,  12'b111111111100, 1'b0);
        check("nonzero-p11-...000", 4'd11, 12'b100000000000, 1'b0);
        check("nonzero-p15-all-0", 4'd15, 12'b000000000000, 1'b0);
        check("nonzero-p15-one-1", 4'd15, 12'b000000000001, 1'b1);

        // Exhaustive cross-check against the mask form.
        begin
            int mismatches = 0;
            for (int v = 0; v < (1 << 16); v++) begin
                logic [3:0]  p;
                logic [12:1] a;
                {p, a} = v[15:0];
                if (ref_direct(p, a) !== ref_mask(p, a)) mismatches++;
            end
            if (mismatches == 0)
                $display("PASS %-24s 0 mismatches over 65536 vectors", "exhaustive");
            else begin
                $display("FAIL %-24s %0d mismatches over 65536 vectors", "exhaustive", mismatches);
                errors++;
            end
        end

        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL (%0d failing checks)", errors);
        $finish;
    end
endmodule
```

## Actual

```
FAIL nonzero-p0-...110        p=0 a=111111111110 got=x expected=1
FAIL nonzero-p0-...111        p=0 a=111111111111 got=x expected=0
FAIL nonzero-p1-...100        p=1 a=111111111100 got=x expected=1
FAIL nonzero-p1-...101        p=1 a=111111111101 got=x expected=1
FAIL nonzero-p1-...110        p=1 a=111111111110 got=x expected=0
FAIL nonzero-p2-...000        p=2 a=111111111000 got=x expected=1
FAIL nonzero-p2-...100        p=2 a=111111111100 got=x expected=0
FAIL nonzero-p11-...000       p=11 a=100000000000 got=x expected=0
FAIL nonzero-p15-all-0        p=15 a=000000000000 got=x expected=0
FAIL nonzero-p15-one-1        p=15 a=000000000001 got=x expected=1
FAIL exhaustive               43 mismatches over 65536 vectors
RESULT: FAIL (11 failing checks)
```

Every directed vector returns `x`, including ones where no bit is unknown and every index is in range.

## Expected

```
PASS nonzero-p0-...110        p=0 a=111111111110 got=1
PASS nonzero-p0-...111        p=0 a=111111111111 got=0
PASS nonzero-p1-...100        p=1 a=111111111100 got=1
PASS nonzero-p1-...101        p=1 a=111111111101 got=1
PASS nonzero-p1-...110        p=1 a=111111111110 got=0
PASS nonzero-p2-...000        p=2 a=111111111000 got=1
PASS nonzero-p2-...100        p=2 a=111111111100 got=0
PASS nonzero-p11-...000       p=11 a=100000000000 got=0
PASS nonzero-p15-all-0        p=15 a=000000000000 got=0
PASS nonzero-p15-one-1        p=15 a=000000000001 got=1
PASS exhaustive               0 mismatches over 65536 vectors
RESULT: PASS
```

Basis for the expected values: IEEE 1800-2017 §11.5.1 — a bit-select `a[i]` reads bit `i` of `a`, and the declared range `[12:1]` makes 1..12 the valid index set, so none of these selects is out of range. The two functions are the same predicate over the same 12 bits and agree arithmetically on all 131072 assignments, checked outside the simulator as well as here. The reference simulator (Verilator 5.052) reports `RESULT: PASS` on this exact file.

## Version

```
=== xezim 0.11.3 ===
git 058f2bba (2026-10-23T17:05:55-07:00)
```

Also reproduced on `main` at `0fca605f` (2026-10-29, 154 commits past the 0.11.3 tag): same 43 mismatches, so it is not already fixed there.

## Ruled out

Each of these still produces exactly 43 mismatches, so none is the trigger:

- `XEZIM_JIT=0` and `XEZIM_JIT=1` — not the Cranelift backend
- `XEZIM_NO_CACHE=1` — not the elaboration cache
- `--wave`, which the help text says forces loops onto the slower AST path
- with and without `--sv2017`

## What makes it go away

All three give 0 mismatches:

- copy the formal into a `logic [11:0]` local and index `b[i-1]`
- declare the formal `[11:0]` and index `bb[i-1]`
- use the mask form

## Scope and a caveat

The exhaustive cross-check fails on 43 of 65536 assignments, clustered at the `P`/`P+1` boundary: 32 return `x` and 11 return the wrong `0`/`1`.

One caveat that may matter for diagnosis: smaller standalone shapes sometimes pass. A bare `function automatic logic f(input logic [12:1] a); return a[1]; endfunction` passed in several contexts I tried, and adding a `$display` inside the callee made a failing case pass again. The testcase above is therefore kept as-is rather than shrunk further; the outcome appears to depend on how the call site is compiled.

No prior report: #413 and #352 cover bit-select and packed-local handling but not a formal's declared range.
