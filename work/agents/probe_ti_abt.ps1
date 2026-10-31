$digits = @('16240','16244','16245','16373','16374','16377','16540','16541',
            '16543','16623','16640','16821','16823','16825','16826','16827',
            '16828','16841','16843')
foreach ($d in $digits) {
    $found = @()
    foreach ($suffix in @('', 'a')) {
        $pn = "sn74abt$d$suffix"
        $u = "https://www.ti.com/lit/gpn/$pn"
        try {
            $r = Invoke-WebRequest -Uri $u -Method Head -MaximumRedirection 5 -TimeoutSec 30 -ErrorAction Stop
            if ($r.StatusCode -eq 200) { $found += $pn }
        } catch { }
        Start-Sleep -Milliseconds 250
    }
    "{0,-8} -> {1}" -f $d, ($(if ($found.Count) { $found -join ', ' } else { 'NONE' }))
}
