# JSON-RPC 2.0 stdio MCP server for Dutch regional archives whose person records are open data in the
# Open Archives API (https://api.openarchieven.nl/1.1). One script serves several archives:
#   -Archive srt  Stadsarchief Rotterdam (Rotterdam City Archives)   tools rotterdam_*
#   -Archive nha  Noord-Hollands Archief                              tools nha_*
# Free API, throttled to 4 requests per second per IP address; this server spaces its calls.
# Archives and inventories of these institutions run on the MAIS-Flexis platform, which loads results in
# the browser only (and Rotterdam blocks automated requests), so this server builds search links for them.
# Works with Windows PowerShell 5.1 and PowerShell 7.
# License: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)
param([string]$Archive = "srt")
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

$api = "https://api.openarchieven.nl/1.1"
$configs = @{
    srt = @{
        prefix = "rotterdam"; server = "rotterdam-city-archives"
        label = "Stadsarchief Rotterdam (Rotterdam City Archives)"
        scope = "civil registration (births, marriages, deaths), population registers, baptism, marriage and burial registers, notarial deeds, Holland America Line passenger lists, militia registers and more, about 23 million person entries"
        places = "'Rotterdam', 'Delfshaven', 'Kralingen', 'Charlois', 'Hillegersberg', 'Overschie'"
        sources = "'BS Geboorte', 'BS Huwelijk', 'BS Overlijden', 'Bevolkingsregister', 'DTB Dopen', 'DTB Trouwen', 'DTB Begraven', 'Notariële archieven', 'Passagiersregisters', 'Militieregisters', 'Kadaster'"
        linkBase = "https://stadsarchief.rotterdam.nl/archieven?mizig=0&miview=lst&milang=nl"
        linkNote = "Open this link in a browser. The Rotterdam City Archives site blocks automated requests, so the results cannot be read by this tool."
    }
    nha = @{
        prefix = "nha"; server = "noord-hollands-archief"
        label = "Noord-Hollands Archief (Haarlem; also the civil registration of Amsterdam and the rest of Noord-Holland)"
        scope = "civil registration of Noord-Holland including Amsterdam (marriages, deaths, births), militia registers, population registers, baptism registers, court records (vredegerecht, veroordeelden, vonnissen), prisoner registers, estate declarations (memories van successie), notarial deeds and more, about 13 million person entries"
        places = "'Haarlem', 'Amsterdam', 'Zaandam', 'Haarlemmermeer', 'Bloemendaal', 'Velsen'"
        sources = "'BS Huwelijk', 'BS Overlijden', 'BS Geboorte', 'Militieregisters', 'Bevolkingsregister', 'DTB Dopen', 'Vredegerecht', 'Klapper op veroordeelden', 'Inschrijving gevangene', 'Notariële archieven', 'Memories van Successie'"
        linkBase = "https://noord-hollandsarchief.nl/bronnen/archieven?mivast=236&miadt=236&mizig=0&miview=lst&milang=nl"
        linkNote = "Open this link in a browser: the search results of the Noord-Hollands Archief are loaded by the page itself, so this tool cannot read them."
    }
}
$archiveCode = $Archive.ToLower()
if (-not $configs.ContainsKey($archiveCode)) { [Console]::Error.WriteLine("Unknown archive '$Archive'. Use one of: " + ($configs.Keys -join ", ")); exit 1 }
$cfg = $configs[$archiveCode]
$px = $cfg.prefix
$userAgent = "dutch-cultural-heritage-collections-mcp/0.5 (+https://github.com/maikell/dutch-cultural-heritage-collections)"
$idPattern = '^\{?[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}?$'
$labelPattern = '^[\p{L}\p{N}][\p{L}\p{N} .,''&()/-]{0,99}$'
$sorts = @{ name = 1; role = 2; event = 3; date_asc = 4; date_desc = -4; place = 5; source = 6 }
$script:lastCall = [DateTime]::MinValue

function Fail($message) { throw [System.ArgumentException]::new($message) }

