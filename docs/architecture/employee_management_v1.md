# Employee Management v1

**Status:** first functional employee-market and contract prototype.  
**Branch:** `feature/employee-management-v1`.  
**Base:** `feature/character-system-v2`.

## Scope

Employee Management v1 introduces a complete basic staffing lifecycle while preserving the Character System v2 employee profile and needs simulation.

## Domain modules

### EmployeeContract

Serializable employment agreement containing:
- stable contract and employee IDs;
- contract type;
- daily salary;
- start day;
- term length and end day;
- active, terminated or expired status;
- termination day.

Supported contract types:
- permanent / indefinite;
- fixed-term 30 days;
- fixed-term 90 days.

Fixed-term agreements include a wage premium over the candidate's baseline salary: 15% for 30 days and 8% for 90 days. Permanent agreements use the candidate's baseline daily salary.

### EmployeeMarketSystem

Generates a deterministic market from an explicit seed. Each market cycle creates eight candidates with stable IDs, randomized professions, skills, personality, appearance, biographies and salary expectations.

The candidate pool refreshes every seven in-game days. Hiring a candidate removes that candidate from the current market.

### EmployeeManagementSystem

Owns the active roster, current market, former-employee archive and contract registry.

Operations:
- initialize the starting roster and assign permanent contracts;
- hire a market candidate under a selected contract type;
- prevent duplicate hiring;
- dismiss an active employee and terminate their contract;
- expire fixed-term contracts after their final active day;
- retain dismissed and expired employees in the former-employee archive;
- refresh the candidate market on its seven-day cycle.

## Presentation integration

The existing CharacterManager remains the scene coordinator and keeps responsibility for spawning and removing CharacterActor nodes.

The UI adds:
- a кадровый рынок panel next to the staff roster;
- candidate rows showing profession, primary skill and salary expectation;
- a candidate detail view using the existing employee profile;
- contract type selection and daily salary preview;
- a hire action;
- an explicit dismissal confirmation;
- current contract terms in active employee profiles.

Newly hired employees receive a CharacterActor and enter the existing roster. Dismissed or expired employees leave the active scene and roster.

## Simulation timing

Market refresh and fixed-term expiry are driven by GameClock.day_advanced. They are independent of render FPS and stop while the game clock is paused.

Employee needs continue to use the existing GameClock.minute_advanced path.

## Economy boundary

Daily salary and contract terms are stored and displayed, but no cash is deducted yet. Studio Economy does not exist in this branch; payroll integration must be implemented through the future Economy transaction API rather than directly mutating a balance in the HR module.

No severance or early-termination fee is charged in this version.

## Smoke test

Run from the project root:

~~~bash
godot --headless --path . --script res://tests/employee_management_smoke_test.gd
~~~

The test covers:
1. permanent contracts for the starting roster;
2. contract serialization round-trip;
3. candidate hiring and removal from the market;
4. selected contract type and salary calculation;
5. duplicate-hire rejection;
6. dismissal, contract termination and former-employee archive;
7. seven-day market refresh;
8. fixed-term contract expiry after the final active day.

## Deliberate limitations

Not included:
- actual payroll transactions or studio balance;
- salary negotiation and counteroffers;
- recruitment advertisements or recruitment cost;
- candidate rejection and employee resignation;
- employee capacity or department staffing limits;
- contract renewal and renegotiation;
- save-game integration and schema migrations;
- relationship effects or morale reactions to dismissal.
