# StockTroder Software Architecture

## 1. Purpose

This document describes how StockTroder is structured in Godot. It complements [game-design.md](game-design.md), which defines the player experience and game rules.

The architecture is designed around a deterministic single-player prototype first, while keeping the simulation boundaries suitable for a future server-authoritative multiplayer version.

## 2. Architectural Principles

- Keep game rules independent from visual presentation.
- Give each system one clear responsibility.
- Keep all money, holdings, prices, and trade validation in the simulation layer.
- Let the UI display state and request actions; it must not change game rules directly.
- Use signals for meaningful state changes instead of tightly coupling every UI control to every system.
- Use seeded randomness so runs can be reproduced during development and tested reliably.
- Prefer plain data objects and small services over one large scene script.
- Keep Phase 1 free of networking concerns while preserving clean action boundaries for Phase 2.

## 3. Runtime Layers

```text
Presentation Layer
  TradingDashboard
  StockList
  StockChart
  TradingClock
  RunSummary
          |
          | user commands and state signals
          v
Application Layer
  TradingSession
  TradeService
  DayTimer
          |
          | validated commands and simulation requests
          v
Simulation Layer
  GameState
  MarketSimulator
  StockData
  MarketEvent
          |
          v
Persistence / Future Networking Boundary
  SaveGame (future)
  Server Authority (future)
```

### Presentation layer

Owns controls, layout, graphs, labels, animations, and player feedback. It reads state from the application layer and emits player intent such as `buy_requested` or `sell_requested`.

The presentation layer must not:

- Modify cash or share counts directly.
- Generate random prices.
- Decide whether a trade is valid.
- Advance the trading day by changing simulation data.

### Application layer

Coordinates a run. It starts and stops the trading clock, passes trade requests to the trade service, asks the market simulator to generate and resolve days, and broadcasts state changes to the UI.

### Simulation layer

Contains the authoritative rules for prices, projections, holdings, cash, day progression, and scoring. This layer should be usable without rendering a scene, which makes it suitable for automated tests and a future multiplayer server.

## 4. Proposed Project Structure

```text
res://
  project.godot
  scenes/
    main.tscn
    trading_dashboard.tscn
    run_summary.tscn
  scripts/
    main.gd
    application/
      trading_session.gd
      day_timer.gd
      trade_service.gd
    simulation/
      game_state.gd
      market_simulator.gd
      stock_data.gd
      market_event.gd
    presentation/
      trading_dashboard.gd
      stock_list.gd
      stock_chart.gd
      trading_clock.gd
      run_summary.gd
  tests/
    test_game_state.gd
    test_market_simulator.gd
    test_trade_service.gd
  docs/
    game-design.md
    architecture.md
```

The exact file names may change during implementation, but the ownership boundaries should remain stable. Godot scenes should contain visual composition and node wiring; GDScript classes should contain behavior and rules.

## 5. Core Components

### `GameState`

The authoritative mutable state for one run.

Responsibilities:

- Store the current trading day.
- Store the remaining seconds or session phase.
- Store cash and starting cash in pence-safe numeric values.
- Store stock definitions and current market values.
- Store each stock's price history and current projection.
- Store the player's holdings.
- Calculate portfolio value and total return.
- Track whether the run is active, resolving, or complete.

`GameState` should expose read methods and controlled mutation methods. Other systems should not write directly into its dictionaries or arrays.

Suggested state shape:

```text
GameState
  starting_cash: int
  cash: int
  current_day: int
  total_days: int
  phase: enum { PREPARING, TRADING, RESOLVING, DEBRIEF, COMPLETE }
  stocks: Array[StockData]
  holdings: Dictionary[String, int]
  seed: int
```

Store currency as integer pence internally. Convert to formatted pounds only at the presentation boundary. This avoids floating-point rounding issues while keeping the UI in pounds, for example `£10,000.00`.

### `StockData`

Represents one fictional company and its market history.

Suggested fields:

```text
symbol: String
company_name: String
personality: String
current_price_pence: int
previous_price_pence: int
price_history_pence: Array[int]
volatility: float
trend: float
projection_low: float
projection_high: float
projection_direction: int
projection_confidence: String
current_news: String
```

