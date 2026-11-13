# Modularization & Refactoring Roadmap

**Engine:** Godot 4.7.2  
**Architecture:** Domain / Core / Presentation  
**Working branch:** `main` (no feature branch until explicitly requested)

## Why now

The project has several scripts that combine unrelated responsibilities. The risk is not file length alone: UI construction, simulation state, scene geometry, navigation and production orchestration are evolving at different rates but currently share the same script-level state.

The refactoring must reduce coupling without changing gameplay behavior. This is an incremental extraction plan, not a rewrite.

## Current hotspots

Current approximate source line counts after the production, editing and logistics extractions:

| File | Lines | Main responsibilities currently mixed |
|---|---:|---|
| `studio_building_manager.gd` | 1,771 | Building lifecycle, script-writing simulation, inventory and module composition |
| `studio_building_actor.gd` | 807 | Building identity, selection, cutaway state, shared building shell and gameplay interfaces |
| `character_manager.gd` | 2,790 | Employee simulation coordination, workplace routing, facilities, relationships, roster UI, employee market and profile |
| `studio_building_interior_smoke_test.gd` | 1,122 | Building geometry, workplace routes, facilities, production interiors and regression cases |

The line counts are a warning signal, not a target in themselves. A module should own one cohesive responsibility and have a small, explicit dependency surface.

## Extraction completed in this pass

### StudioSetLogisticsController

Extracted from `StudioBuildingManager` into:

`scripts/presentation/studio/studio_set_logistics_controller.gd`

Owns:
- set-dressing and set-strike task state;
- technician task assignment and progression;
- prop pickup, delivery, installation, removal and return;
- warehouse/stage route composition;
- logistics completion and worker-readiness checks.

Dependencies are supplied during setup: the building manager adapter, CharacterManager, navigation system and set inventory. The building manager keeps thin compatibility methods and state accessors so existing production flow and smoke tests do not need a simultaneous rewrite.

The first extraction reduced the manager from 5,752 to 5,178 lines. The gameplay state machine itself was moved, not redesigned.

### FilmEditingController

Extracted from `StudioBuildingManager` into:

`scripts/presentation/studio/film_editing_controller.gd`

Owns:
- the active editing-project reference and editor selection;
- editing-project creation and sequence IDs;
- editor availability checks and replacement;
- draft cancellation and timeline ordering controls;
- editing phase advancement through the existing Domain `FilmEditingSystem`;
- Editing Suite inspector UI and its transient control references.

The controller receives the building manager, CharacterManager, FilmEditingSystem and GameClock explicitly during setup. The manager keeps compatibility properties for the active editing project and selected editor, plus thin entry points for minute advancement and inspector construction. The production-to-editing handoff and completed-film archive remain in the manager.

A focused controller smoke test covers project creation, timeline reordering, editor availability pauses, the full editing pipeline and completion notification. The manager drops from 5,178 to 4,750 lines in this extraction. FilmEditingSystem and FilmEditingProject remain unchanged in Domain.

### FilmProductionController and focused collaborators

The production workflow has been separated from `StudioBuildingManager` into a small controller group:

- `scripts/presentation/studio/film_production_controller.gd` — active project/script state, production phases, shift timing, set-dressing orchestration, skill progression and production status.
- `scripts/presentation/studio/film_production_assignment_controller.gd` — crew, cast and background-performer UI, selection state and production-start validation.
- `scripts/presentation/studio/film_scene_performance_controller.gd` — performer blocking, camera targets, off-camera holding marks, cast release and return-to-workplace staging.
- `scripts/domain/film_production/film_crew_catalog.gd` — shared static role definitions and technician/background limits.

The main controller receives the building manager adapter, CharacterManager, Domain FilmProductionSystem, skill progression, GameClock and set inventory. The assignment and scene controllers receive only the dependencies they need. The manager retains building ownership, scene-mark/navigation APIs, the shared script sequence, completed-film archive, set-logistics composition and compatibility methods used by CharacterManager and existing callers.

The Domain `FilmProductionSystem` and `FilmProductionProject` are unchanged. The production-session test verifies project-state ownership, the scene-performance test verifies delegation to the scene controller, and a focused assignment-controller test covers required crew, scripted casting, optional background performers and technician selection.

