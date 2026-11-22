-- GHDL waveform case: a clocked counter with an independent expected trace.
--
-- Expected output comes from the arithmetic of the design itself (a free
-- running 4-bit counter) and is stated in expected.txt by hand from the
-- schedule in the testbench; it is not produced by a model of this VHDL.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ghdl_counter is
  generic (WIDTH : natural := 4);
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    q   : out unsigned(WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of ghdl_counter is
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        q <= (others => '0');
      else
        q <= q + 1;
      end if;
    end if;
  end process;
end architecture;