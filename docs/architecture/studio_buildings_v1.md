# Studio Buildings v1

**Engine:** Godot 4.7.2  
**Branch:** \`main\`
**Status:** interactive placement, workplace assignment and cutaway interiors for three production facilities plus a dedicated prop warehouse.

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
- assign dedicated buildings to facility, catering, administration and marketing staff;
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
