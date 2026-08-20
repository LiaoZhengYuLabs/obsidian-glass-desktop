# Asset Catalog

| Asset group | Location | Public status | Notes |
|---|---|---|---|
| WebGL fluid source | `src/components/wallpaper/` | Included with attribution | See `LICENSE.txt`; derived from the cited MIT projects |
| Deep-space layers | `src/components/wallpaper/space-environment/` | Included as project source | Stars, constellations, galaxies, meteors, parallax, and low-frequency motion |
| Starter animals | `src/components/wallpaper/animal-trail/assets/` | Included for the eight default sprites | Verify individual rights before redistribution outside this project |
| Petdex catalogue metadata | `animal-trail/catalog/creatures.js/json` | Included as a source snapshot | Contains source URLs and creator handles, not a blanket asset license |
| Full Petdex sprite cache | local-only `animal-trail/catalog/assets/` | Ignored by Git | Approximately 3 GB; synchronize explicitly |
| Sidebar application icons | `src/components/sidebar/assets/` | Review before public release | May be trademarks or vendor-provided artwork |
| User wallpaper/music/subtitles | not bundled | Excluded | Keep private and outside the repository |
| Screenshots | `assets/screenshots/` | Include only sanitized PNGs | Remove chat text, usernames, file paths, and tokens |

Use `tools/Sync-AnimalTrailAssets.ps1` for an explicit local asset sync. Do not assume that a public catalogue URL grants redistribution rights.
