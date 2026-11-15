# JSON-RPC 2.0 stdio MCP server for Delpher (Koninklijke Bibliotheek, National Library of the Netherlands)
# Search:    KB SRU 1.2 service https://jsru.kb.nl/sru/sru (no key)
# Full text: KB resolver https://resolver.kb.nl/resolve?urn=<id>:ocr
# Works with Windows PowerShell 5.1 and PowerShell 7.
# License: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

$sruBase = "https://jsru.kb.nl/sru/sru?version=1.2&operation=searchRetrieve"
$resolver = "https://resolver.kb.nl/resolve?urn="
$userAgent = "dutch-cultural-heritage-collections-mcp/0.3 (+https://github.com/maikell/dutch-cultural-heritage-collections)"
$maxText = 15000

# Delpher collections: SRU collection, record schema, Delpher web path and coll code
$collections = @{
    newspapers      = @{ sru = "DDD_artikel";  schema = "ddd"; path = "kranten";        coll = "ddd";    label = "newspaper articles (1618-1995)" }
    magazines       = @{ sru = "DTS_document"; schema = $null; path = "tijdschriften";  coll = "dts";    label = "magazines" }
    books           = @{ sru = "BOEKEN_boek";  schema = $null; path = "boeken";         coll = "boeken"; label = "books" }
    radio_bulletins = @{ sru = "ANP";          schema = $null; path = "radiobulletins"; coll = "anp";    label = "ANP radio bulletins (1937-1984)" }
}
$collectionNames = "newspapers, magazines, books, radio_bulletins"
$itemTypes = @{ article = "artikel"; advertisement = "advertentie"; family_notice = "familiebericht"; illustration = '"illustratie met onderschrift"' }
$idPattern = '^[A-Za-z0-9]{2,20}(:[A-Za-z0-9]{1,20}){1,6}$'
$titlePattern = '^[\p{L}\p{N}][\p{L}\p{N} .,''&()-]{0,99}$'

function Fail($message) { throw [System.ArgumentException]::new($message) }

function Get-Text($url) {
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Headers.Add("User-Agent", $userAgent)
    return $wc.DownloadString($url)
}

function Send-Response($id, $result, $err) {
    $resp = [ordered]@{ jsonrpc = "2.0"; id = $id }
    if ($err) { $resp["error"] = $err } else { $resp["result"] = $result }
    [Console]::WriteLine(($resp | ConvertTo-Json -Depth 12 -Compress))
}
function Send-Text($id, $text) { Send-Response $id @{ content = @(@{ type = "text"; text = $text }) } $null }

function Get-Int($value, $default, $min, $max, $label) {
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { return $default }
    $n = 0
    if (-not [int]::TryParse([string]$value, [ref]$n) -or $n -lt $min) { Fail "Invalid value for ${label}: expected a whole number of at least $min." }
    return [Math]::Min($n, $max)
}

function Get-Collection($value) {
    $key = if ($value) { ([string]$value).Trim().ToLower() } else { "newspapers" }
    if (-not $collections.ContainsKey($key)) { Fail "Unknown collection '$key'. Choose from: $collectionNames." }
    $c = $collections[$key].Clone(); $c["name"] = $key
    return $c
}

# Delpher query syntax is CQL: words, "exact phrase", AND, OR, NOT, brackets
function Get-Query($value) {
    $s = ([string]$value).Trim()
    if ($s.Length -lt 1 -or $s.Length -gt 300) { Fail "Query must be 1 to 300 characters." }
    if ($s -match '[\\<>{}]') { Fail "Query contains invalid characters." }
    if ((($s.ToCharArray() | Where-Object { $_ -eq '"' }) | Measure-Object).Count % 2 -ne 0) { Fail "Query has an odd number of quotation marks." }
    if ($s -match '(?i)\bsortBy\b') { Fail "Use the 'sort' field instead of sortBy." }
    return $s
}

