library ieee;
use ieee.std_logic_1164.all;

-- Chain of N inverting stages built with a for-generate; N is a generic.
entity inv_chain is
  generic (N : positive);
  port (d : in std_logic; q : out std_logic);
end entity;

architecture rtl of inv_chain is
  signal link : std_logic_vector(0 to N);
begin
  link(0) <= d;
  gen : for i in 0 to N - 1 generate
    link(i + 1) <= not link(i);
  end generate;
  q <= link(N);
end architecture;
