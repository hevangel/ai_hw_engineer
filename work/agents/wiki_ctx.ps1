$u = 'https://en.wikipedia.org/wiki/List_of_7400-series_integrated_circuits'
$t = (Invoke-WebRequest -Uri $u -TimeoutSec 60 -UseBasicParsing).Content
foreach ($n in @('16377','16826','16828')) {
    $i = $t.IndexOf($n)
    $start = [Math]::Max(0, $i - 400)
    $window = $t.Substring($start, [Math]::Min(900, $t.Length - $start))
    $text = $window -replace '(?s)<[^>]+>', ' ' -replace '&nbsp;', ' ' -replace '\s+', ' '
    "=== $n ==="
    $text.Trim()
    ""
}
