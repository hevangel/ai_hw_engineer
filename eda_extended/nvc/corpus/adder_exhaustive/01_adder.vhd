library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adder8 is
  port (a, b : in unsigned(7 downto 0);
        cin  : in std_logic;
        sum  : out unsigned(7 downto 0);
        cout : out std_logic);
end entity;

architecture rtl of adder8 is
  signal wide : unsigned(8 downto 0);
begin
  wide <= ('0' & a) + ('0' & b) + (to_unsigned(0, 8) & cin);
  sum  <= wide(7 downto 0);
  cout <= wide(8);
end architecture;
