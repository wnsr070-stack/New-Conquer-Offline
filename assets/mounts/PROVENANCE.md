# Phase 5A mount asset provenance

| Project file | Actual model identity | Source | License |
|---|---|---|---|
| `steed_horse.glb` | Horse | Quaternius Ultimate Animated Animal Pack; public GLB mirror: https://github.com/trebeljahr/quaternius-showcase | CC0-1.0 (pack license and source page) |
| `mount_deer.glb` | Deer | Quaternius Ultimate Animated Animal Pack; public GLB mirror: https://github.com/trebeljahr/quaternius-showcase | CC0-1.0 (pack license and source page) |
| `mount_wolf.glb` | Wolf | Quaternius Ultimate Animated Animal Pack; public GLB mirror: https://github.com/trebeljahr/quaternius-showcase | CC0-1.0 (pack license and source page) |
| `mount_tiger.glb` | Sumatran Tiger | https://gobkit.com/freebies/animal012/SumatranTiger.glb | CC0-1.0 (Gobkit free library) |

Official Quaternius pack page: https://quaternius.com/packs/ultimateanimatedanimals.html
Quaternius pack announcement and CC0 statement: https://www.patreon.com/quaternius/posts/ultimate-animals-53427821
Gobkit CC0 library and API: https://gobkit.com/

The workflow verifies each binary GLB v2 header, declared byte length, JSON chunk, glTF 2.0 asset version, and non-empty mesh list. The Quaternius assets are resolved by their actual model names in the pack mirror, not by renaming unrelated models. All four files are stored under `assets/mounts/` and cached by Actions.
