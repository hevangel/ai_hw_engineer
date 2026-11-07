library ieee;
use ieee.std_logic_1164.all;

package crc8_pkg is
  -- CRC-8, polynomial x^8 + x^2 + x + 1 (0x07), initial value 0, no reflection.
  function crc8_update(crc : std_logic_vector(7 downto 0); data : std_logic_vector(7 downto 0)) return std_logic_vector;
end package;

package body crc8_pkg is
  function crc8_update(crc : std_logic_vector(7 downto 0); data : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable c : std_logic_vector(7 downto 0) := crc xor data;
  begin
    for i in 0 to 7 loop
      if c(7) = '1' then
        c := (c(6 downto 0) & '0') xor x"07";
      else
        c := c(6 downto 0) & '0';
      end if;
    end loop;
    return c;
  end function;
end package body;
