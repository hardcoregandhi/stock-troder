class_name TradeService
extends RefCounted

func buy(state: GameState, symbol: String, quantity: int) -> Dictionary:
	var stock := state.get_stock(symbol)
	if state.phase != GameState.Phase.TRADING:
		return _trade_result(state, false, "Trading is only available during the trading phase.", symbol, quantity, stock)
	if stock == null:
		return _trade_result(state, false, "Unknown stock.", symbol, quantity, null)
	if quantity <= 0:
		return _trade_result(state, false, "Quantity must be positive.", symbol, quantity, stock)
	var cost := stock.current_price_pence * quantity
	if cost > state.cash_pence:
		return _trade_result(state, false, "Not enough cash.", symbol, quantity, stock)
	state.apply_buy_shares(symbol, quantity)
	return _trade_result(state, true, "Bought shares.", symbol, quantity, stock)

func sell(state: GameState, symbol: String, quantity: int) -> Dictionary:
	var stock := state.get_stock(symbol)
	if state.phase != GameState.Phase.TRADING:
		return _trade_result(state, false, "Trading is only available during the trading phase.", symbol, quantity, stock)
	if stock == null:
		return _trade_result(state, false, "Unknown stock.", symbol, quantity, null)
	if quantity <= 0:
		return _trade_result(state, false, "Quantity must be positive.", symbol, quantity, stock)
	if quantity > int(state.holdings[symbol]):
		return _trade_result(state, false, "Not enough shares.", symbol, quantity, stock)
	state.apply_sell_shares(symbol, quantity)
	return _trade_result(state, true, "Sold shares.", symbol, quantity, stock)

func pump(state: GameState, symbol: String) -> Dictionary:
	var stock: StockData = state.get_stock(symbol)
	if state.phase != GameState.Phase.TRADING:
		return _pump_result(state, false, "Pump is only available during trading.", symbol, 0, false, 0.0, false)
	if stock == null:
		return _pump_result(state, false, "Unknown stock.", symbol, 0, false, 0.0, false)
	if state.action_on_cooldown("pump", symbol):
		return _pump_result(state, false, "Pump is cooling down for this stock.", symbol, 0, false, 0.0, false)
	if state.has_pumped(symbol):
		return _pump_result(state, false, "Pump already used for this stock this round.", symbol, 0, false, 0.0, false)
	if state.cash_pence < GameState.PUMP_COST_PENCE:
		return _pump_result(state, false, "Not enough cash for Pump.", symbol, 0, false, 0.0, false)
	state.cash_pence -= GameState.PUMP_COST_PENCE
	state.mark_pumped(symbol)
	state.set_action_cooldown("pump", symbol)
	stock.activate_pump(0.04)
	return _pump_result(state, true, "Pump active on %s: +4.0%% live path. £25.00 spent; correction risk at resolution." % symbol, symbol, GameState.PUMP_COST_PENCE, true, stock.pump_live_boost, true)

func sabotage(state: GameState, symbol: String) -> Dictionary:
	var stock: StockData = state.get_stock(symbol)
	if state.phase != GameState.Phase.TRADING:
		return _manipulation_result(state, false, "Sabotage is only available during trading.", symbol, "sabotage")
	if stock == null:
		return _manipulation_result(state, false, "Unknown stock.", symbol, "sabotage")
	if state.action_on_cooldown("sabotage", symbol):
		return _manipulation_result(state, false, "Sabotage is cooling down for this stock.", symbol, "sabotage")
	if state.has_sabotaged(symbol):
		return _manipulation_result(state, false, "Sabotage already used for this stock this round.", symbol, "sabotage")
	if state.cash_pence < GameState.SABOTAGE_COST_PENCE:
		return _manipulation_result(state, false, "Not enough cash for Sabotage.", symbol, "sabotage")
	state.cash_pence -= GameState.SABOTAGE_COST_PENCE
	state.mark_sabotaged(symbol)
	state.set_action_cooldown("sabotage", symbol)
	stock.activate_sabotage(-0.04)
	return _manipulation_result(state, true, "Sabotage active on %s: negative live pressure and resolution risk. £50.00 spent." % symbol, symbol, "sabotage", GameState.SABOTAGE_COST_PENCE, stock.sabotage_live_pressure)

