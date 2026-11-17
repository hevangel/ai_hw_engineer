-- severity failure: the simulation must stop and the process must exit nonzero.
entity assert_failure is
end entity;

architecture sim of assert_failure is
begin
  process
  begin
    report "intentional failure" severity failure;
    report "AFTER FAILURE";
    wait;
  end process;
end architecture;