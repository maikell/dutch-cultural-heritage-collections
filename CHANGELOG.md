# Changelog

## 0.5.0 - 2026-11-16
- New service: Noord-Hollands Archief (`noord-hollands-archief`), person records via the Open Archives API and archive search links, with skill `noord-hollands-archief`.
- New service: NIOD Institute for War, Holocaust and Genocide Studies (`niod`), archive descriptions via the EHRI portal API and archive search links, with skill `niod`.
- The Rotterdam server is now the shared script `mcp/open_archives_mcp.ps1` (`-Archive srt` or `-Archive nha`); tool names are unchanged.
- Archive search links leave out empty fields.
- Added an infographic of the plugin and its services (`docs/infographic.svg`), a disclaimer and a versioning section in the README.
- Version 0.4.0 (Amsterdam and Rotterdam) was not published separately; it is part of this release.

## 0.4.0 - 2026-11-16
- New service: Amsterdam City Archives person indexes (`amsterdam-city-archives`), including the personal and archive cards 1939-1994, with skill `amsterdam-city-archives`.
- New service: Rotterdam City Archives (`rotterdam-city-archives`): person records via the Open Archives API and search links for archives and inventories, with skill `rotterdam-city-archives`.

## 0.3.0 - 2026-11-15
- Renamed the plugin from `erfgoed` to `dutch-cultural-heritage-collections` ("Dutch cultural heritage collections").
- Added a marketplace manifest so the plugin can be installed from GitHub.

## 0.2.0 - 2026-11-15
- All plugin text is now in English: tool names, parameters, output fields, error messages, skill and README.
- Tools renamed: `delpher_zoeken` -> `delpher_search`, `delpher_tekst` -> `delpher_text`, `delpher_tijdlijn` -> `delpher_timeline`.
- Licensed under Creative Commons Attribution 4.0 International (CC BY 4.0).

## 0.1.0 - 2026-11-15
- First version of the `erfgoed` plugin with the Delpher service (MCP server `delpher` and skill `delpher`).
