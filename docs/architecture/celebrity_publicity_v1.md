# MovieStudio — Celebrity career & publicity v1

Target engine: **Godot 4.7.2**. This module extends Character System v2 and TV Production without replacing either system.

## Career metrics

`CharacterData.recognition` (UI: **Известность**) measures how widely an actor or director is known as a career figure. It is a persistent 0–100 property, distinct from `popularity` (current audience appeal), professional skills, experience and reputation between employees.

**Film release effects:** `CelebritySystem.apply_film_release` evaluates the final film quality at dossier release. Quality below 55 causes negative recognition changes, while better credits increase fame. Very poor productions also reduce popularity. Credit weight depends on role (lead actors, extras, director); director credits carry additional responsibility. Positive recognition growth diminishes near 100, but a notorious flop may damage even a major celebrity. No additional full-film simulation is required. This modifies the already-existing `on_film_dossier_released` hook; fame is not awarded merely when filming completes.

**TV effects:** The existing `CelebritySystem.apply_tv_appearance` still increases recognition by audience reach and quality for eligible television performances. A talk-show invitation requires `recognition >= 70`, but it is just one optional effect of celebrity status. The employee profile shows **Известность · X / 100** without framing it as a TV-only resource.

## Repeatable non-film activities

`CelebrityPublicitySystem` owns event config, eligibility, 0–100 career gains, 0–1 needs deltas, cooldowns and guard protection. Actors and directors can run:

| Activity | Duration (game minutes) | Cooldown | Main effect | Tradeoff |
|---|---:|---:|---|---|
| Fan meet | 60 | 2 game days | Public recognition and popularity | Energy and stress |
| Paparazzi session | 30 | 1 game day | Public recognition, some audience interest | Higher stress; poor coverage may reduce popularity |

No fame is granted before completion. Events require sufficient energy and an available 3D employee actor. A single event can be active on the studio lot at a time, and an employee cannot be booked simultaneously for film, editing or TV production.

`StudioPublicityEventController` selects an exterior meeting site by an operational building's door, routes the star using the existing scene/outdoor navigation, and invites temporary `StudioPublicityCrowd` NPCs. Fans gather in the 3D lot; paparazzi carry visible camera props. Crowd members are visual transient characters with no staff contracts, salary or capacity requirements.

Hired employees with profession `security_guard` are automatically offered guard positions beside the event; they move using their actual 3D actors and current-to-site routes. **Only guards physically at the meeting site count.** Each contributes `0.16 + skill_security * 0.0015` protection, up to 90%. Stress exposure is multiplied by `1 - protection` per in-game minute. Hiring additional guards improves protection only if they reach the event. A guard already occupied with production or editing is ineligible. The event's last result includes the number present and actual stress cost.

Actors/guards return toward their previous workplace after the event; an unassigned guard returns to ordinary roaming. Routine dispatch and breaks do not interrupt the event; manual fast-forward uses existing mark snapping, not ordinary frame-by-frame teleporting. The controller exposes a conflict query so film and TV cannot book event participants.

The profile's **Публичная жизнь** section launches fan meets and paparazzi sessions. Invitations do not require reaching the talk-show threshold, so fame can develop from early career stages.

## Developer testing

`DeveloperEmployeePanel` is attached to the existing **DEV** workspace, not to ordinary gameplay actions. It lists the *current* hired staff, allows selection of `recognition`, `popularity`, `experience`, `physical_fitness`, energy, morale, stress and individual profession skills (plus all skills), and exposes `-10`, `+10`, `+25`, `=70`, and `=100` buttons. A refresh button picks up hires and dismissals. `CharacterDevTuning` validates and clamps writes; needs are converted from displayed percent to persisted 0–1 values.

This deliberately bypasses organic experience/skill caps in DEV only. It does **not** remove growth limits from the normal simulation and does not create employees.

## Regression tests

From the repository root (Godot 4.7.2):

```powershell
& $godot --headless --path . --editor --quit
& $godot --headless --path . --script res://tests/celebrity_publicity_system_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_publicity_event_smoke_test.gd
& $godot --headless --path . --script res://tests/developer_employee_panel_smoke_test.gd
& $godot --headless --path . --script res://tests/tv_guest_show_smoke_test.gd
& $godot --headless --path . --script res://tests/employee_profile_panel_controller_smoke_test.gd
& $godot --headless --path . --script res://tests/film_production_session_smoke_test.gd
```

## Remaining limitations

- Public events currently share a single event slot. Multiple parallel locations, staffing budgets and admission fees are future Studio Economy/PR features.
- Event cooldown state and transient visitor positions are not yet connected to the planned Save System.
- Crowd models intentionally reuse the prototype character visuals, pending replacement with final 3D models.
- The event relies on current door-first routing. The 3D test scenario must still be visually verified in the editor, especially in densely built lots.
- Natural character skill caps remain unchanged outside developer tools.
