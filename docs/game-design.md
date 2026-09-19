# StockTroder Game Design

## 1. High Concept

**StockTroder** is a short-session single-player stock market game. The player buys and sells a small portfolio of fictional companies across a limited number of trading days, trying to finish with more money than they started with.

The appeal comes from making decisions under incomplete information:

- Prices move every trading day.
- News and company behavior provide clues, but never certainty.
- The player chooses when to hold, buy, or sell.
- A short day limit forces the player to act instead of waiting forever.

The first playable version should make the buy/sell/beat-the-clock loop enjoyable before adding sabotage or networking. Phase 1.5 adds one limited Pump action without adding multiplayer or sabotage.

## 2. Product Goals

### Phase 1 goals

- Start a new run with £1,000.00 in cash.
- Show several fictional stocks with current prices, daily movement, and a projection before each trading day begins.
- Let the player buy and sell whole shares.
- Give the player a short real-time trading window for each day.
- Resolve each 30-second trading round automatically when its timer expires.
- Show a simple historical price graph for each stock.
- Calculate portfolio value and final profit/loss.
- Provide a clear end-of-run result and a way to start again.

### Phase 1.5 goal

- Add a risky Pump action for one selected stock during a live trading round.

### Later goals

- Add player-driven market manipulation such as pumping or sabotaging a stock.
- Add consequences, risk, cooldowns, and detection so manipulation is a strategic choice rather than a free bonus.
- Add multiplayer only after the single-player simulation and user interface are stable.

### Non-goals for the first prototype

- Real-world stock data.
- Fractional shares, options, short selling, or margin.
- Persistent accounts or online services.
- Real-time multiplayer.
- Complex financial realism.

## 3. Core Game Loop

Each run lasts a fixed number of trading days. The initial prototype should use **10 trading days**, **£1,000 starting cash**, and a **30-second live trading round** per day. The round length is a tuning value and may change after playtesting.

1. The simulation generates a projection for each stock before the day starts.
2. The player reviews current prices, projections, news, cash, and holdings.
3. The trading clock starts at 30 seconds and prices begin updating in real time.
4. Roughly twice per second, each stock receives a new live price sample based on its projection and volatility.
5. The player buys and sells whole shares while the clock runs and prices move.
6. When the clock reaches zero, the round resolves at its final prices.
7. A debrief shows the day's result, news, price changes, and portfolio value.
8. The player chooses **Next Day** when ready, then the next day's projection is generated and its live round begins.
9. After the final trading round, all holdings are liquidated at the final prices.
10. The game displays the final cash, profit/loss, and a simple performance summary.

The player should be able to understand the state of the market at a glance and make meaningful trades within each 30-second round. A trading day is one complete 30-second round, not one price update. There is no manual **End Day** button in Phase 1, but the player controls when to leave the debrief and start the next round.

## 4. Market Model

The prototype uses fictional stocks with distinct personalities rather than attempting to model real markets accurately.

Suggested initial stocks:

| Symbol | Company | Personality |
| --- | --- | --- |
| AUR | Aurora Robotics | Volatile growth stock |
| BRK | Brickline Retail | Stable consumer stock |
| CYN | Cyanic Energy | News-sensitive energy stock |
| DSK | Deskbound Software | Moderate technology stock |
| HBR | Evergreen Foods | Defensive, slower-moving stock |
| NOV | Frontier Biotech | High-risk binary events |

The default catalog has six stocks. A local run may use a smaller catalog for testing or future match setup, from one to six stocks, while preserving this order and the same seeded behavior. Symbols remain stable.

Each stock has:

- Symbol and display name.
- Current price.
- Previous closing price.
- Historical closing prices.
- Volatility rating.
- Trend or momentum value.
- A small set of possible news events.

### Price projection and real-time movement

Before each day begins, each stock receives a projected percentage change based on its trend, volatility, news, and a seeded random market shock:

```text
projection = trend + news_impact + random_shock
projected_price = max(1.00, current_price * (1.0 + projection))
```

The projection is shown as a range and directional signal, not as a guaranteed exact price. The actual resolved movement is sampled near the projection so the forecast is useful without being certain:

```text
actual_change = projection + resolution_noise
next_price = max(1.00, current_price * (1.0 + actual_change))
```

