# Film Production v1

**Engine:** Godot 4.7.2  
**Branch:** \`main\`  
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

The director, camera operator and technician are dispatched to the Sound Stage when production starts. Cast members do not need to stand on set immediately: they walk around the studio during Preparation and Set Dressing, then are called back for Rehearsal. Production pauses if a required crew member is unavailable, or if a performer cannot reach the set when rehearsal, shooting or review requires them.

## Scene state machine

Each scripted scene passes through these states:

| Phase | Base duration | Visible activity |
|---|---:|---|
| Preparation | 2 min | Director stages the scene; camera operator frames the set; technician checks equipment; cast walks around the studio |
| Set Dressing | 2 min + 1 min per purchased prop | Technician installs reusable props while cast remains free to roam; an empty set uses the neutral setup |
| Rehearsal | 2 + 1 min per performer | Actors rehearse with visible gestures and partner reactions |
| Shooting | 8 + 1 min per performer | Actors perform dialogue/actions; camera rigs track the cast |
| Review | 1 min | Director reviews the take; crew changes to review poses |

If a take scores below 58/100, the director requests a retake. A scene can have at most two retakes. A retake uses 16 + 5 minutes per performer, followed by another review.

The simulation advances in GameClock minutes. Starting a film requires assigned roles, not a perfectly timed shift: the director, camera operator and technician are routed to the Sound Stage, while the cast is released to its normal studio roaming routes during Preparation and Set Dressing. When the set is ready, only the actors needed in the current scene are called back and must physically reach their blocking marks before Rehearsal advances. Actors not needed in the current scene remain free to roam. Assigned production participants remain part of the film through lunch and normal shift boundaries. Manual debug fast-forward processes production minutes deterministically, keeping waiting cast outside and snapping called performers to their current blocking marks.

## In-world performance

The Sound Stage has eight reusable scene marks on its set platform. The marks change by phase and alternate their staging layout between scenes, so performers do not remain at their regular employee workstations throughout the take.

During production:
- while the director, operator and technician prepare the set, cast members walk along their existing studio routes outside the Sound Stage;
- when Rehearsal begins, only the actors assigned to the current scene return to the Sound Stage and move to scene marks;
- the speaking actor plays a speaking gesture, animates a simple mouth shape and displays the current line above the character;
- other performers play reaction or dramatic poses;
- actors reposition between rehearsal, shooting and review blocking;
- the director gestures while staging and switches to a review pose when inspecting a take;
- the camera operator performs a camera-operation pose;
- during set dressing, the technician walks to each planned prop mark and installs the reusable set pieces; during later phases the technician performs equipment checks;
- an optional producer performs a coordination pose;
- the two in-world camera rigs turn toward the current cast blocking;
- a physical slate displays the active scene and phase.

When the film is completed, actors return to their assigned workstations, crew poses reset and the slate reports that the film is ready for editing.

The current character animation is procedural and uses existing arm, leg, torso and head pivots. Acting gestures, body movement and head motion are deliberately exaggerated enough to read clearly at normal camera distance. It is not a full skeletal animation system. Scene dialogue is represented visually; there is no voice acting or audio playback in this slice.

## Quality and results

Each scene's take quality is based on:
- actor acting skill (30%);
- director directing skill (20%);
- camera operator camera skill (16%);
- technician technical skill (12%);
- script potential score (22%);
- team energy, morale and stress;
- seeded take variance;
- a small retake improvement modifier;
- a scene-specific set-dressing modifier derived from owned and missing required props. Missing set pieces lower scene quality but do not prevent production from starting.

The project stores a result for each completed scene: scene ID/number, beat, location, action, dialogue, set ID/title, installed prop IDs, set-dressing quality, final quality, retake count and elapsed production minutes. Scene setup plans are serialized with the production project. A scene's plan can be refreshed during Preparation and until the first Set Dressing minute is processed, including when the player buys props after production starts. The zero-progress Set Dressing window also accepts purchases and adjusts the current phase duration before installation begins. Purchases made before installation progress begins update the current scene; later purchases affect the next scene when its Preparation phase starts, but never rewrite an already dressed or completed scene.

Final film quality is 75% average scene quality and 25% script potential. It is bounded from 0 to 100.

Completion is explicit: \`status = completed\`, all scene results exist, progress is 100%, and the Sound Stage inspector displays the final score and per-scene results. The result message states that the footage is ready for editing; it is not yet a released movie.

## Smoke tests

Run with Godot 4.7.2 from the project root:

~~~powershell
& $godot --headless --path . --script res://tests/film_editing_system_smoke_test.gd
& $godot --headless --path . --script res://tests/film_production_system_smoke_test.gd
& $godot --headless --path . --script res://tests/film_scene_performance_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_navigation_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_set_inventory_smoke_test.gd
& $godot --headless --path . --script res://tests/film_production_session_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_building_interior_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_building_system_smoke_test.gd
& $godot --headless --path . --script res://tests/script_generator_smoke_test.gd
& $godot --headless --path . --script res://tests/script_writing_system_smoke_test.gd
& $godot --headless --path . --script res://tests/employee_work_system_smoke_test.gd
& $godot --headless --path . --script res://tests/employee_market_critical_roles_test.gd
& $godot --headless --path . --script res://tests/employee_management_smoke_test.gd
& $godot --headless --path . --script res://tests/character_system_v2_smoke_test.gd
& $godot --headless --path . --script res://tests/character_skill_profiles_smoke_test.gd
& $godot --headless --path . --script res://tests/character_system_smoke_test.gd
& $godot --headless --path . --script res://tests/game_clock_fast_forward_test.gd
~~~

All smoke-test scripts defer their test bodies until the SceneTree is ready. They share `smoke_test_base.gd`, which accumulates failed expectations and exits with code 1 instead of printing a false PASS.

The production domain test covers role resolution, unavailable-crew pauses, project serialization, all phase transitions, retakes, final quality and completion. The performance test covers workplace-to-set movement, acting pose, dialogue display and return to the workstation. The interior test covers phase-specific blocking marks, camera tracking and the production slate.

## Manual verification

1. Complete a script and select the Sound Stage inspector.
2. Buy one or more set pieces in the Set Dressing Workshop; confirm the budget decreases and an owned item cannot be bought twice.
3. Use a lighthouse script scene; confirm the lighthouse props are selected automatically and reused in every matching scene.
4. Assign each scripted role to an actor/extra. Confirm the producer is optional.
5. Assign the director, camera operator, technician and cast to the Sound Stage, then start filming. The crew is dispatched automatically.
6. During Preparation and Set Dressing, confirm cast members leave the pavilion and walk around the studio while the technician prepares the set.
7. When Rehearsal begins, confirm only actors needed in the current scene return to the pavilion and take their marks; other cast members keep roaming.
8. Observe the technician move between prop marks during Set Dressing.
9. Observe rehearsal gestures, actor repositioning, speaking dialogue and reaction poses.
10. Confirm the dialogue bubble appears only for the speaking character and the speaking mouth visibly animates.
11. Confirm camera rigs turn toward the current blocking and the slate updates scene/phase.
12. Confirm the director, camera operator, technician and producer display their production poses/tasks.
13. Confirm assigned participants remain available through lunch and normal shift boundaries; actors are called only for scenes in which they participate.
14. Confirm low-quality takes request no more than two retakes.
15. Confirm each completed scene advances to the next scene and updates the scene counter.
16. Confirm final completion shows the film quality and all scene results, returns active performers to workstations and changes the slate to ФИЛЬМ ГОТОВ.
17. Recheck normal workplace routing around building footprints and stage walls, employee needs, script writing, manual fast-forward, building selection and camera controls.

## Explicit limitations

- No full timeline editor or manual scene/blocking authoring yet.
- No full skeletal animation, facial animation, lip sync, voice acting or recorded sound.
- Scene actions are generated from the existing beat/action/dialogue fields and mapped to a small procedural animation library.
- Camera rigs rotate to follow the cast; the player cannot yet operate camera tracks, lenses or shot framing.
- No retake-specific dialogue variation or actor memory of previous takes.
- No editing, montage, export, release, marketing, distribution, audience reception or box-office results.
- Set Dressing Workshop currently uses its own prototype budget and is not connected to the future Studio Economy ledger.
- Purchased props and inventory expose serialization methods, but campaign SaveSystem integration does not yet exist.
- Set-piece positions are selected automatically from a small fixed layout; there is no manual set editor or imported production-ready asset library yet.
- Navigation uses grid-based obstacle avoidance for the current studio scale; it is not a full NavMesh or dynamic crowd-avoidance system.
- Film projects and completed results are serializable domain objects but are not yet connected to campaign save/load.
- Only one film production project is active at a time.
