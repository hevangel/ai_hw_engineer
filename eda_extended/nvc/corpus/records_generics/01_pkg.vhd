package shapes is
  type point is record
    x, y : integer;
  end record;
  type point_array is array (natural range <>) of point;
  function manhattan(a, b : point) return natural;

  type tally_t is protected
    procedure add(n : integer);
    impure function total return integer;
  end protected;
end package;

package body shapes is
  function manhattan(a, b : point) return natural is
  begin
    return abs (a.x - b.x) + abs (a.y - b.y);
  end function;

  type tally_t is protected body
    variable sum : integer := 0;
    procedure add(n : integer) is begin sum := sum + n; end procedure;
    impure function total return integer is begin return sum; end function;
  end protected body;
end package body;
