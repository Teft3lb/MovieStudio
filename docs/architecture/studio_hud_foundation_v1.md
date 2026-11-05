# Studio HUD Foundation v1

## Purpose

Provide one presentation-layer shell for the game's current management interfaces. This is a UI refactor only: simulation, employee, construction, film production, set dressing, and editing domain behavior remain owned by their existing systems.

## Layout

- Top bar: studio identity, simulation date/time, speed controls.
- Navigation rail: switches between registered workspace sections.
- Workspace: one active section at a time.
- Context inspector: one selected object's detail panel at a time.
- Developer section: manual time advancement tools, separated from normal play.

## Ownership

StudioHUD owns layout, navigation, and visibility only.

CharacterManager registers:
- Employee roster workspace.
- Recruitment market workspace.
- Employee/candidate context inspector.

StudioBuildingManager registers:
- Studio/building workspace.
- Selected building context inspector.

Both managers continue to own their data, commands, and refresh logic. They only hand their Control trees to the HUD for placement.

## Interaction rules

- Selecting an employee opens the employee workspace and employee inspector.
- Selecting a recruitment candidate opens the market workspace and candidate inspector.
- Selecting a building opens the studio workspace and building inspector.
- Switching workspace sections hides the previous inspector.
- Developer time controls are available under the DEV section, not permanently visible.
- Layout uses Godot containers and minimum sizes rather than fixed screen coordinates.

## Compatibility constraints

- No Domain system depends on StudioHUD.
- Existing game-clock speed and manual fast-forward actions remain unchanged.
- Existing employee, building, production, and editing commands remain unchanged.
- The HUD is a Presentation-layer dependency of the existing presentation managers only.
