# StockTroder UI Redesign

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

## 2. Economy Scale

Use a smaller starting bankroll and larger share prices.

Initial target:

- Starting cash: **£1,000**.
- Shares are whole units.
- Stock prices use large, readable denominations.
- A single share should represent a meaningful decision.
- The player may go all-in on one stock or split money across several stocks.

Suggested opening prices:

| Stock | Opening price | Position |
| --- | ---: | --- |
| AUR | £50 | Volatile growth |
| BRK | £100 | Stable retail |
| CYN | £250 | News-sensitive energy |
| DSK | £500 | Moderate software |
| EGF | £750 | Defensive food |
| FRB | £1,000 | High-risk biotech |

These prices are a first scale, not final balance values. The economy harness should test whether they create useful concentration and diversification choices.

With £1,000, a player can:

- Buy many low-priced shares.
- Buy a few medium-priced shares.
- Buy one expensive share.
- Keep cash instead of investing.

That is the intended tension.

## 3. Primary Screen Layout

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
| AUR   | £50   | ...  | ...        | ...   |  +  |  -         |
| BRK   | £100  | ...  | ...        | ...   |  +  |  -         |
| ...                                                        |
+----------------------+----------------------+-----------------+
| LIVE MARKET           | NEWS FEED                              |
| shared graph and rows | short signals and resolved headlines  |
+---------------------------------------------------------------+
```

The status bar is the top element. The graph and rows are the full main market surface and action surface. The news feed is the explanation surface.

The dashboard must fit responsive 16:9 viewports. The graph stays above compact stock rows. Extra information moves to tabs or separate pages rather than scroll bars. The right panel contains only a readable news feed and short market context. Buy, Sell, Pump, and Sabotage remain row actions.

## 4. Shared Market Graph

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

The graph should use a normalized movement view or an absolute price view deliberately. Absolute prices make money value clear. A normalized percentage view makes performance comparison clear. The first version should show absolute price with percentage change in the legend.

## 5. Stock Rows

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

The buttons should buy or sell one share. A selected-stock panel can provide a quantity control for larger orders, but the common action must be fast.

When the player cannot act:

- Disable the button when the phase does not allow trading.
- Show a short reason for rejection.
- Never hide the stock row.

## 6. News Feed

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

The feed should not reveal the exact future price before resolution.

## 7. Single-Player View

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

## 8. Multiplayer View

The market graph and stock rows remain shared.

Add a compact player panel:

| Player | Cash | Portfolio | Return | Holdings |
| --- | ---: | ---: | ---: | --- |
| You | £... | £... | ... | AUR 2, CYN 1 |
| Alex | £... | £... | ... | BRK 3 |

Multiplayer visibility rule for the first version:

- Show each player's cash, portfolio value, return, and stock holdings.
- Show no private order history or hidden manipulation intentions.
- Make it clear that all players see the same market.
- Keep each player's portfolio separate.

This creates strategic information without requiring a player-driven market price model yet.

## 9. Debrief View

The debrief should reuse the shared graph and add a round result table.

Show:

- Opening and closing prices for every stock.
- Percentage movement.
- Resolved news.
- Player's round profit/loss.
- Other players' round profit/loss in multiplayer.
- Updated holdings and cash.
- Next Day button.

The player should be able to compare the forecast with the result before starting the next round.

## 10. Options

Options should not change competitive economy rules.

Useful settings:

- Window mode.
- Display scale.
- Master volume.
- Graph line thickness or accessibility contrast mode.
- Color-blind-friendly markers and symbols.

The stock palette must retain text symbols and shapes so color is not the only signal.

## 11. Implementation Order

1. Change the economic scale to £1,000 starting cash and large stock prices.
2. Preserve configurable stock count and stable catalog order.
3. Build the shared all-stock graph and legend.
4. Rebuild stock rows as quick-trade controls.
5. Add the news feed.
6. Add multiplayer player holdings panel.
7. Rebuild debrief around the shared graph and round table.
8. Add display and accessibility options.
9. Re-run the economy balance harness across stock counts and price scales.

## 12. Acceptance Criteria

- All configured stocks are visible on one live graph.
- Each stock has a stable color and text legend entry.
- Every stock row has Buy and Sell controls.
- A one-share trade is one quick action.
- Stock prices are large enough that one share matters.
- A £1,000 player can go all-in or diversify.
- The news feed explains current signals without revealing exact future prices.
- Multiplayer shows other players' holdings without allowing client-side authority.
- The graph and rows handle one to six configured stocks.
- The same UI works for single-player and multiplayer market state.
