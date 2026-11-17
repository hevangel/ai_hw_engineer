-- Testbench for the VHDL-93 case, written to VHDL-93 rules.
--
-- std.env, `finish` and conditional variable assignment are VHDL-2008, so this
-- testbench avoids all three: the clock is gated off at the end so every
-- process ends and the simulation stops, and the stimulus is chosen with
-- if/else instead of a conditional assignment.
library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

entity tb_gate93 is
end entity;

architecture sim of tb_gate93 is
  -- std_logic_image is VHDL-2008, so convert with a local function.
  function bit_int (v : std_logic) return integer is
  begin
    if v = '1' then return 1; else return 0; end if;
  end function;
  signal clk : std_logic := '0';
  signal run : boolean := true;
  signal a   : std_logic := '0';
  signal b   : std_logic := '0';
  signal y   : std_logic := '0';
begin
  -- Gate the clock so the simulation can end without VHDL-2008 `finish`.
  clk <= not clk after 5 ns when run else '0';

  dut : entity work.ghdl_gate93 port map (a, b, y);

  process
    variable l : line;
    variable i : natural;
    variable av, bv : std_logic;
  begin
    for i in 0 to 3 loop
      if i < 2 then av := '0'; else av := '1'; end if;
      if i mod 2 = 0 then bv := '0'; else bv := '1'; end if;
      a <= av;
      b <= bv;
      wait for 1 ns;
      write(l, string'("a="));
      write(l, bit_int(av));
      write(l, string'(" b="));
      write(l, bit_int(bv));
      write(l, string'(" y="));
      write(l, bit_int(y));
      writeline(output, l);
    end loop;
    write(l, string'("std93 case done"));
    writeline(output, l);
    run <= false;
    wait;
  end process;
end architecture;