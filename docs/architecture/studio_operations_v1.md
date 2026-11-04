# Studio Operations v1

**Engine:** Godot 4.7.2  
**Branch:** \`feature/studio-operations-v1\`  
**Status:** first workplace simulation and time-based screenplay workflow.

## Scope

Studio Operations v1 connects the active employee roster to the two existing starter buildings. Employees with supported production professions receive automatic workplace assignments, walk through the building entrance to an interior workstation and perform profession-specific work while on shift.

The slice also replaces instant screenplay generation with a time-based writing project and ensures the recruitment market offers a technician in every standard cycle.

## Workplace assignment

\`EmployeeWorkSystem\` is a domain service. It assigns active employees to operational buildings using:
- profession acceptance from \`StudioBuildingCatalog\`;
- profession-specific preferred building types;
- available workplace capacity;
- stable employee and building iteration order.

Initial preferences:

| Profession | Preferred workplace |
|---|---|
| Screenwriter, casting director | Script Department |
| Actor, extra, director, camera operator, technician, production designer | Sound Stage |
| Producer | Sound Stage, then Script Department |
| Other professions | No workplace in this slice |

The Script Department has three workplace slots. The Sound Stage has eight.

Assignments are recalculated when:
- the game initializes its workplace systems;
- a new employee is hired;
- an employee leaves or a fixed-term contract expires;
- the player places another building.

\`CharacterManager\` owns assignments and connects them to \`CharacterActor\`. Each building actor exposes a four-point route: outside approach, doorway threshold, interior corridor and assigned workstation. During breaks and off-duty time, employees reverse the route and leave through the same entrance before resuming their patrol.

Movement uses deterministic waypoints rather than NavMesh pathfinding. It clamps each movement step to avoid overshooting at accelerated simulation speeds. Collision-aware dynamic navigation and obstacle avoidance remain future work.

## Visible building interiors

Both starter buildings now contain procedural 3D interiors. The Script Department has three desks, monitors, keyboards, chairs, a bookshelf and a research board. The Sound Stage has a set backdrop, platform, floor marks, two camera rigs, lighting stands, a director monitor and a technical equipment rack. Workplace points are placed beside the matching props.

The roof assembly is hidden and the camera-facing wall is cut away when the camera is within 36 world units of a building. At a wider view, the full exterior roof and walls return. The interior remains part of the same 3D scene; employees are not hidden or replaced by UI representations.

\`CharacterVisual\` adds procedural profession-specific work poses using the existing arm and leg pivots. Writers, producers and casting staff type or work at desks; directors gesture; camera operators hold a camera stance; technicians perform equipment work; actors and extras rehearse. The existing walk animation remains the movement state and is restored when an employee leaves the workstation.

## Work tasks and skill growth

The existing profession catalogue supplies the task label and primary skill for each assigned employee.

A working employee gains experience only when:
- their scheduled state is \`working\`;
- they have a valid workplace assignment;
- their CharacterActor has reached the assigned work point.

Per in-game work minute:
- primary profession skill: +0.0012;
- reliability, when present in the profile: +0.0002.

Values are capped at 100. The existing needs system still controls shift hours, breaks, energy, stress and morale. Breaks and recovery do not grant skill progress.

The roster now displays each employee's current task. Building inspectors show assigned headcount separately from the number of employees whose professions are accepted by the building.

Employees in facility, catering, administration and marketing professions remain on their existing patrol routes until matching workplace buildings are introduced. They do not receive fabricated assignments to unrelated production buildings.

## Recruitment availability

The standard eight-person market retains its six department-representative slots and one random candidate. The seventh slot is reserved for a technician, because a technician is a required position in the starter Sound Stage crew.

This guarantee applies to the initial market and every standard seven-day refresh. It does not guarantee any particular skill value, salary or specialization.

## Timed screenplay writing

\`ScriptWritingProject\` stores:
- project and target script IDs;
- writer, genre, scene and role parameters;
- required and completed work minutes;
- deterministic random state;
- remaining interruption time and interruption count;
- start time and project status.

The required work time is:

\`base = 180 + 45 × scenes + 30 × roles\`

\`writing_factor = 1.25 − 0.0045 × writing_skill\`

\`reliability_factor = 1.10 − 0.002 × reliability_skill\`

\`required_minutes = max(60, round(base × writing_factor × reliability_factor))\`

The writer must be on shift, have sufficient energy and physically reach the Script Department before work progresses. Scheduled breaks, off-duty time, low energy and travel do not count as writing time.

During active work, the system can generate interruptions such as a phone call, creative block, unscheduled conversation or research pause. An interruption lasts 10–35 in-game minutes. Its chance increases with stress. The project's seeded random state makes interruption sequences reproducible.

Only after the required work is completed does the system invoke \`ScriptGenerator\` and create the final \`FilmScriptData\`. The final script retains the existing deterministic quality score and popularity modifier.

The current prototype supports one active writing project at a time. Projects and completed scripts are runtime-only; campaign save/load and a multi-project queue are not yet integrated.

## Window and interface

The default game window and viewport are now 1600 × 900. The staff and recruitment lists use taller scroll areas. The building inspector is docked between the recruitment panel and the employee profile panel to reduce overlap.

## Smoke tests

Run with Godot 4.7.2 from the project root:

~~~powershell
& $godot --headless --path . --script res://tests/employee_work_system_smoke_test.gd
& $godot --headless --path . --script res://tests/employee_market_critical_roles_test.gd
& $godot --headless --path . --script res://tests/script_writing_system_smoke_test.gd
& $godot --headless --path . --script res://tests/studio_building_interior_smoke_test.gd
~~~

These tests cover profession-to-building assignment, workplace capacity and skill progression, guaranteed technician availability, writing-time scaling, work-shift/workplace gates, interruptions, completion and project serialization. The interior smoke test also checks room props, rotated building routes, doorway traversal, work animation activation and leaving through the entrance.

## Explicit boundaries

Studio Operations v1 does **not** yet start film production. The Sound Stage still reports crew readiness and displays the latest completed script. Film Production v1 must add role casting, actor assignment, scene scheduling, shooting progress and the explicit start-filming action.
