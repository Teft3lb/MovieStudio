# Character System v2

**Status:** first interactive employee-management prototype.  
**Branch:** `main`.  
**Base:** `Character System v1`.

## Goals

Turn the initial six employees from moving scene props into inspectable simulation entities. The player can select an employee in the world or from the roster and inspect a persistent profile.

## World selection

Each CharacterActor:
- belongs to the `studio_employee` group;
- owns a capsule StaticBody3D hitbox on collision layer 2;
- exposes a stable character ID;
- owns a hidden torus selection marker that appears while selected.

CharacterManager casts a camera ray on left-click and walks up the hit collider's parent chain to find the employee actor. Clicking an employee roster entry selects the same actor. The selected employee is highlighted in the world and in the roster.

The selection hitbox is separate from the visual meshes. This keeps picking reliable while the procedural model is replaced with rigged assets later.

## Employee profile

CharacterData originally introduced schema version 2. The current schema version 9 stores birthday progress, per-skill experience, physical fitness and pairwise employee relationships. The profile includes:
- short generated biography;
- career ambition;
- shift and break hours;
- current work state and task.

The detail panel displays profession, age, experience, popularity, daily salary in abstract units, career ambition, professional skills and personality traits. Existing IDs and generated attributes remain serializable.

## Work schedule and needs

CharacterNeedsSystem is a simulation-domain service. It advances only when GameClock emits a game-minute event; it does not use frame delta.

Initial schedule:
- shift: 08:00–17:00;
- lunch break: 12:00–13:00;
- outside the shift: off duty.

Initial needs:
- energy decreases while working and recovers during breaks and off-duty time;
- stress rises during work and decreases during breaks and off-duty time;
- morale reacts gradually to prolonged high stress / low energy and to sustained good conditions.

Profession-specific tasks provide readable activity labels. These rates are initial balancing values and will be tuned after playtesting.

## UI

The left roster lists all employees and shows their work state, energy and morale. The right detail panel shows the selected employee's profile, current task, schedule, needs, skills and personality. The player can select from either the world or roster.

## Smoke test

Run from the project root:

~~~bash
godot --headless --path . --script res://tests/character_system_v2_smoke_test.gd
godot --headless --path . --script res://tests/character_lifecycle_smoke_test.gd
~~~

The test covers:
1. generated biography, career goal and schedule defaults;
2. CharacterData serialization round-trip, including new schema fields and legacy defaults;
3. work, break and off-duty state transitions;
4. energy and stress changes during work and recovery;
5. employee group registration, selection hitbox and visible selection marker.

## Deliberate limitations

Not part of v2:
- hiring and firing;
- contracts and payroll;
- complete relationship graph and social-event simulation;
- advanced autonomous behavior;
- NavMesh pathfinding and obstacle avoidance;
- full character customization;
- save-game migration framework.

The current six-person roster remains a deterministic prototype roster. Salary is displayed but is not yet charged to the studio economy.

## Skill progression and aging

CharacterData schema version 7 introduced skill progression and accelerated biological aging. Schema version 8 extends it with physical fitness and pairwise relationships. The v7 fields are:
- `skill_xp`: per-skill accumulated experience toward the next mastery point;
- `skill_caps`: the employee's individual potential ceiling for each professional skill;
- `growth_points_total` and `growth_points_remaining`: a finite career-long development reserve;
- `age_days`: progress toward the next biological year, measured in game days (0–72).

The starting six-person roster is generated as junior staff: primary skills begin at 18–40, specialization skills at 16–38 and professional experience at 0–5 years. The employee market continues to generate a broader range of candidates, including experienced specialists.

Professional mastery is persistent but not unlimited. Every skill has an employee-specific potential ceiling below 100 for newly generated characters. The primary profession skill and selected specialization can develop further than secondary skills; reliability and supporting skills have their own lower ceilings. Each mastery point also consumes one point from a shared career-long development reserve. Once the reserve is exhausted, no skill can improve further. This makes role assignments and practical experience meaningful choices instead of allowing every employee to become universally perfect.

Normal work develops the employee's primary skill and reliability slowly. Rehearsal and shooting develop the cast and the selected crew. Production experience is distributed across the duration of a phase, so increasing the length of a rehearsal or take does not multiply the total training reward. Age modifies the learning rate, while personal potential and the remaining career reserve bound total growth.

Biological aging is intentionally faster than the operational clock: one biological year passes every 73 game days, so a full 365-day game year advances a character by exactly five biological years. The calendar itself is unchanged; work shifts, lunch, sleep, needs and production schedules continue to use the same game minutes. Legacy schema v6 age progress is migrated proportionally to the new 73-day cycle.

The initial roster remains six employees. Film roles, optional crew positions and background performers are assigned from existing employees; the simulation does not automatically hire or spawn staff. Only player-driven hiring may increase the employee count.

## Character schema version 9 additions

Schema 9 adds one persistent field to the existing profile:
- recognition: 0–100 public awareness, distinct from popularity and increased by television appearances. Physical fitness and reciprocal relationship scores remain part of the schema 8 profile.

CharacterManager advances relationship scores only when two employees have arrived at the same Studio Lounge. Sociability, ambition and discipline influence compatibility; incompatible pairs can develop negative scores. The employee inspector displays the strongest current relationships.

Older saves remain compatible: missing physical_fitness defaults to 50, missing relationships defaults to an empty dictionary, and schema 8 recognition initializes from the saved popularity score.

## Sleeping pose and bed alignment

Staff-housing and star-bungalow arrivals apply the sleeping pose immediately, including instant placement during manual fast-forward. The character's body axis is aligned with the bed's longitudinal axis using the building's world transform, so rotated housing buildings keep sleepers aligned with their mattresses.

## Employee skill profile presentation

The employee inspector displays each profession skill as a progress bar matching the energy and stress indicators in height and track contrast, scaled to that employee's individual skill cap. This makes current mastery and remaining personal potential readable without small numeric fractions. Exact skill/cap values, the remaining experience to the next point, and exhausted/achieved potential states remain available in the control tooltip. Skill rows are reused while the selected employee's profession remains unchanged, avoiding per-minute UI reconstruction.


## Employee roster presentation

`EmployeeRosterPanelController` owns the employee roster and recruitment-market workspace controls, row creation, candidate rendering and refresh behavior. `CharacterManager` remains the owner of employee selection, hiring/dismissal, market timing, work-state decisions and production-participant status; it supplies callbacks and data to the view controller. The employee detail inspector and skill-progress UI remain in CharacterManager for the next presentation extraction pass.


## Employee skill progression presentation

`EmployeeSkillProgressView` owns the reusable skill-row and progress-bar hierarchy, including individual mastery caps, progress-to-next-point tooltips and in-place refreshes. `CharacterManager` retains the Domain skill progression service and provides compatibility methods for profile refresh and clearing. The view does not change skill values, caps, growth points or progression balance.


## Employee profile presentation

`EmployeeProfilePanelController` owns the employee inspector hierarchy, profile text/needs rendering, contract selector, hire/dismiss controls and workplace-dispatch button presentation. `CharacterManager` prepares profile data and remains responsible for candidate selection, contract offers, hiring, dismissal, work assignments and dispatch eligibility. The view emits user actions through Callables and exposes the skill container to the separate `EmployeeSkillProgressView`.
