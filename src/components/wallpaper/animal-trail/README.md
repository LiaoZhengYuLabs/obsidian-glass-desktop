# Animal Trail System

This package keeps the local animal-trail renderer, eight starter presets, and the full Petdex creature catalogue. The renderer caps active animals at 40 and keeps the catalogue limit at 80 so the wallpaper remains responsive on ordinary Windows 11 hardware.

## Included

- `animal-trail.js`: canvas renderer, idle play, cursor interaction, and performance caps.
- `catalog/creatures.js` and `catalog/creatures.json`: a 1,593-entry catalogue snapshot with Petdex source URLs.
- `assets/`: intentionally empty in the public repository. It is the local cache location for eight starter sprites when you synchronize or install them yourself.

The full catalogue sprite cache is about 3 GB (`catalog/sync-report.json`). No community sprite binaries are committed to the public repository. Run `tools/Sync-AnimalTrailAssets.ps1 -DownloadFromPetdex` to fetch only the eight starter sprites into your own local cache, or add `-IncludeAllCatalogAssets -Force` only when a local full cache is needed. You can instead set `OBSIDIAN_GLASS_ANIMAL_SOURCE` to an existing cache. This keeps the default checkout fast and avoids redistributing assets whose individual creator terms are not represented by the wallpaper MIT notice.

The catalogue metadata is retained for discovery. Public checkouts can render an available catalog sprite from its original URL; for offline use, synchronize it into the local cache. Users should verify the rights for any community sprite before publishing or redistributing it.