The manager drops from 4,750 to 2,613 lines in this extraction. The extracted presentation responsibilities are split across controllers of approximately 1,798, 502 and 545 lines rather than being collected into one replacement monolith.

### StudioBuildingPlacementController

Extracted from `StudioBuildingManager` into:

`scripts/presentation/studio/studio_building_placement_controller.gd`

Owns:
- the construction palette and its building-type controls;
- placement-mode state, stage-size selection and rotation;
- the placement preview, 2 m grid snapping and preview validity feedback;
- input handling for placement, rotation and cancellation;
- final placement-rule validation before emitting a placement request.

The manager retains building-data creation, actor instantiation, selection, building-change notifications and navigation/workplace refreshes. The controller receives the manager node and the shared building-data array explicitly; it does not create or own buildings. A focused smoke test covers palette creation, placement-mode transitions, stage-size selection and cancellation.

### StudioBuildingInspectorController

Extracted from `StudioBuildingManager` into:

`scripts/presentation/studio/studio_building_inspector_controller.gd`

Owns:
- the selected building ID and context-inspector panel lifecycle;
- shared building overview, footprint, capacity, occupancy and staff summaries;
- facility-specific information, sound-stage architecture notes and TV Studio overview;
- Script Department controls, progress/result presentation and script summary formatting;
- the UI-side script-generation request, emitted as a typed signal to the manager.

The manager remains the owner of building data and 3D actor highlighting. It supplies narrow read/build adapters for employee eligibility, assigned staff, profession titles and the existing Film Production / Film Editing detail controllers. Script-writing state, project progression, ID allocation and Domain system calls remain in the manager. The inspector only collects user input and renders the supplied state. A focused smoke test covers selection, HUD lifecycle, script-generation request payloads and delegation to the specialized production/editing controllers.

### StudioBuildingVisualFactory

Extracted from `StudioBuildingActor` into:

`scripts/presentation/studio/studio_building_visual_factory.gd`

Owns reusable primitive construction and materials:
- box, cylinder and sphere mesh creation;
- floor surfaces, wall panels and their collision bodies;
- world-space labels and the film slate;
- camera rigs and light stands.

The actor keeps its existing helper method signatures as thin adapters. This preserves all building-specific geometry code and public scene-node names while creating a shared visual-construction boundary for the upcoming type-specific builders. The factory returns the film-slate labels and camera rigs to the actor; navigation, workplace marks, cutaway state and building identity remain in `StudioBuildingActor`. A focused smoke test verifies generated mesh types, dimensions, collision hierarchy, labels and camera equipment.

### StudioSoundStageVisualBuilder

Extracted from `StudioBuildingActor` into:

`scripts/presentation/studio/studio_sound_stage_visual_builder.gd`

Owns the complete type-specific visual assembly for the small, medium and large sound stages:
- three independent exterior roof and facade layouts;
- three dedicated interior film-set arrangements;
- stage-specific camera and lighting placement;
- stage-specific workplace points and set-dressing roots.

The builder receives the shared visual factory explicitly and constructs meshes, labels, camera rigs, lighting and set dressing directly through it. It uses the actor only for the shared perimeter-wall shell and wall-group access, then returns its roof, camera rigs, slate labels, set-dressing root and workplace points as a build-state dictionary. The actor remains the owner of navigation, cutaway state, production labels, scene interaction and public workplace APIs. No scaling-based substitution is introduced: each stage tier keeps its own geometry and node hierarchy. A focused smoke test covers all three tiers, their independent geometry, camera counts and workplace entry/exit routes.

### StudioTVStudioVisualBuilder

Extracted from `StudioBuildingActor` into:

`scripts/presentation/studio/studio_tv_studio_visual_builder.gd`

Owns the complete independent television pavilion composition:
- industrial flat roof, roof beams, entrance canopy and exterior signage;
- control-room glazing and service windows;
- broadcast platform, segmented LED backdrop and host/guest furniture;
- three dedicated camera assemblies, overhead lighting truss and softboxes;
- audience seating and the director's control console;
- the ten authored TV Studio workplace points.

