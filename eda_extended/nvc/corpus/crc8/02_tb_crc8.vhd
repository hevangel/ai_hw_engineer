library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use work.crc8_pkg.all;

entity tb_crc8 is
end entity;

architecture sim of tb_crc8 is
begin
  process
    type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);
    constant msg1 : byte_array := (x"31", x"32", x"33", x"34", x"35", x"36", x"37", x"38", x"39");
    constant msg2 : byte_array := (x"00", x"FF", x"A5", x"5A", x"01", x"80");
    variable crc : std_logic_vector(7 downto 0);
    variable l : line;
  begin
    crc := x"00";
    for i in msg1'range loop crc := crc8_update(crc, msg1(i)); end loop;
    write(l, string'("crc8(123456789)=")); hwrite(l, crc); writeline(output, l);
    crc := x"00";
    for i in msg2'range loop crc := crc8_update(crc, msg2(i)); end loop;
    write(l, string'("crc8(00FFA55A0180)=")); hwrite(l, crc); writeline(output, l);
    crc := x"00";
    for b in 0 to 255 loop
      crc := crc8_update(crc, std_logic_vector(to_unsigned(b, 8)));
    end loop;
    write(l, string'("crc8(00..FF)=")); hwrite(l, crc); writeline(output, l);
    wait;
  end process;
end architecture;
