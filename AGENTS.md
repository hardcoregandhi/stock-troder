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
- The project currently has no configured main scene until one is created and assigned in `project.godot`.
- After adding `class_name` scripts, refresh the Godot editor filesystem with an MCP scan before relying on global class registration.

## Implementation Boundaries

- Keep simulation rules independent from UI nodes.
- Store currency internally as integer pence and format it as pounds in the UI.
- Keep seeded market simulation deterministic for repeatable tests.
- Do not add manual end-day input; days resolve automatically when the 30-second timer expires.
- Do not add multiplayer or market manipulation until the Phase 1 single-player loop is playable.