A stock object contains data, not UI nodes. It should not know how it is rendered.

### `MarketSimulator`

Generates and resolves market behavior using a seeded `RandomNumberGenerator`.

Responsibilities:

- Generate daily market events.
- Generate each stock's pre-round projection.
- Update live prices at the configured market sample interval.
- Produce live price samples about twice per second during a round.
- Resolve the final movement when the 30-second round timer expires.
- Apply price floors.
- Append live samples and resolved prices to history.
- Return a resolution result for the UI.

It should not know about buttons, labels, scene nodes, or player input.

The simulator should keep projection randomness separate from resolution noise. This allows the displayed forecast to be useful without making the final price perfectly predictable.

The simulator should keep the round opening price separate from the current live price. Live movement must not turn each sample into a new trading day or compound the final projection accidentally.

### `TradeService`

The only service that executes trades.

Responsibilities:

- Validate buy requests.
- Validate sell requests.
- Check the current session phase and timer state.
- Check available cash and owned shares.
- Update cash and holdings through controlled `GameState` methods.
- Return a structured success or failure result.

A trade result should include:

```text
success: bool
message: String
symbol: String
quantity: int
execution_price_pence: int
cash_after_trade: int
shares_after_trade: int
```

Phase 1 has no transaction fee, but the result structure should leave room for one later.

### `TradingSession`

Coordinates the complete run lifecycle.

Responsibilities:

- Create a fresh `GameState`.
- Initialize the stock catalog.
- Start the first trading day.
- Start and monitor the 30-second timer.
- Route buy and sell requests to `TradeService`.
- Resolve the market when the timer expires.
- Pause after a resolved round and wait for a Next Day command.
- Start the next day when the player leaves the debrief.
- Liquidate holdings after the final day.
- Emit run-complete data.

`TradingSession` owns the order of operations. The UI should call methods on this component instead of coordinating the simulation itself.

### `DayTimer`

A small application component that owns elapsed time for the active trading window.

Responsibilities:

- Start at 30.0 seconds.
- Count down using frame delta or a Godot `Timer`.
- Emit remaining-time updates for the clock UI.
- Emit one timeout event when the window ends.
- Stop during resolution and after the run completes.

The timeout must be guarded so a day cannot resolve twice if multiple nodes attempt to react to the same frame.

## 6. Trading Day State Machine

```text
PREPARING
    |
    | generate projections and news
    v
TRADING
    |
    | player buys/sells while timer > 0
    v
RESOLVING
    |
    | resolve prices, append history, recalculate value
  v
DEBRIEF
    |
  | player selects Next Day
  |
  +---- current_day < total_days ----> PREPARING
    |
    +---- current_day = total_days ----> COMPLETE
```

### State rules

- Buy and sell requests are accepted only during `TRADING`.
- Projections are generated during `PREPARING` and remain fixed during `TRADING`.
- Prices update during `TRADING` at the configured market sample interval. A market sample is not a new day.
- The timer is stopped during `RESOLVING`.
- The player cannot trade during `RESOLVING`, `DEBRIEF`, or `COMPLETE`.
- The next day's projections are not generated until the player selects Next Day from the debrief.
- The final result is calculated only after final liquidation.

## 7. Main Data Flow

### Starting a run

```text
Main scene
  -> TradingSession.start_run(seed)
  -> GameState created with £10,000
  -> Stock catalog created
  -> MarketSimulator.generate_projections(state)
  -> UI receives run_started and projection_updated
  -> DayTimer starts
```

### Executing a trade

```text
Buy/Sell button
  -> TradingDashboard emits request
  -> TradingSession receives request
  -> TradeService validates request
  -> GameState applies approved trade
  -> TradingSession emits state_changed and trade_completed
  -> UI refreshes cash, holdings, and portfolio value
```

### Resolving a day

