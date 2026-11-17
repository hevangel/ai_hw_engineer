-- Deliberately malformed: the port clause is never closed.
entity broken is
  port (
    a : in std_logic
architecture x of broken is
begin
end architecture;