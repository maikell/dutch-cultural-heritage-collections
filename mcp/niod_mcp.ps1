# JSON-RPC 2.0 stdio MCP server for the archives of the NIOD Institute for War, Holocaust and Genocide Studies
# Source: the open API of the EHRI portal (European Holocaust Research Infrastructure),
#         https://portal.ehri-project.eu/api/v1, repository nl-002896 (NIOD). No key needed.
# The NIOD's own search on archieven.nl loads its results in the browser only, so for that site this server
# builds search links.
# Works with Windows PowerShell 5.1 and PowerShell 7.
# License: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

$api = "https://portal.ehri-project.eu/api/v1"
$portal = "https://portal.ehri-project.eu/units/"
$repository = "nl-002896"
$userAgent = "dutch-cultural-heritage-collections-mcp/0.5 (+https://github.com/maikell/dutch-cultural-heritage-collections)"
$idPattern = '^nl-002896(-[A-Za-z0-9_.]{1,60}){0,12}$'
$maxText = 4000

function Fail($message) { throw [System.ArgumentException]::new($message) }

function Get-Json($path, $params) {
    $parts = @()
    foreach ($p in $params) { $parts += ([uri]::EscapeDataString([string]$p[0]) + "=" + [uri]::EscapeDataString([string]$p[1])) }
    $url = "$api/$path"
    if ($parts.Count -gt 0) { $url += "?" + ($parts -join "&") }
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Headers.Add("User-Agent", $userAgent)
    $wc.Headers.Add("Accept", "application/vnd.api+json")
    $raw = $wc.DownloadString($url)
    return ($raw | ConvertFrom-Json)
}