```text
DayTimer.timeout
  -> TradingSession enters RESOLVING
  -> MarketSimulator.resolve_day(state)
  -> GameState appends prices and updates current values
  -> TradingSession recalculates portfolio value
  -> UI shows resolution feedback
  -> If more days remain: enter DEBRIEF and wait for the player
  -> Otherwise: liquidate holdings and complete the run

### Leaving a debrief

```text
Next Day button
  -> TradingSession.continue_to_next_day()
  -> GameState advances the day and enters PREPARING
  -> MarketSimulator generates the next projection and news
  -> DayTimer starts a new 30-second round
```
```

## 8. Signals and Contracts

Signals should carry data needed by receivers so the UI does not need to inspect internal objects unnecessarily.

Suggested `TradingSession` signals:

```text
run_started(state_snapshot)
day_prepared(day_number, projections, news)
time_updated(seconds_remaining)
trade_completed(trade_result)
trade_rejected(trade_result)
day_resolved(day_number, resolution_result, state_snapshot)
run_completed(summary)
```

Suggested presentation inputs:

- A state snapshot for labels and holdings.
- Projection records for forecast styling.
- A resolution result for the brief end-of-day feedback.
- A final summary for the results screen.

Snapshots should be read-only from the UI's perspective. They prevent accidental mutation of the authoritative state.

## 9. Scene Responsibilities

### `main.tscn`

The application entry point. It creates or references the `TradingSession` and displays the active dashboard or final summary.

### `trading_dashboard.tscn`

Contains the active trading interface:

- Header and currency summary.
- Day and countdown display.
- Stock list.
- Selected-stock chart.
- Buy/sell controls.
- Projection and news display.
- Trade feedback.

It should receive a session reference through a controlled setup method rather than finding simulation nodes through fragile scene-tree paths.

### `run_summary.tscn`

Displays final liquidation cash, total return, and run statistics. It requests a fresh run through the application layer when replay is selected.

## 10. Testing Strategy

The simulation and application layers should be testable without launching the full UI.

### Unit tests

- Starting cash is £10,000.
- A valid buy decreases cash and increases shares.
- A valid sell increases cash and decreases shares.
- Overspending is rejected.
- Selling more shares than owned is rejected.
- Trades are rejected outside the `TRADING` phase.
- Prices never fall below £1.00.
- Every resolved day appends exactly one price per stock.
- The timer resolves a day once.
- The final day liquidates all holdings.
- The same seed produces the same projections and resolutions.
- Different seeds can produce different runs.

### Integration tests

- Starting a session creates six stocks and a first projection.
- Timer expiry causes resolution and enters DEBRIEF; Next Day starts the next 30-second round.
- A complete run reaches `COMPLETE` without manual end-day input.
- The dashboard refreshes after a successful trade.
- The summary appears after final liquidation.

### Manual play checks

- The player can understand a projection before the timer expires.
- Buy and sell buttons remain easy to use under time pressure.
- The countdown does not obscure prices or controls.
- Resolution feedback is readable but does not stall the next round.
- Pound formatting is consistent throughout the game.

## 11. Multiplayer Extension Point

Phase 2 should introduce a server-authoritative adapter around the existing application boundaries.

```text
Client UI
  -> Network session client
  -> Server command endpoint
  -> TradingSession on server
  -> GameState and MarketSimulator
  -> State snapshots/events back to clients
```

The client should submit intents such as:

```text
buy(symbol, quantity)
sell(symbol, quantity)
```

The server should validate the request against its own `GameState`, execute it, and broadcast the result. Clients must never be trusted to submit cash, prices, holdings, or resolved market results.

The deterministic seed remains useful for debugging and replay, but multiplayer authority should come from the server's actual state and event sequence.

## 12. Architecture Decisions and Deferred Decisions

### Decided for Phase 1

- Godot 4.7.
- Single-player.
- Six fictional stocks.
- Ten trading days.
- 30-second trading windows.
- Player-controlled progression after each DEBRIEF.
- Integer pence for internal currency values.
- Seeded random market simulation.
- No transaction fees initially.
- No manual end-day command.

### Deferred

- Whether the 30-second round should be shortened or lengthened after playtesting.
- Whether forecasts are shown as percentages, price ranges, or both.
- Save-game format.
- Manipulation resource and detection rules.
- Multiplayer transport and lobby design.
- Whether multiplayer rounds use a shared timer or player readiness.