# Accept YYYY, YYYY-MM or YYYY-MM-DD; returns DD-MM-YYYY as the KB service expects
function ConvertTo-KbDate($value, $isEnd) {
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { return $null }
    $s = ([string]$value).Trim()
    if ($s -match '^(\d{4})$') { $y = [int]$Matches[1]; if ($isEnd) { return "31-12-$y" } else { return "01-01-$y" } }
    if ($s -match '^(\d{4})-(\d{2})$') {
        $y = [int]$Matches[1]; $m = [int]$Matches[2]
        if ($m -lt 1 -or $m -gt 12) { Fail "Invalid month in date '$s'." }
        $d = if ($isEnd) { [DateTime]::DaysInMonth($y, $m) } else { 1 }
        return ("{0:D2}-{1:D2}-{2}" -f $d, $m, $y)
    }
    if ($s -match '^(\d{4})-(\d{2})-(\d{2})$') {
        $dt = [DateTime]::MinValue
        if (-not [DateTime]::TryParseExact($s, "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$dt)) { Fail "Invalid date '$s'." }
        return $dt.ToString("dd-MM-yyyy")
    }
    Fail "Invalid date '$s': use YYYY, YYYY-MM or YYYY-MM-DD."
}

function Get-Node($el, $name) {
    $n = $el.SelectSingleNode("*[local-name()='$name']")
    if ($n) { return $n.InnerText.Trim() } else { return $null }
}
function Get-Nodes($el, $name) {
    $out = @()
    foreach ($n in $el.SelectNodes("*[local-name()='$name']")) { $t = $n.InnerText.Trim(); if ($t -and ($out -notcontains $t)) { $out += $t } }
    return $out
}

function Invoke-Sru($coll, $cql, $max, $start) {
    $url = "$sruBase&x-collection=$($coll.sru)&maximumRecords=$max&startRecord=$start&query=" + [uri]::EscapeDataString($cql)
    if ($coll.schema) { $url += "&recordSchema=$($coll.schema)" }
    [xml]$doc = Get-Text $url
    $diag = $doc.SelectSingleNode("//*[local-name()='diagnostic']/*[local-name()='message']")
    if ($diag) { throw "Delpher search service: $($diag.InnerText)" }
    return $doc
}

# Normalise dates like "1989/09/12 00:00:00", "1915-01-01" or "[1948]" to YYYY-MM-DD / as given
function Format-Date($s) {
    if (-not $s) { return $null }
    if ($s -match '^(\d{4})[/-](\d{2})[/-](\d{2})') { return "$($Matches[1])-$($Matches[2])-$($Matches[3])" }
    return $s
}

function Get-DelpherLink($coll, $id) {
    return "https://www.delpher.nl/nl/$($coll.path)/view?coll=$($coll.coll)&identifier=" + [uri]::EscapeDataString($id).Replace("%3A", ":")
}

function ConvertTo-Record($coll, $r) {
    $ident = Get-Node $r "identifier"
    if ($coll.name -eq "newspapers") {
        $id = Get-Node $r "metadataKey"
        if (-not $id -and $ident -match 'urn=([^&]+?)(:ocr)?$') { $id = $Matches[1] }
        $rec = [ordered]@{
            id = $id; title = Get-Node $r "title"; newspaper = Get-Node $r "papertitle"; date = Format-Date (Get-Node $r "date")
            type = Get-Node $r "type"; edition = Get-Node $r "edition"; place = Get-Node $r "spatialCreation"; distribution = Get-Node $r "spatial"
            freely_accessible = ((Get-Node $r "accessible") -eq "1")
        }
    }
    elseif ($coll.name -eq "radio_bulletins") {
        $id = $null; if ($ident -match 'urn=([^&]+)$') { $id = $Matches[1] }
        $rec = [ordered]@{ id = $id; title = Get-Node $r "title"; date = Format-Date (Get-Node $r "date") }
    }
    else {
        $id = Get-Node $r "recordIdentifier"
        if ($coll.name -eq "books" -or -not $id -or $id -match '^http') { if ($ident -match 'urn=([^&]+)$') { $id = $Matches[1] } }
        $rec = [ordered]@{
            id = $id; title = Get-Node $r "title"; date = Format-Date (Get-Node $r "date"); type = Get-Node $r "type"
            creators = @(@(Get-Nodes $r "creator") + @(Get-Nodes $r "contributor") | Select-Object -First 5)
            publisher = Get-Node $r "publisher"; place = Get-Node $r "publisherSpatial"; extent = Get-Node $r "extent"
            subjects = @(Get-Nodes $r "subject" | Where-Object { $_ -notmatch '^\d' } | Select-Object -First 6)
        }
    }
    $rec["delpher_url"] = if ($rec.id) { Get-DelpherLink $coll $rec.id } else { $null }
    return $rec
}

function Get-Filters($coll, $a) {
    $clauses = @("(" + (Get-Query $a.query) + ")")
    $from = ConvertTo-KbDate $a.from $false
    $to = ConvertTo-KbDate $a.to $true
    if ($from -and $to) { $clauses += "date within ""$from $to""" }
    elseif ($from) { $clauses += "date >= ""$from""" }
    elseif ($to) { $clauses += "date <= ""$to""" }
    if ($a.newspaper) {
        if ($coll.name -ne "newspapers") { Fail "The 'newspaper' filter only works in the newspapers collection." }
        $k = ([string]$a.newspaper).Trim()
        if ($k -notmatch $titlePattern) { Fail "Invalid newspaper title." }
        $clauses += "papertitle=""$k"""
    }
    if ($a.type) {
        if ($coll.name -ne "newspapers") { Fail "The 'type' filter only works in the newspapers collection." }
        $s = ([string]$a.type).Trim().ToLower()
        if (-not $itemTypes.ContainsKey($s)) { Fail "Unknown type '$s'. Choose from: article, advertisement, family_notice, illustration." }
        $clauses += "type=$($itemTypes[$s])"
    }
    return ($clauses -join " and ")
}

function Get-OcrText($xmlText) {
    [xml]$doc = $xmlText
    $parts = @()
    foreach ($n in $doc.SelectNodes("//*[local-name()='title' or local-name()='p']")) {
        $t = ($n.InnerText -replace '\s+', ' ').Trim()
        if ($t) { $parts += $t }
    }
    return ($parts -join "`n`n")
}

while ($true) {
    $line = [Console]::ReadLine()
    if ($null -eq $line) { break }
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $id = $null
    try {
        $req = $line | ConvertFrom-Json
        $id = $req.id
        switch ($req.method) {
            "initialize" {
                Send-Response $id @{ protocolVersion = "2024-11-05"; capabilities = @{ tools = @{} }; serverInfo = @{ name = "delpher"; version = "0.2.0" } } $null
            }
            "notifications/initialized" { }
            "ping" { Send-Response $id @{} $null }
            "tools/list" {
                $collProp = @{ type = "string"; enum = @("newspapers", "magazines", "books", "radio_bulletins"); description = "Collection (default newspapers)."; default = "newspapers" }
                $queryProp = @{ type = "string"; description = "Query as on Delpher: words, ""exact phrase"", AND, OR, NOT and brackets. Search terms are matched against Dutch texts, e.g. 'Osdorp AND Sloterplas' or '""Nieuwe Meervaart""'." }
                $typeProp = @{ type = "string"; enum = @("article", "advertisement", "family_notice", "illustration"); description = "Newspapers only: kind of item." }
                $tools = @(
                    @{
                        name = "delpher_search"
                        description = "Search Delpher (Koninklijke Bibliotheek, National Library of the Netherlands): digitised Dutch newspapers (1618-1995), magazines, books and ANP radio bulletins (1937-1984). Returns title, newspaper or publisher, date, id and a Delpher link per hit. Use delpher_text with the id for the full text."
                        inputSchema = @{ type = "object"; properties = @{
                            query = $queryProp
                            collection = $collProp
                            from = @{ type = "string"; description = "Start date: YYYY, YYYY-MM or YYYY-MM-DD." }
                            to = @{ type = "string"; description = "End date: YYYY, YYYY-MM or YYYY-MM-DD." }
                            newspaper = @{ type = "string"; description = "Newspapers only: exact newspaper title, e.g. 'Het Parool', 'De Volkskrant', 'Algemeen Handelsblad'." }
                            type = $typeProp
                            sort = @{ type = "string"; enum = @("relevance", "oldest", "newest"); description = "Order (default relevance)."; default = "relevance" }
                            max = @{ type = "integer"; description = "Number of results (default 10, max 50)."; default = 10 }
                            start = @{ type = "integer"; description = "Position of the first result, for the next page (default 1)."; default = 1 }
                        }; required = @("query") }
                    },
                    @{
                        name = "delpher_text"
                        description = "Get the full OCR text of a Delpher item, using the id from delpher_search. Newspapers and radio bulletins: the whole item. Books and magazines: one scanned page at a time (parameter page). OCR may contain reading errors; check quotes against the scan via the Delpher link."
                        inputSchema = @{ type = "object"; properties = @{
                            id = @{ type = "string"; description = "Id from delpher_search, e.g. ABCDDD:010846211:mpeg21:a0137, anp:1949:07:12:59:mpeg21 or MMKB45:254398000." }
                            collection = $collProp
                            page = @{ type = "integer"; description = "Books and magazines only: page number of the scan (default 1)."; default = 1 }
                        }; required = @("id") }
                    },
                    @{
                        name = "delpher_timeline"
                        description = "Count how often a query occurs in Delpher per year or per decade, to see when a topic appears and fades in the newspapers (or another collection). At most 40 periods per call."
                        inputSchema = @{ type = "object"; properties = @{
                            query = $queryProp
                            collection = $collProp
                            from_year = @{ type = "integer"; description = "First year, e.g. 1900." }
                            to_year = @{ type = "integer"; description = "Last year, e.g. 1995." }
                            step = @{ type = "string"; enum = @("year", "decade"); description = "Per year or per decade (default decade)."; default = "decade" }
                            newspaper = @{ type = "string"; description = "Newspapers only: exact newspaper title." }
                            type = $typeProp
                        }; required = @("query", "from_year", "to_year") }
                    }
                )
                Send-Response $id @{ tools = $tools } $null
            }
            "tools/call" {
                $toolName = $req.params.name
                $a = $req.params.arguments
                if ($null -eq $a) { $a = New-Object PSObject }

                if ($toolName -eq "delpher_search") {
                    $coll = Get-Collection $a.collection
                    $cql = Get-Filters $coll $a
                    $sort = if ($a.sort) { ([string]$a.sort).ToLower() } else { "relevance" }
                    if ($sort -eq "oldest") { $cql += " sortBy dc.date/sort.ascending" }
                    elseif ($sort -eq "newest") { $cql += " sortBy dc.date/sort.descending" }
                    elseif ($sort -ne "relevance") { Fail "Sort: choose relevance, oldest or newest." }
                    $max = Get-Int $a.max 10 1 50 "max"
                    $start = Get-Int $a.start 1 1 100000 "start"
                    $doc = Invoke-Sru $coll $cql $max $start
                    $total = [int]$doc.SelectSingleNode("//*[local-name()='numberOfRecords']").InnerText
                    $recs = @()
                    foreach ($r in $doc.SelectNodes("//*[local-name()='recordData']")) { $recs += (ConvertTo-Record $coll $r) }
                    $next = $doc.SelectSingleNode("//*[local-name()='nextRecordPosition']")
                    $out = [ordered]@{ collection = $coll.label; cql = $cql; total = $total; shown = $recs.Count; start = $start }
                    if ($next) { $out["next_start"] = [int]$next.InnerText }
                    $out["results"] = @($recs)
                    if ($coll.name -ne "newspapers") { $out["note"] = "The KB search service does not hold everything delpher.nl shows for this collection; counts may be lower than on the website." }
                    Send-Text $id ($out | ConvertTo-Json -Depth 6)
                }
                elseif ($toolName -eq "delpher_text") {
                    $coll = Get-Collection $a.collection
                    $oid = ([string]$a.id).Trim()
                    if ($oid -notmatch $idPattern) { Fail "Invalid id. Use the id from delpher_search." }
                    $urn = $null; $extra = [ordered]@{}
                    switch ($coll.name) {
                        "newspapers" {
                            if ($oid -notmatch ':a\d+$') { Fail "Give the id of an article (ending in :a plus a number), e.g. ABCDDD:010846211:mpeg21:a0137." }
                            $urn = "${oid}:ocr"
                        }
                        "radio_bulletins" { if ($oid -notmatch ':mpeg21$') { $oid = "${oid}:mpeg21" }; $urn = "${oid}:ocr" }
                        { $_ -in @("books", "magazines") } {
                            $p = Get-Int $a.page 1 1 99999 "page"
                            $base = $oid -replace ':mpeg21$', ''
                            $urn = ("{0}:{1:D5}:ocr" -f $base, $p); $extra["page"] = $p
                        }
                    }
                    $text = $null
                    try { $text = Get-OcrText (Get-Text ($resolver + $urn)) }
                    catch {
                        $msg = $_.Exception.Message
                        if ($msg -match '403') { throw "This text is not freely available (often because of copyright); read it on Delpher or in the KB reading room." }
                        if ($msg -match '404') { throw "No text found for this id (check the collection and page number)." }
                        throw
                    }
                    $truncated = $false
                    if ($text.Length -gt $maxText) { $text = $text.Substring(0, $maxText); $truncated = $true }
                    $out = [ordered]@{ id = $oid; collection = $coll.name }
                    foreach ($k in $extra.Keys) { $out[$k] = $extra[$k] }
                    $out["delpher_url"] = Get-DelpherLink $coll $oid
                    $out["characters"] = $text.Length
                    if ($truncated) { $out["truncated"] = "Text shortened to $maxText characters." }
                    $out["text"] = $text
                    Send-Text $id ($out | ConvertTo-Json -Depth 4)
                }
                elseif ($toolName -eq "delpher_timeline") {
                    $coll = Get-Collection $a.collection
                    $fromYear = Get-Int $a.from_year $null 1400 2100 "from_year"
                    $toYear = Get-Int $a.to_year $null 1400 2100 "to_year"
                    if ($null -eq $fromYear -or $null -eq $toYear) { Fail "Give from_year and to_year." }
                    if ($toYear -lt $fromYear) { Fail "to_year is before from_year." }
                    $step = if ($a.step) { ([string]$a.step).ToLower() } else { "decade" }
                    if ($step -notin @("year", "decade")) { Fail "Step: choose year or decade." }
                    $size = if ($step -eq "year") { 1 } else { 10 }
                    $first = if ($size -eq 10) { [int]([Math]::Floor($fromYear / 10) * 10) } else { $fromYear }
                    $buckets = [Math]::Ceiling(($toYear - $first + 1) / $size)
                    if ($buckets -gt 40) { Fail "Too many periods ($buckets); choose a shorter range or step decade (max 40)." }
                    $base = @{ query = $a.query; newspaper = $a.newspaper; type = $a.type }
                    $rows = @(); $sum = 0
                    for ($y = $first; $y -le $toYear; $y += $size) {
                        $yEnd = [Math]::Min($y + $size - 1, $toYear); $yStart = [Math]::Max($y, $fromYear)
                        $f = New-Object PSObject -Property $base
                        $f | Add-Member -NotePropertyName from -NotePropertyValue "$yStart"
                        $f | Add-Member -NotePropertyName to -NotePropertyValue "$yEnd"
                        $doc = Invoke-Sru $coll (Get-Filters $coll $f) 0 1
                        $n = [int]$doc.SelectSingleNode("//*[local-name()='numberOfRecords']").InnerText
                        $sum += $n
                        $label = if ($size -eq 1) { "$yStart" } else { "$yStart-$yEnd" }
                        $rows += [ordered]@{ period = $label; count = $n }
                    }
                    $out = [ordered]@{ collection = $coll.label; query = [string]$a.query; step = $step; total = $sum; periods = @($rows) }
                    if ($coll.name -eq "newspapers") { $out["note"] = "Counts are absolute hits; not every year has the same number of digitised newspapers (almost nothing after 1995)." }
                    Send-Text $id ($out | ConvertTo-Json -Depth 4)
                }
                else {
                    Send-Response $id $null @{ code = -32601; message = "Tool not found: $toolName" }
                }
            }
            default {
                if ($null -ne $id) { Send-Response $id $null @{ code = -32601; message = "Method not supported: $($req.method)" } }
            }
        }
    }
    catch [System.ArgumentException] {
        if ($null -ne $id) { Send-Response $id $null @{ code = -32602; message = $_.Exception.Message } }
    }
    catch {
        if ($null -ne $id) { Send-Response $id $null @{ code = -32603; message = $_.Exception.Message } }
    }
}
