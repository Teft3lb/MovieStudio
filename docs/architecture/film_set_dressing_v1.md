# Film Set Dressing v1

**Engine:** Godot 4.7.2  
**Integration:** directly in main  
**Status:** first playable reusable-prop workflow.

## Goal

Make the Sound Stage feel like a working film set without turning filming into a slow construction simulator. The player buys a small library of reusable set pieces. When a film scene calls for a recognizable location, the production system selects matching owned props and the technician installs them before rehearsal.

The player does not manually place every object in this slice. The focus is a visible, readable production sequence: prepare the scene, watch the technician dress the set, then watch the actors rehearse and shoot.

## Runtime ownership

- **StudioSetCatalog** defines thematic prop groups, item prices, quality bonuses and scene-to-set matching.
- **StudioSetInventory** owns the prototype prop budget, purchased prop IDs and each prop's physical location: warehouse, in transit to stage, on stage or in transit back to the warehouse. Purchased props remain reusable.
- **FilmProductionSystem** normalizes one setup plan per scripted scene, scales installation/strike phase durations by the available technician count, records the set result after shooting and completes the scene only after strike.
- **FilmProductionProject** serializes each scene setup plan and technician count. A plan can be refreshed during Preparation and before installation starts.
- **StudioBuildingManager** provides the Decor Shop workspace, maintains warehouse stock visuals, assigns prop trips to available Sound Stage technicians and blocks production phase progress until each logistics task is complete.
- **StudioBuildingActor** owns the Sound Stage set root and Prop Warehouse interior, creates reusable prop meshes, exposes installation/storage marks and only clears a set after the strike workflow returns all pieces.
- **StudioNavigationSystem** builds obstacle-aware routes between the Sound Stage, warehouse and employee workstations.
- **CharacterActor** follows the combined indoor/outdoor routes; **CharacterVisual** shows installation/removal poses and a transport case while a technician carries a prop.

## The Set Dressing Workshop

The standalone **Decor Shop** workspace exposes seven themed groups. It is available from the bottom navigation and is not embedded in the Sound Stage inspector, so players can browse and buy reusable pieces without first selecting a building:

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

For each scene, the catalog checks location text first, then action text, and finally uses a genre-specific fallback group when the generated wording is not recognized. The keyword map covers the current ScriptGenerator location catalogue; specific locations take precedence over genre defaults.

Every catalog item in the matched group is a required scene prop. Owned items are included in the physical setup; missing items are retained in the plan and reduce set-dressing quality. A scene with no owned items still uses the neutral stage, but its missing requirements remain visible to the player. Props are reusable across matching scenes and future films.

A scene setup contains its scene ID, matched source group, visible set ID/title, installed prop IDs, required and missing prop IDs, setup duration and set-dressing quality.

The current installation duration is two base minutes plus one parallel work round per batch of props: `2 + ceil(installed_prop_count / technician_count)`. A neutral scene therefore still has a short two-minute equipment/setup phase. Strike uses `1 + ceil(installed_prop_count / technician_count)` minutes, including a one-minute neutral-stage clearance. The plan is stored on FilmProductionProject and is not recalculated every game minute. While the scene is in Preparation, a successful purchase refreshes its installed/missing prop list, setup duration and quality. The current scene's plan is locked once technicians begin collecting props; later purchases are evaluated for the next scene during its Preparation phase.

## Production phase integration

Each scene follows:

1. **Preparation** — director and camera operator prepare blocking; cast gathers on stage.
2. **Set Dressing** — each assigned technician walks to the warehouse, retrieves a purchased prop, carries it to the Sound Stage and installs it. Multiple technicians can deliver different pieces concurrently.
3. **Rehearsal** — actors rehearse with visible gestures and partner reactions.
4. **Shooting** — actors perform their generated action/dialogue; camera rigs track the blocking.
5. **Review** — the director reviews the take and production quality is calculated.
6. **Set Strike** — after a scene is accepted, technicians remove each installed piece, carry it back to the warehouse and return it to stock. The next scene cannot begin until the previous set is cleared.

The director, camera operator and primary technician remain required crew members. Production routes them to their Sound Stage workstations regardless of shift state; cast members are released during Preparation and Set Dressing. Every additional technician assigned to the Sound Stage joins the logistics pool. During Set Dressing, each worker walks from the stage to the warehouse, retrieves a purchased piece, carries it to an installation mark and installs it. Workers handle separate pieces concurrently; when there are fewer technicians than props, they make additional trips. Production waits until every delivery is complete and the workers have returned to their stage workstations before the rehearsal phase can advance. Set Strike follows the reverse route: technicians remove props, carry them to the warehouse and return them to shelf stock. The phase cannot finish while any piece remains on stage. During Rehearsal, Shooting and Review, cast members and other staff assigned to the Sound Stage who are not performing in the current scene move to holding marks behind the camera line. The director, camera operator and technician remain at their dedicated stations unless a logistics task moves the technician. Non-performing employees receive an explicit off-camera task/status and return to their workstations during Set Strike or when production ends. Manual debug fast-forward snaps off-camera staff to their holding marks, preserving deterministic phase progress.

