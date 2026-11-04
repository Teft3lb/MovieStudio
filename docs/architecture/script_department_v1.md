# Script Department v1

**Engine:** Godot 4.7.2  
**Branch:** \`feature/studio-buildings-v1\`  
**Status:** first deterministic script generation prototype.

## Player workflow

1. Select the Script Department building.
2. Choose an active screenwriter from the studio roster.
3. Choose a genre.
4. Set the number of scenes (3–20).
5. Set the number of roles (1–8).
6. Generate the script.
7. Review its potential rating and structured scene outline.
8. Select the Sound Stage to inspect the script and crew readiness.

A screenwriter is required. The generator rejects employees whose profession is not \`screenwriter\`.

## Supported genres

- Drama
- Comedy
- Action
- Romance
- Mystery / detective
- Adventure
- Science fiction

Genre content is local data: title pools, loglines, locations, actions, dialogue prompts and a baseline genre score. Generation does not require an external AI service or internet access.

## Generated data

\`FilmScriptData\` stores:
- stable script ID;
- title and genre;
- logline;
- writer ID and display name;
- requested scene and role counts;
- cast with role IDs and character names;
- ordered scenes with dramatic beat, location, action, dialogue and characters present;
- potential score (0–100);
- potential rating (1–5 stars);
- popularity modifier (0.80–1.20).

The data model supports dictionary serialization for later save/load and Film Editor integration.

## Potential success rating

The score is deterministic for the same writer data, genre, order parameters and seed.

Current score composition:

| Factor | Weight |
|---|---:|
| Screenwriting skill | 34% of writer score |
| Story structure | 25% of writer score |
| Dialogue | 16% of writer score |
| Creativity | 15% of writer score |
| Research | 10% of writer score |
| Writer score contribution to final rating | 58% |
| Scene-count fit | 14% |
| Role-count fit | 10% |
| Genre baseline | 18% |

A small seeded variation prevents every script with identical inputs from receiving exactly the same score while preserving reproducibility.

Star thresholds:
- 1 star: below 45;
- 2 stars: 45–59;
- 3 stars: 60–73;
- 4 stars: 74–87;
- 5 stars: 88–100.

The popularity modifier is derived from the score:

\`modifier = 0.80 + potential_score / 250\`

It is an input for the future film-success model, not a guaranteed probability of box-office success. Direct audience preferences, current genre demand, market saturation, script originality analysis and production quality are not yet simulated.

## Integration

- The Script Department UI reads employees through \`CharacterManager.get_employees()\`.
- The selected screenwriter's skills directly affect the score.
- The latest generated script is held by \`StudioBuildingManager\` in runtime memory and displayed by the Sound Stage.
- Pressing the order button creates a `ScriptWritingProject`; the final `FilmScriptData` is generated only after the required work time is completed.
- The writer must be assigned to the Script Department, reach its work point, be on shift and have sufficient energy.
- Writing time scales with scene count, role count, writing skill and reliability. Work pauses during travel, breaks, off-duty hours, low energy and random 10–35 minute interruptions.
- Workplace assignment and task progress are implemented by Studio Operations v1. Projects remain runtime-only until campaign save/load is added.

## Smoke test

Run from the project root using Godot 4.7.2:

~~~powershell
& $godot --headless --path . --script res://tests/script_generator_smoke_test.gd
~~~

The test covers requested scene and role counts, scene structure, rating bounds, deterministic output, serialization, writer skill influence and rejection of non-screenwriters.

## Deliberate limitations

Not included:
- manual screenplay editing;
- full branching story logic;
- scene dependency graph;
- character relationship continuity;
- genre trend simulation and audience segmentation;
- screenplay revisions and writer work duration;
- persistent campaign storage;
- direct film production and box-office calculation.
