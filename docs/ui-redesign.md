# StockTroder UI Redesign

This is a forward-looking design plan. The current implementation described below
is the starting point for the redesign, not the final visual target. Keep the
rules and data contracts stable unless a separate game-design change is approved.

Status labels: **Shipped** means the current build has this behavior, **Partial**
means the foundation exists but the intended presentation is incomplete, and
**Planned** means it is future work.

## 1. Design Goal

The trading screen should feel like a live market board, not a stock picker with a detail popup.

The player should see the whole market, understand which stocks are moving, and act quickly without opening another view.

The main questions should be visible at once:

- Which stocks are rising or falling?
- What does the projection say?
- What news explains the movement?
- How much cash is available?
- What do I currently own?
- Which Buy or Sell action should I take now?

## 2. Economy Scale (Shipped Baseline)

The current economy uses a £1,000 starting bankroll, whole shares, pence-based
internal values, and large share prices. Use these values as the starting point
for the visual redesign; balance changes belong in the economy documents and
tests, not in this visual redesign document.

Current baseline:

- Starting cash: **£1,000**.
- Shares are whole units.
- Stock prices use large, readable denominations.
- A single share should represent a meaningful decision.
- The player may go all-in on one stock or split money across several stocks.

Current opening prices:

| Stock | Opening price | Position |
| --- | ---: | --- |
| AUR | £50 | Volatile growth |
| BRK | £100 | Stable retail |
| CYN | £250 | News-sensitive energy |
| DSK | £500 | Moderate software |
| EGF | £750 | Defensive food |
| FRB | £1,000 | High-risk biotech |

These prices are the current catalog baseline. Any future economy change should
be reflected in the simulation tests and the player-facing screens together.

With £1,000, a player can:

- Buy many low-priced shares.
- Buy a few medium-priced shares.
- Buy one expensive share.
- Keep cash instead of investing.

That is the intended tension.

## 3. Primary Screen Layout (Shipped, With Polish Remaining)

```text
+---------------------------------------------------------------+
| ROUND 1/10 | TIME | CASH | PORTFOLIO | RETURN | MATCH STATUS |
+---------------------------------------------------------------+
|                                                               |
|                  SHARED LIVE MARKET GRAPH                    |
|        all stocks, colored lines, legend, price scale        |
|                                                               |
+----------------------+----------------------+-----------------+
| Stock | Price | +/-  | Projection | Owned | BUY | SELL       |
| AUR   | £50   | ...  | ...        | ...   |  +  |  -  | PUMP | SABOTAGE | HYPE | FUD | CALL | PUT |
| BRK   | £100  | ...  | ...        | ...   |  +  |  -         |
| ...                                                        |
+----------------------+----------------------+-----------------+
| LIVE MARKET           | NEWS FEED                              |
| shared graph and rows | short signals and resolved headlines  |
+---------------------------------------------------------------+
```

The status bar is the top element. The graph and rows are the full main market surface and action surface. The news feed is the explanation surface.

The dashboard fits responsive 16:9 viewports. The graph stays above compact stock
rows. The news panel is hidden at narrow widths, while chart ranges and secondary
information use controls rather than page scrolling. Buy, Sell, Pump, Sabotage,
Hype, Fud, Call, and Put remain row actions.

## 4. Shared Market Graph (Shipped, With Polish Remaining)

The graph shows every configured stock at once.

Each series has:

- A stable rainbow color.
- A visible symbol label in the legend.
- Current price in the legend.
- A line that updates every live market sample.
- A clear current-price marker.

The graph must also support:

- A readable price axis.
- A readable time axis.
- Enough contrast between lines.
- A selected-stock highlight.
- A non-color label for every series.
- Fewer than six series when a multiplayer match is configured with a smaller catalog.

The live graph currently uses normalized percentage movement from the selected
range start. The redesign should preserve that comparison-friendly behavior,
while making the range label and price context clearer. Debrief also provides
day-results and game-so-far ranges.

## 5. Stock Rows (Shipped)

Each stock row is a complete quick-trade control.

Show:

- Color marker.
- Symbol.
- Company name.
- Live price.
- Change from round opening price.
- Projected end-of-round range.
- Shares owned.
- Position value.
- One-share Buy button.
- One-share Sell button.
- Pump, Sabotage, Hype, Fud, Call, and Put action buttons after Buy and Sell.

The buttons should buy or sell one share. A selected-stock panel can provide a quantity control for larger orders, but the common action must be fast.

When the player cannot act:

- Disable the button when the phase does not allow trading.
- Show a short reason for rejection.
- Never hide the stock row.

Manipulation and option buttons show their paid cost in the tooltip, become
unavailable outside `TRADING`, and change to an active label after use. The row
remains the only action surface; do not duplicate these controls in a detail
panel.

## 6. News Feed (Shipped, With Polish Remaining)

News becomes a first-class market signal.

The feed should show:

