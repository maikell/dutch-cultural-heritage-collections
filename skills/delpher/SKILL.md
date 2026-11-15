---
name: delpher
description: Use this skill whenever the user asks to search historical Dutch newspapers, magazines, books or ANP radio bulletins in Delpher (Koninklijke Bibliotheek, delpher.nl): what old newspapers wrote about a place, street, person, building, event or plan, when a topic first appeared, how often something was in the news per year or decade, or to read the full text of a Delpher item. Triggers include "search Delpher", "old newspapers", "zoek in Delpher", "oude kranten", "what did Het Parool write in 1965 about...", "newspaper archive", "family notice", "advertisement from", "ANP bulletin", and Delpher links (delpher.nl/nl/kranten/view?...identifier=...).
---

# Delpher (Koninklijke Bibliotheek)

Use the `delpher` MCP server. It queries the KB's open search service (SRU, jsru.kb.nl) and the KB resolver for OCR text. No account or key is needed.

## Tools

| Tool | Purpose |
|------|---------|
| `delpher_search` | Search a collection; returns id, title, newspaper or publisher, date and a Delpher link per hit |
| `delpher_text` | Full OCR text of one hit, by id |
| `delpher_timeline` | Hit counts per year or decade, for trends |

Collections (`collection`): `newspapers` (default, articles 1618-1995), `magazines`, `books`, `radio_bulletins` (ANP 1937-1984).

## Workflow

1. Search with `delpher_search`. Narrow with `from`/`to` (YYYY, YYYY-MM or YYYY-MM-DD), and for newspapers `newspaper` (exact title such as `Het Parool`, `De Volkskrant`, `Algemeen Handelsblad`, `De Telegraaf`, `Trouw`, `NRC Handelsblad`) and `type` (`article`, `advertisement`, `family_notice`, `illustration`). Use `sort: oldest` to find the first mention. For an overview of a place, start with `type: article`, because advertisements and family notices usually dominate the hits.
2. Read the most relevant hits with `delpher_text` (pass the same `collection`). Books and magazines are read per scanned page (`page`); newspaper and ANP ids give the whole item. Use `next_start` from a search result to page further. Articles on one page often share the id prefix and have consecutive numbers (`...:a0170`, `...:a0171`): read neighbours when a story continues under a new heading.
3. For "when / how often" questions, use `delpher_timeline` and present the counts as a chart or table.
4. Also search `magazines` and `books` when the user wants everything that can be found.

## Query syntax

Same as the Delpher search box: plain words, `"exact phrase"`, `AND`, `OR`, `NOT`, brackets. Queries are matched against Dutch texts, so search in Dutch. Historic spelling matters: also try variants (`Sloterplas` / `Sloterplasch`, `Nieuw West` / `Nieuw-West`, `ij` / `y`, `c` / `k`, `sch` endings). Combine place names with the city or district (`Osdorp AND Amsterdam`) to avoid other places with the same name, and treat stray hits from outside the area (often OCR errors) as noise.

## Reporting

- Always give the Delpher link per source, with newspaper and date: [title](delpher_url), *Het Parool*, 12-09-1989.
- OCR contains reading errors. Quote short fragments only, mark obvious OCR errors, and tell the user to check the scan via the link before quoting in public (opinion pieces, social media).
- `freely_accessible: false` or a refusal from `delpher_text` means the text is protected (copyright, often after about 1945 for magazines and books); give the link and say it can be read on Delpher or in the KB reading room. Do not try to fetch the text another way.
- Coverage is uneven: newspapers stop around 1995, not all titles and years are digitised, and for magazines, books and radio bulletins the KB search service holds only part of what delpher.nl shows. Mention this when counts or absence of hits matter for a conclusion.
- News items and family notices name private persons (victims, residents, the deceased): summarise them by event, leave names out unless the user asks for a specific person, and do not compile profiles of individuals.
- Answer in the user's language.

## Fallback

If the MCP server is unavailable, the same service can be called directly:
`https://jsru.kb.nl/sru/sru?version=1.2&operation=searchRetrieve&x-collection=DDD_artikel&recordSchema=ddd&maximumRecords=10&query=<CQL>`
(collections `DDD_artikel`, `DTS_document`, `BOEKEN_boek`, `ANP`; dates as `date within "DD-MM-YYYY DD-MM-YYYY"`), and text via `https://resolver.kb.nl/resolve?urn=<article-id>:ocr`.
