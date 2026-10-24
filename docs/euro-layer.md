# StockTroder Eurogame Layer

## 1. Purpose

This document records the Eurogame ideas for StockTroder. It states what is built, the numbers used, and what is still open.

The goal is long-term planning. A player should start each run with something to build, a private plan to follow, a shared problem to manage, and abilities that make their choices different from other players.

Rules in this document are first test values. They need playtesting and the seeded strategy runs in [economy-balance-plan.md](economy-balance-plan.md).

## 2. Summary

| Idea | Status | Where |
| --- | --- | --- |
| 1. Roles with abilities and drawbacks | Built | `PlayerRole`, `TradeService`, `RoundResolutionService` |
| 2. Credibility and influence from holdings | Built | `GameState`, `TradeService` |
| 3. Pay for future projections | Built as Research | `MarketSimulator`, `TradeService` |
| 4. Starting stock | Built as a dealt home stake | `RunSetupService` |
| 5. Shared goal and market crash | Built as Market Stability | `RunSetupService`, `MarketSimulator` |
| 6. Starting goals with end rewards | Built as dealt goals | `PlayerGoals`, `RoundResolutionService` |
| 7. Secret HYPE/FUD | Built | `TradingSession`, `NetworkSnapshotService`, dashboard feed |
| 8. Comeback after a bad start | Open design question | Section 10 |

## 3. Roles

Each player has one role. In single-player, the player picks a role from the main menu. Computer players use fixed roles. In multiplayer, the host deals roles from the match seed, with no repeats until all five are used.

| Role | Ability | Drawback |
| --- | --- | --- |
| Hedgie | Calls and puts cost 40% less. | HYPE/FUD has half strength. |
| Pension Fund | Earns 1% of held share value at every close. | Calls and puts cost 50% more. |
| Redditor | HYPE/FUD costs £40. | HYPE/FUD is less reliable: 45% work, 30% backfire. |
| Belford | HYPE/FUD has 1.75x strength. | HYPE/FUD costs £120. |
| Insider | Sees which stories are planted HYPE or FUD. | Cannot plant HYPE/FUD. |

The base values for a player with no role are: £75 HYPE/FUD, 1.0x strength, 55% work, 20% backfire, normal option premium, no dividend.

Design intent:

- Hedgie rewards timing with options.
- Pension Fund rewards holding shares. This is the "higher return for more share volume" role.
- Redditor makes many cheap, noisy stories.
- Belford makes few, strong, expensive stories.
- Insider is the counter-role to secret HYPE/FUD.

Computer roles: Mara (Conservative) is Pension Fund, Quinn (Balanced) is Hedgie, Rook (Aggressive) is Belford.

## 4. Credibility and Influence

Held shares build credibility. At every close, a player gains 1 credibility point for each £250 of share value they hold. Credibility never drops.

- 4 credibility points make 1 influence level.
- Influence is capped at level 5 (20 points).
- Each influence level adds 15% HYPE/FUD strength, 3% work chance, and removes 2% backfire chance.

Credibility comes from holding, not from trading volume. Trade volume has no fee, so buying and selling the same share in one second would build credibility for free. Holding value at the close cannot be faked that way.

## 5. Research: Paying for Future Projections

During the Brief, the player can pay £30 to research one stock. Research shows tomorrow's story and tomorrow's base forecast for that stock. The note is private.

How it works:

- `MarketSimulator` rolls each stock's story and random shock one day ahead, using a separate seeded random stream. This keeps live prices and resolution rolls unchanged when research is used.
- The base forecast is `trend + news impact + random shock`. The final projection also adds momentum from today's close, which can change it by up to 2.5%.
- Research is not available on the final day, because there is no later day.
- Research is limited to one note per stock per day.

Research is visible in the Brief outlook (TOMORROW column) and in the PLAN tab.

## 6. Starting Stock

Every player starts with £1,000 cash and a dealt home stake. The home stake is about £300 of one stock priced at £300 or less. With the default catalog this is 6 AUR, 3 BRK, or 1 CYN. Players get different home stocks where possible.

