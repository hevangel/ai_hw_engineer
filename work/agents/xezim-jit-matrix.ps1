$image = 'ai-hw-engineer:latest'
$mount = 'B:\ai_hw_engineer:/workspace'
$tb = 'cd design/ttl_74xx && xezim --simulate --sv2017 --error-exit --max-time 500ms -s tb_ttl_74x679 src/ttl_74x679.sv tb/tb_ttl_74x679.sv 2>&1 | grep -E "Fatal|PASS:" | tail -2'

$settings = @(
    @{ label = 'default (no env)'; env = @() },
    @{ label = 'XEZIM_JIT=0';      env = @('-e','XEZIM_JIT=0') },
    @{ label = 'XEZIM_JIT=1';      env = @('-e','XEZIM_JIT=1') },
    @{ label = 'XEZIM_TS_JIT=0';   env = @('-e','XEZIM_TS_JIT=0') },
    @{ label = 'XEZIM_JIT=0 + TS_JIT=0'; env = @('-e','XEZIM_JIT=0','-e','XEZIM_TS_JIT=0') }
)

foreach ($s in $settings) {
    "=== $($s.label) ==="
    $args = @('run','--rm') + $s.env + @('-v',$mount,'-w','/workspace',$image,'sh','-c',$tb)
    & docker @args
    ""
}
