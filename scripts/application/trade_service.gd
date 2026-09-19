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