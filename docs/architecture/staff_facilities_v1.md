# Staff Facilities v1

**Engine:** Godot 4.7.2  
**Status:** first playable staff-service facilities.

## Buildings

| Building | Capacity | Purpose |
|---|---:|---|
| Cafeteria | 12 seats | Employees visit during their scheduled lunch break |
| Staff Housing | 8 beds | Employees visit after their shift to rest |

Both buildings are optional construction choices in the Studio building palette. The existing off-duty and lunch roaming behavior remains available when the corresponding facility has not been built or has no free slot.

## Runtime behavior

- `CharacterManager` assigns facility slots deterministically from the employee roster and the built facility list.
- `CharacterActor` owns a temporary facility route separate from its permanent workplace route. This prevents a lunch or overnight visit from overwriting the employee's assigned workstation.
- The route planner exits the source building, follows the outdoor navigation path, then enters the destination facility.
- At 12:00, employees with a cafeteria slot walk to a seat, play an eating pose, and receive improved energy recovery and stress reduction.
- At 13:00, they return to their assigned workplaces.
- At the end of their shift, employees with a housing slot walk to a bed, play a resting pose, and receive improved overnight energy recovery and stress reduction.
- At the next shift, they return to their assigned workplaces.
- Employees assigned to an active film production are not sent to facilities. Production dispatch can recall an employee from a facility when their role is required.
- Facility visits do not replace workplace assignments. Facility occupancy is reported separately in the selected building inspector.

## Developer tools

The Developer workspace includes a `+10,000` button. Each press adds 10,000 units to the Set Dressing Workshop budget, refreshes the decor shop and reports the resulting balance. The grant is intentionally separate from the future studio-wide economy and payroll ledger.

## Smoke tests

Run from the project root:

~~~bash
godot --headless --path . --script res://tests/studio_building_system_smoke_test.gd
godot --headless --path . --script res://tests/character_system_v2_smoke_test.gd
godot --headless --path . --script res://tests/studio_set_inventory_smoke_test.gd
godot --headless --path . --script res://tests/studio_hud_smoke_test.gd
godot --headless --path . --script res://tests/staff_facilities_smoke_test.gd
~~~

The facility tests cover building capacities and interior route points, facility travel and return without losing workplace assignments, cafeteria and housing recovery bonuses, visitor occupancy, and the developer budget grant.

## Manual verification

1. Open the Studio workspace and place a Cafeteria and one or more Staff Housing buildings.
2. Inspect each building and confirm the seat/bed capacity and current visitor count.
3. Advance the clock to 12:00. Confirm assigned employees walk from their workplaces to cafeteria seats and display the eating task.
4. Confirm lunch improves energy and reduces stress more quickly than an ordinary break.
5. Advance to 13:00. Confirm employees leave the cafeteria and return to their original workplace positions.
6. Advance to the end of the shift. Confirm employees walk to available beds and display the resting task.
7. Advance to the next shift. Confirm employees leave housing and return to their assigned workstations.
8. Start a film production and cross a lunch or shift boundary. Confirm active production participants stay with the shoot and are not pulled into facilities.
9. Open Developer Tools, press `+10,000`, and confirm the decor shop budget increases by exactly 10,000 and the updated balance is shown.
10. Recheck navigation around building footprints, the access road, sound-stage walls, manual fast-forward and pause behavior.

## Limitations

- Facility visits are not part of campaign save/load until the campaign SaveSystem is integrated.
- Sleeping and eating currently use procedural standing poses; seated/lying skeletal animations are a later character-animation task.
- Facility buildings have no construction price yet; construction costs belong to the future Studio Economy system.
- Employees beyond built facility capacity keep the existing fallback behavior until additional capacity is constructed.