The builder receives the shared visual factory explicitly and uses the actor only for the common perimeter-wall shell and wall-group access. It returns the roof and workplace points to the actor; building identity, cutaway state and navigation remain with the actor. A focused smoke test covers the visual hierarchy, equipment counts and all ten workplace entry/exit routes.

### StudioOfficeVisualBuilder

Extracted from `StudioBuildingActor` into:

`scripts/presentation/studio/studio_office_visual_builder.gd`

Owns the separate Script Department and Editing Suite architectures:
- office-specific roof, base trim, facade glazing and signage;
- writer desks, computer stations, keyboards, chairs, bookshelves and research board;
- three editing workstations with timeline/preview monitors, keyboards and audio mixers;
- shared reference display and audio equipment rack;
- the three workplace marks for each office type.

The builder receives the shared visual factory and delegates only the common perimeter-wall shell and wall-group lookup to the actor. It returns the roof and workplace points without owning building identity, navigation or office workflow state. A focused smoke test covers both office variants, their distinct node hierarchies, equipment counts and workplace entry/exit routes.

### StudioFacilityVisualBuilder

Extracted from `StudioBuildingActor` into:

`scripts/presentation/studio/studio_facility_visual_builder.gd`

Owns six non-office building compositions:
- Prop Warehouse, including racks, shelves, storage marks and its inventory display root;
- Fitness Center, including cardio stations, mirrors and roof skylight;
- Studio Lounge, including coffee area, sofas, plants and six social places;
- Cafeteria, including serving counter, kitchen pass, twelve seats and their facing positions;
- Staff Housing, including eight bed layouts and sleeping marks;
- Star Bungalow, including its private bedroom and single sleeping mark.

The builder receives the shared visual factory and uses the actor only for the common perimeter-wall shell and wall-group access. It returns roof/workplace metadata plus the warehouse inventory root and storage positions. The actor remains responsible for warehouse inventory updates, set-prop visuals, navigation, sleeping/facility simulation and building identity. A focused smoke test covers all six layouts, storage updates, seating/bed alignment and workplace routes.

### StudioBuildingNavigationController

Extracted from `StudioBuildingActor` into:

`scripts/presentation/studio/studio_building_navigation_controller.gd`

Owns the per-building navigation layer:
- workplace entry routes, including the doorway, indoor corridor and obstacle-aware path;
- reverse exit routes from the employee's live world position;
- nearest occupied-bed resolution when a housing exit request has no explicit slot;
- per-building interior bounds and authored obstacle layouts for offices, stages, TV Studio and facilities;
- sound-stage scene-to-scene routes that account for visible set-dressing props.

The controller receives building data, the interior transform, the existing Domain `StudioNavigationSystem`, workplace points, entrance marks and the live set-dressing root as explicit setup dependencies. `StudioBuildingActor` retains its public navigation API as thin compatibility adapters. Outdoor building-to-building routing remains in `StudioBuildingManager`; the Domain pathfinding algorithm is unchanged. A focused smoke test covers rotated buildings, all three stage tiers, TV Studio, facility endpoints and live housing exits.

### StudioBuildingMarkerProvider

Extracted from `StudioBuildingActor` into:

`scripts/presentation/studio/studio_building_marker_provider.gd`

Owns authored spatial markers and orientation rules:
- workplace facing directions for cafeteria, lounge, fitness, housing and TV Studio;
- phase- and scene-specific actor blocking marks for all three sound-stage tiers;
- off-camera holding positions and camera focus points;
- reusable set-dressing placement marks;
- warehouse pickup/storage marks.

The provider receives building data, the interior transform, workplace positions and warehouse storage positions as explicit setup dependencies. It owns no scene nodes and does not change production, inventory, sleeping or employee simulation state. `StudioBuildingActor` keeps its existing public methods as compatibility adapters. A focused smoke test checks every stage tier, phase offsets, alternating scene blocking, rotated facility facing and all eight warehouse marks.

## Target module boundaries

### 1. StudioBuildingManager

Keep the manager as a composition root and public façade. Extract in small steps:

