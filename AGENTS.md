# StockTroder Agent Instructions

## Immediate Agent instructions
- Use NASA plain language in all docs, code, comments, and replies. Avoid complex verbose explanations.
- No work should be left uncommitted in VCS.

## Project Context

- This is a Godot 4.7.2 project named `StockTroder`.
- The game is a single-player stock trading prototype with 30-second live trading rounds, price updates about twice per second, automatic day progression, fictional stocks, and pound-denominated currency.
- Read `docs/game-design.md` for player-facing rules and `docs/architecture.md` for software boundaries before making structural changes.

## Godot Access and Validation

- Godot is installed and available through the Godot AI MCP server connected to the editor.
- The terminal may not have a standalone `godot` executable on `PATH`; do not conclude that Godot is unavailable from a terminal lookup alone.
- Use the Godot MCP tools for editor state, project runs, runtime inspection, GDScript evaluation, filesystem scans, and Godot-specific tests when available.
- Never close, quit, or restart Godot through MCP to refresh cached scripts. That breaks the editor bridge and requires a manual reopen by the user. If a cache refresh is needed, stop and ask the user to restart Godot manually, then wait for the MCP plugin to reconnect.
- The project currently has no configured main scene until one is created and assigned in `project.godot`.
- After adding `class_name` scripts, refresh the Godot editor filesystem with an MCP scan before relying on global class registration.

## Implementation Boundaries

- Keep simulation rules independent from UI nodes.
- Game UI must fit the target viewport without scroll bars. Use compact layouts, tabs, pages, or panels instead of vertical scrolling.
- Design UI for responsive 16:9 viewports, not one fixed pixel resolution. Use anchors, proportional regions, minimum readable sizes, and tabs/pages when content needs more room.
- `Brief` and `Debrief` are runtime UI states built inside `TradingDashboard`; do not expect separate `brief.tscn` or `brief.gd` files.
- Pump, Sabotage, and Fake News are implemented single-player mechanics. "Phase 1.5" in older docs means a development milestone, not a gameplay phase or screen. Multiplayer requests for these actions remain rejected until multiplayer rules are designed.
- Forward actions such as Continue, Next Day, Start Trading, and Restart belong in the bottom-right action area and use a subtle green style.
- Store currency internally as integer pence and format it as pounds in the UI.
- Keep seeded market simulation deterministic for repeatable tests.
- Do not add manual end-day input; days resolve automatically when the 30-second timer expires.
- Do not add multiplayer or market manipulation until the Phase 1 single-player loop is playable.
