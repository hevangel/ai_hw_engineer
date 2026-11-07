library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

entity tb_gate93 is
end entity;

architecture sim of tb_gate93 is
  signal a, b, y : std_logic;
begin
  y <= a nand b;
  process
    variable l : line;
  begin
    for i in 0 to 3 loop
      if i mod 2 = 1 then a <= '1'; else a <= '0'; end if;
      if i / 2 = 1 then b <= '1'; else b <= '0'; end if;
      wait for 1 ns;
      write(l, string'("nand "));
      write(l, std_logic'image(a)(2));
      write(l, std_logic'image(b)(2));
      write(l, string'("="));
      write(l, std_logic'image(y)(2));
      writeline(output, l);
    end loop;
    wait;
  end process;
end architecture;