- Stock symbol.
- Stable color marker.
- Short headline.
- Time or round label.
- Directional effect when resolved.
- Whether the item is a forecast signal or a resolved explanation.

Example:

```text
ROUND 3  CYN  New energy contract announced
Forecast signal: positive
```

After resolution:

```text
ROUND 3  CYN  New energy contract announced
Resolved: +12.4%
```

Planted stories are secret. Other players see them as ordinary company news.
The planter sees `YOUR HYPE` or `YOUR FUD`. Insiders see `PLANTED HYPE` or
`PLANTED FUD`:

```text
ROUND 3  CYN  NEWS
COMPANY NEWS  New energy contract announced
```

The feed should not reveal the exact future price before resolution.

## 7. Single-Player View (Shipped)

Single-player should show:

- The complete market graph.
- Every stock row.
- The news feed.
- The player's cash and portfolio.
- A readable news feed and short market context.

The player should not need to change screens to compare stocks.

## 7.1 Forward Action Pattern

Forward actions use one consistent rule:

- Place `START TRADING`, `NEXT DAY`, `CONTINUE`, and `RESTART` in a bottom-right action bar.
- Use a subtle green style to show that the action moves the game forward.
- Keep Back, Exit, and Cancel separate from the forward action.
- Keep the action visible without scrolling.

## 8. Multiplayer View (Partial)

The market graph and stock rows remain shared. The current build also supports
three deterministic computer players in local runs, network readiness, and
rankings ordered by return.

The current rankings panel provides the shared player comparison. The intended
compact player panel is:

| Player | Cash | Portfolio | Return | Holdings |
| --- | ---: | ---: | ---: | --- |
| You | £... | £... | ... | AUR 2, CYN 1 |
| Alex | £... | £... | ... | BRK 3 |

Multiplayer visibility rule:

- Show each player's cash, portfolio value, return, and stock holdings.
- Show no private order history or hidden manipulation intentions.
- Make it clear that all players see the same market.
- Keep each player's portfolio separate.

This creates strategic information without requiring a player-driven market
price model.

## 9. Debrief View (Shipped, With Polish Remaining)

The debrief should reuse the shared graph and add a round result table.

Show:

- Opening and closing prices for every stock.
- Percentage movement.
- Resolved news.
- Action markers for Pump, Sabotage, Hype, Fud, Call, and Put, including correction, backfire, and settlement status.
- Player's round profit/loss.
- Other players' round profit/loss in multiplayer.
- Updated holdings and cash.
- Next Day button.

The player should be able to compare the forecast with the result before starting the next round.

## 10. Options (Partial)

Options should not change competitive economy rules.

Useful settings:

- Window mode.
- Display scale.
- Master volume.
- Graph line thickness or accessibility contrast mode.
- Color-blind-friendly markers and symbols.

The stock palette must retain text symbols and shapes so color is not the only signal.

## 10.1 Run Complete Screen Polish (Planned)

Improve the run-complete screen so the ending feels like a clear payoff, not another debrief panel.

- Make the winner the first visual signal with a large, unmistakable winner reveal and a short celebratory "Tada" moment.
- Present final standings in a strong hierarchy: winner, final portfolio value, total return, starting cash, and profit/loss.
- Show the player's final stats at a glance, with enough detail to explain the result without making the screen feel like a spreadsheet.
- Add a compact run recap for standout moments such as best trade, biggest gain, biggest loss, and manipulation outcomes.
- Use restrained motion, sound, and highlight treatment to make the reveal feel special while keeping all values readable and accessible.
- Keep `RESTART` and return-to-menu actions in the bottom-right action area after the result has been understood.

The current screen already shows the run title, millionaire victory message,
starting cash, final cash, total return, days completed, final holdings, rankings,
and restart. The planned redesign should improve hierarchy and celebration
without changing scoring or the summary contract.

## 11. Remaining Forward Polish Plan

1. Rework the run-complete layout around the winner and final result.
2. Add final-stat cards or a compact stat grid for value, return, cash, and days.
3. Add a readable run recap using completed round data for best and worst moments.
4. Replace the generic player-id victory text with the winner display name and rank context.
5. Add restrained reveal motion and optional sound, with a reduced-motion fallback.
6. Complete the opponent holdings panel and options persistence where still missing.
7. Review narrow-width behavior so the result and actions remain visible without scrolling.

## 12. Target Review Checklist

- The live dashboard shows all configured stocks with stable color and text labels.
- Every stock row exposes Buy, Sell, manipulation, and option actions with clear disabled states.
- The live chart identifies whether it shows round, recent-history, or game-so-far movement.
- The news feed separates forecast, market, player, AI, and network activity.
- Debrief shows resolved prices, action outcomes, portfolio result, and rankings.
- Run complete names the winner, explains the final result, and makes the next action obvious.
- Local and network summaries use the same readable hierarchy.
- The dashboard and result screens remain usable at narrow widths without accidental overflow.
