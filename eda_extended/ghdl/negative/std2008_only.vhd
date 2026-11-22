-- VHDL-2008-only syntax: an "all"-sensitized process.
-- Must be rejected by --std=93 and accepted by --std=08.
library ieee;
use ieee.std_logic_1164.all;

entity std2008_only is
end entity;

architecture rtl of std2008_only is
  signal clk : std_logic := '0';
begin
  -- An all-sensitized process reads every signal it references, so clk is
  -- implicitly in the sensitivity list and no wait statement is allowed.
  p : process (all)
  begin
    if rising_edge(clk) then
      report "clock edge";
    end if;
  end process;
end architecture;