The projection remains visible throughout the 30-second trading round. It represents the expected direction and approximate end-of-round movement, not a single delayed price update. The news item linked to that movement is revealed in the debrief.

During the round, the market produces a live price sample about every 0.5 seconds. Each sample moves toward the projected end-of-round price while adding a smaller random movement based on the stock's volatility:

```text
live_price = projected_path(progress) + live_noise
```

The graph shows these live samples as they arrive. At zero seconds, the final price is resolved and the round enters debrief. After the player selects **Next Day**, the next day's projection is generated and its new 30-second live price path begins.

The exact values should be tuned for fun, but the initial target is:

- Typical daily movement: roughly -8% to +8%.
- Rare major movement: roughly -20% to +20%.
- No stock may fall below £1.00.
- The random seed should be stored for debugging and repeatable test runs.

The simulation should use a seeded random number generator so a run can be reproduced during development.

## 5. Player Economy

The player begins with:

- Cash: £1,000.
- Shares: 0 in every stock.
- Trading fee: none for the first prototype.
- Pump cost: **£25.00 (2,500 pence)** per use. This is 2.5% of the £1,000 starting cash, so it matters but does not block normal trading.

Rules:

- The player can only buy whole shares.
- The player cannot spend more cash than they have.
- The player cannot sell more shares than they own.
- Buying decreases cash immediately.
- Selling increases cash immediately.
- Portfolio value equals cash plus the market value of all holdings.
- Final profit/loss equals final liquidation cash minus starting cash.

A small transaction fee can be added after the basic loop works, but it should not obscure whether the market simulation is fun.

### Phase 1.5 Pump

Pump is a single-player action available only during `TRADING`. It targets the selected stock and costs £25.00 immediately. Each stock can be pumped once per round. A successful Pump lifts that stock's short-term live price path by 4%, but the round resolution applies a correction risk: there is a seeded 65% chance of an 8% correction and a 35% chance of a smaller 2% correction. The result is never a guaranteed profit, and the normal £1.00 price floor still applies.

The player can see the cost, availability, and correction risk in the dashboard. Pump usage resets when the player selects **Next Day**. The debrief reports whether a Pump correction affected the resolved result.

## 6. Information and UI

The main screen should be a compact trading dashboard rather than a collection of separate menus.

### Required areas

- **Top status bar:** current day, seconds remaining, cash, portfolio value, and total return.
- **Stock list:** symbol, name, current price, projected change, shares owned, position value, stable color marker, and one-share Buy/Sell buttons.
- **Selected stock panel:** larger price display, company name, projection range, confidence label, and short news/event text.
- **Shared market chart:** one live multi-series graph for every configured stock, with a text legend showing each symbol, company, color, and current price.
- **News feed:** timestamped stock headlines with forecast signals and resolved outcomes.
- **Trade controls:** quantity input or stepper, Buy button, Sell button, and a clear validation message. Each stock row should also provide fast one-click buy and sell actions.
- **Trading clock:** prominent countdown from 30 seconds to zero that remains visible while the player trades.
- **Debrief:** a pause after each round showing resolved prices, changes, portfolio value, and the news items that affected the round.
- **Next Day control:** starts the next round only when the player is ready. It is unavailable during live trading and unnecessary after the final round.
- **End-of-run summary:** starting cash, final cash, total return, best trade, and a replay button.

### Usability requirements

- Prices and changes must be readable without opening another screen.
- Positive and negative changes need more than color alone, such as `+4.2%` and `-3.1%` labels.
- Projections must be visually distinct from actual prices and clearly labeled as estimates.
- The countdown must be readable without covering stock prices or trade buttons.
- The debrief must explain the round result without requiring the player to infer it from the graph alone.
- Invalid trades explain why they failed.
- The player can always see which stock is selected.
- The graph must update during the round as live price samples arrive, then retain the completed round in the run history.
- Stock prices should use large denominations so one share is a meaningful decision and the player can go all-in or diversify.

## 7. News Events

News is a lightweight explanation for price movement and a source of uncertainty. Each day, a stock may receive one event, or the market may receive a broad event.

Example events:

- Product launch beats expectations: positive impact.
- Supply chain disruption: negative impact.
- Analyst upgrade: small positive impact.
- Regulatory review: negative and volatile impact.
- Quiet trading day: minimal impact.

News should be fictional and concise. Events should explain what happened without revealing the exact future price.

## 8. Proposed Godot Architecture

