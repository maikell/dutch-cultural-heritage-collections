---
name: niod
description: Use this skill whenever the user asks to search the archives of the NIOD Institute for War, Holocaust and Genocide Studies (Amsterdam) - archives and collections about the Second World War, the German occupation of the Netherlands, resistance and collaboration, the persecution of the Jews, camps such as Westerbork, Vught and Amersfoort, the Joodsche Raad, the Dutch East Indies and Japanese occupation, or genocide studies - or the NIOD image collection. Triggers include "NIOD", "oorlogsarchief", "Tweede Wereldoorlog archief", "Westerbork", "Joodsche Raad", "verzet", "NSB", "Indië archief", and links to archieven.nl/mi/298 or portal.ehri-project.eu.
---

# NIOD archives

Use the `niod` MCP server. It searches the NIOD archive descriptions in the open API of the EHRI portal (European Holocaust Research Infrastructure, repository `nl-002896`): archives, series, inventory items and the NIOD image collection. No key is needed.

## Tools

| Tool | Purpose |
|------|---------|
| `niod_search` | Search descriptions; returns title, dates, access code (toegang, e.g. `250i`), inventory number, extent, summary and an EHRI link |
| `niod_item` | Full description of one archive or item (history, content, arrangement, access), its parent, and its children; `within` searches inside it |
| `niod_archive_search_link` | Search link for the NIOD's own search on archieven.nl (also persons and files not in EHRI); open it in a browser |

## Workflow

1. Search with `niod_search` in Dutch terms (most descriptions are Dutch): `Westerbork`, `Joodsche Raad`, `"Raad van Verzet"`, a person's or organisation's name, a place. Results mix whole archives (`top_level: true`) with single inventory items and photos.
2. Open a whole archive with `niod_item` to read its history and content and to list its series; use `within` to find specific inventory numbers inside it (for example `transport` inside 250i Westerbork).
3. Cite an item as: NIOD, access code, inventory number, title. To consult or request it, the NIOD reading room or the NIOD search on archieven.nl (`niod_archive_search_link`) is the place; some archives are temporarily unavailable or partly restricted.

## Sensitivity

These archives document persecution, deportation, violence and collaboration. Report factually and respectfully, without speculation. Names of victims, perpetrators and other private persons appear in descriptions: mention them only as far as the user's question needs, and do not build profiles of private individuals. Some inventory numbers are restricted (beperkt openbaar); say so when a description mentions it.

## Reporting

- Give the EHRI link per item (`url`), with access code and inventory number.
- Answer in the user's language.
