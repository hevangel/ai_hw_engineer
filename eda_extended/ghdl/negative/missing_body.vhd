-- Deliberately missing the architecture body: analysis succeeds but
-- elaboration of a top that instantiates it must fail.
library ieee;
use ieee.std_logic_1164.all;

entity missing_body is
  port (a : in std_logic; y : out std_logic);
end entity;