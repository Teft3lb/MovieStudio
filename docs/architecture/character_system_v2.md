# Character System v2

**Status:** first interactive employee-management prototype.  
**Branch:** \`feature/character-system-v2\`.  
**Base:** \`feature/character-system-v1\`.

## Goals

Turn the initial six employees from moving scene props into inspectable simulation entities. The player can select an employee in the world or from the roster and inspect a persistent profile.

## World selection

Each CharacterActor:
- belongs to the \`studio_employee\` group;
- owns a capsule StaticBody3D hitbox on collision layer 2;
- exposes a stable character ID;
- owns a hidden torus selection marker that appears while selected.

CharacterManager casts a camera ray on left-click and walks up the hit collider's parent chain to find the employee actor. Clicking an employee roster entry selects the same actor. The selected employee is highlighted in the world and in the roster.

The selection hitbox is separate from the visual meshes. This keeps picking reliable while the procedural model is replaced with rigged assets later.

## Employee profile

CharacterData schema version 2 adds:
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
~~~

The test covers:
1. generated biography, career goal and schedule defaults;
2. schema v2 serialization round-trip;
3. work, break and off-duty state transitions;
4. energy and stress changes during work and recovery;
5. employee group registration, selection hitbox and visible selection marker.

## Deliberate limitations

Not part of v2:
- hiring and firing;
- contracts and payroll;
- relationship graph;
- advanced autonomous behavior;
- NavMesh pathfinding and obstacle avoidance;
- full character customization;
- save-game migration framework.

The current six-person roster remains a deterministic prototype roster. Salary is displayed but is not yet charged to the studio economy.
