entity top_missing is
end entity;

architecture sim of top_missing is
  signal s : bit;
begin
  u : entity work.not_defined port map (s);
end architecture;