func plant_fake_news(state: GameState, symbol: String, direction: int) -> Dictionary:
	var stock: StockData = state.get_stock(symbol)
	var normalized_direction := clampi(direction, -1, 1)
	var cost := fake_news_cost_pence(state)
	if state.phase != GameState.Phase.TRADING:
		return _manipulation_result(state, false, "Fake News is only available during trading.", symbol, "fake_news", normalized_direction)
	if stock == null:
		return _manipulation_result(state, false, "Unknown stock.", symbol, "fake_news", normalized_direction)
	if not bool(PlayerRole.value(state.role, "can_plant_news")):
		return _manipulation_result(state, false, "%s cannot plant HYPE/FUD." % PlayerRole.display_name(state.role), symbol, "fake_news", normalized_direction)
	if state.action_on_cooldown("fake_news", symbol):
		return _manipulation_result(state, false, "HYPE/FUD is cooling down for this stock.", symbol, "fake_news", normalized_direction)
	if normalized_direction == 0:
		return _manipulation_result(state, false, "Fake News needs a positive or negative direction.", symbol, "fake_news", normalized_direction)
	if state.has_planted_fake_news(symbol):
		return _manipulation_result(state, false, "Fake News already used for this stock this round.", symbol, "fake_news", normalized_direction)
	if state.cash_pence < cost:
		return _manipulation_result(state, false, "Not enough cash for Fake News.", symbol, "fake_news", normalized_direction)
	state.cash_pence -= cost
	state.mark_fake_news_planted(symbol)
	state.set_action_cooldown("fake_news", symbol)
	var level := state.influence_level()
	var projection_weight := 0.03 * float(PlayerRole.value(state.role, "fake_news_strength")) * (1.0 + 0.15 * float(level)) * float(normalized_direction)
	var success_chance := clampf(float(PlayerRole.value(state.role, "fake_news_success_chance")) + 0.03 * float(level), 0.0, 0.9)
	var backfire_chance := clampf(float(PlayerRole.value(state.role, "fake_news_backfire_chance")) - 0.02 * float(level), 0.0, 1.0 - success_chance)
	var headline := stock.planted_headline(normalized_direction)
	stock.projection_change += projection_weight
	stock.projection_low += projection_weight
	stock.projection_high += projection_weight
	stock.projected_price_pence = maxi(100, roundi(float(stock.current_price_pence) * (1.0 + stock.projection_change)))
	stock.activate_fake_news(projection_weight, headline, success_chance, backfire_chance)
	var result := _manipulation_result(state, true, "%s planted on %s: \"%s\". %s spent; outcome is uncertain." % ["HYPE" if normalized_direction > 0 else "FUD", symbol, headline, _format_pence(cost)], symbol, "fake_news", cost, projection_weight, normalized_direction)
	result["headline"] = headline
	result["influence_level"] = level
	return result

static func fake_news_cost_pence(state: GameState) -> int:
	return int(PlayerRole.value(state.role, "fake_news_cost_pence"))

func buy_research(state: GameState, symbol: String, forecast: Dictionary) -> Dictionary:
	var stock := state.get_stock(symbol)
	var next_day := state.current_day + 1
	var result := {"success": false, "action": "research", "symbol": symbol, "cost_pence": 0, "cash_after_action": state.cash_pence}
	if state.phase != GameState.Phase.BRIEF and state.phase != GameState.Phase.TRADING:
		result["message"] = "Research is available during the brief and trading."
	elif stock == null:
		result["message"] = "Unknown stock."
	elif forecast.is_empty():
		result["message"] = "There is no later day to research."
	elif int(state.research_reports.get(symbol, {}).get("day", 0)) == next_day:
		result["message"] = "Day %d research on %s is already in your notes." % [next_day, symbol]
	elif state.cash_pence < GameState.RESEARCH_COST_PENCE:
		result["message"] = "Not enough cash for research."
	else:
		state.cash_pence -= GameState.RESEARCH_COST_PENCE
		var report := {"day": next_day, "text": str(forecast["text"]), "impact": float(forecast["impact"]), "base_change": float(forecast["base_change"])}
		state.research_reports[symbol] = report
		result["success"] = true
		result["cost_pence"] = GameState.RESEARCH_COST_PENCE
		result["cash_after_action"] = state.cash_pence
		result["report"] = report
		result["message"] = "Research on %s: Day %d story \"%s\", base forecast %+.1f%%." % [symbol, next_day, report["text"], float(report["base_change"]) * 100.0]
	return result

func buy_call(state: GameState, symbol: String, quantity: int = 1, time_remaining_ratio: float = 1.0) -> Dictionary:
	return _buy_option(state, symbol, quantity, OptionContract.CALL, time_remaining_ratio)

func buy_put(state: GameState, symbol: String, quantity: int = 1, time_remaining_ratio: float = 1.0) -> Dictionary:
	return _buy_option(state, symbol, quantity, OptionContract.PUT, time_remaining_ratio)

