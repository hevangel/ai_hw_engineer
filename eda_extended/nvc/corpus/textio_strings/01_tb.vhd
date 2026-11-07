use std.textio.all;

entity tb_strings is
end entity;

architecture sim of tb_strings is
begin
  process
    variable l : line;
    constant s : string := "extended eda";
    variable t : time := 12 ns + 500 ps;
  begin
    write(l, string'("len=")); write(l, s'length); writeline(output, l);
    write(l, string'("slice=")); write(l, s(1 to 8)); writeline(output, l);
    write(l, string'("image=")); write(l, integer'image(-42)); writeline(output, l);
    write(l, string'("pos=")); write(l, character'pos('A')); writeline(output, l);
    write(l, string'("bool=")); write(l, boolean'image(s'length > 10)); writeline(output, l);
    write(l, string'("tostr=")); write(l, to_string(2 ** 10)); writeline(output, l);
    write(l, string'("time_ps=")); write(l, t / 1 ps); writeline(output, l);
    write(l, string'("upper=")); write(l, to_string(s'high)); writeline(output, l);
    wait;
  end process;
end architecture;
