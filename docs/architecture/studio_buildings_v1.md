# Studio Buildings v1

**Engine:** Godot 4.7.2  
**Branch:** \`main\`
**Status:** interactive placement, workplace assignment, cutaway production interiors and staff/social facilities.

## Scope

Studio Buildings v1 replaces the two placeholder cubes in the main scene with interactive, procedurally assembled buildings and adds a basic construction workflow.

Implemented building types:

| Type ID | Display name | Footprint | Workplaces | Accepted professions |
|---|---|---:|---:|---|
| \`script_department\` | Сценарный отдел | 8 × 6 m | 3 | Screenwriter, producer, casting director |
| \`sound_stage\` | Съёмочный павильон | 14 × 12 m | 8 | Actor, extra, director, camera operator, technician, production designer, producer |
| \`editing_suite\` | Монтажный отдел | 10 × 8 m | 3 | Film editor |
| \`prop_warehouse\` | Склад реквизита | 10 × 8 m | 0 | Storage only; no employee workplace slots |

Three starter buildings are spawned when the main scene initializes:
- Script Department at \`(-16, 0, -16)\`.
- Sound Stage №1 at \`(0, 0, 0)\`.
- Prop Warehouse at \`(20, 0, 10)\`.

The building models are assembled from reusable Godot primitive meshes. No external art assets are required for this prototype.

## Architecture

### Domain

- \`StudioBuildingCatalog\` contains immutable type definitions, footprints, workplace capacity and accepted professions.
- \`StudioBuildingData\` represents one placed building and supports dictionary serialization.
- \`StudioBuildingPlacementRules\` is a presentation-independent placement validator. It checks plot bounds, rotated footprints and minimum spacing.

### Presentation

- \`StudioBuildingActor\` owns building identity, selection, cutaway state, navigation and public gameplay interfaces. It composes shared shell construction with type-specific visual builders.
- \`StudioBuildingVisualFactory\` creates reusable primitive meshes, floor/wall panels, collision bodies, world-space labels, film slates, camera rigs and light stands. The actor delegates these low-level construction helpers while retaining building identity, navigation and gameplay state.
- \`StudioSoundStageVisualBuilder\` receives \`StudioBuildingVisualFactory\` as an explicit dependency and assembles the three independent sound-stage architectures and their interiors. It returns visual references, production-slate labels and workplace points to the actor without owning navigation or production state.
- \`StudioTVStudioVisualBuilder\` receives the shared visual factory and assembles the separate broadcast pavilion, including its LED wall, host/guest area, audience seating, camera rigs, control console and ten workplace marks. It returns the roof and workplace points to the actor; it does not own building navigation or identity.
- \`StudioOfficeVisualBuilder\` receives the shared visual factory and assembles the Script Department and Editing Suite as distinct office interiors. It returns the roof and workplace points to the actor; office workflows and navigation remain outside the builder.
- \`StudioFacilityVisualBuilder\` receives the shared visual factory and assembles the Prop Warehouse, Fitness Center, Studio Lounge, Cafeteria, Staff Housing and Star Bungalow. It returns the roof/workplace metadata and warehouse inventory root/marks; the actor retains inventory updates and simulation-facing APIs.
- \`StudioBuildingNavigationController\` receives the placed building's interior transform, entrance/workplace metadata, Domain navigation system and live set-dressing root. It owns indoor workplace/exit path construction, per-building obstacle layouts and sound-stage scene routing. The actor retains the same public navigation methods as compatibility adapters; outdoor routing remains in the manager.
- \`StudioBuildingMarkerProvider\` receives the interior transform, building data, workplace points and warehouse storage positions. It owns authored production marks, off-camera holding points, focus points, set-dressing positions, warehouse pickup marks and facility facing directions. The actor retains its existing marker APIs as compatibility adapters.
- \`StudioSetPropVisualBuilder\` receives \`StudioBuildingVisualFactory\` and creates the mesh hierarchy for each reusable catalogued prop. Warehouse ownership, prop location transitions, scene setup progress and installation/return lifecycle remain in the actor and set-logistics/inventory systems.
- \`StudioBuildingManager\` owns placed building instances, building creation, selection and subsystem composition.
- \`StudioBuildingPlacementController\` owns the construction palette, placement mode, preview, grid snapping, rotation and placement validation. It emits a placement request; the manager remains responsible for creating the building actor and notifying dependent systems.
- \`StudioBuildingInspectorController\` owns the selected building ID, context-inspector lifecycle, shared building/facility summaries and building-specific UI. It emits script-generation requests; the manager retains script-writing state and Domain system orchestration. Sound-stage and editing-suite detail sections remain delegated to their specialized controllers.
- \`StudioSetLogisticsController\` owns the set-dressing / set-strike task state machine, technician assignments, warehouse transfers and logistics route composition. \`StudioBuildingManager\` supplies building/scene operations through a narrow adapter and retains compatibility wrappers for the production coordinator.
- \`CharacterManager.get_employees()\` exposes a copy of the active roster for workplace and production interfaces.
- \`main.gd\` initializes the building manager after scene children have completed their setup.

### Placement controls

1. Click **Построить сценарный отдел**, **Построить съёмочный павильон** or **Построить монтажный отдел**.
2. Move the mouse over the plot to position the preview.
3. Placement snaps to a 2 m grid.
4. Green preview means valid placement; red means invalid.
5. Left click places the building.
6. Press \`R\` to rotate by 90 degrees.
7. Right click or \`Esc\` cancels build mode.

Placement is restricted to the current 100 × 100 m prototype plot. A 1.5 m minimum gap is enforced between building footprints. Buildings cannot overlap, obstruct the existing access road or extend beyond the plot.

Construction is free in this slice because Studio Economy has not been implemented. The UI states this explicitly.

## Building interactions

### Script Department

The building panel:
- lists active screenwriters available in the studio roster;
- allows the player to choose a screenwriter;
- exposes genre, scene count and role count;
- starts a time-based writing project and displays progress, remaining work time and interruptions;
- generates the structured script after the writing project is completed and displays its one-to-five-star potential rating and bounded popularity modifier.

### Sound Stage

The building panel:
- shows the latest generated script, if one exists;
- lists staff in professions accepted by the stage;
- checks the four initial crew positions: director, actor, camera operator and technician;
- reports how many required positions are currently covered.

The starting roster covers three of the four required positions. The standard recruitment market now guarantees at least one technician candidate in every eight-person market cycle.

The Sound Stage is the player-facing production workspace for Film Production v1. It hosts casting and crew assignments, scene blocking, rehearsal, takes, retakes and recorded scene results.

### Prop Warehouse

The warehouse is a dedicated storage facility rather than a staffed workplace. It has a cutaway interior with racks and shelf positions for the studio's reusable set props. The film production manager updates the shelf display as props are collected and returned. Technicians use the warehouse's storage marks as the endpoints of their indoor/outdoor delivery routes.

### Editing Suite

The building panel:
- lists assigned film editors;
- receives completed footage from the active Film Production project;
- lets the player prepare an editing project and reorder scenes before work begins;
- advances editing only while the selected editor is on shift and physically at the Editing Suite;
- displays assembly, fine-cut, sound-mix, color-grading and export progress.

The standard eight-person recruitment market guarantees one film editor. The Editing Suite has three cutaway editing consoles, monitors, a reference screen and an audio rack.


## Television Studio

The TV Studio is a separate 20 × 16 m broadcast pavilion, not a rescaled or recolored Sound Stage. Its dedicated architecture includes a flat industrial roof, control-room glazing, a multi-camera recording stage, segmented LED backdrop, host desk, guest seating, two audience rows, camera rigs, overhead lighting truss and a director's control console.

The building has ten authored workplace marks for a host, two guests, director, two camera operators, technician, producer, screenwriter and production designer. Its accepted-profession list is exposed to the building inspector, but the TV Studio does not automatically take permanent workplace assignments away from the Film Sound Stage. Television participants are intended to be called to the pavilion for scheduled TV sessions.

## Simulation boundaries

The current implementation does **not** yet:
- connect warehouse inventory locations to campaign SaveSystem state;
- charge construction or maintenance costs;
- simulate construction time;
- persist workplace assignments in a campaign save;
- use NavMesh pathfinding or dynamic obstacle avoidance;
- provide full skeletal work animations or interactive interior equipment;
- assign dedicated buildings to administration and marketing staff;
- persist building state in a campaign save.

Studio Operations v1 consumes accepted-profession lists and workplace capacities, routes employees through building entrances, and provides visible cutaway interiors with procedural props and work animations. Film Production v1 adds casting and shooting; Film Editing v1 adds the post-production workflow in the Editing Suite.

## Smoke tests

Run from the project root using Godot 4.7.2:

~~~powershell
& $godot --headless --path . --script res://tests/studio_building_system_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_building_interior_smoke_test.gd
~~~

The interior test covers room props, workplace navigation and exit routes for the TV Studio as well as the existing building types.


## Размеры съёмочных павильонов

Павильон строится в одном из трёх размеров:

| Размер | Площадь основания | Рабочие места |
|---|---:|---:|
| Малый | 10 × 8 м | 6 |
| Средний | 14 × 12 м | 8 |
| Большой | 22 × 18 м | 12 |

Размер фиксируется в данных здания и сохраняется при сериализации. Он участвует в проверке границ участка, пересечений, геометрии интерьера, навигации и расчёте рабочих мест. Уже построенные здания не меняют размер при выборе нового павильона.

## Звёздный домик

Звёздный домик — отдельное жилое помещение с одной кроватью. В него направляется популярный актёр с популярностью от 70 пунктов, если свободное место доступно; остальные сотрудники продолжают пользоваться общим домиком персонала. Сон в звёздном домике восстанавливает энергию и снижает стресс быстрее, чем обычное жильё.

## Departure routing and navigation

When an employee leaves a workplace after a rehearsal or shooting take, CharacterManager requests a fresh exit path from the employee's current world position. It does not assume that the employee is still standing at the assigned workstation; scene marks can be several metres away from the cached commute endpoint. CharacterActor follows this live exit route to the actual building entrance.

Large-stage set-wall navigation clearance is aligned with the employee capsule size so smoothed A* routes do not send characters too close to collision walls. Staff-housing exit requests without an explicit bed slot resolve the nearest occupied bed before constructing the route, preventing the current bed from being treated as an impassable obstacle.

## Follow-up: distinct sound-stage architecture

Sound-stage tiers are separate architectural compositions, not scaled copies of one building:
- Small: compact low-rise studio with a gable roof, narrow loading entrance, compact set and six crew positions (10 × 8 m).
- Medium: rectangular industrial pavilion with a flat roof, standard loading door, two-camera interior and eight crew positions (14 × 12 m).
- Large: high-bay production hangar with roof trusses, skylights, a control-room window, taller loading door, expanded set/camera layout and twelve crew positions (22 × 18 m).

Each model keeps an identity interior transform. Footprint, wall positions, roof geometry, set dimensions, camera/light placement, navigation bounds and crew marks are authored for that tier.

## New staff/social buildings

- Fitness Center: 12 × 10 m, four training stations. Actors visit between 17:00 and 19:00; training gradually increases persistent physical fitness while consuming energy.
- Studio Lounge: 14 × 12 m, six social places. Employees visit between 19:00 and 21:00; lounge time reduces stress, improves morale and advances reciprocal relationship scores.
- Star Bungalow: 10 × 8 m, one private bed for an eligible popular actor.

Building inspector cards show the selected stage's architecture profile and explain each facility's capacity and effects.

## Current building catalog and stage architecture

The initial catalog table above describes the original Buildings v1 set. The current catalog also includes cafeteria, staff housing, star bungalow, fitness center, studio lounge and a dedicated TV Studio. Sound stages now have three distinct architectural models, not one model scaled to different footprints:

| Type ID | Display name | Footprint | Workplaces | Notes |
|---|---|---:|---:|---|
| `tv_studio` | Телевизионная студия | 20 × 16 m | 10 | Separate multi-camera broadcast pavilion for series and talk shows |

| Stage model | Footprint | Crew slots | Architecture |
|---|---:|---:|---|
| Small | 10 × 8 m | 6 | Compact low-rise studio with a gable roof and narrow loading entrance |
| Medium | 14 × 12 m | 8 | Rectangular industrial pavilion with a flat roof and standard loading door |
| Large | 22 × 18 m | 12 | High-bay production hangar with roof trusses, skylights, control-room glazing and a taller loading door |

All three models have identity interior transforms. Their wall positions, roof geometry, set dimensions, camera/light placement, navigation bounds and crew marks are authored independently for each tier. The production selector chooses the smallest operational stage that satisfies the current script and owned set-piece requirements.

The Fitness Center provides four training stations; the Studio Lounge provides six social places. See staff_facilities_v1.md for schedules and simulation effects.


## Building test suites

The top-level `tests/studio_building_interior_smoke_test.gd` remains the single SceneTree entry point. It runs the geometry, sound-stage, facility and employee integration suites through a shared RefCounted test base, preserving one aggregated assertion list and process exit code. Dedicated navigation, marker-provider and set-prop visual-builder smoke tests cover their extracted components directly.


### Fixture isolation

The interior smoke suites run cases with separate building fixtures. Each case frees its spawned building nodes immediately after its assertions, avoiding stacked physics wall colliders when testing employee movement and TV Studio routes. The top-level runner asserts that no building fixtures leak between suites.


### Workstation route contracts

Forward and reverse workplace routes use the same authored per-slot doorway offset in offices and warehouses. Sound stages, TV studios and shared facilities retain the centered entrance. Workplace routes contain at least four positions (outside, inside, corridor, workstation); the navigation solver may add intermediate positions around obstacles. Wall-collision bodies expose a consistently named `CollisionShape3D` child, preserving scene-path checks and character collision.


### Expanded studio plot

Studio construction limits now span 168 × 168 world units (previously 96 × 96); the ground plane and access road are correspondingly wider/longer, and camera zoom supports the expanded site. Production-start readiness reports an actionable reason instead of showing a generic missing-crew message, and a suitably sized stage with the most assigned staff is preferred when multiple stages exist.
