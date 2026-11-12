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
| `studio_building_actor.gd` | 3,147 | Building node lifecycle, navigation, scene marks, set props, all procedural building geometry |
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

Keep the actor responsible for the placed building's scene identity, selection, cutaway state and public workplace/scene navigation API.

Extract procedural visuals into builders:
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
2. Split StudioBuildingActor's temporary procedural geometry from the stable building interaction and navigation layer.
3. Split CharacterManager presentation from employee simulation coordination.
4. Split the interior smoke test into focused suites.

The building-manager UI extractions are complete. The next large structural boundary is StudioBuildingActor: procedural visuals must be separated from the building's stable identity, navigation and gameplay interfaces before the project adds more building types and richer 3D assets.