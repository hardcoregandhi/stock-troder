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