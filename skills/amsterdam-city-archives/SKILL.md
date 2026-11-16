---
name: amsterdam-city-archives
description: Use this skill whenever the user asks to search the person indexes of the Amsterdam City Archives (Stadsarchief Amsterdam, archief.amsterdam/indexen) - population registers, gezinskaarten, persoonskaarten and archiefkaarten (1939-1994), baptism, marriage (ondertrouw) and burial registers, notarial deeds, militia registers, poorterboeken, WWII registrations - for family history or the history of an Amsterdam person, family, street or neighbourhood. Triggers include "Stadsarchief Amsterdam", "archief.amsterdam", "zoek in de indexen", "persoonskaart", "archiefkaart", "gezinskaart", "bevolkingsregister Amsterdam", "voorouders in Amsterdam", "stamboom", and links to archief.amsterdam/indexen.
---

# Amsterdam City Archives - person indexes

Use the `amsterdam-city-archives` MCP server. It queries the Memorix genealogy service behind archief.amsterdam/indexen, with the public key that the archive's own search page uses (override with the environment variable `AMSTERDAM_MEMORIX_KEY`).

## Tools

| Tool | Purpose |
|------|---------|
| `amsterdam_person_search` | Search persons; filter on `source`, `role`, `place`, `from_year`/`to_year`; page with `page` |
| `amsterdam_sources` | Hit counts per source for a query, and the exact source names to filter on |
| `amsterdam_record` | One record by `record_id`: everyone named in it, the archive reference and public scans |

## Workflow

1. Start with `amsterdam_sources` for a name to see in which indexes it occurs, then search with `amsterdam_person_search` and a `source` filter. Names in old records vary: try spelling variants (`Leeuwen` / `Leeuwe`, `y` / `ij`, `ck` / `k`, patronyms such as `Jansz` / `Janszoon`) and use `"exact phrase"` for a full name.
2. Open promising hits with `amsterdam_record` to see family members, witnesses, the archive reference (`archief.amsterdam/archief/<access number>/<inventory number>`) and the scan.
3. Combine sources to follow a person or family over time: baptism (DTB Dopen) -> ondertrouw -> population registers 1851-1893 -> gezinskaarten 1893-1939 -> persoonskaarten / archiefkaarten 1939-1994 -> burial (DTB Begraven, Begraafregisters).

## Persoons- en archiefkaarten (index 28)

The sources `Persoonskaarten` and `Archiefkaarten` are the Amsterdam population cards of 1939-1994 (archive cards are copies of personal cards, for people who died or left Amsterdam). Each card has 35 sections: name, birth date and place, nationality, parents, relation to head of household, occupation (often incomplete), spouse, marriage, divorce or death, addresses with dates, children (usually on the father's card) and remarks. Religion and some remarks are blacked out. "VOW" means "vertrokken onbekend waarheen" (left, whereabouts unknown). Many cards of Jewish Amsterdammers were destroyed in WWII; some were reconstructed afterwards. From 1991 new residents and births were registered only in the national GBA.

## Privacy and access

- Scans of cards of persons born less than 100 years ago are not shown online, because they may still be alive. `deceased_reported: true` (shown as "Overleden: Ja") means the archive has received proof of death; then the card can be requested. A request needs the full name, exact birth and death dates and official proof of death, at least three months after the death; see archief.amsterdam/uitleg/indexen/28-persoons-en-archiefkaarten. People can see their own card at the archive's information centre with valid ID.
- Do not use these indexes to look up, locate or profile living private persons, and do not compile information about a private individual across sources unless the user is researching their own family or a historical person. Summarise records about private persons by event and keep personal details to what the user's question needs.
- Some sources concern sensitive histories (WWII police reports, forced labour, patients' registers, convictions): report them factually and without speculation.

## Reporting

- Give the archive link per record: [name, source, date](url).
- Index data can contain transcription errors and names in the wrong field; tell the user to check the scan before relying on a detail.
- Answer in the user's language.
