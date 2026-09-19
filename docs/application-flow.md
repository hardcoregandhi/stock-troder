# StockTroder Application Flow

## 1. Main Menu

The first screen should be a simple application menu, not the trading dashboard.

```text
Main Menu
  - Single Player
  - Multiplayer
  - Options
  - Quit
```

### Single Player

- Creates a local `TradingSession`.
- Starts a fresh seeded run with the default six-stock catalog, or a bounded local stock count for test setup.
- Opens the trading dashboard.
- Returns to the main menu after the run summary or when the player leaves.

The stock catalog is created by `GameState`, not by the dashboard. A configured count keeps the first stocks in stable order, so seeded runs remain repeatable and future host setup can use the same boundary.

### Multiplayer

- Opens the multiplayer lobby.
- Lets the player host or join a session.
- Shows connection state, player list, and ready state.
- Starts the match only when the host starts and the lobby rules are met.

### Options

Phase 1 options should be small and useful:

- Master volume.
- Window mode.
- Display scale.
- Round length for local testing only, if it does not affect normal scoring.

Options should be stored locally. Do not add accounts or online settings yet.

### Quit

- Quit the application after a clear confirmation.
- On desktop, use `get_tree().quit()`.
- In multiplayer, disconnect cleanly before quitting.

## 2. Scene Flow

```text
Main
  -> MainMenu
      -> SinglePlayerSession -> TradingDashboard -> Brief -> Trading -> Debrief -> Brief -> RunSummary
      -> MultiplayerLobby -> MultiplayerSession -> TradingDashboard -> Brief -> Trading -> Debrief -> Brief -> RunSummary
      -> Options
      -> QuitConfirmation
```

The menu owns navigation. The trading dashboard owns trading presentation. The session owns game rules.

No screen should modify cash, prices, holdings, or network authority directly.

The dashboard shows all configured stocks together on one live chart. The selected stock controls the detail panel only. The legend uses each stock's stable color with its symbol, company name, and current price, so text remains available when colors are hard to distinguish.

## 3. Multiplayer Format

Phase 2 uses a shared market with separate player portfolios.

- One host acts as the server authority.
- The server owns the market seed and round clock.
- Every player sees the same stock prices, projections, news, and round timer.
- Each player has separate cash and holdings.
- A player's trades affect that player's portfolio only in the first multiplayer version.
- Pump, sabotage, and planted news need a separate shared-market design before they affect other portfolios.
- Target size: 2 to 6 players.
- Match length: 10 rounds.
- Round length: 30 seconds, with a brief before each round and a debrief after each resolved round.

This gives multiplayer strategic comparison without requiring a full player-driven market simulation in the first network build.

## 4. Multiplayer Authority

```text
Client input
  -> Network command
  -> Host validates command
  -> Host updates player portfolio
  -> Host broadcasts result and state snapshot
```

The client may send intent only:

```text
buy(symbol, quantity)
sell(symbol, quantity)
pump(symbol)
ready_for_next_day()
```

The client must not send `pump`, `sabotage`, or planted-news intents in Phase 1.5. Pump, Sabotage, and Fake News are single-player actions. A network request for Sabotage or Fake News receives a clear rejection and cannot change cash, prices, news, or holdings.

The client must never send:

- Cash values.
- Prices.
- Holdings after a trade.
- Resolved market results.
- Timer values.
- The random seed.

The host owns:

- Market simulation.
- Round timing.
- Player cash and holdings.
- Trade validation.
- Manipulation validation.
- Match progression.
- Final scoring.

## 5. Multiplayer Phases

### Phase 2A: Local application shell

- Add main menu.
- Add scene navigation.
- Add single-player entry and return flow.
- Add options and quit confirmation.
- Keep multiplayer button as a lobby entry point.

### Phase 2B: Host and join lobby

- Add host session.
- Add join-by-address session.
- Show connected players.
- Add ready state.
- Add host start control.
- Reject version or rule mismatches.

### Phase 2C: Synchronized market

- Host creates one market simulation.
- Clients receive projections and prices.
- Host owns the 30-second timer.
- Clients receive debrief results.
- Next Day begins only after the host advances the match.

### Phase 2D: Server-authoritative trading

- Add command IDs.
- Validate buy and sell commands on the host.
- Broadcast accepted trades and rejection reasons.
- Handle disconnects and late commands.
- Add replay logs for debugging.

### Phase 2E: Shared manipulation

- Decide whether Pump changes only the actor's strategy or the shared market.
- Define sabotage and planted news as multiplayer mechanics.
- Add public action feedback.
- Add anti-spam and disconnect rules.
- Test whether one player's action changes another player's best response.

Until Phase 2E is designed, the local flow is:

```text
Trading row
  -> TradingSession action method
  -> TradeService paid validation
  -> GameState and StockData mutation
  -> MarketSimulator seeded outcome at resolution
  -> News feed and debrief marker
```

## 6. Network Rules

- The host is authoritative.
- Commands are processed in order.
- Every command has a unique ID.
- A command is accepted only in the correct match phase.
- A disconnected player does not pause the match unless the host chooses that rule.
- The host can end a match safely.
- The client displays server state, not predicted authority state.

## 7. Options Boundaries

Options change presentation or local controls only.

They must not change competitive match rules:

- No client-only timer changes in multiplayer.
- No client-only price changes.
- No client-only starting cash.
- No client-only manipulation cost.

Local test settings may expose round length in development builds, but scored runs should record their rules.

## 8. Acceptance Criteria

### Menu

- The project opens on the main menu.
- Single Player starts the current playable loop.
- Options opens and closes without changing game state.
- Quit shows confirmation and exits cleanly.
- Back navigation returns to the correct parent screen.

### Multiplayer lobby

- A player can host a lobby.
- Another player can join by address.
- Both players appear in the lobby.
- The host can start a ready match.
- The host can reject invalid commands.
- Both clients receive the same market state and round phase.
- A player cannot alter another player's cash or holdings.

### Multiplayer match

- The host owns the market seed and timer.
- Trades are validated on the host.
- State snapshots are reproducible for debugging.
- Brief, Trading, Debrief, and Next Day remain synchronized.
- Disconnects do not corrupt the match state.
