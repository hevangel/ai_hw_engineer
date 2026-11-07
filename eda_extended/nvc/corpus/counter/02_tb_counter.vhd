library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_counter is
end entity;

architecture sim of tb_counter is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal en  : std_logic := '0';
  signal q   : unsigned(3 downto 0);
begin
  dut : entity work.counter generic map (WIDTH => 4) port map (clk => clk, rst => rst, en => en, q => q);

  clk <= not clk after 5 ns;

  stim : process
    variable l : line;
    procedure tick(n : natural) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
        wait for 1 ns;
        write(l, string'("t=")); write(l, now / 1 ns); write(l, string'(" rst=")); write(l, std_logic'image(rst)(2));
        write(l, string'(" en=")); write(l, std_logic'image(en)(2));
        write(l, string'(" q=")); write(l, to_integer(q));
        writeline(output, l);
      end loop;
    end procedure;
  begin
    tick(2);
    rst <= '0';
    en <= '1';
    tick(18);
    en <= '0';
    tick(2);
    rst <= '1';
    tick(1);
    write(l, string'("COUNTER DONE")); writeline(output, l);
    finish;
  end process;
end architecture;