function New-Params($pairs) {
    $list = New-Object System.Collections.ArrayList
    foreach ($p in $pairs) { [void]$list.Add($p) }
    return ,$list
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

function Get-Id($value) {
    $s = ([string]$value).Trim()
    if ($s -notmatch $idPattern) { Fail "Invalid id: expected an EHRI id of a NIOD item, starting with nl-002896." }
    return $s
}

function Get-Short($s, $n) {
    if (-not $s) { return $null }
    $t = ([string]$s).Trim()
    if ($t.Length -gt $n) { return $t.Substring(0, $n) + " ..." }
    return $t
}

# Access code (toegang) from the description's localId, e.g. "nld-250i_nld" -> "250i"
function Get-AccessCode($desc, $item) {
    $l = [string]$desc.localId
    if ($l -match '^[a-z]{3}-(.+)_[a-z]{3}$') { return $Matches[1] }
    foreach ($alt in @($item.attributes.alternateIds)) { if ([string]$alt -match '^(.+)_[A-Z]{3}$') { return $Matches[1] } }
    return $null
}

# Inventory numbers from alternateIds, without internal 32-character GUIDs
function Get-InventoryNumber($item) {
    $ids = @($item.attributes.alternateIds) | Where-Object { $_ -and ($_ -notmatch '^[0-9A-Fa-f]{32}$') -and ($_ -notmatch '_[A-Z]{3}$') }
    if ($ids.Count -eq 0) { return $null }
    return ($ids -join ", ")
}

function Get-Dates($d) {
    $v = (@($d.unitDates) | Where-Object { $_ }) -join "; "
    if ($v) { return $v } else { return $null }
}

function Get-Description($item) {
    $ds = @($item.attributes.descriptions)
    $d = $ds | Where-Object { $_.languageCode -eq "nld" } | Select-Object -First 1
    if (-not $d) { $d = $ds | Select-Object -First 1 }
    return $d
}

function ConvertTo-Summary($item) {
    $d = Get-Description $item
    $rec = [ordered]@{
        id = $item.id
        title = $d.name
        dates = Get-Dates $d
        access_code = Get-AccessCode $d $item
        inventory_number = Get-InventoryNumber $item
        extent = $d.extentAndMedium
        summary = Get-Short $d.scopeAndContent 300
        top_level = (($item.id -split '-').Count -le 3)
        url = $portal + $item.id
    }
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
                Send-Response $id @{ protocolVersion = "2024-11-05"; capabilities = @{ tools = @{} }; serverInfo = @{ name = "niod"; version = "0.5.0" } } $null
            }
            "notifications/initialized" { }
            "ping" { Send-Response $id @{} $null }
            "tools/list" {
                $tools = @(
                    @{
                        name = "niod_search"
                        description = "Search the archives of the NIOD Institute for War, Holocaust and Genocide Studies (Amsterdam) through the EHRI portal: archive descriptions, series and inventory items, and the NIOD image collection, mainly about the Second World War, the German occupation, the Holocaust, the Dutch East Indies and genocide. Returns title, dates, access code (toegang), inventory number, extent, summary and a link."
                        inputSchema = @{ type = "object"; properties = @{
                            query = @{ type = "string"; description = "Words to search for, e.g. 'Westerbork', 'Joodsche Raad', '""Raad van Verzet""', 'Puttkammer'. The archive descriptions are mostly in Dutch." }
                            max = @{ type = "integer"; description = "Results per page (default 20, max 100)."; default = 20 }
                            page = @{ type = "integer"; description = "Page number (default 1)."; default = 1 }
                        }; required = @("query") }
                    },
                    @{
                        name = "niod_item"
                        description = "Get one NIOD archive description or inventory item by id from niod_search: full description (history, content, arrangement, access), its parent, and its child items (series or inventory numbers). Use within to search inside it."
                        inputSchema = @{ type = "object"; properties = @{
                            id = @{ type = "string"; description = "EHRI id from niod_search, e.g. nl-002896-mf800962 (Westerbork, Judendurchgangslager)." }
                            within = @{ type = "string"; description = "Optional words to search for among the items inside this description." }
                            max_children = @{ type = "integer"; description = "Number of child items to list (default 30, max 100)."; default = 30 }
                            page = @{ type = "integer"; description = "Page of child items (default 1)."; default = 1 }
                        }; required = @("id") }
                    },
                    @{
                        name = "niod_archive_search_link"
                        description = "Build a search link for the NIOD's own archive search on archieven.nl, which also covers persons and files that are not in EHRI. The results only load in a browser, so open the link there; this tool does not fetch them."
                        inputSchema = @{ type = "object"; properties = @{
                            all_words = @{ type = "string"; description = "All of these words." }
                            any_words = @{ type = "string"; description = "Any of these words." }
                            phrase = @{ type = "string"; description = "Exact phrase." }
                            access_number = @{ type = "string"; description = "Access code (toegangscode), e.g. '250i'." }
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

                if ($toolName -eq "niod_search") {
                    $q = Get-Text $a.query "query" 200
                    if (-not $q) { Fail "Give a query." }
                    $max = Get-Int $a.max 20 1 100 "max"
                    $page = Get-Int $a.page 1 1 10000 "page"
                    $data = Get-Json "$repository/search" (New-Params @(@("q", $q), @("type", "DocumentaryUnit"), @("limit", $max), @("page", $page)))
                    $recs = @(); foreach ($it in $data.data) { $recs += (ConvertTo-Summary $it) }
                    $out = [ordered]@{ archive = "NIOD (via EHRI portal)"; query = $q; total = $data.meta.total; page = $page; pages = $data.meta.pages; shown = $recs.Count; results = @($recs) }
                    Send-Text $id ($out | ConvertTo-Json -Depth 6)
                }
                elseif ($toolName -eq "niod_item") {
                    $iid = Get-Id $a.id
                    $item = (Get-Json $iid (New-Params @())).data
                    $d = Get-Description $item
                    $out = ConvertTo-Summary $item
                    $out.Remove("summary")
                    foreach ($f in @("biographicalHistory", "scopeAndContent", "archivalHistory", "acquisition", "appraisal", "systemOfArrangement", "conditionsOfAccess", "conditionsOfReproduction", "accessPoints")) {
                        $v = $d.$f
                        if ($v) { $key = ($f -creplace '([A-Z])', '_$1').ToLower(); $out[$key] = Get-Short $v $maxText }
                    }
                    if ($item.relationships.parent.data.id) { $out["parent_id"] = $item.relationships.parent.data.id }
                    $within = Get-Text $a.within "within" 200
                    $maxc = Get-Int $a.max_children 30 1 100 "max_children"
                    $page = Get-Int $a.page 1 1 10000 "page"
                    $params = New-Params @(@("limit", $maxc), @("page", $page))
                    if ($within) { [void]$params.Add(@("q", $within)) }
                    $kids = Get-Json "$iid/search" $params
                    $children = @()
                    foreach ($k in $kids.data) {
                        $kd = Get-Description $k
                        $children += [ordered]@{ id = $k.id; title = $kd.name; dates = Get-Dates $kd; inventory_number = Get-InventoryNumber $k }
                    }
                    $out["children_total"] = $kids.meta.total
                    $out["children_page"] = $page
                    $out["children"] = @($children)
                    Send-Text $id ($out | ConvertTo-Json -Depth 6)
                }
                elseif ($toolName -eq "niod_archive_search_link") {
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
                        url = "https://www.archieven.nl/mi/298/?mivast=298&miadt=298&mizig=0&miview=lst&milang=nl&" + ($parts -join "&")
                        note = "Open this link in a browser: the NIOD search on archieven.nl loads its results in the page itself, so this tool cannot read them."
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
