# Profession Catalogue

**Engine:** Godot 4.7.2  
**Module:** `scripts/domain/staff/profession_catalog.gd`  
**Status:** 20 active professions with profession-specific skill profiles.

## Design

The catalogue is the single source of truth for department membership, localized profession titles, salary expectations, biographies, career goals, default work tasks, schedules, specializations and skill profiles.

The studio has **20 professions across six departments**

Every profession receives **4–8 relevant skills**, not the entire studio-wide skill catalogue. Reliability is broadly useful across the workforce; communication appears only where the role actually requires it. A profession's primary skill is always included. A supported specialization adds its own skill where it is distinct from the base profile.

## Departments and professions

| Department | Count | Profession IDs |
|---|---:|---|
| Creative | 6 | `actor`, `extra`, `director`, `screenwriter`, `producer`, `casting_director` |
| Production | 4 | `camera_operator`, `technician`, `production_designer`, `film_editor` |
| Facility | 3 | `cleaner`, `maintenance_worker`, `security_guard` |
| Catering | 3 | `chef`, `bartender`, `waiter` |
| Administration | 2 | `secretary`, `personal_assistant` |
| Marketing | 2 | `marketing_manager`, `pr_specialist` |
| **Total** | **20** | |

## Profession skill profiles

| Profession | Skills |
|---|---|
| Actor | Acting, improvisation, diction, movement, screen presence, communication, creativity, reliability |
| Extra | Acting, movement, camera work, communication, reliability |
| Director | Directing, visual storytelling, actor direction, camera work, creativity, management, communication, reliability |
| Screenwriter | Writing, story structure, dialogue, character development, research, creativity, reliability |
| Producer | Management, budgeting, negotiation, planning, communication, reliability |
| Casting director | Casting, observation, acting, communication, negotiation, management, reliability |
| Camera operator | Camera work, composition, lighting, technical, visual storytelling, reliability |
| Technician | Technical, maintenance, set design, prop design, reliability, communication, plus one specialization skill |
| Film editor | Editing, visual storytelling, sound, creativity, reliability |
| Production designer | Set design, creativity, technical, communication, reliability, plus one specialization skill |
| Cleaner | Maintenance, organization, hygiene, reliability |
| Maintenance worker | Maintenance, technical, safety compliance, reliability |
| Security guard | Security, observation, communication, safety compliance, reliability |
| Chef | Culinary, menu planning, hygiene, organization, creativity, reliability |
| Bartender | Hospitality, beverage service, communication, organization, reliability |
| Waiter | Hospitality, service speed, communication, organization, reliability |
| Secretary | Administration, communication, organization, planning, reliability |
| Personal assistant | Communication, administration, organization, planning, discretion, reliability |
| Marketing manager | Marketing, market research, creativity, communication, management, planning, reliability, plus one specialization skill |
| PR specialist | Communication, marketing, writing, press relations, negotiation, crisis management, reliability |

## Specializations

Specializations are profile attributes, not additional professions or market categories:

- Technician: lighting, sound, equipment, editing.
- Production designer: sets, costumes, makeup, props.
- Marketing manager: advertising, social media, advertising design.

The specialization skill is included in the employee's skill dictionary and receives a higher generation range. Duplicate base/specialization skills are shown only once.

## Integration

- `CharacterGenerator` creates only the skill IDs allowed by the selected profession and specialization.
- `CharacterData` stores only that profile's skills and filters out unrelated IDs when deserializing.
- `CharacterManager` renders only the selected employee's skill profile.
- The primary profession skill is generated at a higher range than secondary skills.
- The existing six Character System v2 profession IDs keep their verified work schedules and task labels.
- Film editors use the production department schedule and are assigned to the Editing Suite; the standard eight-person market cycle guarantees one editor alongside the guaranteed technician.

## Save data

This is a new development-only data shape; no released save-game compatibility or migration path is maintained. CharacterData schema version is 5.

## Boundaries

Skill values are currently generated profile attributes. Skill-based production outcomes, learning, training, career progression and skill decay are future systems; this change does not invent new simulation loops for them.
