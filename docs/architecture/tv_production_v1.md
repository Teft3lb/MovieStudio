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

## Current boundary and next work

This milestone establishes the independent television domain and its serialization/scheduling contracts. The current system instance runs one active TV episode at a time, matching the first dedicated TV stage; multiple concurrent TV stages will require a session registry. The 3D television studio building, production-floor presentation, television control panel, broadcast calendar UI, network/distribution deals and actual contract negotiation UI are subsequent presentation/economy milestones. The film-production pipeline remains independent.
