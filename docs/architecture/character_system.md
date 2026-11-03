# Character System v1

**Status:** first playable prototype specification.  
**Scope:** character data, deterministic generation, procedural placeholder visual, simple movement and roster UI.

## 1. Design goals

A character is a persistent simulation entity, not merely a mesh in the 3D scene. The same identity and state must later support hiring, contracts, careers, relationships, film casting, needs and save/load.

The first implementation intentionally limits itself to six visible employees and a small set of professions. It validates the data and presentation pipeline before adding complex AI.

## 2. Character state

The initial CharacterData model contains:
- stable ID;
- first and last name;
- profession ID and age;
- experience, popularity and daily salary;
- professional skills;
- personality traits;
- needs (energy, morale, stress);
- appearance parameters.

The state is serializable through to_dict() and from_dict(). The schema has an explicit version field. This is an initial DTO-style representation; a dedicated save migration layer will be introduced with SaveSystem.

## 3. Deterministic generation

CharacterGenerator receives a RandomNumberGenerator, a stable character ID and a profession ID.

All generated fields derive from the supplied RNG. Given the same seed and inputs, the result must be identical. This supports reproducible tests, debugging and future campaign generation.

The first profession set is:
- actor;
- director;
- screenwriter;
- camera operator;
- producer;
- technician (supported by the data model and generator, not in the initial roster).

Profession-specific primary skills and salary baselines are data-driven dictionaries for this prototype. They are balancing placeholders, not final economy values.

## 4. Appearance and visual representation

CharacterVisual builds a stylized human placeholder from primitive meshes:
- torso and trousers;
- head, ears and simple facial features;
- hair variants;
- arms and hands;
- legs and shoes.

Appearance indices choose skin, hair and outfit palettes. Height and head scale introduce basic variation. This is a graybox/procedural prototype, not final character art.

The target art direction remains stylized realism inspired by The Movies: readable silhouettes, human proportions, expressive faces and reusable modular clothing. A production character will later use a shared rig, skinned meshes, modular clothing and authored animation clips.

## 5. Character actor and movement

CharacterActor owns one character's 3D presentation and a temporary waypoint route.

For v1, movement is a deterministic loop between hand-authored waypoints. A simple procedural swing animates arms and legs. This deliberately avoids NavMesh and pathfinding until the building, walkable-area and obstacle systems are designed.

Character movement and its procedural walk animation consume the same scaled delta from GameClock via get_simulation_delta(real_delta). At 0×, both freeze; at 3× or 6×, both advance at the matching simulation rate. This is intentionally simulation-local: camera controls and the rest of the presentation layer are not slowed by changing Engine.time_scale.

Future navigation must account for:
- building entrances and exits;
- doors and access restrictions;
- walkable surfaces;
- obstacles and crowd avoidance;
- work destinations and schedules;
- off-screen simulation.

## 6. Initial roster

The main scene spawns six employees:
- two actors;
- one director;
- one screenwriter;
- one camera operator;
- one producer.

A fixed seed makes the initial roster reproducible while still giving each employee different names, skills, personality, needs and appearance. The roster panel exposes the generated names, professions, primary skills and morale.

## 7. Current limitations

Not implemented in Character System v1:
- hiring and firing UI;
- contracts, wages and payroll integration;
- selection and character detail panel;
- relationship graph;
- schedules, tasks and workplace assignments;
- needs decay and recovery;
- autonomous social behavior;
- navigation mesh;
- save/load integration;
- final rigged character assets and animation library.

These are deliberate follow-up systems, not hidden assumptions.

## 8. Smoke test

Run from the project root:

~~~powershell
godot --headless --path . --script res://tests/character_system_smoke_test.gd
~~~

The test checks:
1. generation creates a valid identity and expected actor skill;
2. appearance parameters exist;
3. to_dict() / from_dict() preserve key state;
4. identical seeds and inputs produce identical character data.

The interactive test is to launch the main scene and verify six visible characters, readable name tags, walking animation and roster entries.