If a scene has no owned props for its location, the technician performs a short equipment/neutral-stage setup. Missing props never block production start: the player may proceed with a neutral or incomplete set, while the scene quality score is reduced for every missing required item. The pre-production panel previews missing catalog items, and the active production panel shows scene coverage and the current set-dressing quality. There is no indefinite rehearsal or setup loop: every phase has a bounded duration and production transitions automatically.

## Physical presentation

The Sound Stage owns an Interior/SetDressing node. Each scene plan creates hidden child Node3D instances at fixed installation positions on the central set platform. The installation marks are derived from the same position list as the prop instances, so a technician reaches the object they are visibly installing. A technician visits the corresponding mark, performs the installation action and makes that individual prop visible. The actor refuses to replace a non-empty set root; the manager can clear it only after every on-stage prop has passed through removal and warehouse return.

The Prop Warehouse is a separate cutaway building with storage racks and a live shelf display. Every owned prop in warehouse stock has a visible shelf representation. When a technician picks up a prop, the shelf instance is removed and a transport case appears in the character's hands. The case remains visible during the trip to the stage; it is hidden after installation. During Set Strike the same case appears while a technician carries a removed piece back to storage. The warehouse pickup marks and Sound Stage installation marks are connected through the employees' existing workplace entrance routes and obstacle-aware outdoor navigation.

Props are not removed when a scene changes. They are hidden one at a time only after the technician reaches the piece and completes the removal action; the stage root is cleared after the inventory confirms that no prop remains on stage.

The current set pieces are stylized primitive meshes. Their purpose is to make the technician's work and the scene's art direction visible; imported production-quality models, lighting variants, wall kits and a player-facing set editor remain future work.

## Navigation and wall avoidance

StudioNavigationSystem uses Godot 4.7.2 AStarGrid2D to build a 2D X/Z route with a configurable cell size and rectangular obstacle footprints.

Outdoor workplace travel treats each building footprint as an obstacle. The route reaches the destination building's outside entrance first, then follows the building's existing entrance/corridor/workstation path. When an employee changes buildings, the employee exits through the previous workplace route before a new outdoor route is calculated.

Sound Stage scene paths use local obstacle footprints for both side walls and the rear backdrop. Visible set props are added as obstacles so actors and technicians do not cut through installed objects. If a route starts inside an installed prop or ends at that prop's installation mark, only that endpoint prop is omitted from the obstacle set for the route; this lets the technician leave a newly installed piece or approach a piece during strike without making the rest of the set non-solid. A line-of-sight smoothing pass removes unnecessary grid turns while retaining clearance from other obstacles.

This is a bounded solution for the current small studio map. It is not a general NavMesh, does not yet model moving crowds or arbitrary rotated obstacle polygons, and should be revisited if the world grows substantially.

## Quality contribution

The scene setup stores a set-dressing quality score starting from a neutral baseline of 45. Owned pieces add their catalog quality bonuses; each missing required piece applies a 10-point set-dressing penalty before the score is clamped. The production quality calculation applies the existing 14% scene modifier against the neutral baseline, so a missing set lowers the scene score without overpowering acting, directing, camera work or script potential. Production start remains available regardless of set coverage.

Completed scene results retain the set ID/title, set-dressing quality, installed prop IDs, required prop IDs and missing prop IDs for later editing, release and review systems.

## Tests

Run from the project root with Godot 4.7.2:

~~~powershell
& $godot --headless --path . --script res://tests/studio_navigation_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_set_inventory_smoke_test.gd
& $godot --headless --path . --script res://tests/film_production_system_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_building_interior_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_building_system_smoke_test.gd
& $godot --headless --path . --script res://tests/film_scene_performance_smoke_test.gd
~~~

The navigation test checks detours around outdoor building footprints and Sound Stage walls. The inventory test checks purchases, valid/invalid location transitions, location serialization, scene matching and technician-scaled setup duration. The production test checks installation/strike durations, technician scaling, project serialization and recorded scene props. The interior test checks warehouse shelves, pickup marks, carrying visuals and the rule that a new scene cannot replace the old set before explicit strike clearance. The performance test checks speaking mouth motion, plus a stage employee walking behind the camera and returning to the workstation.

## Explicit limitations

- The prototype uses a separate 3,000-unit set budget; it is not connected to the future Studio Economy ledger.
- Purchased inventory and prop locations have serialization methods, but campaign SaveSystem integration does not yet exist.
- Set matching is based on a deterministic Russian-language keyword map with genre fallbacks; more complex screenplay tags and custom set requirements remain future work.
- All matching owned props are used automatically; there is no per-scene prop picker yet.
- Prop positions are selected from a fixed layout; the player cannot manually place, rotate or remove set pieces.
- Visuals use primitive meshes; imported models, production lighting, dressing presets and environment-specific wall kits are future work.
- Navigation is grid-based and static; crowd avoidance, arbitrary rotated polygons and dynamic obstacles are future work.
- The production estimate covers phase work rounds; actual walking time between the stage and warehouse is simulated by the world clock and is not included in the displayed remaining-work estimate.
