# Staff Facilities v1

**Engine:** Godot 4.7.2  
**Status:** first playable staff-service facilities.

## Buildings

| Building | Capacity | Purpose |
|---|---:|---|
| Cafeteria | 12 seats | Employees visit during their scheduled lunch break |
| Staff Housing | 8 beds | Employees sleep overnight from 22:00 until their next shift |

Both buildings are optional construction choices in the Studio building palette. The existing off-duty and lunch roaming behavior remains available when the corresponding facility has not been built or has no free slot.

## Runtime behavior

- `CharacterManager` assigns facility slots deterministically from the employee roster and the built facility list.
- `CharacterActor` owns a temporary facility route separate from its permanent workplace route. This prevents a lunch or overnight visit from overwriting the employee's assigned workstation.
- The route planner exits the source building, follows the outdoor navigation path, then enters the destination facility.
- At 12:00, employees with a cafeteria slot walk to an individual chair, turn toward the table, lower into a seated pose, animate alternating hand movement and chewing, and receive improved energy recovery and stress reduction.
- At 13:00, they leave through the facility entrance and return to their assigned workplaces.
- At the end of their shift (17:00 in the default schedule), employees leave their workplaces and roam the studio during evening free time.
- At 22:00, employees with a housing slot walk to an individual bed, lie down in a compact procedural sleeping pose, and receive improved overnight energy recovery and stress reduction.
- At the next shift, they leave the bed and return to their assigned workplaces. Free-roaming employees without a workplace assignment can also use a facility and exit back to their roaming route.
- Production staff assigned to the Sound Stage are not auto-dispatched there while idle; they roam until an active film calls them. An editor is auto-dispatched only while an editing project is a draft or in progress.
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
6. Advance to the end of the shift (17:00 by default). Confirm employees leave their workstations and roam the studio instead of immediately entering beds.
7. Advance to 22:00. Confirm employees enter housing, lie down and display the resting task without a floating name tag.
8. Advance to the next shift. Confirm employees leave housing and return to their assigned workstations.
9. Start a film production and cross a lunch or shift boundary. Confirm active production participants stay with the shoot and are not pulled into facilities.
10. Open Developer Tools, press `+10,000`, and confirm the decor shop budget increases by exactly 10,000 and the updated balance is shown.
11. Recheck navigation around building footprints, the access road, sound-stage walls, manual fast-forward and pause behavior.

## Limitations

- Facility visits are not part of campaign save/load until the campaign SaveSystem is integrated.
- Eating and sleeping use procedural seated/lying poses built from the existing character pivots; a full skeletal animation and food/bed interaction system remain future work.
- Facility buildings have no construction price yet; construction costs belong to the future Studio Economy system.
- Employees beyond built facility capacity keep the existing fallback behavior until additional capacity is constructed.
