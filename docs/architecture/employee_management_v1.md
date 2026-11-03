# Employee Management v1

**Status:** first functional employee-market and contract prototype.  
**Branch:** `feature/employee-management-v1`.  
**Base:** `feature/character-system-v2`.

## Scope

Employee Management v1 introduces a complete basic staffing lifecycle while preserving the Character System v2 employee profile and needs simulation.

## Profession catalogue

The data-driven `ProfessionCatalog` is the single source of truth for department membership, localized job titles, primary skills, base salary expectations, career goals, biography pools, default work-task descriptions and department-level schedules.

The current catalogue contains 40 professions across six departments:
- Creative: actor, extra, director, screenwriter, producer, casting director.
- Production: camera operator, assistant camera operator, gaffer, lighting technician, sound engineer, boom operator, film editor, production designer, set builder, costume designer, makeup artist, props master and legacy general technician.
- Facility: cleaner, maintenance worker, electrician, security guard.
- Catering: chef, sous-chef, bartender, waiter, cafeteria worker.
- Administration: secretary, personal assistant, receptionist, HR manager, accountant, office manager.
- Marketing: marketing manager, advertising manager, PR specialist, social media manager, advertising graphic designer, press officer.

The eight-candidate market is seeded and initially distributes candidates across all six departments. New skill keys are merged with defaults when loading older CharacterData payloads, and the legacy `technician` profession remains supported.

The catalogue currently provides profession-specific profile data, schedules and task descriptions. Dedicated workplace assignments, department buildings, uniforms, animations and autonomous task execution are later Employee AI / Studio Operations work.

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
- candidate rows showing profession, department, primary skill and salary expectation;
- a candidate detail view using the existing employee profile;
- contract type selection and daily salary preview;
- a hire action;
- an explicit dismissal confirmation;
- current contract terms in active employee profiles.

Newly hired employees receive a CharacterActor and enter the existing roster. Dismissed or expired employees leave the active scene and roster.

## Simulation timing

Market refresh and fixed-term expiry are driven by GameClock.day_advanced. They are independent of render FPS and stop while the game clock is paused.

Employee needs continue to use the existing GameClock.minute_advanced path.

The development HUD includes manual fast-forward controls for one hour, one day, seven days and thirty days. They invoke the same minute/day signal path as ordinary simulation, work while paused, preserve the selected speed mode and batch roster/detail UI refresh until the operation completes. Manual advancement is capped at 365 days per call. This synchronous test utility advances signal-driven systems such as employee needs, contract expiry and market refresh; it does not replay frame-based CharacterActor movement or visual animations during the skipped interval. Actors resume normal movement after the skip.

## Economy boundary

Daily salary and contract terms are stored and displayed, but no cash is deducted yet. Studio Economy does not exist in this branch; payroll integration must be implemented through the future Economy transaction API rather than directly mutating a balance in the HR module.

No severance or early-termination fee is charged in this version.

## Smoke test

Run from the project root:

~~~bash
godot --headless --path . --script res://tests/employee_management_smoke_test.gd
~~~

The test covers:
1. generation and metadata for all 40 professions;
2. balanced market representation of all six departments;
3. compatibility with the legacy technician role and older CharacterData skill payloads;
4. permanent contracts for the starting roster;
5. contract serialization round-trip;
6. candidate hiring and removal from the market;
7. selected contract type and salary calculation;
8. duplicate-hire rejection;
9. dismissal, contract termination and former-employee archive;
10. seven-day market refresh;
11. fixed-term contract expiry after the final active day.

A separate clock test is available:

~~~bash
godot --headless --path . --script res://tests/game_clock_fast_forward_test.gd
~~~

It runs a full 30-day fast-forward while paused, verifies every minute and day-boundary signal, checks that a 30-day contract expires on day 31, confirms the candidate market refreshes during the skip, and verifies preservation of time-of-day and speed mode.

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