| Target module | Responsibility |
|---|---|
| `StudioBuildingPlacementController` | Build mode, preview, rotation, placement input and placement validation; extracted in this pass |
| `StudioBuildingInspectorController` | Building detail panel lifecycle and inspector selection; extracted in this pass |
| `FilmProductionController` | Production project/phase orchestration, shared-shift timing, set-dressing coordination and status; extracted in this pass |
| `FilmProductionAssignmentController` | Crew/cast/background selection and production-start validation; extracted in this pass |
| `FilmScenePerformanceController` | Scene blocking, camera/performer staging and off-camera holding; extracted in this pass |
| `FilmCrewCatalog` | Shared production role and technician configuration; extracted in this pass |
| `FilmEditingController` | Editor assignment, editing draft, timeline operations and editing progression; extracted in this pass |
| `StudioSetLogisticsController` | Technician/prop logistics; extracted in the previous pass |

Do not move all UI and simulation code into one replacement manager. Each controller should own its own state and expose a narrow API.

### 2. StudioBuildingActor

Keep the actor responsible for the placed building's scene identity, selection and cutaway state. Shared primitive construction is extracted into `StudioBuildingVisualFactory`; per-building indoor path construction is extracted into `StudioBuildingNavigationController`.

Keep the actor's public workplace/scene methods as compatibility adapters. Authored production/facility marker data is extracted into `StudioBuildingMarkerProvider`. Next, split the interior smoke test by feature boundary. Type-specific visual builders already extracted:
- shared primitive/material construction;
- sound-stage tier builders (small, medium and large remain distinct authored architectures);
- TV Studio builder;
- office and editing-suite builders;
- staff/social facility and housing builders.

Builders should receive explicit build context and return or populate a visual root plus navigation metadata. They must not become alternate owners of the building's gameplay state.

### 3. CharacterManager

Keep CharacterManager as the employee-system composition root and compatibility façade.

Extract presentation and coordination by responsibility:
- roster view;
- employee profile view and skill-progress rows;
- recruitment market view;
- workplace/facility dispatch coordinator;
- relationship/social interaction coordinator.

Existing Domain systems for needs, aging, work, skill progression and employment remain the source of simulation rules. Do not duplicate their calculations in presentation controllers.

### 4. Tests

Split the large interior smoke test by feature boundary once the corresponding production modules are stable:
- building geometry and authored dimensions;
- workplace and facility navigation;
- sleeping pose / bed alignment;
- production stage marks and camera blocking;
- set logistics and warehouse transfers.

Keep a small top-level runner that invokes the focused suites.

## Refactoring rules

1. Preserve existing public method contracts while extracting a subsystem. Migrate callers only after the new module has a working test.
2. Move one cohesive responsibility per commit. Avoid combining a structural refactor with new gameplay mechanics or balancing changes.
3. Keep simulation rules in Domain. Presentation modules may coordinate Nodes and scenes, but Domain scripts must not depend on UI or scene nodes.
4. Avoid circular script preloads and hidden cross-module access to another script's private state.
5. Prefer explicit setup dependencies and typed method arguments over broad dictionaries or untyped service locators.
6. Preserve save/data schemas and serialized identifiers. Refactoring must not require a save migration unless a separate design explicitly calls for one.
7. After each extraction, run the closest smoke test first, then the related integration tests and a headless editor parse using Godot 4.7.2.
8. Do not claim runtime validation until those commands have actually been run.
9. Keep the verified Character System v2 behavior intact; UI extraction must not change simulation timing, work schedules, needs, skill progression or pause behavior.

## Recommended order

1. Run Godot 4.7.2 parse and smoke tests for the set-logistics, film-editing, film-production, building-placement and building-inspector controller group.
2. Split the large interior smoke test by feature boundary, beginning with navigation and sleeping/facility pose cases.
3. Split CharacterManager presentation from employee simulation coordination.
4. Split the interior smoke test into focused suites.

The building-manager UI extractions and the first building-visual extraction are complete. Sound Stage, TV Studio, office and staff/social facility geometry are isolated; per-building indoor navigation is delegated to StudioBuildingNavigationController; authored production/facility markers are delegated to StudioBuildingMarkerProvider. The next step is splitting the large interior smoke test by feature boundary.