function Get-Json($path, $params) {
    # Stay well below the Open Archives limit of 4 requests per second
    $wait = 300 - ([DateTime]::UtcNow - $script:lastCall).TotalMilliseconds
    if ($wait -gt 0) { Start-Sleep -Milliseconds ([int]$wait) }
    $parts = @()
    foreach ($k in $params.Keys) { if ($null -ne $params[$k] -and "$($params[$k])" -ne "") { $parts += ([uri]::EscapeDataString($k) + "=" + [uri]::EscapeDataString([string]$params[$k])) } }
    $url = "$api/$path`?" + ($parts -join "&")
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Headers.Add("User-Agent", $userAgent)
    $raw = $wc.DownloadString($url)
    $script:lastCall = [DateTime]::UtcNow
    $data = $raw | ConvertFrom-Json
    if ($data.error_description) { throw "Open Archives: $($data.error_description)" }
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

function Get-Text($value, $field, $maxLen) {
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { return $null }
    $s = ([string]$value).Trim()
    if ($s.Length -gt $maxLen) { Fail "${field} is too long (max $maxLen characters)." }
    if ($s -match '[\\<>{}]') { Fail "${field} contains invalid characters." }
    return $s
}

function Get-Label($value, $field) {
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { return $null }
    $s = ([string]$value).Trim()
    if ($s -notmatch $labelPattern) { Fail "Invalid value for ${field}." }
    return $s
}

function Format-EventDate($d) {
    if (-not $d) { return $null }
    if ($d.year -and $d.month -and $d.day) { return ("{0:D4}-{1:D2}-{2:D2}" -f [int]$d.year, [int]$d.month, [int]$d.day) }
    if ($d.year -and $d.month) { return ("{0:D4}-{1:D2}" -f [int]$d.year, [int]$d.month) }
    if ($d.year) { return [string]$d.year }
    return $null
}

function Get-PersonName($pn) {
    if (-not $pn) { return $null }
    $parts = @($pn.PersonNameFirstName, $pn.PersonNamePatronym, $pn.PersonNamePrefixLastName, $pn.PersonNameLastName) | Where-Object { $_ }
    if ($parts.Count -eq 0 -and $pn.PersonNameLiteral) { return [string]$pn.PersonNameLiteral }
    return ($parts -join " ")
}

function As-Array($x) { if ($null -eq $x) { return @() } else { return @($x) } }

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
                Send-Response $id @{ protocolVersion = "2024-11-05"; capabilities = @{ tools = @{} }; serverInfo = @{ name = $cfg.server; version = "0.5.0" } } $null
            }
            "notifications/initialized" { }
            "ping" { Send-Response $id @{} $null }
            "tools/list" {
                $tools = @(
                    @{
                        name = "${px}_person_search"
                        description = "Search persons in the $($cfg.label) through the Open Archives API: $($cfg.scope). Returns name, role, event, date, place, source type, identifier and links."
                        inputSchema = @{ type = "object"; properties = @{
                            query = @{ type = "string"; description = "Name to search for, optionally with a year or period, e.g. 'Jan van Leeuwen', 'van Leeuwen 1850-1900', 'Maria Bakker 1875'. Two persons in one record: 'Jan van Leeuwen & Maria Bakker'." }
                            source_type = @{ type = "string"; description = "Exact source type, e.g. $($cfg.sources). See ${px}_sources." }
                            event_place = @{ type = "string"; description = "Place of the event, e.g. $($cfg.places)." }
                            role = @{ type = "string"; description = "Role in the record, e.g. 'Bruidegom', 'Bruid', 'Overledene', 'Kind', 'Vader', 'Moeder', 'Geregistreerde', 'Passagier'." }
                            sort = @{ type = "string"; enum = @("name", "date_asc", "date_desc", "place", "source", "role", "event"); description = "Sort order (default name)."; default = "name" }
                            max = @{ type = "integer"; description = "Number of results (default 25, max 100)."; default = 25 }
                            start = @{ type = "integer"; description = "Offset of the first result, for paging (default 0)."; default = 0 }
                        }; required = @("query") }
                    },
                    @{
                        name = "${px}_record"
                        description = "Get one record of the $($cfg.label) by identifier from ${px}_person_search: all persons with their roles, age, birth place and occupation, the event, the archive reference (access number, inventory, document number) and links to the scan."
                        inputSchema = @{ type = "object"; properties = @{ identifier = @{ type = "string"; description = "identifier (a GUID) from ${px}_person_search." } }; required = @("identifier") }
                    },
                    @{
                        name = "${px}_sources"
                        description = "List the source types of the $($cfg.label) in the Open Archives data with the number of person entries per type."
                        inputSchema = @{ type = "object"; properties = @{} }
                    },
                    @{
                        name = "${px}_archive_search_link"
                        description = "Build a search link for the archives and inventories (archieven, toegangen, inventarissen) of the $($cfg.label). The results only load in a browser, so open the link there; this tool does not fetch them."
                        inputSchema = @{ type = "object"; properties = @{
                            all_words = @{ type = "string"; description = "All of these words, e.g. 'Coolsingel stadhuis'." }
                            any_words = @{ type = "string"; description = "Any of these words." }
                            phrase = @{ type = "string"; description = "Exact phrase." }
                            access_number = @{ type = "string"; description = "Access number (toegangsnummer), e.g. '444-01'." }
                            from_year = @{ type = "integer"; description = "Start of period." }
                            to_year = @{ type = "integer"; description = "End of period." }
                        } }
                    }
                )
                Send-Response $id @{ tools = $tools } $null
            }
            "tools/call" {
                $toolName = $req.params.name
                $a = $req.params.arguments
                if ($null -eq $a) { $a = New-Object PSObject }

                if ($toolName -eq "${px}_person_search") {
                    $q = Get-Text $a.query "query" 200
                    if (-not $q) { Fail "Give a query (a name)." }
                    $sortKey = if ($a.sort) { ([string]$a.sort).ToLower() } else { "name" }
                    if (-not $sorts.ContainsKey($sortKey)) { Fail "Sort: choose name, date_asc, date_desc, place, source, role or event." }
                    $params = [ordered]@{
                        name = $q; archive_code = $archiveCode; lang = "nl"
                        number_show = (Get-Int $a.max 25 1 100 "max"); start = (Get-Int $a.start 0 0 100000 "start")
                        sort = $sorts[$sortKey]
                        sourcetype = (Get-Label $a.source_type "source_type"); eventplace = (Get-Label $a.event_place "event_place"); relationtype = (Get-Label $a.role "role")
                    }
                    $data = Get-Json "records/search.json" $params
                    $recs = @()
                    foreach ($d in (As-Array $data.response.docs)) {
                        $place = (As-Array $d.eventplace) -join ", "
                        $recs += [ordered]@{
                            identifier = $d.identifier; name = $d.personname; role = $d._relationtype; event = $d._eventtype
                            date = Format-EventDate $d.eventdate; place = $(if ($place) { $place } else { $null }); source_type = $d.sourcetype
                            url = $d.url
                        }
                    }
                    $out = [ordered]@{ archive = "$($cfg.label) (via Open Archives)"; query = $q; total = $data.response.number_found; start = $params.start; shown = $recs.Count; results = @($recs) }
                    Send-Text $id ($out | ConvertTo-Json -Depth 6)
                }
                elseif ($toolName -eq "${px}_record") {
                    $rid = ([string]$a.identifier).Trim()
                    if ($rid -notmatch $idPattern) { Fail "Invalid identifier: expected a GUID from ${px}_person_search." }
                    $rid = $rid.Trim('{', '}')
                    $r = Get-Json "records/show.json" ([ordered]@{ archive = $archiveCode; identifier = $rid; lang = "nl" })
                    $roles = @{}
                    foreach ($rel in (As-Array $r.RelationEP)) { $roles[[string]$rel.PersonKeyRef] = $rel.RelationType }
                    $people = @()
                    foreach ($p in (As-Array $r.Person)) {
                        $pp = [ordered]@{ name = Get-PersonName $p.PersonName; role = $roles[[string]$p.'@pid'] }
                        if ($p.Age.PersonAgeLiteral) { $pp["age"] = $p.Age.PersonAgeLiteral } elseif ($p.Age.PersonAgeYears) { $pp["age"] = $p.Age.PersonAgeYears }
                        if ($p.BirthDate.Year) { $pp["birth_date"] = (@($p.BirthDate.Year, $p.BirthDate.Month, $p.BirthDate.Day) | Where-Object { $_ }) -join "-" }
                        if ($p.BirthPlace.Place) { $pp["birth_place"] = $p.BirthPlace.Place }
                        if ($p.Profession) { $pp["occupation"] = (As-Array $p.Profession) -join ", " }
                        if ($p.Residence.Place) { $pp["residence"] = $p.Residence.Place }
                        $people += $pp
                    }
                    $ev = @(As-Array $r.Event)[0]
                    $src = $r.Source
                    $ref = $src.SourceReference
                    $scans = @()
                    foreach ($s in (As-Array $src.SourceAvailableScans.Scan)) { $scans += [ordered]@{ viewer = $s.UriViewer; image = $s.Uri; preview = $s.UriPreview } }
                    $out = [ordered]@{
                        archive = $cfg.label
                        identifier = $rid
                        event = $ev.EventType
                        date = $(if ($ev.EventDate.LiteralDate) { $ev.EventDate.LiteralDate } else { $ev.EventDate.Year })
                        place = $ev.EventPlace.Place
                        source_type = $src.SourceType
                        persons = @($people)
                        reference = [ordered]@{ access_number = $ref.Archive; collection = $ref.Collection; book = $ref.Book; inventory_number = $ref.RegistryNumber; document_number = $ref.DocumentNumber; folio = $ref.Folio }
                        scans = @($scans)
                        archive_url = $src.SourceDigitalOriginal
                        url = "https://www.openarchieven.nl/${archiveCode}:$rid"
                    }
                    Send-Text $id ($out | ConvertTo-Json -Depth 6)
                }
                elseif ($toolName -eq "${px}_sources") {
                    $data = Get-Json "stats/records.json" ([ordered]@{ archive_code = $archiveCode })
                    $row = @($data)[0]
                    $rows = @(); foreach ($s in (As-Array $row.sourcetypes)) { $rows += [ordered]@{ source_type = $s.sourcetype; count = $s.count } }
                    $out = [ordered]@{ archive = "$($cfg.label) (via Open Archives)"; total = $row.count; source_types = @($rows) }
                    Send-Text $id ($out | ConvertTo-Json -Depth 4)
                }
                elseif ($toolName -eq "${px}_archive_search_link") {
                    $all = Get-Text $a.all_words "all_words" 200
                    $any = Get-Text $a.any_words "any_words" 200
                    $phrase = Get-Text $a.phrase "phrase" 200
                    $acc = Get-Text $a.access_number "access_number" 30
                    $from = Get-Int $a.from_year $null 1000 2100 "from_year"
                    $to = Get-Int $a.to_year $null 1000 2100 "to_year"
                    if (-not ($all -or $any -or $phrase -or $acc)) { Fail "Give at least one of all_words, any_words, phrase or access_number." }
                    $p = [ordered]@{ mizk_alle = $all; mizk_of = $any; mizk_exact = $phrase; mip1 = $acc; mibj = $from; miej = $to }
                    $parts = @(); foreach ($k in $p.Keys) { if ($null -ne $p[$k] -and "$($p[$k])" -ne "") { $parts += ($k + "=" + [uri]::EscapeDataString([string]$p[$k])) } }
                    $out = [ordered]@{
                        url = $cfg.linkBase + "&" + ($parts -join "&")
                        note = $cfg.linkNote
                    }
                    Send-Text $id ($out | ConvertTo-Json -Depth 3)
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
