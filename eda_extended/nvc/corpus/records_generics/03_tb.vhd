library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use work.shapes.all;

entity tb_records is
end entity;

architecture sim of tb_records is
  signal d, q3, q4 : std_logic := '0';
begin
  u3 : entity work.inv_chain generic map (N => 3) port map (d, q3);
  u4 : entity work.inv_chain generic map (N => 4) port map (d, q4);

  process
    variable l : line;
    constant pts : point_array(0 to 3) := ((0, 0), (3, 4), (-2, 5), (7, -1));
    variable tally : tally_t;
  begin
    for i in pts'range loop
      for j in i + 1 to pts'high loop
        tally.add(manhattan(pts(i), pts(j)));
        write(l, string'("d(")); write(l, i); write(l, string'(",")); write(l, j);
        write(l, string'(")=")); write(l, manhattan(pts(i), pts(j)));
        writeline(output, l);
      end loop;
    end loop;
    write(l, string'("total=")); write(l, tally.total); writeline(output, l);
    d <= '1';
    wait for 1 ns;
    write(l, string'("inv3=")); write(l, std_logic'image(q3)(2));
    write(l, string'(" inv4=")); write(l, std_logic'image(q4)(2));
    writeline(output, l);
    wait;
  end process;
end architecture;
