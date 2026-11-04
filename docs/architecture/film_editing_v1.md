# Film Editing v1

**Engine:** Godot 4.7.2  
**Branch:** main  
**Status:** initial implementation; Godot runtime verification pending.

## Goal

Turn a completed Film Production project into an edited film. The player builds an Editing Suite, hires or assigns a film editor, prepares the scene timeline, and advances the film through post-production using GameClock time.

This slice ends with an edited film ready for release. Distribution, marketing, audience reception and box-office simulation are later systems.

## Runtime ownership

- FilmEditingSystem owns editing project validation, timeline operations, phase transitions and final quality calculation.
- FilmEditingProject owns the serializable editing state, source scene results and editable timeline order.
- StudioBuildingManager coordinates the production-to-editing handoff, editor assignment, Editing Suite UI and GameClock updates.
- EmployeeWorkSystem assigns film editors to the Editing Suite.
- CharacterVisual provides a procedural editing workstation pose.
- StudioBuildingActor creates the Editing Suite interior and three workstation routes.

FilmEditingSystem copies the completed production scene results into its project. It does not mutate the source FilmProductionProject.

## Entry conditions

- The active FilmProductionProject must have status = completed.
- Every scripted scene must have a recorded scene result.
- A film editor must be assigned to the Editing Suite.
- The standard eight-person employee market guarantees one film editor in addition to the guaranteed technician.

The editor must be on shift and physically at the Editing Suite for editing to advance. Production-department scheduling currently gives editors the 07:00–16:00 shift. If the assigned editor leaves the roster or is moved out of the department, the project pauses and the player can reassign another editor without losing the current phase or elapsed work. A draft can be cancelled and prepared again before editing starts.

## Timeline preparation

Creating an editing project copies the source film title, genre, final production quality and scene result records. The initial timeline preserves screenplay order.

Before editing starts, the player can select a scene and move it one position earlier or later. The timeline is locked once editing begins. Every scene must appear exactly once; invalid or duplicate timeline indices are rejected, and malformed serialized timelines recover to source order.

The timeline is currently scene-level. Shot-level trims, transitions, multiple video/audio tracks and keyframe editing are not implemented.

## Editing state machine

The project passes through five phases:

| Phase | Duration |
|---|---:|
| Assembly cut | 18 + 3 minutes per scene |
| Fine cut | 12 + 2 minutes per scene |
| Sound mix | 10 + 1 minute per scene |
| Color grading | 8 + 1 minute per scene |
| Final export | 5 minutes |

The GameClock advances one editing minute at a time. If the editor is on break, off shift, travelling or no longer at the Editing Suite, the project pauses without consuming editing time. The project reports the reason for the pause.

## Quality

Final edited quality is bounded from 0 to 100 and combines:

- source production quality: 75%;
- editor's editing skill snapshot: 20%;
- timeline continuity score: 5%.

Timeline continuity starts at 100 for the original order. Scene inversions reduce the score, down to a floor of 70. The calculation is deterministic; there is no random quality roll during editing.

The completed project stores source quality, editor skill, continuity score, final quality and total editing time. The film is marked ready for release, not yet released.

## Smoke tests

Run with Godot 4.7.2 from the project root:

~~~powershell
& $godot --headless --path . --script res://tests/film_editing_system_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_building_system_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_building_interior_smoke_test.gd
& $godot --headless --path . --script res://tests/employee_market_critical_roles_test.gd
& $godot --headless --path . --script res://tests/employee_management_smoke_test.gd
& $godot --headless --path . --script res://tests/character_skill_profiles_smoke_test.gd
& $godot --headless --path . --script res://tests/employee_work_system_smoke_test.gd
~~~

The editing domain test covers production completion validation, timeline reordering, invalid indices, serialization recovery, pause behaviour, all editing phases, elapsed-time estimates and final quality.

## Manual verification

1. Complete all scenes in the Sound Stage.
2. Build an Editing Suite and confirm the film editor is assigned to it.
3. Select the Editing Suite and choose the assigned editor.
4. Prepare the editing project and reorder at least one scene.
5. Start editing while the editor is on shift and at the workstation.
6. Confirm progress through assembly, fine cut, sound mix, color grading and export.
7. Confirm the project pauses during the editor's break or after the shift ends, then resumes when the editor returns.
8. Confirm final quality, continuity score and total editing time are displayed.
9. Confirm the Sound Stage no longer allows a new film to start until editing is complete.

## Explicit limitations

- No shot-level timeline, trims, transitions, multi-track audio/video, subtitles or keyframes.
- No actual video rendering, audio mixing or colour-processing output files; phases are management simulation.
- No campaign save/load integration yet. EditingProject is serializable, but the active project and in-memory completed-film archive are not persisted.
- Only one active production/editing chain is retained at a time; a completed chain is moved to a runtime archive when the next film starts.
- No release scheduling, marketing campaign, distribution deal, audience reviews or box-office simulation.
- No production or post-production payroll and per-film cost integration.
