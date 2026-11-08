entity assert_failure is
end entity;

architecture sim of assert_failure is
begin
  process
  begin
    report "before failure";
    assert false report "intentional failure" severity failure;
    report "after failure";
    wait;
  end process;
end architecture;
