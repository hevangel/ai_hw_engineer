-- process (all) is VHDL-2008: it analyses with --std=08 and must be rejected with --std=93.
entity std2008_only is
end entity;

architecture sim of std2008_only is
  signal a, b : bit;
begin
  process (all)
  begin
    b <= not a;
  end process;
end architecture;
