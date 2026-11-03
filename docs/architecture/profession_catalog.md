# Profession Catalogue

**Engine:** Godot 4.7.2  
**Module:** \`scripts/domain/staff/profession_catalog.gd\`  
**Status:** first data-driven catalogue integrated with Employee Management v1.

## Design

Profession data is centralized instead of duplicating profession-specific dictionaries across CharacterData, CharacterGenerator, EmployeeMarketSystem and CharacterNeedsSystem.

Each profession defines:
- stable profession ID;
- localized title;
- department ID;
- primary skill;
- base daily salary expectation;
- default work-task description;
- career goal;
- biography pool.

The catalogue also owns localized department titles, skill titles and default work schedules by department.

## Departments and professions

| Department | Profession IDs |
|---|---|
| Creative | \`actor\`, \`extra\`, \`director\`, \`screenwriter\`, \`producer\`, \`casting_director\` |
| Production | \`camera_operator\`, \`assistant_camera_operator\`, \`gaffer\`, \`lighting_technician\`, \`sound_engineer\`, \`boom_operator\`, \`film_editor\`, \`production_designer\`, \`set_builder\`, \`costume_designer\`, \`makeup_artist\`, \`props_master\`, \`technician\` |
| Facility | \`cleaner\`, \`maintenance_worker\`, \`electrician\`, \`security_guard\` |
| Catering | \`chef\`, \`sous_chef\`, \`bartender\`, \`waiter\`, \`cafeteria_worker\` |
| Administration | \`secretary\`, \`personal_assistant\`, \`receptionist\`, \`hr_manager\`, \`accountant\`, \`office_manager\` |
| Marketing | \`marketing_manager\`, \`advertising_manager\`, \`pr_specialist\`, \`social_media_manager\`, \`graphic_designer\`, \`press_officer\` |

The \`technician\` ID is retained for compatibility with Character System v2 data.

## Integration

- CharacterData resolves job title, department and primary skill through the catalogue.
- CharacterGenerator creates the complete skill set and profession-specific salary, biography, career goal and work schedule.
- EmployeeMarketSystem samples candidates across all departments so a default eight-person market represents every department.
- CharacterNeedsSystem uses profession-specific default task descriptions.
- CharacterManager displays department and profession information in candidate and employee profiles.

New skill keys are merged with default values when deserializing older CharacterData payloads.

## Current boundaries

The catalogue does not yet provide:
- department-specific buildings or room requirements;
- uniforms or profession-specific 3D appearance;
- workstations, equipment requirements or task targets;
- specialized cleaning, cooking, serving, security or personal-assistant behavior;
- staffing quotas or department leadership hierarchy.

Those behaviors belong to Studio Operations and Employee AI, which will consume this catalogue rather than maintaining their own profession lists.
