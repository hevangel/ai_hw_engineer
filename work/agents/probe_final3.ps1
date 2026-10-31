$u = 'https://en.wikipedia.org/wiki/List_of_7400-series_integrated_circuits'
$t = (Invoke-WebRequest -Uri $u -TimeoutSec 60 -UseBasicParsing).Content
foreach ($n in @('16377','16826','16828')) {
    "$n occurrences in list: $([regex]::Matches($t, [regex]::Escape($n)).Count)"
}

"---- Nexperia with browser UA ----"
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
foreach ($pn in @('74ABT16377A','74ABT16826A','74ABT16828A','74ABT16827A','74ABT16240A')) {
    $url = "https://assets.nexperia.com/documents/data-sheet/$pn.pdf"
    try {
        $r = Invoke-WebRequest -Uri $url -MaximumRedirection 5 -TimeoutSec 40 -UserAgent $ua -ErrorAction Stop
        "{0,-14} -> {1} {2} len={3}" -f $pn, $r.StatusCode, $r.Headers['Content-Type'], $r.RawContentLength
    } catch {
        "{0,-14} -> ERR {1}" -f $pn, $_.Exception.Response.StatusCode.value__
    }
    Start-Sleep -Milliseconds 300
}
