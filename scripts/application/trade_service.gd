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
	if state.has_pumped(symbol):
		return _pump_result(state, false, "Pump already used for this stock this round.", symbol, 0, false, 0.0, false)
	if state.cash_pence < GameState.PUMP_COST_PENCE:
		return _pump_result(state, false, "Not enough cash for Pump.", symbol, 0, false, 0.0, false)
	state.cash_pence -= GameState.PUMP_COST_PENCE
	state.mark_pumped(symbol)
	stock.activate_pump(0.04)
	return _pump_result(state, true, "Pump active on %s: +4.0%% live path. £25.00 spent; correction risk at resolution." % symbol, symbol, GameState.PUMP_COST_PENCE, true, stock.pump_live_boost, true)

func sabotage(state: GameState, symbol: String) -> Dictionary:
	var stock: StockData = state.get_stock(symbol)
	if state.phase != GameState.Phase.TRADING:
		return _manipulation_result(state, false, "Sabotage is only available during trading.", symbol, "sabotage")
	if stock == null:
		return _manipulation_result(state, false, "Unknown stock.", symbol, "sabotage")
	if state.has_sabotaged(symbol):
		return _manipulation_result(state, false, "Sabotage already used for this stock this round.", symbol, "sabotage")
	if state.cash_pence < GameState.SABOTAGE_COST_PENCE:
		return _manipulation_result(state, false, "Not enough cash for Sabotage.", symbol, "sabotage")
	state.cash_pence -= GameState.SABOTAGE_COST_PENCE
	state.mark_sabotaged(symbol)
	stock.activate_sabotage(-0.04)
	return _manipulation_result(state, true, "Sabotage active on %s: negative live pressure and resolution risk. £50.00 spent." % symbol, symbol, "sabotage", GameState.SABOTAGE_COST_PENCE, stock.sabotage_live_pressure)

func plant_fake_news(state: GameState, symbol: String, direction: int) -> Dictionary:
	var stock: StockData = state.get_stock(symbol)
	var normalized_direction := clampi(direction, -1, 1)
	if state.phase != GameState.Phase.TRADING:
		return _manipulation_result(state, false, "Fake News is only available during trading.", symbol, "fake_news", normalized_direction)
	if stock == null:
		return _manipulation_result(state, false, "Unknown stock.", symbol, "fake_news", normalized_direction)
	if normalized_direction == 0:
		return _manipulation_result(state, false, "Fake News needs a positive or negative direction.", symbol, "fake_news", normalized_direction)
	if state.has_planted_fake_news(symbol):
		return _manipulation_result(state, false, "Fake News already used for this stock this round.", symbol, "fake_news", normalized_direction)
	if state.cash_pence < GameState.FAKE_NEWS_COST_PENCE:
		return _manipulation_result(state, false, "Not enough cash for Fake News.", symbol, "fake_news", normalized_direction)
	state.cash_pence -= GameState.FAKE_NEWS_COST_PENCE
	state.mark_fake_news_planted(symbol)
	var projection_weight := 0.03 * float(normalized_direction)
	stock.projection_change += projection_weight
	stock.projection_low += projection_weight
	stock.projection_high += projection_weight
	stock.projected_price_pence = maxi(100, roundi(float(stock.current_price_pence) * (1.0 + stock.projection_change)))
	stock.activate_fake_news(normalized_direction, projection_weight, stock.current_news)
	return _manipulation_result(state, true, "Player-planted fake news posted for %s: %s direction. £75.00 spent; outcome is uncertain." % [symbol, "positive" if normalized_direction > 0 else "negative"], symbol, "fake_news", GameState.FAKE_NEWS_COST_PENCE, projection_weight, normalized_direction)

func liquidate_all(state: GameState) -> int:
	var liquidated_value := 0
	for stock in state.stocks:
		var quantity := int(state.holdings[stock.symbol])
		if quantity <= 0:
			continue
		liquidated_value += stock.current_price_pence * quantity
		state.apply_sell_shares(stock.symbol, quantity)
	return liquidated_value

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
		"action": "pump",
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