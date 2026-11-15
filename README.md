# Dutch cultural heritage collections

Claude plugin for searching and reading Dutch cultural heritage collections: digitised newspapers, books, magazines, archives and image banks from Dutch libraries, archives and museums (GLAM institutions). Each collection is a separate service with its own MCP server in `mcp/` and its own skill in `skills/`.

## Install

```
/plugin marketplace add maikell/dutch-cultural-heritage-collections
/plugin install dutch-cultural-heritage-collections@dutch-cultural-heritage-collections
```

Or download the repository as a ZIP and add it as a plugin in Claude.

## Services

More collections will follow, starting with the image bank of the Amsterdam City Archives (Stadsarchief Amsterdam).


| Service | MCP server | Tools | Source |
|---------|-----------|-------|--------|
| Delpher (KB) | `delpher` | `delpher_search`, `delpher_text`, `delpher_timeline` | KB SRU search service `jsru.kb.nl` and resolver `resolver.kb.nl` (open, no key) |

### Delpher

Delpher is the Dutch national platform for digitised historical texts, run by the Koninklijke Bibliotheek (KB, National Library of the Netherlands).

- **delpher_search**: search newspapers (1618-1995), magazines, books and ANP radio bulletins (1937-1984), with filters for period, newspaper, type (article, advertisement, family notice, illustration) and sort order (relevance, oldest, newest).
- **delpher_text**: the full OCR text of a newspaper article or radio bulletin, or of one page of a book or magazine.
- **delpher_timeline**: the number of hits per year or per decade.

Limitations: protected texts (copyright) can only be read on Delpher or in the KB reading room; for magazines, books and radio bulletins the search service holds only part of what delpher.nl shows. See the KB terms of use for large-scale reuse (dataservices@kb.nl).

## Requirements

Windows with Windows PowerShell 5.1 (installed by default) or PowerShell 7. No extra packages needed.

## Adding a service

1. Add a server as `mcp/<service>_mcp.ps1` (same structure as `delpher_mcp.ps1`: JSON-RPC over stdio, validated input, clear error messages).
2. Register it in `.mcp.json`.
3. Write `skills/<service>/SKILL.md`.
4. Update the table above, `CHANGELOG.md` and the version in `.claude-plugin/plugin.json`.

## License

This plugin is licensed under the [Creative Commons Attribution 4.0 International License (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/). See `LICENSE`. Texts and images retrieved from Delpher remain subject to the terms of the KB and the rights holders.