Keep simulation logic independent from the UI so the same model can later support multiplayer or automated tests.

### Main components

- `GameState`: owns the current day, cash, holdings, stocks, history, and run status.
- `MarketSimulator`: generates projections, resolves the timed trading day using a seeded random generator, and produces price changes/events.
- `StockData`: data object for one stock's identity, price, history, and traits.
- `TradeService`: validates and executes buy/sell actions against `GameState`.
- `TradingDashboard`: displays state and sends player actions to the game model.
- `StockChart`: renders live and historical prices for every configured stock in one shared chart. The selected stock remains the detail-panel focus.
- `RunSummary`: displays the final result and restarts the run.

The UI should react to state changes rather than directly modifying prices, cash, or holdings. This keeps rules in one place and makes future multiplayer authority easier to add.

## 9. Phase 1 Milestones

### Milestone 1: Simulation shell

- Create a main scene and game state.
- Generate the initial stock catalog with a bounded stock count. The default is six stocks.
- Add seeded round projections and automatic 30-second round resolution.
- Add a debrief pause and player-controlled Next Day transition.
- Add a temporary debug display for day, prices, and cash.

### Milestone 2: Trading

- Implement buy and sell validation.
- Display holdings and portfolio value.
- Add the trading countdown and player-controlled day progression after each debrief.
- Add final liquidation and run completion.

### Milestone 3: Dashboard

- Replace debug display with the trading dashboard.
- Add stock selection, a shared multi-stock line graph, and a matching text legend.
- Add daily news text and clear trade feedback.
- Add end-of-run summary and restart flow.

### Milestone 4: Tuning

- Play several complete runs.
- Tune volatility, event frequency, and day count.
- Confirm that both conservative and risky strategies can be viable.
- Add automated tests for trade rules, price floors, day progression, and final scoring.

## 10. Phase 1 Acceptance Criteria

Phase 1 is complete when all of the following are true:

- A new run starts with £1,000 cash and six stocks by default.
- A configured run can use one to six stocks without changing their stable order or seeded results.
- The player can select a stock for details while the shared chart shows every configured stock.
- Each stock shows a clearly labeled projection before the trading window starts.
- The player can buy and sell valid quantities.
- Invalid trades are rejected without changing the game state.
- The 30-second countdown is visible and trades are available while it runs.
- When the countdown reaches zero, prices resolve and history is appended.
- The game enters a debrief and does not start the next round until the player selects Next Day.
- Prices never fall below 1.00.
- The player can reach the final day and receive a final profit/loss result.
- Restarting creates a fresh run.
- The same seed produces the same sequence of market results.
- The game can be played without inspecting the debugger or project files.

## 11. Phase 1.5: Market Manipulation

After the core loop is stable, add optional actions that spend money or a limited influence resource.

Possible actions:

- **Pump:** temporarily increases positive momentum for one stock, but raises volatility and may create a later correction.
- **Sabotage:** temporarily decreases momentum for one stock, but costs more and increases the chance of detection.
- **Rumor campaign:** changes the next day's news weighting with uncertain results.

Every manipulation action should have:

- A visible cost.
- A target stock.
- A duration or resolution day.
- A risk or downside.
- Feedback explaining the result.

The player should still be able to win without manipulation. Manipulation is meant to create a second strategic layer, not become a required button press.

## 12. Phase 2: Multiplayer Direction

Multiplayer should use a server-authoritative market simulation. Clients submit trade or manipulation requests; the server validates them and advances the shared market state.

Possible multiplayer formats:

- Competitive portfolios sharing one market.
- A small lobby where players trade during the same short day timer.
- A market where manipulation actions compete for limited influence.

Before multiplayer work begins, the single-player model should already have:

- Serializable game state.
- Deterministic seeded market updates.
- Centralized trade validation.
- No UI code that directly owns game rules.
- Clear event IDs or action records for replay and debugging.

## 13. Open Design Questions

These can wait until the first playable loop exists:

- Should each run use a fixed seed, a daily seed, or a fully random seed?
- Should the player receive a small amount of income between days?
- Should there be a market-wide index or only individual stocks?
- Should a run have difficulty settings that alter volatility and starting cash?
- Should manipulation be legal in the fictional world, illegal, or simply risky?
- Should multiplayer be synchronous with a timer or turn-based with player readiness?
