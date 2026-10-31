$image = 'ai-hw-engineer:latest'
$mount = 'B:\ai_hw_engineer:/workspace'
$base = 'xezim --simulate --max-time 500ms -s tb_ttl_74x679 src/ttl_74x679.sv tb/tb_ttl_74x679.sv 2>&1 | grep -E "Fatal|PASS:" | tail -2'

$cases = @(
    @{ label = 'XEZIM_NO_CACHE=1';            env = @('-e','XEZIM_NO_CACHE=1'); cmd = "cd design/ttl_74xx && $base" },
    @{ label = 'no --sv2017 flag';            env = @();                       cmd = "cd design/ttl_74xx && $base" },
    @{ label = 'XEZIM_X_WARN=1 (X tracing)';  env = @('-e','XEZIM_X_WARN=1','-e','XEZIM_X_WARN_LIMIT=5'); cmd = "cd design/ttl_74xx && $base" }
)

foreach ($c in $cases) {
    "=== $($c.label) ==="
    $args = @('run','--rm') + $c.env + @('-v',$mount,'-w','/workspace',$image,'sh','-c',$c.cmd)
    & docker @args
    ""
}
