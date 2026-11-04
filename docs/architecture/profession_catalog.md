# Profession Catalogue

**Engine:** Godot 4.7.2  
**Module:** `scripts/domain/staff/profession_catalog.gd`  
**Status:** focused 19-profession catalogue integrated with Employee Management v1.

## Design

The catalogue deliberately limits the studio workforce to **19 professions across six departments**. The creative department receives the greatest role depth because actors, directors, screenwriters and producers directly affect the player's film-making decisions. Other departments use broad professions rather than a separate job for every production task.

A profession defines:
- stable profession ID;
- localized title and department;
- primary skill;
- base daily salary expectation;
- default work-task description;
- career goal and biography pool.

Specialization is a lightweight profile attribute, not a separate profession or candidate-market category. It reuses the existing skill model and is deliberately limited to three professions where it adds meaningful production variety.

## Departments and professions

| Department | Count | Profession IDs |
|---|---:|---|
| Creative | 6 | `actor`, `extra`, `director`, `screenwriter`, `producer`, `casting_director` |
| Production | 3 | `camera_operator`, `technician`, `production_designer` |
| Facility | 3 | `cleaner`, `maintenance_worker`, `security_guard` |
| Catering | 3 | `chef`, `bartender`, `waiter` |
| Administration | 2 | `secretary`, `personal_assistant` |
| Marketing | 2 | `marketing_manager`, `pr_specialist` |
| **Total** | **19** | |

## Specializations

Only three professions have specializations:

- Technician: lighting, sound, equipment, editing.
- Production designer: sets, costumes, makeup, props.
- Marketing manager: advertising, social media, advertising design.

All other professions remain broad, without additional specialization layers. This keeps the non-creative workforce easy to understand and avoids turning staff management into RTS-style micromanagement.

## Compatibility

The six Character System v2 profession IDs remain stable: `actor`, `director`, `screenwriter`, `camera_operator`, `producer` and `technician`. Their verified 08:00–17:00 schedule and 12:00–13:00 break are preserved, along with the existing camera-operator title and task label.

The previous 40-role draft is not allowed to leak into the active market. Its 21 additional role IDs are retained as migration aliases and resolve to one of the 19 supported professions. Where a former role maps naturally to one of the three supported specialization groups, that specialization is retained. Old character payloads without `specialization_id` remain loadable.

## Integration

- CharacterData stores and serializes the specialization ID.
- CharacterGenerator selects a valid specialization for the three supported professions and gives its mapped existing skill a profession-appropriate value.
- EmployeeMarketSystem samples only the 19 active profession IDs and continues to represent all six departments in the initial eight-candidate market.
- CharacterManager displays a specialization next to the profession when one exists.
- CharacterNeedsSystem continues to use the profession's default work-task description; specializations do not create separate task loops.

## Boundaries

The catalogue does not create department buildings, staffing quotas, dedicated workstations, uniforms, animations or specialized autonomous behaviors. Those belong to later Studio Operations / Employee AI systems.