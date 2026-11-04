# Foundation Prototype — controls and scope

## Current purpose

This is a technical graybox, not a representative art sample. It verifies that the Godot project opens, the free camera responds, and the simulation clock advances independently from rendering.

## Controls

- W / A / S / D or arrow keys — move the camera focus point.
- Shift — faster camera movement.
- Middle mouse drag — orbit the camera.
- Right mouse drag — pan the camera.
- Mouse wheel — zoom in/out.
- HUD buttons — pause, 1×, 3× and 6× simulation speed.

## Current implementation

- A simple placeholder studio lot made from primitive meshes.
- An orbit camera with movement, orbit, pan and zoom.
- A discrete game clock starting at day 1, 08:00.
- A small debug HUD for time and simulation speed.

## Explicitly not implemented yet

- Building placement and construction validation.
- NPCs, navigation and staff simulation.
- Save/load.
- Script Department and scenario generation.
- Film editor, scene playback and economy.

## Validation checklist

- [ ] Open the project in Godot 4.7.2 without parse or import errors.
- [ ] Run the main scene.
- [ ] Verify camera movement, orbit, pan and zoom.
- [ ] Verify that pause stops game time.
- [ ] Verify that 1×, 3× and 6× advance time at the expected relative rates.
- [ ] Verify day rollover at 24:00.
