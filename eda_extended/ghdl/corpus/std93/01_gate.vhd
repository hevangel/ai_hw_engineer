-- GHDL VHDL-93 case: analysed and run with --std=93.
--
-- Exercises constructs that must be rejected by a VHDL-2008-only reading and
-- accepted here: a process with an explicit sensitivity list, `std_logic_arith`
-- is deliberately avoided in favour of `numeric_std`, and no VHDL-2008-only
-- syntax is used.
--
-- The expected output is derived by hand from the gate function's truth table
-- and is stated in expected.txt.
library ieee;
use ieee.std_logic_1164.all;

entity ghdl_gate93 is
  port (
    a : in  std_logic;
    b : in  std_logic;
    y : out std_logic
  );
end entity;

architecture rtl of ghdl_gate93 is
begin
  -- Explicit sensitivity list: legal in every standard, and a useful check
    -- that the analyser is not silently accepting VHDL-2008 `process (all)`.
  process (a, b)
  begin
    y <= a xor b;
  end process;
end architecture;