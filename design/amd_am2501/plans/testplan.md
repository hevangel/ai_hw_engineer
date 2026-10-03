# Test plan: Am2501

Pin-level `tb_top.sv` exhausts 16 prior states x two directions x two PE
levels x 64 six-CE patterns x 16 preset words = 65,536 transitions. A
simultaneous two-CE DUT uses the low two CE bits and is checked independently.
The oracle uses the successor/predecessor list in AMD's Figure 7; TC is
checked before and after each edge, including inhibit and preset cases.

CP HIGH is the legal control-update window: change mode, direction, enables,
and P there, wait, lower CP, then raise it after setup. Check held-high and
falling clocks. Four actual six-CE devices share a clock and direction;
upper CEs wire to lower TCs as in AMD Figure 9. Run 65,540 up clocks and
65,540 down clocks, crossing every 4-, 8-, 12-, and 16-bit boundary. Also
inhibit at terminal states and validate synchronous preset priority.

This discrete component has no transaction bus interface; direct exhaustive
pin stimulation is used instead of a UVM bus agent. Every mismatch and
missing coverage count is fatal; success requires an explicit pass marker.
