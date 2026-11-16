# JSON-RPC 2.0 stdio MCP server for the person indexes of the Amsterdam City Archives (Stadsarchief Amsterdam)
# Source: Memorix genealogy service https://webservices.memorix.nl/genealogy, the same service that
# powers https://archief.amsterdam/indexen. The key below is the public key that archief.amsterdam itself
# publishes in its search page; set AMSTERDAM_MEMORIX_KEY to use a key of your own.
# Works with Windows PowerShell 5.1 and PowerShell 7.
# License: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

$base = "https://webservices.memorix.nl/genealogy"
$apiKey = if ($env:AMSTERDAM_MEMORIX_KEY) { $env:AMSTERDAM_MEMORIX_KEY } else { "eb37e65a-eb47-11e9-b95c-60f81db16c0e" }
$userAgent = "dutch-cultural-heritage-collections-mcp/0.4 (+https://github.com/maikell/dutch-cultural-heritage-collections)"
$uuidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
$labelPattern = '^[\p{L}\p{N}][\p{L}\p{N} .,''&()/-]{0,99}$'

function Fail($message) { throw [System.ArgumentException]::new($message) }

function Get-Json($path, $params) {
    $parts = @("apiKey=" + [uri]::EscapeDataString($apiKey))
    foreach ($p in $params) { $parts += ([uri]::EscapeDataString([string]$p[0]) + "=" + [uri]::EscapeDataString([string]$p[1])) }
    $url = "$base/$path`?" + ($parts -join "&")
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Headers.Add("User-Agent", $userAgent)
    $wc.Headers.Add("Accept", "application/json")
    $raw = $wc.DownloadString($url)
    $data = $raw | ConvertFrom-Json
    if ($data.error) { throw "Amsterdam City Archives search service: $($data.error.message)" }
    return $data
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

function Get-Query($value) {
    $s = ([string]$value).Trim()
    if ($s.Length -lt 1 -or $s.Length -gt 200) { Fail "Query must be 1 to 200 characters." }
    if ($s -match '[\\<>{}\[\]:]') { Fail "Query contains invalid characters." }
    if ((($s.ToCharArray() | Where-Object { $_ -eq '"' }) | Measure-Object).Count % 2 -ne 0) { Fail "Query has an odd number of quotation marks." }
    return $s
}

function Get-Label($value, $field) {
    $s = ([string]$value).Trim()
    if ($s -notmatch $labelPattern) { Fail "Invalid value for ${field}." }
    return $s
}

# Clean HTML fragments such as "<br />Overleden: Ja" into plain text
function Get-Plain($s) {
    if (-not $s) { return $null }
    $t = [string]$s -replace '<br\s*/?>', '; ' -replace '<[^>]+>', ' '
    $t = [System.Net.WebUtility]::HtmlDecode($t)
    $t = ($t -replace '\s+', ' ').Trim(' ', ';')
    if ($t) { return $t } else { return $null }
}

# Dates come as YYYY-MM-DD with 00 for unknown parts
function Format-Date($s) {
    if (-not $s) { return $null }
    $t = [string]$s -replace '-00', ''
    return $t
}

# Adds the filter query parameters for source, role, place and period to a parameter list
function Add-Filters($params, $a) {
    if ($a.source) { $v = 'search_s_register_type_title:"' + (Get-Label $a.source "source") + '"'; [void]$params.Add(@("fq[]", $v)) }
    if ($a.role) { $v = 'search_s_type_title:"' + (Get-Label $a.role "role") + '"'; [void]$params.Add(@("fq[]", $v)) }
    if ($a.place) { $v = 'search_s_plaats:"' + (Get-Label $a.place "place") + '"'; [void]$params.Add(@("fq[]", $v)) }
    $from = Get-Int $a.from_year $null 1300 2100 "from_year"
    $to = Get-Int $a.to_year $null 1300 2100 "to_year"
    if ($null -ne $from -or $null -ne $to) {
        if ($null -eq $from) { $from = 1300 }
        if ($null -eq $to) { $to = 2100 }
        if ($to -lt $from) { Fail "to_year is before from_year." }
        $v = "search_i_datum:[{0}0000 TO {1}1231]" -f $from, $to
        [void]$params.Add(@("fq[]", $v))
    }
}

function New-Params($pairs) {
    $list = New-Object System.Collections.ArrayList
    foreach ($p in $pairs) { [void]$list.Add($p) }
    return ,$list
}

function ConvertTo-Person($p) {
    $m = $p.metadata
    $notes = Get-Plain $m.diversen
    $rec = [ordered]@{
        id = $p.id
        record_id = $p.deed_id
        name = $m.person_display_name
        first_name = $m.voornaam
        prefix = $m.tussenvoegsel
        last_name = $m.achternaam
        role = $m.type_title
        source = $m.register_type_title
        record_type = $m.deed_type_title
        date = Format-Date $m.datum
        birth_date = Format-Date $m.datum_geboorte
        place = $m.plaats
    }
    if ($m.leeftijd) { $rec["age"] = $m.leeftijd }
    if ($m.beroep) { $rec["occupation"] = $m.beroep }
    if ($notes) { $rec["notes"] = $notes }
    if ($notes -match '(?i)overleden:\s*ja') { $rec["deceased_reported"] = $true }
    $rec["has_scan"] = ($m.has_assets -eq "deed")
    $rec["url"] = "https://archief.amsterdam/indexen/deeds/$($p.deed_id)"
    return $rec
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
                Send-Response $id @{ protocolVersion = "2024-11-05"; capabilities = @{ tools = @{} }; serverInfo = @{ name = "amsterdam-city-archives"; version = "0.4.0" } } $null
            }
            "notifications/initialized" { }
            "ping" { Send-Response $id @{} $null }
            "tools/list" {
                $queryProp = @{ type = "string"; description = "Name or words to search for, e.g. 'Jan van Leeuwen', 'Leeuwen' or '""Pieter Jansz""' for an exact phrase." }
                $filterProps = @{
                    source = @{ type = "string"; description = "Exact source (index) name, e.g. 'Archiefkaarten', 'Persoonskaarten', 'Gezinskaarten', 'Bevolkingsregister 1874-1893', 'DTB Dopen', 'DTB Begraven', 'Ondertrouwregister', 'Notariële archieven', 'Begraafregisters', 'Militieregisters', 'Poorterboeken'. Use amsterdam_sources to see the names with hits." }
                    role = @{ type = "string"; description = "Exact role, e.g. 'Geregistreerde', 'Bruidegom', 'Bruid', 'Overledene', 'Dopeling', 'Vader', 'Moeder', 'Partner', 'Getuige'." }
                    place = @{ type = "string"; description = "Exact place, e.g. 'Amsterdam', 'Sloten', 'Watergraafsmeer', 'Nieuwer-Amstel'." }
                    from_year = @{ type = "integer"; description = "First year of the record date." }
                    to_year = @{ type = "integer"; description = "Last year of the record date." }
                }
                $searchProps = @{ query = $queryProp; max = @{ type = "integer"; description = "Results per page (default 25, max 100)."; default = 25 }; page = @{ type = "integer"; description = "Page number (default 1)."; default = 1 } }
                foreach ($k in $filterProps.Keys) { $searchProps[$k] = $filterProps[$k] }
                $sourceProps = @{ query = $queryProp }
                foreach ($k in @("role", "place", "from_year", "to_year")) { $sourceProps[$k] = $filterProps[$k] }
                $tools = @(
                    @{
                        name = "amsterdam_person_search"
                        description = "Search the person indexes of the Amsterdam City Archives (Stadsarchief Amsterdam, archief.amsterdam/indexen): about 30 sources including the population registers, family cards (gezinskaarten 1893-1939), personal cards and archive cards (persoonskaarten and archiefkaarten 1939-1994), baptism, marriage and burial registers, notarial deeds, militia registers and WWII registrations. Returns name, role, source, date, place, record id and a link to the record on archief.amsterdam."
                        inputSchema = @{ type = "object"; properties = $searchProps; required = @("query") }
                    },
                    @{
                        name = "amsterdam_sources"
                        description = "Count the hits of a query per source (index) in the Amsterdam City Archives, to see where a name occurs and which exact source names to use as a filter."
                        inputSchema = @{ type = "object"; properties = $sourceProps; required = @("query") }
                    },
                    @{
                        name = "amsterdam_record"
                        description = "Get one record (deed, card or register entry) from the Amsterdam City Archives by record_id from amsterdam_person_search: all persons named in it with their roles, the archive reference, and links to the scans if they are public."
                        inputSchema = @{ type = "object"; properties = @{ record_id = @{ type = "string"; description = "record_id (a UUID) from amsterdam_person_search." } }; required = @("record_id") }
                    }
                )
                Send-Response $id @{ tools = $tools } $null
            }
            "tools/call" {
                $toolName = $req.params.name
                $a = $req.params.arguments
                if ($null -eq $a) { $a = New-Object PSObject }

                if ($toolName -eq "amsterdam_person_search") {
                    $q = Get-Query $a.query
                    $max = Get-Int $a.max 25 1 100 "max"
                    $page = Get-Int $a.page 1 1 10000 "page"
                    $params = New-Params @(@("q", $q), @("rows", $max), @("page", $page), @("sort", "score desc"))
                    Add-Filters $params $a
                    $data = Get-Json "person" $params
                    $recs = @(); foreach ($p in $data.person) { $recs += (ConvertTo-Person $p) }
                    $pg = $data.metadata.pagination
                    $out = [ordered]@{ archive = "Stadsarchief Amsterdam"; query = $q; total = $pg.total; page = $pg.currentPage; pages = $pg.pages; shown = $recs.Count; results = @($recs) }
                    Send-Text $id ($out | ConvertTo-Json -Depth 6)
                }
                elseif ($toolName -eq "amsterdam_sources") {
                    $q = Get-Query $a.query
                    $params = New-Params @(@("q", $q), @("object_type", "person"), @("facetSort", "count"), @("fields[]", "search_s_register_type_title"), @("rows", 60))
                    Add-Filters $params $a
                    $data = Get-Json "filters" $params
                    $rows = @(); $sum = 0
                    foreach ($f in $data.filter.search_s_register_type_title) { $rows += [ordered]@{ source = $f.label; count = $f.count }; $sum += [int]$f.count }
                    $out = [ordered]@{ archive = "Stadsarchief Amsterdam"; query = $q; total = $sum; sources = @($rows) }
                    Send-Text $id ($out | ConvertTo-Json -Depth 5)
                }
                elseif ($toolName -eq "amsterdam_record") {
                    $rid = ([string]$a.record_id).Trim()
                    if ($rid -notmatch $uuidPattern) { Fail "Invalid record_id: expected a UUID from amsterdam_person_search." }
                    $deed = (Get-Json "deed/$rid" (New-Params @())).deed
                    if (-not $deed) { throw "No record found for this record_id." }
                    $d = @($deed)[0]
                    $persons = Get-Json "person" (New-Params @(@("q", "*"), @("rows", 100), @("fq[]", ("deed_id:""" + $rid + """"))))
                    $people = @()
                    foreach ($p in $persons.person) {
                        $m = $p.metadata
                        $pp = [ordered]@{ name = $m.person_display_name; role = $m.type_title }
                        if ($m.datum_geboorte) { $pp["birth_date"] = Format-Date $m.datum_geboorte }
                        if ($m.leeftijd) { $pp["age"] = $m.leeftijd }
                        if ($m.beroep) { $pp["occupation"] = $m.beroep }
                        $n = Get-Plain $m.diversen; if ($n) { $pp["notes"] = $n }
                        $people += $pp
                    }
                    $dm = $d.metadata
                    $refText = [string]$dm.diversen
                    $archiveRef = $null
                    if ($refText -match 'https?://archief\.amsterdam/archief/[^"''<\s]+') { $archiveRef = $Matches[0] }
                    $scans = @()
                    foreach ($s in $d.asset) { $scans += [ordered]@{ title = $s.dc_title; preview = $s.'thumb.large'; download = $s.download } }
                    $out = [ordered]@{
                        archive = "Stadsarchief Amsterdam"
                        record_id = $rid
                        source = $dm.register_naam
                        record_type = $dm.type_title
                        date = Format-Date $dm.datum
                        place = $dm.plaats
                        persons = @($people)
                        archive_reference = $archiveRef
                        notes = Get-Plain ($refText -replace '<a[^>]*>.*?</a>', '')
                        scans = @($scans)
                        url = "https://archief.amsterdam/indexen/deeds/$rid"
                    }
                    if ($scans.Count -eq 0) { $out["scan_note"] = "No public scan. Scans of persons born less than 100 years ago, or not proven deceased, are not shown online." }
                    Send-Text $id ($out | ConvertTo-Json -Depth 6)
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
