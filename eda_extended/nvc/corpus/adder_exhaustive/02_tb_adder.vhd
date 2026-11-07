library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_adder is
end entity;

architecture sim of tb_adder is
  signal a, b, sum : unsigned(7 downto 0);
  signal cin, cout : std_logic;
begin
  dut : entity work.adder8 port map (a => a, b => b, cin => cin, sum => sum, cout => cout);

  process
    variable l : line;
    variable checks, mismatches : natural := 0;
    variable expect : natural;
  begin
    for x in 0 to 255 loop
      for y in 0 to 255 loop
        for c in 0 to 1 loop
          a <= to_unsigned(x, 8);
          b <= to_unsigned(y, 8);
          if c = 1 then cin <= '1'; else cin <= '0'; end if;
          wait for 1 ns;
          expect := x + y + c;
          checks := checks + 1;
          if to_integer(sum) /= expect mod 256 or (cout = '1') /= (expect >= 256) then
            mismatches := mismatches + 1;
          end if;
        end loop;
      end loop;
    end loop;
    write(l, string'("ADDER checks=")); write(l, checks);
    write(l, string'(" mismatches=")); write(l, mismatches);
    writeline(output, l);
    assert mismatches = 0 report "adder mismatches" severity failure;
    wait;
  end process;
end architecture;
