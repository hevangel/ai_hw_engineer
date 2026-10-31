$candidates = @(
  'sn74116','sn74ls116','sn74ls116a',
  'sn74119','sn74ls119',
  'sn74418','sn74ls418','sn74s418',
  'sn74515','sn74ls515','sn74als515',
  'sn74743','sn74ls743','sn74s743'
)
foreach ($pn in $candidates) {
    $u = "https://www.ti.com/lit/gpn/$pn"
    try {
        $r = Invoke-WebRequest -Uri $u -Method Head -MaximumRedirection 5 -TimeoutSec 30 -ErrorAction Stop
        "{0,-14} -> {1} {2}" -f $pn, $r.StatusCode, $r.Headers['Content-Type']
    } catch {
        "{0,-14} -> ERR {1}" -f $pn, $_.Exception.Response.StatusCode.value__
    }
    Start-Sleep -Milliseconds 250
}
