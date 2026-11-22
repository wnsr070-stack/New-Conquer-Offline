# Wilderness Visual Reference Specification

Status: approved visual direction for Wilderness Checkpoints 2, 3 and 4  
Reference: user-supplied isometric wilderness map image (1536 × 1230 px), approved on 2026-11-22.  
Project branch for the current implementation: `test/wilderness-checkpoint2-terrain`.

## Visual language extracted from the approved reference

- A bright, saturated, lush green grassland is the dominant surface; it should read as healthy vivid grass, not pale olive, grey, dusty, or washed out.
- The playable wilderness is a broad, coherent landscape with a clear central region and natural transitions into surrounding terrain.
- A continuous dramatic mountain chain occupies the far northern/back edge. Peaks vary in height and silhouette; snow is restricted to the northern peaks.
- The mid-ground uses broad, raised, stepped grassy plateaus and rolling hills rather than isolated small rock lumps or dark sunken patches.
- Natural rocky outcrops and boulders interrupt plateau edges and slopes without replacing the grassy top surfaces.
- A winding blue river belt is a major visual landmark around the central region. Checkpoint 2 reserves its low winding corridor; the actual blue water course and bridge integration are planned for Checkpoint 3.
- Light dirt paths connect the central crossings/bridges to the outer terrain and wind naturally through the grass.
- Forest clusters, scattered trees, rocks and small environmental details provide scale and visual richness.
- The composition is readable from an elevated, wide isometric camera: central landforms remain visible together, with the northern mountain wall framing the horizon.

## Checkpoint 2 engineering targets

- Wilderness ground plane: 2200 × 2200 metres.
- Grass: Poly Haven Leafy Grass PBR maps (albedo/diffuse, normal, roughness), vivid green tint `Color(0.52, 0.82, 0.38)`; retain the already accepted roughness/specular treatment.
- North mountain chain: two staggered, connected rows with overlapping silhouettes. Front row height 30–45 m; rear row height 55–85 m. Adjacent masses should visually overlap by approximately 40–50% so no sky gaps remain along the northern horizon.
- Snow treatment: northern mountain peaks only; no snow on plateaus or southern/eastern/western hills.
- Grassy plateaus around the city: raised and visibly stepped, 10–22 m high, with typical horizontal dimensions 70–130 m. Keep bright grass on top and natural exposed rock on selected edges.
- Required rock assets: `rock_face_01.glb`, `rock_face_02.glb`, and `boulder_01.glb`.
- Preserve the 320 × 320 m Twin City, 18 m moat, all four bridges, and a level 25 m safety apron around the moat and bridge exits.
- Reserve a low, winding 30 m corridor around the city for the future river. Do not fill it with water in Checkpoint 2; water shaping and final bridge/river integration belong to Checkpoint 3.
- Add light dirt paths from all four bridge exits toward the surrounding plateaus.
- Close the far east, west and southern horizon with connected low terrain. Use a soft sky-blue WorldEnvironment fog beginning at 650 m to hide the square ground edge and distant brown void.
- Every placed terrain mass must pass a real transformed AABB check and have its base buried between 1.5 m and 3 m below the ground reference. Reject narrow vertical pillars and floating masses.
- Keep natural materials matte: high roughness, low specular and zero metallic on exposed rock.
- Exclude `alpine_and_arctic_biomes.glb` completely; it is not an approved visual asset.

## Checkpoint sequence

- Checkpoint 2: establish the green wilderness, northern mountain wall, raised plateaus, rock edges, horizon closure, river corridor reservation and bridge approach paths.
- Checkpoint 3: form the winding blue river in the reserved corridor and integrate the crossings/bridges while preserving the city safety apron.
- Checkpoint 4: enrich and polish the wider wilderness composition (vegetation, secondary paths, details and visual QA) without changing the approved reference direction.

## Approval rule

The reference image establishes the target art direction, not automatic approval of generated screenshots. Each checkpoint's actual Godot PNG captures must be shown and visually approved before the next checkpoint is treated as accepted or merged into a protected branch.
