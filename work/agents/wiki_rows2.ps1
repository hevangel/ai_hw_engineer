$u = 'https://en.wikipedia.org/wiki/List_of_7400-series_integrated_circuits'
$r = Invoke-WebRequest -Uri $u -TimeoutSec 60 -UseBasicParsing
$t = $r.Content
foreach ($n in @('16377','16826','16828','16240','16821')) {
    $m = [regex]::Match($t, "(?is)<tr[^>]*>(?:(?!</tr>).)*?\b$n\b(?:(?!</tr>).)*?</tr>")
    if ($m.Success) {
        $row = $m.Value -replace '(?s)<[^>]+>', ' ' -replace '&nbsp;', ' ' -replace '\s+', ' '
        "=== $n ===`n$($row.Trim())`n"
    } else {
        "=== $n === NOT FOUND AS TABLE ROW"
    }
}
