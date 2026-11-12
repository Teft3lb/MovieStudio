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

- \`StudioBuildingActor\` creates the exterior, cutaway walls, roof assembly, interior props, workplace routes, building hitbox, name label and selection marker.
- \`StudioBuildingManager\` owns placed building instances, build mode, preview, selection and building detail panels.
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

The interior test covers room props in all three building types


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

The initial catalog table above describes the original Buildings v1 set. The current catalog also includes cafeteria, staff housing, star bungalow, fitness center and studio lounge. Sound stages now have three distinct architectural models, not one model scaled to different footprints:

| Stage model | Footprint | Crew slots | Architecture |
|---|---:|---:|---|
| Small | 10 × 8 m | 6 | Compact low-rise studio with a gable roof and narrow loading entrance |
| Medium | 14 × 12 m | 8 | Rectangular industrial pavilion with a flat roof and standard loading door |
| Large | 22 × 18 m | 12 | High-bay production hangar with roof trusses, skylights, control-room glazing and a taller loading door |

All three models have identity interior transforms. Their wall positions, roof geometry, set dimensions, camera/light placement, navigation bounds and crew marks are authored independently for each tier. The production selector chooses the smallest operational stage that satisfies the current script and owned set-piece requirements.

The Fitness Center provides four training stations; the Studio Lounge provides six social places. See staff_facilities_v1.md for schedules and simulation effects.