Return is measured against starting value, which is cash plus the dealt stake. A new run always starts at a return of £0.

## 7. Dealt Goals

Each player gets two private goals at the start, similar to tickets in *Ticket to Ride*. Goals pay at the final close, before the last liquidation.

The first goal always builds on the home stake:

| Goal | Rule | Reward |
| --- | --- | --- |
| Hold | Hold twice the dealt home stake at the final close | £120 |

The second goal is drawn from:

| Goal | Rule | Reward |
| --- | --- | --- |
| Spread | Hold 3 different stocks at the final close | £80 |
| Price | Another stock closes the game at 120% of its start price or higher | £100 |
| Value | Finish with a portfolio worth 130% of starting value | £100 |

A missed goal pays nothing. *Ticket to Ride* subtracts points for missed tickets. That penalty is not used yet, because it would make a bad start worse. See Section 10.

Price goals can be pushed by Pump and HYPE, and blocked by other players with Sabotage and FUD.

## 8. Market Stability: Shared Goal and Crash

Each run deals one bellwether stock. Every player shares its result.

- **Floor:** If the bellwether closes below 80% of its start price, the market crashes. Every stock loses 15% at that close. The floor then resets to 80% of the post-crash price, so one bad day cannot crash the market every day after.
- **Target:** If the bellwether closes the game at 115% of its start price or higher, every player gains £100.

The crash is applied after all other resolution effects. The debrief, feed, and PLAN tab report crashes.

A crash hurts players who hold many shares most. That makes a crash a weapon against the leader, and a risk for everyone. Players can Pump or HYPE the bellwether to protect it, or Sabotage and FUD it to force a crash.

## 9. Secret HYPE/FUD

Planted stories are now secret.

- A planted story appears in other players' feeds as ordinary `COMPANY NEWS`, using a believable headline that matches its direction.
- The planter sees their own story as `YOUR HYPE` or `YOUR FUD`.
- Insiders see every planted story as `PLANTED HYPE` or `PLANTED FUD`.
- Debrief outcomes for planted stories (worked, failed, backfired) show only for the planter and Insiders.
- In multiplayer, the host removes planted-story data from each client's snapshots and resolutions unless that client planted the story or is an Insider. Clients cannot read it from network data.
- Pump, Sabotage, trades, and options are still public activity.

The market still reacts. The forecast still moves when a story is planted, because the market believes the story. Players can notice a sudden forecast change, but they cannot know for certain who caused it or if it is real.

If two players plant on the same stock in one round, their strength adds together. The latest planter's odds are used at resolution.

## 10. Open Question: Can a Bad Start Recover?

Concern: a player who starts badly may never catch up, because profit compounds. This may fit the theme, but it can make the last half of a run feel decided.

What already pushes back:

- Goal and cooperative rewards are flat pound amounts. They are worth more to a small portfolio than a large one.
- A market crash hits large share positions hardest.
- Price goals and the bellwether can be attacked by any player.

What adds to the snowball:

- Pension Fund dividends grow with holdings.
- Credibility grows with held value, so rich players get stronger HYPE/FUD sooner.

Options to test:

1. **Keep it.** The snowball is the theme. Make the end-of-run summary say so.
2. **Last-place research.** The player in last place gets one free Research per day.
3. **Leader scrutiny.** The leading player's HYPE/FUD backfire chance rises by 10%.
4. **Credibility from activity.** Grant 1 credibility per day to players holding any shares, so small players still reach influence.
5. **Missed-goal penalty.** Adopt the *Ticket to Ride* penalty only if testing shows the comeback tools are strong enough.

Recommended test: run paired seeds with and without options 2 and 3. Compare the chance that the player in last place on Day 3 finishes above last place.

## 11. Other Open Items

- Multiplayer role choice in the lobby. The host currently deals roles.
- More goal types, such as holding a stock for a number of days.
- Computer players do not buy Research or aim at goals yet.
- Balance values in this document need the economy test runs.
