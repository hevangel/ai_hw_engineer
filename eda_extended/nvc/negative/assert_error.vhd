entity assert_error is
end entity;

architecture sim of assert_error is
begin
  process
  begin
    assert false report "intentional error" severity error;
    report "after error";
    wait;
  end process;
end architecture;
