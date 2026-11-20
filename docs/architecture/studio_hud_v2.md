# Studio HUD and world bootstrap v2

## Interaction model

- The workspace drawer is hidden by default.
- Bottom navigation opens the requested workspace; pressing the active navigation item closes the drawer.
- A left-click in the 3D world closes the drawer before character or building selection is processed.
- The drawer remains open while the player is actively placing a building, so placement can continue without reopening the palette.
- The employee market remains a separate workspace and is labelled explicitly as the market.

## Construction workspace

The construction workspace is registered by `StudioBuildingManager` and is opened from the `ЗДАНИЯ` navigation entry. Its content is scrollable and exposes the catalog's core business buildings, including film promotion, costume wardrobe and prop exchange.

## Startup guarantees

The main scene calls `ensure_startup_content()` after the building manager's regular setup. This operation is idempotent: it does not duplicate the three original starter buildings or already-registered workspaces.

The startup integration test verifies:

- the script department, sound stage and prop warehouse are present in the world model;
- each starter building has a world actor;
- construction, prop shop, employee and market workspaces are registered;
- the workspace drawer starts closed.
