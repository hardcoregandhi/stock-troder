@tool
extends McpTestSuite

const GAME_STATE = preload("res://scripts/simulation/game_state.gd")
const MARKET_SIMULATOR = preload("res://scripts/simulation/market_simulator.gd")

func suite_name() -> String:
	return "market_simulator"

func test_prepare_and_live_samples_use_trading_contract() -> void:
	var state = GAME_STATE.new(2026, 2)
	var simulator = MARKET_SIMULATOR.new(2026)
	var projections := simulator.prepare_day(state)
	assert_eq(state.phase, GAME_STATE.Phase.TRADING)
	assert_eq(projections.size(), state.stocks.size())
	var initial_history_size := state.get_stock("AUR").live_price_history_pence.size()
	var updates := simulator.update_live_prices(state, 0.5)
	assert_eq(updates.size(), state.stocks.size())
	assert_gt(state.get_stock("AUR").live_price_history_pence.size(), initial_history_size)
	for stock in state.stocks:
		assert_true(stock.current_price_pence >= MARKET_SIMULATOR.PRICE_FLOOR_PENCE)

func test_resolved_prices_respect_price_floor_and_append_history() -> void:
	var state = GAME_STATE.new(77, 1)
	var simulator = MARKET_SIMULATOR.new(77)
	var stock = state.get_stock("AUR")
	stock.current_price_pence = MARKET_SIMULATOR.PRICE_FLOOR_PENCE
	stock.set_projection(-5.0, -5.0, -4.0, "Test floor", 0.0)
	state.phase = GAME_STATE.Phase.TRADING
	var history_sizes: Dictionary = {}
	for item in state.stocks:
		history_sizes[item.symbol] = item.price_history_pence.size()
	simulator.resolve_day(state)
	assert_eq(state.phase, GAME_STATE.Phase.COMPLETE)
	for item in state.stocks:
		assert_true(item.current_price_pence >= MARKET_SIMULATOR.PRICE_FLOOR_PENCE)
		assert_eq(item.price_history_pence.size(), int(history_sizes[item.symbol]) + 1)

func test_resolution_reports_open_close_percentage_and_news() -> void:
	var state = GAME_STATE.new(88, 2)
	var simulator = MARKET_SIMULATOR.new(88)
	simulator.prepare_day(state)
	var opening_prices: Dictionary = {}
	for stock in state.stocks:
		opening_prices[stock.symbol] = stock.round_open_price_pence
	var resolutions := simulator.resolve_day(state)
	for resolution in resolutions:
		var opening_price := int(resolution["opening_price_pence"])
		var closing_price := int(resolution["closing_price_pence"])
		assert_eq(opening_price, int(opening_prices[resolution["symbol"]]))
		assert_eq(resolution["percentage_change"], float(closing_price - opening_price) / float(opening_price))
		assert_false(str(resolution["news"]).is_empty())

func test_same_seed_matches_projections_live_samples_and_resolution() -> void:
	var first_state = GAME_STATE.new(404, 2)
	var second_state = GAME_STATE.new(404, 2)
	var first_simulator = MARKET_SIMULATOR.new(404)
	var second_simulator = MARKET_SIMULATOR.new(404)
	var first_projections := first_simulator.prepare_day(first_state)
	var second_projections := second_simulator.prepare_day(second_state)
	assert_eq(first_projections, second_projections)
	first_simulator.update_live_prices(first_state, 0.5)
	second_simulator.update_live_prices(second_state, 0.5)
	assert_eq(_prices(first_state), _prices(second_state))
	assert_eq(first_simulator.resolve_day(first_state), second_simulator.resolve_day(second_state))

func _prices(state) -> Array[int]:
	var prices: Array[int] = []
	for stock in state.stocks:
		prices.append(stock.current_price_pence)
	return prices
