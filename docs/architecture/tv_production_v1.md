# Television Production v1

## Purpose

Television is a separate production business inside MovieStudio. It does not reuse FilmProductionSystem as a generic project runner. Television has its own program catalogue, season/episode hierarchy, talk-show format, recurring shooting schedules, broadcast results and talent-market effects.

## Domain modules

- `TVSeriesData` owns series metadata, format, regular cast, crew assignments, planned seasons and episode runtime.
- `TVSeasonData` owns one season and its ordered episode list, completion state, rating and audience totals.
- `TVEpisodeData` is the shared production record for a series episode or talk-show issue. It stores production phases, assigned talent, production quality, broadcast rating and audience reach.
- `TVTalkShowData` owns a permanent host, guest pool, format, episode archive and audience statistics.
- `TVScheduleEntry` stores a weekly shooting slot and the employees committed to it. Overlapping slots are rejected when they share cast or crew.
- `TVProductionSystem` creates programs, expands season plans, registers recurring schedules, starts due episodes, advances the television production phases, records broadcasts and serializes its complete state.

## Production cycle

A TV episode follows its own compact cycle:

1. Preparation of the television set.
2. Rehearsal with the host or regular cast and invited guests.
3. Recording.
4. Postproduction.
5. Ready for broadcast.
6. Broadcast, audience rating and career effects.

The production controller supplies crew/cast readiness and a performance snapshot each game minute. The domain system pauses rather than consuming production time when required participants are unavailable.

## Weekly scheduling

Game day 1 is treated as Monday. Weekly schedules use day indices 0–6, exact start hour/minute and a duration window. A schedule fires once per game day at its configured start minute. Regular cast, host and crew cannot be booked into overlapping TV production slots. A guest is checked against existing commitments when an episode is started. The start API also accepts unavailable employee IDs from active film production, so the future TV controller can prevent a cast/crew member from being used by two simultaneous productions. A schedule window cannot cross midnight.

## Popularity, recognition and contracts

CharacterData schema 9 adds persistent public recognition as a separate metric from popularity:

- Popularity reflects current audience interest and sentiment.
- Recognition reflects how widely the actor is known and accumulates through exposure.

Broadcasts apply role-weighted effects to regular cast, hosts and guests. The CelebritySystem then exposes a marketability score and suggested daily contract salary. EmployeeManagementSystem provides that profile to the contract-offer layer; the existing fixed-term contract premiums still apply. These are offer recommendations, not automatic contract changes.

Legacy schema 8 characters initialize recognition from their saved popularity, preserving existing stars rather than resetting their public profile.

## Smoke test

Run from the project root:

~~~bash
godot --headless --path . --script res://tests/tv_production_system_smoke_test.gd
~~~

The TV production smoke test covers series and season generation, talk-show hosts and guests, weekly schedule conflicts and triggers, production phases and pause behavior, audience results, career progression, contract-offer profiles, and mid-production serialization recovery.

## External-host celebrity talk shows (playable 3D session)

Television guest shows now have an independent domain rule and presentation workflow without expanding the original 1,000-line television production system:

- `TVShowInvitationPolicy` requires at least 70/100 *recognition* (public familiarity) for studio actors or directors; popularity remains a separate audience-interest metric. The policy lists three external host profiles and checks that existing TV personnel can staff direction, camera and technical operations. When a famous director is the guest, they may also direct their own interview, avoiding a mandatory extra hire.
- `TVGuestShowPanel` provides the invitation UI in the selected TV Studio's building inspector. If no eligible guest exists, the selection control is visibly disabled. Employees assigned to the TV Studio fill the crew; guests may come from another building.
- `TVGuestShowController` creates a one-time talk show and due schedule using the existing `TVProductionSystem`. It sends the guest actor along the real studio route, waits for the guest, presenter and crew, runs preparation/rehearsal/recording/postproduction, then broadcasts and publishes audience results. Film and TV assignments cannot use the same employees concurrently.
- `TVGuestHostVisitor` reuses the existing 3D character visual, walks from outside the door to the presentation mark, speaks during the recording and leaves through the door after the shoot. It is never added to `CharacterManager.employees`, employee contracts, headcount or payroll. Manual clock advancement may snap travel endpoints consistently with the existing simulation's skip-time rules.

The guest is routed to a free standing location near the interview chair (rather than inside the chair collider), and returns to their previous workplace after recording. The invitation is one-time, not a permanent employee-hosted TV series; the domain still retains its independent recurring-show and serialized catalog APIs.

`CelebritySystem.apply_film_project_release` grants recognition and quality-sensitive popularity to credited actors and film directors when a completed film is released. A TV broadcast grants appearance-based recognition to invited actors and directors; `CharacterData` already persists both fields. Experienced actors and directors from the market can also join the studio with established recognition. The character inspector displays a 0–100 recognition progress bar and the 70% eligibility threshold.

~~~powershell
& $godot --headless --path . --script res://tests/tv_guest_show_smoke_test.gd
& $godot --headless --path . --script res://tests/tv_production_system_smoke_test.gd
& $godot --headless --path . --script res://tests/character_system_v2_smoke_test.gd
~~~

The invited-show smoke test covers the 69.9/70 eligibility boundary, directors, external non-employee hosts, occupied film cast, TV crew readiness, shooting, host departure, broadcast, and the guest's career benefits. End-to-end physical navigation, wardrobe, audience reactions and production budgeting still require in-game QA and follow-up work. UI/runtime state is not yet wired into the future global Save System.

## Current boundary and next work

This milestone establishes the independent television domain and its serialization/scheduling contracts. The current system instance runs one active TV episode at a time, matching the first dedicated TV stage; multiple concurrent TV stages will require a session registry. The dedicated 3D TV Studio building now exists as a separate construction option, with its own broadcast set, audience seating, camera rigs, lighting grid and ten navigation/workplace marks. An introductory production-floor guest-show controller, host NPC, and inspector UI are now available. Persistent recurring show programming UI, broadcast calendar, network/distribution deals, production fees, and contract negotiation UI remain subsequent presentation/economy milestones. The film-production pipeline remains independent.
