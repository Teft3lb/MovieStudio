# Character Context UI & HUD Refactor v1

## Scope

This increment introduces a new character interaction layer and a warmer cinematic visual system without replacing the existing employee simulation, workplace assignments, production, publicity or skill progression.

## Visual language

The HUD now uses a shared `StudioUITheme` resource with a warm studio palette: charcoal and plum surfaces, muted burgundy, brass/gold highlights, cream typography and semantic status colors. The theme owns shared control styling and reusable panel/card/notification styles.

The management navigation uses icon-led section labels. The HUD also exposes a lightweight notification stack so routine employee actions no longer need to create blocking confirmation windows.

## Character selection and radial actions

`CharacterContextMenuController` owns the context-menu flow and coordinates two independent views: `CharacterActionWheel` and `CharacterDetailsDialog`. Selecting a 3D employee or an employee roster entry opens the radial wheel near the character's projected screen position. The center shows the employee monogram, name, profession and current task. The compact wheel uses a 380×380 logical layout, 104×62 action buttons and a 116×108 center card; the six-action arrangement is tested for button/card collisions and viewport bounds. Action availability is built from the employee's profession, assignment and live simulation state.

The large CharacterManager remains the source of simulation state and exposes narrow action/query methods; it does not build the radial controls or own their visual layout.

Current radial actions include:

- Character details.
- Profession-specific activity ("По своим делам").
- Rest in an available leisure facility.
- Actor/extra fitness training when the fitness center is available.
- Fan meeting for actors, subject to production availability.
- Cancel an active manual activity/workplace dispatch or return to the assigned workplace.

The radial menu is presentation-only. It delegates all actions to CharacterManager and the existing activity/publicity systems.

## Profession-specific activity

`CharacterManualActivityPolicy` now defines preferred activity building types by profession. The manager searches operational buildings in that priority order and asks the existing manual activity controller to validate capacity, route, production conflicts and availability before dispatching the employee.

Examples:

- Actors/extras: rehearsal stage, fitness center, lounge, cafeteria.
- Directors: rehearsal stage, lounge, cafeteria.
- Screenwriters/producers/casting directors: script department, lounge, cafeteria.
- Camera operators: stage practice, lounge, cafeteria.
- Film editors: editing suite, lounge, cafeteria.
- Technicians/production designers/maintenance workers: prop warehouse, lounge, cafeteria.
- Other professions: lounge or cafeteria.

Camera operators can use the sound stage for camera practice. Production designers and maintenance workers can use the prop warehouse for role-appropriate practice. These activities use the existing timed manual-order flow and skill progression; they do not create a parallel AI or schedule system.

Manual activities can now be cancelled through a safe return-to-workplace route. If the return route is temporarily blocked, the order remains active and the UI reports that it will finish once a safe route is available.

## Character details window

The radial wheel opens a separate modal character sheet containing:

- Name, profession, department, age and current task.
- Experience, popularity, recognition, salary and development-point reserve.
- Energy, morale, stress and actor physical fitness.
- Profession-specific skill bars with individual skill caps.
- Biography, career goal, personality and contract.

The modal refreshes while open using the existing employee minute updates. It does not change character data or progression.

## Compatibility and boundaries

- Existing Character System v2 simulation remains the source of truth.
- Existing employee roster and recruitment market remain registered workspace panels.
- Candidate hiring/dismissal controls and publicity controls remain in the existing profile inspector.
- Selecting a 3D employee no longer forces the roster workspace open; the radial menu is the primary interaction.
- Selecting a roster row opens the same radial menu, keeping world and list interaction consistent.
- The current 3D drag-to-building gesture remains available. The radial menu is a separate click interaction.
- This is the first UI migration pass. Building, film production, editing, shop and recruitment workspaces still need to be migrated to the new visual components in later increments.
