class_name PlayerGoals
extends RefCounted

const HOLD := "HOLD"
const SPREAD := "SPREAD"
const PRICE := "PRICE"
const VALUE := "VALUE"

const HOLD_REWARD_PENCE: int = 12_000
const SPREAD_REWARD_PENCE: int = 8_000
const PRICE_REWARD_PENCE: int = 10_000
const VALUE_REWARD_PENCE: int = 10_000
const PRICE_TARGET_RATIO: float = 1.2
const VALUE_TARGET_RATIO: float = 1.3

# The first goal always builds on the dealt home stake; the second is drawn.
static func deal(state: GameState, random: RandomNumberGenerator) -> Array[Dictionary]:
	var goals: Array[Dictionary] = []
	if not state.home_symbol.is_empty():
		var home_target := int(state.holdings.get(state.home_symbol, 0)) * 2
		goals.append(_goal(HOLD, state.home_symbol, home_target, HOLD_REWARD_PENCE, "Hold %d %s at the final close" % [home_target, state.home_symbol]))
	var options: Array[Dictionary] = []
	if state.stocks.size() >= 2:
		var spread_target := mini(3, state.stocks.size())
		options.append(_goal(SPREAD, "", spread_target, SPREAD_REWARD_PENCE, "Hold %d different stocks at the final close" % spread_target))
	var price_stock := _other_stock(state, random)
	var price_target := roundi(float(price_stock.current_price_pence) * PRICE_TARGET_RATIO)
	options.append(_goal(PRICE, price_stock.symbol, price_target, PRICE_REWARD_PENCE, "%s closes the game at %s or higher" % [price_stock.symbol, _pounds(price_target)]))
	var value_target := roundi(float(state.starting_value_pence) * VALUE_TARGET_RATIO)
	options.append(_goal(VALUE, "", value_target, VALUE_REWARD_PENCE, "Finish with a portfolio worth %s" % _pounds(value_target)))
	goals.append(options[random.randi_range(0, options.size() - 1)])
	return goals

static func progress(goal: Dictionary, state: GameState) -> int:
	var symbol := str(goal.get("symbol", ""))
	match str(goal.get("type", "")):
		HOLD:
			return int(state.holdings.get(symbol, 0))
		SPREAD:
			var count := 0
			for held_symbol in state.holdings:
				if int(state.holdings[held_symbol]) > 0:
					count += 1
			return count
		PRICE:
			var stock := state.get_stock(symbol)
			return 0 if stock == null else stock.current_price_pence
		VALUE:
			return state.portfolio_value_pence()
	return 0

static func is_complete(goal: Dictionary, state: GameState) -> bool:
	return progress(goal, state) >= int(goal.get("target", 0))

static func evaluate(state: GameState) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for goal in state.goals:
		var result := goal.duplicate()
		result["progress"] = progress(goal, state)
		result["complete"] = is_complete(goal, state)
		results.append(result)
	return results

static func progress_text(goal: Dictionary, state: GameState) -> String:
	var current := progress(goal, state)
	var target := int(goal.get("target", 0))
	var goal_type := str(goal.get("type", ""))
	if goal_type == PRICE or goal_type == VALUE:
		return "%s / %s" % [_pounds(current), _pounds(target)]
	return "%d / %d" % [current, target]

static func _goal(type: String, symbol: String, target: int, reward_pence: int, text: String) -> Dictionary:
	return {"type": type, "symbol": symbol, "target": target, "reward_pence": reward_pence, "text": text}

static func _other_stock(state: GameState, random: RandomNumberGenerator) -> StockData:
	var candidates: Array[StockData] = []
	for stock in state.stocks:
		if stock.symbol != state.home_symbol:
			candidates.append(stock)
	if candidates.is_empty():
		return state.stocks[0]
	return candidates[random.randi_range(0, candidates.size() - 1)]

static func _pounds(pence: int) -> String:
	return "£%d.%02d" % [pence / 100, pence % 100]
