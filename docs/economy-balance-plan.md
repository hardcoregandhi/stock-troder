# Economy Balance Plan

## 1. Purpose

This document defines how to test and tune an economy with automated simulations and focused human playtests.

It applies the principles in [economy.md](economy.md) to StockTroder. The same process can support a board game or another resource-driven game.

Automated tests can find mathematical problems. Human playtests are still needed for clarity, fun, pacing, and perceived fairness.

## 2. Balance Workflow

1. Define the player decisions the economy should create.
2. List every source, resource, sink, and opportunity cost.
3. Normalize values as percentages or action points.
4. Define common, strong, and catastrophic outcomes.
5. Build a seeded simulation harness.
6. Test extreme strategies.
7. Remove dominant strategies.
8. Run human playtests on promising parameter sets.
9. Record decisions and explanations, not only scores.
10. Change one major variable at a time.

## 3. Automated Strategy Runners

Use the real `MarketSimulator`, `GameState`, `TradeService`, and manipulation rules. Do not create a second balance model that can drift from the game.

Each strategy should support the same events:

```text
strategy.start_run(seed, parameters)
strategy.on_projection(state)
strategy.on_market_sample(state)
strategy.on_debrief(state, resolution)
strategy.finish_run(summary)
```

Initial strategy probes:

- `buy_and_hold`: buy a target stock and never sell.
- `forecast_follower`: buy stocks with positive projections.
- `momentum_trader`: trade after live movement and sell after reversals.
- `cash_preserver`: keep a reserve and make low-risk trades.
- `diversifier`: spread cash across several stocks.
- `pump_always`: Pump whenever available.
- `pump_signal_only`: Pump only when projection and live movement agree.
- `never_pump`: use normal trading only.

These are probes, not claims about perfect players.

## 4. Paired Seed Runs

Compare strategies on the same seeds so they face the same market.

```text
for seed in seeds:
    result_a = run(strategy_a, seed)
    result_b = run(strategy_b, seed)
    compare(result_a, result_b)
```

Useful pairings:

- `pump_always` versus `never_pump`.
- `pump_signal_only` versus `never_pump`.
- `buy_and_hold` versus `momentum_trader`.
- `cash_preserver` versus `diversifier`.

## 5. Metrics

Record these for every strategy:

- Mean final cash.
- Median final cash.
- Standard deviation.
- 10th and 90th percentile final cash.
- Chance of finishing below starting cash.
- Lowest cash during a run.
- Number of trades.
- Number of Pump actions.
- Mean return per round.
- Largest single-round loss.
- Recovery rate after a bad round.

Use distributions, not only averages. A high mean with a poor 10th percentile may describe a risky strategy, not a dominant one.

## 6. Dominance Checks

For strategies A and B:

```text
dominance_rate(A, B) = runs where A beats B / total paired runs
```

Warning signs:

- One strategy beats every other strategy on nearly every seed.
- `pump_always` beats `never_pump` even without a useful signal.
- `cash_preserver` loses nearly every run because exposure is rewarded too strongly.
- `buy_and_hold` beats active trading even though live prices create no selling advantage.
- A losing first round predicts nearly every final result.

The target is not equal win rates. The target is context dependence: different actions should be best in different states.

## 7. Sensitivity Sweeps

Test ranges, not one magic value:

```text
pump_cost_percent = 0.01, 0.02, 0.025, 0.03, 0.04
pump_boost_percent = 0.02, 0.04, 0.06
correction_chance = 0.40, 0.55, 0.65, 0.75
round_length_seconds = 20, 30, 40
```

For each combination:

1. Run the same seed set.
2. Record all strategy metrics.
3. Find regions where multiple strategies remain viable.
4. Reject regions with dominant or useless actions.

The output should be a table or CSV that shows how balance changes as each parameter moves.

## 8. Formula Versus Simulation

Compare the formula's prediction with the simulated result:

```text
formula_error = simulated_mean_value - predicted_value
relative_error = formula_error / max(1.0, abs(predicted_value))
```

Large error may mean:

- The formula omitted timing.
- The player can sell before correction.
- The action changes the market path rather than only the final price.
- The player has more information than the formula assumes.
- Risk has value beyond expected cash.

That is useful model feedback. The formula should be improved, not defended as truth.

## 9. Pump Experiment

For each seed, compare identical market states:

```text
Run A: buy shares normally
Run B: spend the same budget on Pump and buy the target
Run C: keep the budget in cash
```

Compare final and round-level distributions across several Pump costs and correction risks.

Desired result:

- Pump is useful in some states.
- Normal buying is better in some states.
- Keeping cash is better in some states.
- No option wins regardless of market state.

## 10. Balance Invariants

Automated tests should assert:

- Cash never becomes negative.
- A failed action does not change state.
- Price floors are respected.
- The same seed produces the same result.
- A bad round does not remove all meaningful future actions.
- Final liquidation is included in final cash.
- Manipulation costs are paid exactly once.
- Per-round action limits reset at the correct boundary.

## 11. Human Playtest Handoff

After automated sampling identifies a few promising parameter regions, run human tests on those regions.

Ask players:

- What felt safest?
- What felt strongest?
- Did you feel forced to use one action?
- Did losses feel understandable?
- Did you have a way to recover?
- Did saving resources feel useful?
- Did the graph and forecast communicate value?
- Did the action feel fair when it failed?
- Did the economy become more interesting or more automatic over time?

Watch behavior as well as answers. A player may say an action is balanced while using it every time.

## 12. Limits of Automation

Automated runs can test:

- Mathematical balance.
- Distribution shape.
- Dominant strategies.
- Solvency.
- Sensitivity to costs and probabilities.
- Determinism and regression safety.

Automated runs cannot reliably test:

- Graph readability.
- Whether a player understands a forecast.
- Whether timing feels exciting rather than stressful.
- Whether the debrief is satisfying.
- Whether a risk feels fair.

Use automated sampling first, then human playtesting on a small set of promising values.

## 13. Current StockTroder Parameters to Sweep

- Starting cash: £5,000, £10,000, £15,000.
- Round length: 20, 30, 40 seconds.
- Market sample interval: 0.5 seconds initially.
- Pump cost: 1%, 2.5%, 4% of starting cash.
- Pump live boost: 2%, 4%, 6%.
- Correction chance: 40%, 55%, 65%, 75%.
- Correction size: 4%, 8%, 12%.
- News impact range.
- Stock volatility range.

The first harness should focus on Pump and ordinary trading. Planting news and sabotage should be added to the harness only after their rules are specified.