static func option_premium_pence(stock: StockData, time_remaining_ratio: float = 1.0, role_id: String = PlayerRole.NONE) -> int:
	var premium_rate := clampf(stock.volatility * 0.5 + 0.02, 0.03, 0.07)
	var time_factor := 0.25 + 0.75 * sqrt(clampf(time_remaining_ratio, 0.0, 1.0))
	var role_factor := float(PlayerRole.value(role_id, "option_premium_multiplier"))
	return maxi(100, roundi(float(stock.current_price_pence) * premium_rate * time_factor * role_factor))

func _buy_option(state: GameState, symbol: String, quantity: int, option_type: String, time_remaining_ratio: float) -> Dictionary:
	var stock := state.get_stock(symbol)
	if state.phase != GameState.Phase.TRADING:
		return _option_result(state, false, "%s options are only available during trading." % option_type, symbol, option_type, 0, 0, 0, quantity)
	if stock == null:
		return _option_result(state, false, "Unknown stock.", symbol, option_type, 0, 0, 0, quantity)
	if quantity <= 0:
		return _option_result(state, false, "Quantity must be positive.", symbol, option_type, 0, 0, 0, quantity)
	var premium_per_contract := option_premium_pence(stock, time_remaining_ratio, state.role)
	var total_premium := premium_per_contract * quantity
	if total_premium > state.cash_pence:
		return _option_result(state, false, "Not enough cash for %s." % option_type, symbol, option_type, 0, premium_per_contract, 0, quantity)
	state.cash_pence -= total_premium
	state.add_option_position(OptionContract.new(option_type, symbol, stock.current_price_pence, total_premium, quantity, state.current_day))
	return _option_result(state, true, "Bought %s on %s at %s strike for %s." % [option_type, symbol, _format_pence(stock.current_price_pence), _format_pence(total_premium)], symbol, option_type, total_premium, premium_per_contract, stock.current_price_pence, quantity)

func liquidate_all(state: GameState) -> int:
	var liquidated_value := 0
	for stock in state.stocks:
		var quantity := int(state.holdings[stock.symbol])
		if quantity <= 0:
			continue
		liquidated_value += stock.current_price_pence * quantity
		state.apply_sell_shares(stock.symbol, quantity)
	return liquidated_value

func _option_result(state: GameState, success: bool, message: String, symbol: String, option_type: String, premium_pence: int, premium_per_contract: int, strike_pence: int, quantity: int) -> Dictionary:
	return {
		"success": success,
		"message": message,
		"action": "option",
		"option_type": option_type,
		"symbol": symbol,
		"quantity": quantity,
		"premium_pence": premium_pence,
		"premium_per_contract_pence": premium_per_contract,
		"strike_price_pence": strike_pence,
		"cash_after_action": state.cash_pence,
	}

func _format_pence(value: int) -> String:
	return "£%d.%02d" % [value / 100, value % 100]

func _trade_result(
	state: GameState,
	success: bool,
	message: String,
	symbol: String,
	quantity: int,
	stock: StockData
) -> Dictionary:
	var price := 0 if stock == null else stock.current_price_pence
	var shares := 0 if not state.holdings.has(symbol) else int(state.holdings[symbol])
	return {
		"success": success,
		"message": message,
		"action": "trade",
		"symbol": symbol,
		"quantity": quantity,
		"execution_price_pence": price,
		"cash_after_trade": state.cash_pence,
		"shares_after_trade": shares,
	}

func _pump_result(
	state: GameState,
	success: bool,
	message: String,
	symbol: String,
	cost_pence: int,
	pump_active: bool,
	live_boost: float,
	correction_risk: bool,
) -> Dictionary:
	return {
		"success": success,
		"message": message,
		"action": "pump",
		"symbol": symbol,
		"cost_pence": cost_pence,
		"cash_after_action": state.cash_pence,
		"live_boost": live_boost,
		"correction_risk": correction_risk,
		"pump_active": pump_active,
	}

func _manipulation_result(
	state: GameState,
	success: bool,
	message: String,
	symbol: String,
	action: String,
	cost_pence: int = 0,
	pressure: float = 0.0,
	direction: int = 0
) -> Dictionary:
	return {
		"success": success,
		"message": message,
		"action": action,
		"symbol": symbol,
		"cost_pence": cost_pence,
		"cash_after_action": state.cash_pence,
		"live_pressure": pressure,
		"direction": direction,
		"uncertain": action == "fake_news" or action == "sabotage",
	}