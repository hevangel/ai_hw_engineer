$candidates = @(
  'https://www.ti.com/lit/gpn/sn74abt16377a',
  'https://www.ti.com/lit/gpn/sn54abt16377',
  'https://www.ti.com/lit/gpn/sn74abt16826a',
  'https://www.ti.com/lit/gpn/sn74abt16828a',
  'https://assets.nexperia.com/documents/data-sheet/74ABT16377A.pdf',
  'https://assets.nexperia.com/documents/data-sheet/74ABT16826A.pdf',
  'https://assets.nexperia.com/documents/data-sheet/74ABT16828A.pdf',
  'https://assets.nexperia.com/documents/data-sheet/74ABT16827A.pdf'
)
foreach ($u in $candidates) {
    try {
        $r = Invoke-WebRequest -Uri $u -Method Head -MaximumRedirection 5 -TimeoutSec 30 -ErrorAction Stop
        "{0} -> {1} {2}" -f $u, $r.StatusCode, $r.Headers['Content-Type']
    } catch {
        "{0} -> ERR {1}" -f $u, $_.Exception.Response.StatusCode.value__
    }
    Start-Sleep -Milliseconds 250
}
