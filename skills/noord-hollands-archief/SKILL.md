---
name: noord-hollands-archief
description: Use this skill whenever the user asks to search the Noord-Hollands Archief (Haarlem) - persons in the civil registration of Noord-Holland including Amsterdam (births, marriages, deaths), militia registers, population registers, baptism registers, court and prison records (vredegerecht, veroordeelden, vonnissen, gevangenen), estate declarations (memories van successie) or notarial deeds, or its archives and inventories. Triggers include "Noord-Hollands Archief", "NHA", "huwelijksakte Amsterdam", "overlijdensakte Haarlem", "burgerlijke stand Noord-Holland", "memorie van successie", and links to noord-hollandsarchief.nl.
---

# Noord-Hollands Archief

Use the `noord-hollands-archief` MCP server (tools `nha_*`).

- Persons come from the open data of the Noord-Hollands Archief through the Open Archives API (openarchieven.nl, archive code `nha`): about 13 million person entries. The API allows 4 requests per second; the server spaces its calls.
- The NHA holds the civil registration (burgerlijke stand) of all of Noord-Holland, including the marriages and deaths of Amsterdam. For Amsterdam population registers, church registers and the personal cards, use the `amsterdam-city-archives` service; combine both for Amsterdam family history.
- Archives and inventories: the NHA search (MAIS-Flexis) loads its results in the page. `nha_archive_search_link` only builds a search link; open it in a browser (Claude in Chrome or the built-in browser) to read the results.

## Tools

| Tool | Purpose |
|------|---------|
| `nha_person_search` | Search persons by name, optionally with a year or period in the query (`van Leeuwen 1880-1920`); filter on `source_type`, `event_place`, `role`; sort with `date_asc` / `date_desc` |
| `nha_record` | One record by `identifier`: all persons with roles, age, birth place and occupation, the archive reference and scan links |
| `nha_sources` | Source types and counts |
| `nha_archive_search_link` | Search link for archives and inventories on noord-hollandsarchief.nl |

## Workflow

1. Search with `nha_person_search`, narrowing with a period in the query and with `source_type` (for example `BS Huwelijk`) and `event_place` (for example `Amsterdam`, `Haarlem`, `Zaandam`).
2. Open the most relevant hits with `nha_record` for parents, witnesses, ages, occupations and the archive reference.
3. For organisations, buildings, municipalities or topics, give a link from `nha_archive_search_link` and, if a browser is available, open it there to read the results.

## Privacy

Do not use these records to look up, locate or profile living private persons. Civil registration becomes public after 100 years (births), 75 years (marriages) and 50 years (deaths). Court and prison records concern real people: report them factually, by event, and only as far as the user's question needs.

## Reporting

- Give a link per record: the Open Archives page (`url`) and, when present, the archive's own link (`archive_url`).
- Index data can contain transcription errors; tell the user to check the scan before relying on a detail.
- Answer in the user's language.
