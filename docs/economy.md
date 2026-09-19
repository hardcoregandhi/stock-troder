# Balancing Game Economies

## 1. Purpose

An economy controls what players gain, spend, save, risk, and value. It is not just a list of prices. It is the decision system that turns resources into meaningful choices.

The central question is:

> Does the economy create several useful choices, or does it eventually reveal one best action?

This guide applies to StockTroder and board games in general. The detailed automated testing process is in [economy-balance-plan.md](economy-balance-plan.md).

## 2. Economy Versus Realism

A game economy does not need to copy a real economy. It needs to be readable, consistent, tunable, and strategically useful.

Game theory and economy design can derive defensible starting values. They do not provide one inevitable answer. A board game can calculate how gold, items, and victory points should relate, then use playtesting to correct for timing, player perception, and unexpected strategies.

For StockTroder, £1,000 is a scale for expressing budgets, prices, costs, gains, and losses. It is still derived from intended relationships, such as how many large-denomination shares the player can buy and how much cash should remain available.

## 3. The Basic Economy Model

Every economy has four parts:

```text
Sources -> Resources -> Decisions -> Sinks
             ^             |
             +-- feedback -+
```

- **Sources:** starting cash, rewards, income, selling assets.
- **Resources:** money, shares, cards, energy, influence, time, information.
- **Decisions:** buy, save, trade, bid, invest, attack, diversify.
- **Sinks:** purchases, fees, upkeep, damage, risk, one-use actions, opportunity cost.

An economy with strong sources and weak sinks inflates. An economy with strong sinks and weak sources feels restrictive. A good economy keeps resources valuable across the whole game.

## 4. Economic Shapes

Choose the intended shape before choosing numbers.

### Tight economy

Resources are scarce and players cannot do everything. This supports auctions, survival, and short trading games. The risk is that one mistake becomes irreversible.

### Expanding economy

Players gain resources and options over time. This supports engine builders. The risk is runaway leaders and automatic end games.

### Cycling economy

Resources move in and out repeatedly. Players gain, spend, recover, and make new choices. This supports markets, worker placement, and deck builders.

### Auction economy

Value is discovered through competition and changing demand. This supports *For Sale*, *Modern Art*, and *Power Grid*.

StockTroder is mainly a cycling economy with limited expansion: good rounds create more capital for later rounds. Its intended scale is a £1,000 bankroll with share prices such as £50, £100, £250, £500, £750, and £1,000.

## 5. Deriving Values Through Relationships

A value has meaning through its relationship to other values.

```text
cost rate = action cost / starting resource
reward rate = expected reward / action cost
risk rate = plausible loss / player assets
pacing rate = resource change per round
```

For a board-game item:

```text
item value = immediate VP
             + expected future income
             + flexibility
             + scarcity or denial value
             - action cost
             - risk
```

A simple gold-to-VP comparison is:

```text
gold efficiency = total expected VP / gold cost
```

Equal efficiency is not required. A risky item may have higher upside and lower reliability. A defensive item may have lower efficiency but protect the player from a bad state. The test is whether one option dominates every alternative after opportunity cost is included.

## 6. Applying the Model to StockTroder

StockTroder does not convert gold directly into VP. It converts cash into uncertain positions, then positions into future cash.

```text
action value = expected cash outcome
               + information value
               + flexibility value
               - cash cost
               - risk cost
               - opportunity cost
```

### Starting cash

Starting cash should be derived from the desired number of meaningful actions:

```text
starting_cash = target positions
                * reference stock price
                * desired position size
                + reserve for future choices
```

The player should be able to buy several positions, keep a reserve, and use a special action without treating one button as mandatory.

### Pump

Pump should be compared with buying shares and holding cash:

```text
expected_pump_gain = shares exposed
                     * stock price
                     * expected price boost
                     * probability of realizing the boost

expected_pump_value = expected_pump_gain
                      - expected correction loss
                      - Pump cost
```

The model must include the player's ability to sell during the live round. A Pump that can be exited before correction is more valuable than one resolved only at the end.

The Pump cost must be re-scaled with the new bankroll. A first test value is 2.5% of starting cash, or £25, rather than the old £250 value. The 4% boost and correction risk remain test hypotheses. They are useful only if normal buying, Pump, and holding cash are each best in some market states.

### Planted news

News can provide information, influence the market, or both:

```text
news value = information value
             + expected influence gain
             - failure cost
             - action cost
             - opportunity cost
```

If news changes what the player knows and guarantees what the market does, it may be too powerful. A safer first model changes event probabilities without guaranteeing the result.

### Sabotage

Sabotage needs its own risk model:

```text
sabotage value = target position gain
                 - action cost
                 - detection risk
                 - backlash risk
```

It should not be priced as a simple negative Pump.

## 7. Payoff Tables

A payoff table connects formulas to game rules.

| Action | Market state | Result | Player value |
| --- | --- | --- | ---: |
| Buy | Price rises | Position gains | `+gain` |
| Buy | Price falls | Position loses | `-loss` |
| Hold cash | Opportunity appears | Player can act later | `+flexibility` |
| Pump | Boost realized | Position gains more | `+boost - cost` |
| Pump | Correction occurs | Position loses value | `-correction - cost` |
| Plant news | Signal works | Better information or movement | `+influence - cost` |
| Plant news | Signal fails | Money and opportunity lost | `-cost - failure` |

Ask:

> For which market states is each action the best response?

If an action wins in every row, it is dominant. If it wins in no row, it is decorative rather than strategic.

## 8. Feedback and Recovery

Positive feedback creates a lead:

```text
lead -> more resources -> more options -> larger lead
```

This can feel rewarding but can also make later play meaningless. A good economy distinguishes between being ahead, being safe, and being able to recover.

Useful recovery tools include:

- Opportunities for players who are behind.
- Diminishing returns on large holdings.
- Public information that enables response.
- Costs that scale with power.
- A fixed end point that limits compounding.

Catch-up should keep the game contestable without erasing good decisions.

## 9. Design Lessons from Board Games

- *Power Grid*: money must compete with auctions, operating costs, and future plans.
- *For Sale*: players need valuation ceilings and must respect opportunity cost.
- *Modern Art*: value changes with context and demand.
- *Incan Gold*: stopping can be as important as starting.
- *Can't Stop*: visible risk can make continuation meaningful.
- *Terraforming Mars* and *Wingspan*: compounding engines need limits and counterplay.
- *Coup* and *Skull*: partial information works when signals are readable but not certain.

Use these games as mechanism case studies, not as sources of transferable prices.

## 10. Practical Rule

Do not ask whether a price is realistic in isolation. Ask whether the price creates the intended exchange:

- What does the player give up?
- What can the player gain?
- How often can the action be used?
- What can go wrong?
- Can the player recover?
- Is another action better in a different state?

The automated balance method for answering these questions is in [economy-balance-plan.md](economy-balance-plan.md).
