# Studio Business & Asset Lifecycle v1

## Scope

This layer connects studio infrastructure, reusable production assets, film promotion and the existing studio operating budget. It is separate from Character System v2 and the existing celebrity publicity event.

## Existing celebrity publicity

The fan-meeting loop is already implemented by `celebrity_publicity_system.gd`, `studio_publicity_event_controller.gd`, `studio_publicity_crowd.gd` and `employee_publicity_controls.gd`. It remains the source of truth for public appearances, crowd gathering, security and celebrity popularity. This increment does not duplicate or replace it.

## Business buildings

Three selectable building types are added:

- `film_promotion`: launches paid advertising campaigns for completed films.
- `costume_wardrobe`: stores purchased costume sets and displays them in the building interior.
- `prop_exchange`: sells owned decorations and costumes back to the studio's operating budget.

These are service buildings, not employee workplaces. A wardrobe must exist before costume sets can be purchased; the promotion and exchange buildings are required for their respective actions.

## Shared operating budget

The existing `StudioSetInventory.budget` remains the prototype studio operating budget for this increment. Prop purchases, costume purchases, advertising campaigns and resale proceeds all use the same balance. This avoids introducing parallel wallets before the dedicated Studio Economy milestone.

The balance is still a prototype budget; payroll, rent, distribution revenue and a full financial ledger are not part of this increment.

## Wardrobe

`StudioCostumeCatalog` defines reusable costume sets with a purchase price, genre compatibility, visual color and scene-quality bonus. `StudioWardrobeInventory` owns the purchased costume IDs and serializes them independently.

For each scene, the best owned costume set matching the film genre is selected automatically. Only one matching set is applied per scene, preventing quality bonuses from stacking without limit. The wardrobe building renders the owned sets as hanging costume silhouettes.

## Prop condition and maintenance

Each owned decoration stores condition from 0 to 100, unique film IDs in which it has been used, and its current logistics location.

A completed scene applies 7.5 condition points of wear to each installed prop. Repeated scenes in the same film add wear but do not count as separate film reuses. The active film is excluded from its own reuse penalty, so only previous films reduce novelty. Condition and usage history are included in inventory serialization, with safe defaults for older payloads.

Technicians can repair decorations while they are working and otherwise free of production, editing, publicity or manual-activity assignments. Repairs are performed only for props returned to the warehouse. A repair task takes 30 game minutes and restores up to 25 condition points. A prop being repaired cannot be sold.

## Reuse and scene quality

Two independent modifiers are recorded for every scene setup:

- **Condition penalty:** up to 8 quality points based on average prop wear.
- **Reuse penalty:** 2.5 quality points per previous film use, averaged across installed props and capped at 12.

The reuse history is based on distinct previous films, not scene count. Repair restores condition but deliberately does not erase reuse history; a repaired prop can look good again, but it does not become creatively new.

Genre-matched costumes add their catalog bonus directly to scene quality. These modifiers are visible in production scene details and completed scene records.

## Film promotion

The marketing system offers three paid campaign tiers:

| Campaign | Cost | Base commercial-success bonus |
|---|---:|---:|
| Local | 250 | +4 |
| Regional | 600 | +8 |
| National | 1,200 | +14 |

A film can receive at most three campaigns. Subsequent campaigns have diminishing returns (100%, 60%, 30%). Advertising increases the film's **commercial success score**, not its artistic production quality. The score is stored in the editing project and completed-film archive so the future Film Distribution system can use it when calculating audience reach and box office performance.

## Current boundaries

- The commercial-success score is now calculated and persisted, but box-office revenue, release windows and distribution contracts remain part of the future Film Distribution milestone.
- Costume selection is genre-based and automatic; per-character costume assignment and costume wear are not yet modeled.
- Repairs use the existing technician profession and warehouse routing. A dedicated maintenance department and repair priority queue are future extensions.
- The shared budget is intentionally transitional until the full Studio Economy system is introduced.
