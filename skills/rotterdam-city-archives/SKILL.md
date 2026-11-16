---
name: rotterdam-city-archives
description: Use this skill whenever the user asks to search the Rotterdam City Archives (Stadsarchief Rotterdam, stadsarchief.rotterdam.nl) - persons in civil registration (births, marriages, deaths), population registers, baptism, marriage and burial registers, notarial deeds, passenger lists of the Holland America Line or militia registers, or the archives and inventories (archieven, toegangen) of Rotterdam. Triggers include "Stadsarchief Rotterdam", "Rotterdamse voorouders", "zoek in het Rotterdamse archief", "Holland-Amerika Lijn passagiers", "toegang Rotterdam", and links to stadsarchief.rotterdam.nl.
---

# Rotterdam City Archives

Use the `rotterdam-city-archives` MCP server.

- Persons come from the open data of Stadsarchief Rotterdam through the Open Archives API (openarchieven.nl, archive code `srt`): about 23 million person entries. The API allows 4 requests per second; the server spaces its calls.
- Archives and inventories: stadsarchief.rotterdam.nl blocks automated requests and loads its results in the page. `rotterdam_archive_search_link` only builds a search link; open it in a browser (Claude in Chrome or the built-in browser) to read the results, and do not try to get around the block in another way.

## Tools

| Tool | Purpose |
|------|---------|
| `rotterdam_person_search` | Search persons by name, optionally with year or period in the query (`van Leeuwen 1850-1900`); filter on `source_type`, `event_place`, `role`; sort with `date_asc` / `date_desc` |
| `rotterdam_record` | One record by `identifier`: all persons with roles, age, birth place and occupation, the archive reference and scan links |
| `rotterdam_sources` | Source types and counts |
| `rotterdam_archive_search_link` | Search link for archives and inventories on stadsarchief.rotterdam.nl |

## Workflow

1. Search with `rotterdam_person_search`. Put a period in the query to narrow it, and add `source_type` (for example `BS Huwelijk`) or `event_place` (Rotterdam, Delfshaven, Kralingen, Charlois, Hillegersberg, Overschie, IJsselmonde, Hoogvliet, Pernis) when results are broad. Two names joined with `&` find records naming both, which is useful for couples.
2. Open the most relevant hits with `rotterdam_record` to get parents, witnesses and the archive reference (access number, inventory number, document number).
3. For questions about archives of organisations, companies, buildings or topics, give the user a link from `rotterdam_archive_search_link` and, if a browser is available, open it there to read the results.

## Privacy

Do not use these records to look up, locate or profile living private persons. Civil registration becomes public after 100 years (births), 75 years (marriages) and 50 years (deaths); the open data follows these limits. Summarise records about private persons by event and keep personal details to what the user's question needs.

## Reporting

- Give a link per record: the Open Archives page (`url`) and, when present, the archive's own link (`archive_url`).
- Index data can contain transcription errors; tell the user to check the scan before relying on a detail.
- Answer in the user's language.
