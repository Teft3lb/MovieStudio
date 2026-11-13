# MovieStudio — 3D employee drag-and-drop orders v1

**Target:** Godot 4.7.2, Character System v2, additive feature on `main`.

## Player interaction

In the 3D world, left-click a character as before to select them. Keep the left mouse button pressed and move at least **12 px** to enter drag mode. Moving over a building shows an outline-style target ring and a tooltip with the activity or a concrete rejection reason (green = allowed, red = blocked). Releasing the button over a valid building starts the activity; releasing elsewhere does nothing. `Esc` or right-click cancels an in-progress drag. The player does not pick the character up or teleport them: the employee walks to the destination over the existing navigation graph.

The `CharacterDragDropController` owns *only* gesture recognition and transient visual feedback. It is registered by `StudioBuildingManager` and handles mouse releases even when the pointer ends over the HUD. Selection is initiated from both existing character-click pathways to avoid depending on the Godot scene-tree input dispatch order. The existing building-selection, scene-dossier dragging and placement tools retain priority.

## Temporary manual activities

`CharacterManualActivityController` is independent of film production and permanent staffing. A drop creates a **timed personal activity order**; it never reassigns a profession, workplace, employment contract or film role. Orders follow an explicit route from the actor's current position through the source building's exit, outdoor AStar, destination entrance, then to an available internal activity slot. The character uses the existing performance animation in `CharacterActor.start_scene_performance`, with `allow_unassigned=true` to support staff not currently assigned to a workplace.

`CharacterManualActivityPolicy` defines activities and modifiers:

| Destination | Activity | Duration | Effect |
|---|---|---:|---|
| Studio lounge | Socializing / relaxation | 60 min | Stronger stress reduction, improved morale |
| Cafeteria | Snack break | 35 min | Energy recovery and stress reduction |
| Fitness center | Workout | 60 min | Improves fitness, reduces stress, costs energy |
| Staff housing / star bungalow | Rest | 90 min | Energy recovery and lower stress |
| Sound stage | Actor/director rehearsal | 75 min | Acting/directing skill XP; energy cost |
| TV studio | Television rehearsal | 75 min | Acting/directing skill XP |
| Script department | Writing / production practice for matching professions | 60 min | Corresponding profession skill XP |
| Editing suite | Film-editing practice for editors | 60 min | Editing skill XP |
| Prop warehouse | Technician practice | 50 min | Technical skill XP |

Skill XP uses the existing `CharacterSkillProgressionSystem.award_skill_experience`, respecting age, skill potential, global growth points and the limit that no employee can perfect all skills. Regular character needs continue to progress; manual bonuses are applied once per *actual* activity minute, only after arrival, not during travel. Normal gameplay does not snap actors to destinations. The existing manual clock fast-forward intentionally snaps the travel endpoint, consistent with existing sim behavior.

A completed activity routes the actor back to their original workplace through the door-first navigation pipeline. Unassigned employees resume regular outdoor roaming. A temporarily unavailable return path is retried without granting additional XP or needs bonuses. When a route is blocked for three game hours before arrival, the order is abandoned; navigation recovery is still the responsibility of the existing actor navigation module.

Existing public events, filming and editing assignments block manual drag orders. A stage containing an active film or TV recording cannot be used for personal rehearsal. Film, TV and publicity systems cannot book employees while they hold a manual activity order. The normal shift dispatcher defers to that order until it completes. Facility occupancy includes employees already using seats/beds and other manual orders, preventing duplicate reservations.

## Module ownership

- `scripts/presentation/characters/character_drag_drop_controller.gd` — mouse gesture, hover and feedback
- `scripts/domain/characters/character_manual_activity_policy.gd` — permitted destinations, duration, effects
- `scripts/presentation/characters/character_manual_activity_controller.gd` — routing, reservations, lifecycle and return
- Existing `CharacterManager` and `StudioBuildingManager` gain narrow façade methods and input/scheduling hooks, without implementing the rules themselves.

## Regression test

```powershell
& $godot --headless --path . --editor --quit
& $godot --headless --path . --script res://tests/character_drag_drop_smoke_test.gd
& $godot --headless --path . --script res://tests/staff_facilities_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_cross_building_recovery_smoke_test.gd
& $godot --headless --path . --script res://tests/film_production_session_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_publicity_event_smoke_test.gd
```

The new test covers click versus drag, valid and invalid hover/drop, non-teleporting activity start, recovery from stress, scene rehearsal XP, blocking live production and return routing.

## Remaining technical work

- Full NavMesh/local avoidance for employees in crowded doorways is separate. This release reuses current door-first route building and the existing actor obstruction recovery.
- Refined task scheduling (priority, queue, cancel an already-started order, player-specified duration), save/load persistence and dedicated physical props/animations for each job will follow later.
- Visual QA in a running 3D scene is still required. Passing headless tests does not verify crowded-level collision behavior.
