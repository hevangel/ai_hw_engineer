# Formal plan

No reset or initialization assumption. Arbitrary initial architectural state;
ignore only the first unavailable $past sample. Assert source/ZERO/OR/OE/carry,
counter update, independent register load, modulo pointer movement and exact
pre-edge-PC push. An anyconst watched slot checks unrelated-word retention.
Run depth-16 BMC, unbounded induction/PDR and covers for each source, push/pop,
wrap, repeat and ZERO overriding OR. Real code validates complete linkage.
