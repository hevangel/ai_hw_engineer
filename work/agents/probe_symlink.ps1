$candidates = @(
  'https://www.ti.com/lit/ds/symlink/sn74116.pdf',
  'https://www.ti.com/lit/ds/symlink/sn74ls116.pdf',
  'https://www.ti.com/lit/ds/symlink/sn74119.pdf',
  'https://www.ti.com/lit/ds/symlink/sn74als743.pdf',
  'https://www.ti.com/lit/ds/symlink/sn74hct515.pdf',
  'https://www.ti.com/lit/ds/symlink/sn74abt16377.pdf',
  'https://www.ti.com/lit/ds/symlink/sn74abt16826.pdf',
  'https://www.ti.com/lit/ds/symlink/sn74abt16828.pdf'
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
