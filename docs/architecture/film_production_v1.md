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
- `FilmCrewCatalog` owns the shared static crew-role definitions, technician role IDs and background-performer limit.
- `FilmProductionController` owns active production project/script state, phase progression, shared-shift timing, set-dressing coordination, skill progression and production status.
- `FilmProductionAssignmentController` owns crew/cast/background assignment controls, selection state and production-start validation.
- `FilmScenePerformanceController` owns scene blocking, performer staging, camera targeting and off-camera bystander movement/return.
- `StudioBuildingManager` remains the composition root and compatibility façade. It supplies dependencies and building/stage APIs, owns building data, the shared script sequence and completed-film archive, and coordinates the production-to-editing handoff.
- \`CharacterManager\` exposes employee lookup, workplace assignment checks, task updates and actor access without transferring ownership of the roster. Production roles keep their workplace assignment for later dispatch, but do not automatically occupy an idle Sound Stage; the employee inspector can manually call an assigned employee to the stage or editing suite and release them again. Active production takes precedence over manual calls. An editor is auto-dispatched only for an active draft/in-progress editing project.
- \`CharacterActor\` handles movement between the assigned workplace and a scene blocking mark.
- \`CharacterVisual\` plays procedural acting and crew poses using the existing Character System v2 model.
- \`StudioBuildingActor\` owns the physical scene marks, production slate and camera rigs.

### Presentation controller boundary

The presentation controllers are located under `scripts/presentation/studio/`. The main controller coordinates production state and delegates assignment and scene-performance responsibilities to focused collaborators. The collaborators receive explicit dependencies and use the manager's public building/stage adapters; they do not access its private building arrays or duplicate Domain simulation rules.

`FilmCrewCatalog` is data-only. It is shared by the main and assignment controllers so required roles, technician IDs and background limits are defined in one place.

The film system does not own or duplicate employee data. Projects store stable employee IDs for crew and cast assignments. Outside an active film, the player can select an assigned employee and use the inspector's stage-call or editing-room button; that manual assignment persists across shift boundaries until the player releases the employee. This is a workplace call/hold control, not yet a separate free-form rehearsal session or skill-training loop.

## Start conditions and casting

The player starts production from the Sound Stage inspector after a script is completed.

Required positions:
- one director;
- one camera operator;
- one technician;
- an actor or extra assigned to every scripted role.

A producer is optional. When present, the producer coordinates the production and contributes management mastery to film quality. Optional crew positions also include lighting, sound and equipment technicians, up to two additional technicians, a production designer, costume designer and makeup artist. The player explicitly assigns these positions; the selected employees are stored by stable employee ID and included in production readiness checks.

Each script role receives an \`OptionButton\` assignment. Initial assignments distribute roles across available actors/extras in roster order. The player can change these assignments before filming. One employee may play multiple roles across the film; if two such roles appear in the same scene, the employee is represented once in the physical blocking.

The director, camera operator and technician are dispatched to the Sound Stage when production starts. Cast members do not need to stand on set immediately: they walk around the studio during Preparation and Set Dressing, then are called back for Rehearsal. Production pauses if a required crew member is unavailable, or if a performer cannot reach the set when rehearsal, shooting or review requires them.

## Scene state machine

Each scripted scene passes through these states:

| Phase | Base duration | Visible activity |
|---|---:|---|
| Preparation | 2 min | Director stages the scene; camera operator frames the set; technician checks equipment; cast walks around the studio |
| Set Dressing | 2 + ceil(installed props / technicians) min | Technicians collect reusable props from the warehouse and install them in parallel; an empty set uses the neutral setup |
| Rehearsal | 2 + 1 min per performer | Actors rehearse with visible gestures and partner reactions |
| Shooting | 8 + 1 min per performer | Actors perform dialogue/actions; camera rigs track the cast |
| Review | 1 min | Director reviews the take; crew changes to review poses |
| Set Strike | 1 + ceil(installed props / technicians) min | Technicians remove props, return them to warehouse stock and clear the stage |

If a take scores below 58/100, the director requests a retake. A scene can have at most two retakes. A retake uses 16 + 5 minutes per performer, followed by another review. Once the take is accepted, the scene result is recorded and the project enters Set Strike. The next scene cannot enter Preparation until every installed prop has been removed from the stage and returned to warehouse stock. The film is marked completed only after the final scene's strike is finished.

The phase table contains short-project base durations. Feature projects scale every phase with one persisted project multiplier, so Preparation, Set Dressing, Rehearsal, Shooting, Review, Retakes and Set Strike all contribute to a multi-day schedule. The estimate is expressed in the actual shared-shift work minutes of the assigned cast and crew; travel time between the Sound Stage and warehouse remains world-simulation time and is not included in the phase estimate. Starting a film requires assigned roles, not a perfectly timed shift: the director, camera operator and technician are routed to the Sound Stage, while the cast is released to its normal studio roaming routes during Preparation and Set Dressing. When the set is ready, only the actors needed in the current scene are called back and must physically reach their blocking marks before Rehearsal advances. Actors not needed in the current scene remain free to roam. During a shift, assigned production participants remain part of the film through lunch. When the shared shift closes, phase clocks pause; the team is released for off-duty recovery after any active prop delivery or return is completed, then is called back for the next shift. Manual debug fast-forward processes production minutes deterministically, keeping waiting cast outside and snapping called performers to their current blocking marks.

## In-world performance

The Sound Stage has eight reusable scene marks on its set platform. The marks change by phase and alternate their staging layout between scenes, so performers do not remain at their regular employee workstations throughout the take.

During production:
- while the director, operator and technician prepare the set, cast members walk along their existing studio routes outside the Sound Stage;
- during Rehearsal, Shooting and Review, cast members and other staff who are not in the current shot walk to holding marks behind the camera line; required crew remain at their workstations and are not incorrectly removed from the camera station or monitor;
- when Rehearsal begins, only the actors assigned to the current scene return to the Sound Stage and move to scene marks;
- the speaking actor plays a speaking gesture, animates a simple mouth shape and displays the current line above the character;
- other performers play reaction or dramatic poses;
- actors reposition between rehearsal, shooting and review blocking;
- the director gestures while staging and switches to a review pose when inspecting a take;
- the camera operator performs a camera-operation pose;
- during Set Dressing, every available Sound Stage technician can work on a separate prop: they walk to the warehouse, pick up a purchased piece, carry it to the stage and install it; during Set Strike, they remove pieces and carry them back to storage; the phase clock waits until the logistics workers have returned to their workstations;
- multiple technicians reduce the installation and strike work-round durations; if fewer technicians are available than props, each technician makes additional trips;
- during Rehearsal, Shooting and Review, cast members and other staff who are not performing in the current scene move behind the camera to off-camera holding marks; the director, camera operator and technician remain at their dedicated stations unless a logistics task moves the technician;
- an optional producer performs a coordination pose;
- the two in-world camera rigs turn toward the current cast blocking; the primary camera operator stands behind the active rig and performs a hands-on camera pose;
- a physical slate displays the active scene and phase.

When the film is completed, actors return to their assigned workstations, crew poses reset and the slate reports that the film is ready for editing.

The current character animation is procedural and uses existing arm, leg, torso and head pivots. Acting gestures, body movement and head motion are deliberately exaggerated enough to read clearly at normal camera distance. It is not a full skeletal animation system. Scene dialogue is represented visually; there is no voice acting or audio playback in this slice.

## Quality and results

Each scene's take quality uses the following weighted skill inputs:
- principal cast acting (25%);
- director directing (17%);
- camera operation (14%);
- average technical skill across selected technicians (11%);
- script potential (18%);
- lighting and sound (2.5% each);
- set design (4%);
- costume design and makeup (2% each);
- background acting (1%);
- producer management (1%).

Team energy, morale and stress, seeded take variance, a small retake improvement modifier and the scene-specific set-dressing modifier are applied in addition to those skill weights. Unassigned optional roles use a neutral baseline and do not impose a penalty.

The project stores a result for each completed scene: scene ID/number, beat, location, action, dialogue, set ID/title, installed prop IDs, set-dressing quality, final quality, retake count and elapsed production minutes. Scene setup plans are serialized with the production project. A scene's plan can be refreshed during Preparation and until the first Set Dressing minute is processed, including when the player buys props after production starts. The zero-progress Set Dressing window also accepts purchases and adjusts the current phase duration before installation begins. Purchases made before installation progress begins update the current scene; later purchases affect the next scene when its Preparation phase starts, but never rewrite an already dressed or completed scene.

Final film quality is 75% average scene quality and 25% script potential. It is bounded from 0 to 100.

Completion is explicit: \`status = completed\`, all scene results exist, progress is 100%, and the Sound Stage inspector displays the final score and per-scene results. The result message states that the footage is ready for editing; it is not yet a released movie.

## Smoke tests

Run with Godot 4.7.2 from the project root:

~~~powershell
& $godot --headless --path . --script res://tests/film_editing_system_smoke_test.gd
& $godot --headless --path . --script res://tests/film_production_system_smoke_test.gd
& $godot --headless --path . --script res://tests/film_production_assignment_controller_smoke_test.gd
& $godot --headless --path . --script res://tests/film_scene_performance_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_navigation_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_set_inventory_smoke_test.gd
& $godot --headless --path . --script res://tests/film_production_session_smoke_test.gd
& $godot --headless --path . --script res://tests/film_production_overnight_recovery_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_building_interior_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_building_system_smoke_test.gd
& $godot --headless --path . --script res://tests/script_generator_smoke_test.gd
& $godot --headless --path . --script res://tests/script_writing_system_smoke_test.gd
& $godot --headless --path . --script res://tests/employee_work_system_smoke_test.gd
& $godot --headless --path . --script res://tests/employee_market_critical_roles_test.gd
& $godot --headless --path . --script res://tests/employee_management_smoke_test.gd
& $godot --headless --path . --script res://tests/character_system_v2_smoke_test.gd
& $godot --headless --path . --script res://tests/character_skill_profiles_smoke_test.gd
& $godot --headless --path . --script res://tests/character_lifecycle_smoke_test.gd
& $godot --headless --path . --script res://tests/character_system_smoke_test.gd
& $godot --headless --path . --script res://tests/game_clock_fast_forward_test.gd
~~~

All smoke-test scripts defer their test bodies until the SceneTree is ready. They share `smoke_test_base.gd`, which accumulates failed expectations and exits with code 1 instead of printing a false PASS.

The production domain test covers role resolution, unavailable-crew pauses and automatic recovery, technician-scaled installation/strike timing, project serialization, all phase transitions, retakes, final quality and completion. The assignment-controller test covers required crew, scripted cast, optional background performers, technician selection and start validation. The production-session test verifies that the manager façade exposes the controller-owned project and that active crew remain ready at their scene/holding marks. The performance test covers scene-controller delegation, workplace-to-set movement, acting pose, dialogue display and return to the workstation. The interior test covers the warehouse, prop pickup/return visuals, phase-specific blocking marks, camera tracking and the production slate.

## Manual verification

1. Complete a script and select the Sound Stage inspector.
2. Open the Decor Shop from bottom navigation, buy one or more set pieces; confirm the budget decreases, an owned item cannot be bought twice and the pieces appear on the Prop Warehouse shelves.
3. Use a lighthouse script scene; confirm technicians walk to the warehouse, pick up matching lighthouse props and carry them into the Sound Stage. Assign multiple technicians to the stage and observe concurrent deliveries.
4. Assign each scripted role to an actor/extra. Confirm the producer is optional. Select an actor or director in the employee inspector and call them to the stage; confirm the call remains active across a shift boundary, then release them back to roaming. Use the same control for an assigned editor to send them to the editing suite.
5. Assign the director, camera operator, technician and cast to the Sound Stage, then start filming. The crew is dispatched automatically.
6. During Preparation and Set Dressing, confirm cast members leave the pavilion and walk around the studio while technicians collect and install props.
7. When Rehearsal begins, confirm only actors needed in the current scene return to the pavilion and take their marks; other cast members keep roaming.
8. Observe rehearsal gestures, actor repositioning, speaking dialogue and reaction poses.
9. During Rehearsal and Shooting, confirm non-performing cast and staff walk behind the camera; the camera operator stays at the rig and the director stays beside the monitor.
10. Confirm the dialogue bubble appears only for the speaking character and the speaking mouth visibly animates.
11. Confirm camera rigs turn toward the current blocking and the slate updates scene/phase.
12. Confirm the director, camera operator, technician and producer display their production poses/tasks.
13. After the scene is accepted, observe Set Strike: technicians remove the pieces, carry them back to the warehouse and place them on the shelves. Confirm the stage is not cleared before the last prop is returned.
14. Confirm the next scene does not begin until the previous set is cleared and the technicians return to their workstations.
15. Confirm assigned participants remain available through lunch and normal shift boundaries; actors are called only for scenes in which they participate.
16. Let the clock pass the end of the shared production shift and reach 00:15. Confirm production phase minutes stop, performers leave the active marks, and outstanding prop logistics can finish safely.
17. Advance to the next shared work shift without restarting the film, including via the +1 day button. Confirm the same scene and phase resume after the crew returns, without duplicated props, reset progress, or indefinitely travelling technicians.
18. Confirm low-quality takes request no more than two retakes.
19. Confirm final completion shows the film quality and all scene results, returns active performers to workstations and changes the slate to ФИЛЬМ ГОТОВ.
20. Recheck normal workplace routing around building footprints and stage walls, employee needs, script writing, manual fast-forward, building selection and camera controls.

## Explicit limitations

- No full timeline editor or manual scene/blocking authoring yet.
- No full skeletal animation, facial animation, lip sync, voice acting or recorded sound.
- Scene actions are generated from the existing beat/action/dialogue fields and mapped to a small procedural animation library.
- Camera rigs rotate to follow the cast and the operator occupies the primary rig; a live SubViewport/video-feed panel and player-operated camera tracks, lenses or shot framing are not implemented yet.
- No retake-specific dialogue variation or actor memory of previous takes.
- Film editing, timeline ordering, sound mix, color grading and export are implemented. Release scheduling, marketing, distribution, audience reception and box-office results are not implemented yet.
- Set Dressing Workshop currently uses its own prototype budget and is not connected to the future Studio Economy ledger.
- Purchased props and inventory expose serialization methods, but campaign SaveSystem integration does not yet exist.
- Set-piece positions are selected automatically from a small fixed layout; there is no manual set editor or imported production-ready asset library yet.
- Navigation uses grid-based obstacle avoidance for the current studio scale; it is not a full NavMesh or dynamic crowd-avoidance system.
- Film projects and completed results are serializable domain objects but are not yet connected to campaign save/load.
- Only one film production project is active at a time.
- Cafeteria and staff housing are optional facilities. Production participants remain assigned during the shift and lunch; after the shared shift ends, they are released for free time and staff-housing recovery once active prop logistics are safe. They are recalled for the next production shift.


## Working hours and overnight pause

Every production phase advances only during the shared shift window of the assigned cast and crew. The effective window is the intersection of their individual shifts, and its duration is stored on the project so the estimate is expressed in working days rather than assuming a fixed nine-hour day. When the window closes, phase clocks stop. Set Dressing and Set Strike may finish outstanding prop delivery, installation, removal and warehouse-return tasks after the phase clock stops, but they do not consume production phase minutes outside the shift. Once logistics are safe, the team is released to normal free-time and staff-housing behavior; active performers return to their marks on the next shift. The camera is idled while production is paused. A morning work call may interrupt an employee still walking to staff housing and replan the journey directly back to their assigned workstation. During manual fast-forward, no physics frames are generated between minute events; logistics workers therefore finish each scripted travel leg at its destination mark before its task state advances, matching the existing fast-forward behavior of scene performers. Normal-time navigation still uses physical movement. The dedicated overnight-recovery smoke test covers both behaviors; full live-scene movement and collision recovery still require visual verification.

## Background performers, professional progression and lifecycle

Background extras are assigned separately from scripted cast roles. Up to four extras can be selected, bounded by the eight physical scene marks after reserving space for scripted performers. Background performers join every scene without replacing principal cast members. An employee assigned to a scripted role cannot also be selected as background.

Professional mastery is persistent. Normal work develops an employee's primary skill and reliability. Rehearsal develops actors' acting, diction, movement and improvisation, and the director's actor-direction skills. Shooting develops the cast and the selected camera, lighting, sound, equipment, set, costume and makeup specialists. Set Dressing and Review develop the staff working in those phases. Skill experience is stored separately from the 0–100 mastery value; the amount of experience required for each next point rises with mastery, and age modifies the learning rate.

The production shift is calculated from the overlap of all assigned cast, crew and background performers. This prevents optional crew members from being silently required outside their own shifts. Project schema v5 persists the shared-shift workday length and feature phase-duration multiplier alongside background performer assignments.

## Career pacing and staffing constraints

The career target is approximately 30–40 released feature films for a highly demanded actor over a full career. With five biological years passing per 365 game days, an actor's age-20-to-65 career spans roughly nine game years. The corresponding average interval between major acting credits is 82–110 game days. The long-term studio release cadence remains 30–45 game days per feature, with an actor appearing in a subset of releases rather than every project. This release interval is a campaign-balance target, not yet an enforced timer: Film Distribution, marketing, release scheduling and box-office simulation are still future systems.

An 8–12-scene feature now targets 8–15 shared-shift working days from first preparation through the final set strike. The target interpolates from 8 days at eight scenes to 15 days at twelve scenes; longer scripts add approximately 1.25 working days per scene beyond twelve. Larger scene casts and heavier prop plans increase the target, while additional technicians modestly reduce it. Short scripts below eight scenes retain compact timings for shorts and smoke-test fixtures. Retakes add their full scaled duration to the estimate. The editing workflow adds approximately 2–3.5 editor working days for an 8–12-scene feature, adjusted by the editor's skill; longer scripts add further editing time. FilmEditingProject schema v2 persists the editor's effective workday length and the skill-adjusted phase multiplier.

Feature-film career credits will count released feature films, not background appearances or uncompleted shoots. That counter belongs with the future distribution/release flow and must not be inferred from scene count alone.

Staffing remains player-controlled. The initial six-person team is not automatically expanded to fill optional crew roles or background positions. Those positions must be assigned from existing employees; only an explicit player hiring action can grow the roster.


## Physical screenplay and film transfer

Completed screenplays now have a tracked production dossier and a clickable 3D folder outside the writers' entrance. Drag with the left mouse button to a suitable sound stage before production can begin. When shooting finishes, the folder becomes an actual reel that must be dragged to an editing suite before the editing project can be created. Once the editor finishes, drag the mastered film to the marked release dock at world position (23, 0, -28). The release dock records the film in the studio's completed archive. A pending previous film must be delivered for release before starting the next one. Building placement reserves the release dock area, and the staged screenplay determines the cast/scene assignments. This is the handoff layer, not a substitute for a future marketing or distribution economy.
