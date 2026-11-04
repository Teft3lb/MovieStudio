# Studio Buildings v1

**Engine:** Godot 4.7.2  
**Branch:** \`feature/studio-buildings-v1\`  
**Status:** first interactive building and placement slice.

## Scope

Studio Buildings v1 replaces the two placeholder cubes in the main scene with interactive, procedurally assembled buildings and adds a basic construction workflow.

Implemented building types:

| Type ID | Display name | Footprint | Workplaces | Accepted professions |
|---|---|---:|---:|---|
| \`script_department\` | Сценарный отдел | 8 × 6 m | 3 | Screenwriter, producer, casting director |
| \`sound_stage\` | Съёмочный павильон | 14 × 12 m | 8 | Actor, extra, director, camera operator, technician, production designer, producer |

Two starter buildings are spawned when the main scene initializes:
- Script Department at \`(-14, 0, -8)\`.
- Sound Stage №1 at \`(0, 0, 0)\`.

The building models are assembled from reusable Godot primitive meshes. No external art assets are required for this prototype.

## Architecture

### Domain

- \`StudioBuildingCatalog\` contains immutable type definitions, footprints, workplace capacity and accepted professions.
- \`StudioBuildingData\` represents one placed building and supports dictionary serialization.
- \`StudioBuildingPlacementRules\` is a presentation-independent placement validator. It checks plot bounds, rotated footprints and minimum spacing.

### Presentation

- \`StudioBuildingActor\` creates the 3D model, building hitbox, name label and selection marker.
- \`StudioBuildingManager\` owns placed building instances, build mode, preview, selection and building detail panels.
- \`CharacterManager.get_employees()\` exposes a copy of the active roster for workplace and production interfaces.
- \`main.gd\` initializes the building manager after scene children have completed their setup.

### Placement controls

1. Click **Построить сценарный отдел** or **Построить съёмочный павильон**.
2. Move the mouse over the plot to position the preview.
3. Placement snaps to a 2 m grid.
4. Green preview means valid placement; red means invalid.
5. Left click places the building.
6. Press \`R\` to rotate by 90 degrees.
7. Right click or \`Esc\` cancels build mode.

Placement is restricted to the current 100 × 100 m prototype plot. A 1.5 m minimum gap is enforced between building footprints. Buildings cannot overlap or extend beyond the plot.

Construction is free in this slice because Studio Economy has not been implemented. The UI states this explicitly.

## Building interactions

### Script Department

The building panel:
- lists active screenwriters available in the studio roster;
- allows the player to choose a screenwriter;
- exposes genre, scene count and role count;
- generates a structured script and displays its title, logline, cast, scene beats, locations, actions and dialogue;
- displays a one-to-five-star potential rating and a bounded popularity modifier.

### Sound Stage

The building panel:
- shows the latest generated script, if one exists;
- lists staff in professions accepted by the stage;
- checks the four initial crew positions: director, actor, camera operator and technician;
- reports how many required positions are currently covered.

The starting roster normally covers three of the four required positions; a technician can be hired through the existing employee market.

The stage is a production-readiness interface only. It does not yet shoot scenes.

## Simulation boundaries

The current implementation does **not** yet:
- charge construction or maintenance costs;
- simulate construction time;
- assign staff to persistent workplace slots;
- route employees into buildings or use NavMesh pathfinding;
- simulate indoor rooms or building interiors;
- run autonomous workplace tasks;
- produce scenes or films;
- persist building state in a campaign save.

The catalogue's accepted-profession lists and workplace capacities are the first integration contract for the next Studio Workplace AI / Film Production stages.

## Smoke tests

Run from the project root using Godot 4.7.2:

~~~powershell
& $godot --headless --path . --script res://tests/studio_building_system_smoke_test.gd
~~~

The test covers the building catalogue, accepted professions, serialization, plot bounds, overlap rejection and 90-degree footprint rotation.
