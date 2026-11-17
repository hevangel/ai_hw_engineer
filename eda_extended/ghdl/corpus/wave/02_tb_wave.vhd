-- Testbench for the GHDL waveform case.
--
-- The schedule is fixed below: reset is held for two rising edges, then
-- released, and the counter is sampled after every rising edge from then on.
-- The expected trace in expected.txt is derived by hand from that schedule.
--
-- std.textio keeps the output plain text, so expected.txt is independent of
-- the tool that prints it. This case is VHDL-2008, so std.env.finish is
-- available and ends the run cleanly.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_wave is
end entity;

architecture sim of tb_wave is
  constant WIDTH : natural := 4;
  constant PERIOD : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal q   : unsigned(WIDTH - 1 downto 0) := (others => '0');
begin

  clk <= not clk after PERIOD / 2;

  dut : entity work.ghdl_counter
    generic map (WIDTH => WIDTH)
    port map (clk => clk, rst => rst, q => q);

  process
    variable l : line;
    variable n : natural := 0;
  begin
    -- Two rising edges with reset asserted (t = 5 ns and 15 ns).
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';

    for n in 1 to 6 loop
      wait until rising_edge(clk);
      -- Sample one delta after the edge so the registered update is visible.
      wait for 1 ns;
      write(l, string'("q="));
      write(l, to_integer(q));
      writeline(output, l);
    end loop;

    write(l, string'("wave case done"));
    writeline(output, l);
    finish;
  end process;
end architecture;