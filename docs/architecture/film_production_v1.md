# Film Production v1

**Engine:** Godot 4.7.2  
**Branch:** \`feature/film-production-v1\`  
**Status:** first playable end-to-end scene-shooting workflow.

## Goal

Turn a completed \`FilmScriptData\` into a finished shooting project. The player assigns performers to roles, starts filming in the Sound Stage, watches the cast rehearse and perform, and receives a per-scene quality record plus a completed film result.

This slice deliberately stops when principal photography is complete. Editing, release, marketing, distribution and box-office simulation are separate systems.

## Runtime ownership

- \`FilmProductionSystem\` owns deterministic production rules and phase transitions.
- \`FilmProductionProject\` owns the runtime project state and its serializable representation.
- \`StudioBuildingManager\` coordinates the active script, crew/cast selection, GameClock updates, production UI and stage presentation.
- \`CharacterManager\` exposes employee lookup, workplace assignment checks, task updates and actor access without transferring ownership of the roster.
- \`CharacterActor\` handles movement between the assigned workplace and a scene blocking mark.
- \`CharacterVisual\` plays procedural acting and crew poses using the existing Character System v2 model.
- \`StudioBuildingActor\` owns the physical scene marks, production slate and camera rigs.

The film system does not own or duplicate employee data. Projects store stable employee IDs for crew and cast assignments.

## Start conditions and casting

The player starts production from the Sound Stage inspector after a script is completed.

Required positions:
- one director;
- one camera operator;
- one technician;
- an actor or extra assigned to every scripted role.

A producer is optional. When present, the producer coordinates the production and contributes to the team's condition snapshot.

Each script role receives an \`OptionButton\` assignment. Initial assignments distribute roles across available actors/extras in roster order. The player can change these assignments before filming. One employee may play multiple roles across the film; if two such roles appear in the same scene, the employee is represented once in the physical blocking.

The director, camera operator, technician and all cast employees must be on shift and inside the Sound Stage when the player starts filming. During production, a break, low availability or leaving the workplace pauses production instead of consuming shooting time.

## Scene state machine

Each scripted scene passes through these states:

| Phase | Base duration | Visible activity |
|---|---:|---|
| Preparation | 12 min | Cast moves to blocking marks; director stages the scene; technician checks equipment |
| Rehearsal | 10 + 3 min per performer | Actors rehearse and move to rehearsal blocking |
| Shooting | 24 + 8 min per performer | Actors perform dialogue/actions; camera rigs track the cast |
| Review | 6 min | Director reviews the take; crew changes to review poses |

If a take scores below 58/100, the director requests a retake. A scene can have at most two retakes. A retake uses 16 + 5 minutes per performer, followed by another review.

The simulation advances in GameClock minutes. Production pauses during off-shift time, scheduled breaks, actor travel and unavailable required crew. Manual debug fast-forward processes production minutes deterministically and snaps active performers to their current blocking marks at the end of the skip.

## In-world performance

The Sound Stage has eight reusable scene marks on its set platform. The marks change by phase and alternate their staging layout between scenes, so performers do not remain at their regular employee workstations throughout the take.

During production:
- actors move from their workstations to scene marks and face their scene partners;
- the speaking actor plays a speaking gesture and displays the current line above the character;
- other performers play reaction or dramatic poses;
- actors reposition between rehearsal, shooting and review blocking;
- the director gestures while staging and switches to a review pose when inspecting a take;
- the camera operator performs a camera-operation pose;
- the technician performs equipment checks;
- an optional producer performs a coordination pose;
- the two in-world camera rigs turn toward the current cast blocking;
- a physical slate displays the active scene and phase.

When the film is completed, actors return to their assigned workstations, crew poses reset and the slate reports that the film is ready for editing.

The current character animation is procedural and uses existing arm, leg, torso and head pivots. It is not a full skeletal animation system. Scene dialogue is represented visually; there is no voice acting or audio playback in this slice.

## Quality and results

Each scene's take quality is based on:
- actor acting skill (30%);
- director directing skill (20%);
- camera operator camera skill (16%);
- technician technical skill (12%);
- script potential score (22%);
- team energy, morale and stress;
- seeded take variance;
- a small retake improvement modifier.

The project stores a result for each completed scene: scene ID/number, beat, location, action, dialogue, final quality, retake count and elapsed production minutes.

Final film quality is 75% average scene quality and 25% script potential. It is bounded from 0 to 100.

Completion is explicit: \`status = completed\`, all scene results exist, progress is 100%, and the Sound Stage inspector displays the final score and per-scene results. The result message states that the footage is ready for editing; it is not yet a released movie.

## Smoke tests

Run with Godot 4.7.2 from the project root:

~~~powershell
& $godot --headless --path . --script res://tests/film_production_system_smoke_test.gd
& $godot --headless --path . --script res://tests/film_scene_performance_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_building_interior_smoke_test.gd
& $godot --headless --path . --script res://tests/script_generator_smoke_test.gd
& $godot --headless --path . --script res://tests/employee_work_system_smoke_test.gd
& $godot --headless --path . --script res://tests/employee_management_smoke_test.gd
& $godot --headless --path . --script res://tests/character_system_v2_smoke_test.gd
& $godot --headless --path . --script res://tests/game_clock_fast_forward_test.gd
~~~

The production domain test covers role resolution, unavailable-crew pauses, project serialization, all phase transitions, retakes, final quality and completion. The performance test covers workplace-to-set movement, acting pose, dialogue display and return to the workstation. The interior test covers phase-specific blocking marks, camera tracking and the production slate.

## Manual verification

1. Complete a script and select the Sound Stage.
2. Assign each scripted role to an actor/extra. Confirm the producer is optional.
3. Start filming while the director, camera operator, technician and cast are on shift inside the stage.
4. Observe actors move from workstations to the set marks.
5. Observe rehearsal gestures, actor repositioning, speaking dialogue and reaction poses.
6. Confirm the dialogue bubble appears only for the speaking character.
7. Confirm camera rigs turn toward the current blocking and the slate updates scene/phase.
8. Confirm the director, camera operator, technician and producer display their production poses/tasks.
9. Confirm production pauses when a required employee takes a break or leaves the shift, then resumes after the team returns.
10. Confirm low-quality takes request no more than two retakes.
11. Confirm each completed scene advances to the next scene and updates the scene counter.
12. Confirm final completion shows the film quality and all scene results, returns actors to workstations and changes the slate to \`ФИЛЬМ ГОТОВ\`.
13. Recheck normal workplace routing, employee needs, script writing, manual fast-forward, building selection and camera controls.

## Explicit limitations

- No full timeline editor or manual scene/blocking authoring yet.
- No full skeletal animation, facial animation, lip sync, voice acting or recorded sound.
- Scene actions are generated from the existing beat/action/dialogue fields and mapped to a small procedural animation library.
- Camera rigs rotate to follow the cast; the player cannot yet operate camera tracks, lenses or shot framing.
- No retake-specific dialogue variation or actor memory of previous takes.
- No editing, montage, export, release, marketing, distribution, audience reception or box-office results.
- No production payroll, per-film budget or equipment rental cost integration.
- Film projects and completed results are serializable domain objects but are not yet connected to campaign save/load.
- Only one film production project is active at a time.
