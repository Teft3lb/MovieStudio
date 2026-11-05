# Film Set Dressing v1

**Engine:** Godot 4.7.2  
**Integration:** directly in main  
**Status:** first playable reusable-prop workflow.

## Goal

Make the Sound Stage feel like a working film set without turning filming into a slow construction simulator. The player buys a small library of reusable set pieces. When a film scene calls for a recognizable location, the production system selects matching owned props and the technician installs them before rehearsal.

The player does not manually place every object in this slice. The focus is a visible, readable production sequence: prepare the scene, watch the technician dress the set, then watch the actors rehearse and shoot.

## Runtime ownership

- **StudioSetCatalog** defines thematic prop groups, item prices, quality bonuses and scene-to-set matching.
- **StudioSetInventory** owns the prototype prop budget and purchased prop IDs. Purchased props are reusable and are not consumed by production.
- **FilmProductionSystem** normalizes one setup plan per scripted scene, includes setup time in the production estimate, advances the set-dressing phase and records the used set and props in the completed scene result.
- **FilmProductionProject** serializes the scene setup plans so a running film keeps the same art direction if inventory changes later.
- **StudioBuildingManager** provides the Set Dressing Workshop UI, builds scene plans from the current inventory and coordinates technician movement.
- **StudioBuildingActor** owns the physical set-dressing root, creates prop meshes, progressively reveals installed pieces and provides navigation marks.
- **StudioNavigationSystem** builds obstacle-aware paths for outdoor workplace travel and movement inside the Sound Stage.
- **CharacterActor** follows supplied scene paths; **CharacterVisual** provides a distinct set-piece installation pose.

## The Set Dressing Workshop

The Sound Stage inspector exposes seven themed groups:

| Set group | Example pieces |
|---|---|
| City Street | Shopfront, street lamp, bench |
| Family Home | Sofa, coffee table, floor lamp |
| Forest | Trees, rocks, trail sign |
| Lighthouse | Keeper console, beacon, railing |
| Industrial | Cargo crates, pipes, work light |
| Office | Desk, bookshelf, evidence board |
| Science Fiction | Lab console, reactor, holographic display |

The initial prototype budget is 3,000 studio units. Every item has a fixed catalog price. A purchase validates the prop ID and catalog price, rejects duplicate purchases, checks the remaining budget, deducts the price and records the owned prop ID.

The UI disables already-purchased items and items the current budget cannot afford. Buying an item refreshes the inspector. The budget is intentionally separate from Studio Economy for this development slice; it is not a claim that the final economy will use a second wallet.

## Scene matching

For each scene, the catalog first checks its location text and then its action text. A deterministic Russian-language keyword map assigns the scene to one of the seven thematic groups.

All owned props from the matched group are included in the scene setup. If the studio owns no props for that group, the scene uses the neutral stage. Props are reused across matching scenes and future films.

A scene setup contains its scene ID, matched set/group ID and localized title, source group ID, selected prop IDs, setup duration and set-dressing quality.

The current duration rule is two base minutes plus one minute per installed prop, capped at ten minutes. A neutral scene therefore still has a short two-minute equipment/setup phase. The plan is stored on FilmProductionProject and is not recalculated every minute.

## Production phase integration

Each scene follows:

1. **Preparation** — director and camera operator prepare blocking; cast gathers on stage.
2. **Set Dressing** — the technician moves between installation marks. The next prop appears when the corresponding part of the setup phase is complete.
3. **Rehearsal** — actors rehearse with visible gestures and partner reactions.
4. **Shooting** — actors perform their generated action/dialogue; camera rigs track the blocking.
5. **Review** — the director reviews the take and production quality is calculated.

The technician remains a required crew member. During Set Dressing, the technician may leave the normal workstation to install pieces. Production waits while the technician travels to the current installation mark; this prevents the phase clock from consuming the setup duration while the technician is still walking. Manual debug fast-forward snaps the active technician to the current installation mark at the end of each skipped minute, preserving deterministic phase progress.

If a scene has no owned props for its location, the technician performs a short equipment/neutral-stage setup. There is no indefinite rehearsal or setup loop: every phase has a bounded duration and production transitions automatically.

## Physical presentation

The Sound Stage owns an Interior/SetDressing node. Each scene plan creates child Node3D instances at a small fixed set of installation positions. Their visual meshes are assembled from the existing box, cylinder and sphere primitives, so no external art assets are required for the first playable slice.

Props start hidden. During Set Dressing, the number of visible props follows phase progress. The same scene key prevents unnecessary recreation every game minute. When the scene changes, the old prop roots are replaced with the next scene's planned props.

The current set pieces are stylized primitive meshes. Their purpose is to make the technician's work and the scene's art direction visible; imported production-quality models, lighting variants, wall kits and a player-facing set editor remain future work.

## Navigation and wall avoidance

StudioNavigationSystem uses Godot 4.7.2 AStarGrid2D to build a 2D X/Z route with a configurable cell size and rectangular obstacle footprints.

Outdoor workplace travel treats each building footprint as an obstacle. The route reaches the destination building's outside entrance first, then follows the building's existing entrance/corridor/workstation path. When an employee changes buildings, the employee exits through the previous workplace route before a new outdoor route is calculated.

Sound Stage scene paths use local obstacle footprints for both side walls and the rear backdrop. Visible set props are added as obstacles so actors and technicians do not cut through installed objects. A line-of-sight smoothing pass removes unnecessary grid turns while retaining clearance from obstacles.

This is a bounded solution for the current small studio map. It is not a general NavMesh, does not yet model moving crowds or arbitrary rotated obstacle polygons, and should be revisited if the world grows substantially.

## Quality contribution

The scene setup stores a set-dressing quality score. The production quality calculation adds a small modifier based on the difference from the neutral baseline. The base weights for acting, directing, camera, technical work and script potential remain unchanged; purchased decorations are a polish bonus, not a replacement for staff skills or screenplay quality.

Completed scene results retain the set ID/title, set-dressing quality and installed prop IDs for later editing, release and review systems.

## Tests

Run from the project root with Godot 4.7.2:

~~~powershell
& $godot --headless --path . --script res://tests/studio_navigation_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_set_inventory_smoke_test.gd
& $godot --headless --path . --script res://tests/film_production_system_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_building_interior_smoke_test.gd
& $godot --headless --path . --script res://tests/film_scene_performance_smoke_test.gd
~~~

The navigation test checks detours around outdoor building footprints and Sound Stage walls. The inventory test checks purchases, duplicate/invalid purchases, serialization, scene matching and reusable prop plans. The production test checks the bounded Set Dressing phase, estimates, project serialization and recorded scene props. The interior test checks physical prop creation and progressive visibility. The performance test checks speaking mouth motion.

## Explicit limitations

- The prototype uses a separate 3,000-unit set budget; it is not connected to the future Studio Economy ledger.
- Purchased inventory has serialization methods, but campaign SaveSystem integration does not yet exist.
- Set matching is based on a small deterministic Russian-language keyword map.
- All matching owned props are used automatically; there is no per-scene prop picker yet.
- Prop positions are selected from a fixed layout; the player cannot manually place, rotate or remove set pieces.
- Visuals use primitive meshes; imported models, production lighting, dressing presets and environment-specific wall kits are future work.
- Navigation is grid-based and static; crowd avoidance, arbitrary rotated polygons and dynamic obstacles are future work.
