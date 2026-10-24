@tool
extends McpTestSuite

const GAME_STATE = preload("res://scripts/simulation/game_state.gd")
const MARKET_SIMULATOR = preload("res://scripts/simulation/market_simulator.gd")
const TRADE_SERVICE = preload("res://scripts/application/trade_service.gd")

func suite_name() -> String:
	return "market_simulator"

func test_prepare_and_live_samples_use_trading_contract() -> void:
	var state = GAME_STATE.new(2026, 2)
	var simulator = MARKET_SIMULATOR.new(2026)
	var projections := simulator.prepare_day(state)
	assert_eq(state.phase, GAME_STATE.Phase.BRIEF)
	assert_eq(projections.size(), state.stocks.size())
	assert_true(simulator.start_trading(state))
	assert_eq(state.phase, GAME_STATE.Phase.TRADING)
	var initial_history_size := state.get_stock("AUR").live_price_history_pence.size()
	var updates := simulator.update_live_prices(state, 0.5)
	assert_eq(updates.size(), state.stocks.size())
	assert_gt(state.get_stock("AUR").live_price_history_pence.size(), initial_history_size)
	for stock in state.stocks:
		assert_true(stock.current_price_pence >= MARKET_SIMULATOR.PRICE_FLOOR_PENCE)

func test_live_noise_is_bounded_and_more_visible_during_round() -> void:
	var state = GAME_STATE.new(2026, 2)
	var simulator = MARKET_SIMULATOR.new(2026)
	simulator.prepare_day(state)
	simulator.start_trading(state)
	var opening_prices: Dictionary = {}
	for stock in state.stocks:
		opening_prices[stock.symbol] = stock.round_open_price_pence
	simulator.update_live_prices(state, 0.5)
	for stock in state.stocks:
		var projected_path := lerpf(float(stock.round_open_price_pence), float(stock.projected_price_pence), 0.5)
		var relative_noise := absf(float(stock.current_price_pence) / projected_path - 1.0)
		assert_true(relative_noise <= MARKET_SIMULATOR.MAX_LIVE_NOISE + 0.001)
	simulator.update_live_prices(state, 1.0)
	var changed_stock_count := 0
	for stock in state.stocks:
		if stock.current_price_pence != int(opening_prices[stock.symbol]):
			changed_stock_count += 1
	assert_gt(changed_stock_count, 0)

func test_resolution_archives_full_round_price_path() -> void:
	var state = GAME_STATE.new(303, 2)
	var simulator = MARKET_SIMULATOR.new(303)
	simulator.prepare_day(state)
	simulator.start_trading(state)
	simulator.update_live_prices(state, 0.5)
	var stock = state.get_stock("AUR")
	var live_sample_count: int = stock.live_price_history_pence.size()
	simulator.resolve_day(state)
	assert_eq(stock.round_history_pence.size(), 1)
	assert_eq(stock.round_history_pence[0].size(), live_sample_count + 1)
	assert_eq(stock.round_history_pence[0][0], stock.round_open_price_pence)
	assert_eq(stock.round_history_pence[0][-1], stock.current_price_pence)

func test_recent_history_adds_bounded_weight_to_projection() -> void:
	var history_state = GAME_STATE.new(304, 2)
	var baseline_state = GAME_STATE.new(304, 2)
	var history_simulator = MARKET_SIMULATOR.new(304)
	var baseline_simulator = MARKET_SIMULATOR.new(304)
	var history_stock = history_state.get_stock("AUR")
	history_stock.price_history_pence.append(6_000)
	var history_projections := history_simulator.prepare_day(history_state)
	var baseline_projections := baseline_simulator.prepare_day(baseline_state)
	var history_change := float(history_projections[0]["projection_change"])
	var baseline_change := float(baseline_projections[0]["projection_change"])
	assert_gt(history_change, baseline_change)
	assert_true(history_change - baseline_change <= MARKET_SIMULATOR.MAX_HISTORY_INFLUENCE + 0.000001)

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
	simulator.start_trading(state)
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
	first_simulator.start_trading(first_state)
	second_simulator.start_trading(second_state)
	first_simulator.update_live_prices(first_state, 0.5)
	second_simulator.update_live_prices(second_state, 0.5)
	assert_eq(_prices(first_state), _prices(second_state))
	assert_eq(first_simulator.resolve_day(first_state), second_simulator.resolve_day(second_state))

func test_same_seed_matches_with_configured_multi_stock_catalog() -> void:
	var first_state = GAME_STATE.create_default(404, 2, 4)
	var second_state = GAME_STATE.create_default(404, 2, 4)
	var first_simulator = MARKET_SIMULATOR.new(404)
	var second_simulator = MARKET_SIMULATOR.new(404)
	assert_eq(first_state.stocks.size(), 4)
	assert_eq(first_state.stocks[3].symbol, "DSK")
	assert_eq(first_simulator.prepare_day(first_state), second_simulator.prepare_day(second_state))
	first_simulator.start_trading(first_state)
	second_simulator.start_trading(second_state)
	first_simulator.update_live_prices(first_state, 0.5)
	second_simulator.update_live_prices(second_state, 0.5)
	assert_eq(_prices(first_state), _prices(second_state))
	assert_eq(first_simulator.resolve_day(first_state), second_simulator.resolve_day(second_state))
	first_simulator.start_trading(first_state)
	second_simulator.start_trading(second_state)

func test_pump_changes_live_price_path() -> void:
	var normal_state = GAME_STATE.new(515, 2)
	var pumped_state = GAME_STATE.new(515, 2)
	var normal_simulator = MARKET_SIMULATOR.new(515)
	var pumped_simulator = MARKET_SIMULATOR.new(515)
	normal_simulator.prepare_day(normal_state)
	pumped_simulator.prepare_day(pumped_state)
	normal_simulator.start_trading(normal_state)
	pumped_simulator.start_trading(pumped_state)
	var pump_result := TRADE_SERVICE.new().pump(pumped_state, "AUR")
	assert_true(pump_result["success"])
	normal_simulator.update_live_prices(normal_state, 0.75)
	pumped_simulator.update_live_prices(pumped_state, 0.75)
	normal_simulator.start_trading(normal_state)
	pumped_simulator.start_trading(pumped_state)
	assert_gt(pumped_state.get_stock("AUR").current_price_pence, normal_state.get_stock("AUR").current_price_pence)

func test_pumped_resolution_is_seeded_and_reports_correction() -> void:
	var first_state = GAME_STATE.new(616, 2)
	var second_state = GAME_STATE.new(616, 2)
	var first_simulator = MARKET_SIMULATOR.new(616)
	var second_simulator = MARKET_SIMULATOR.new(616)
	first_simulator.prepare_day(first_state)
	second_simulator.prepare_day(second_state)
	first_simulator.start_trading(first_state)
	second_simulator.start_trading(second_state)
	assert_true(TRADE_SERVICE.new().pump(first_state, "AUR")["success"])
	assert_true(TRADE_SERVICE.new().pump(second_state, "AUR")["success"])
	var first_resolutions := first_simulator.resolve_day(first_state)
	var second_resolutions := second_simulator.resolve_day(second_state)
	assert_eq(first_resolutions, second_resolutions)
	var aur_resolution: Dictionary = first_resolutions[0]
	assert_true(aur_resolution.has("pump_correction"))
	assert_true(aur_resolution["pump_used"])

func test_pump_changes_resolution_path_under_same_seed() -> void:
	var normal_state = GAME_STATE.new(717, 2)
	var pumped_state = GAME_STATE.new(717, 2)
	var normal_simulator = MARKET_SIMULATOR.new(717)
	var pumped_simulator = MARKET_SIMULATOR.new(717)
	normal_simulator.prepare_day(normal_state)
	pumped_simulator.prepare_day(pumped_state)
	normal_simulator.start_trading(normal_state)
	pumped_simulator.start_trading(pumped_state)
	assert_true(TRADE_SERVICE.new().pump(pumped_state, "AUR")["success"])
	var normal_resolution := normal_simulator.resolve_day(normal_state)[0]
	var pumped_resolution := pumped_simulator.resolve_day(pumped_state)[0]
	assert_true(pumped_resolution["pump_used"])
	assert_gt(float(pumped_resolution["pump_correction_percent"]), 0.0)
	assert_ne(pumped_resolution["closing_price_pence"], normal_resolution["closing_price_pence"])

func test_sabotage_changes_live_path_and_seeded_resolution() -> void:
	var first_state = GAME_STATE.new(818, 2)
	var second_state = GAME_STATE.new(818, 2)
	var first_simulator = MARKET_SIMULATOR.new(818)
	var second_simulator = MARKET_SIMULATOR.new(818)
	first_simulator.prepare_day(first_state)
	second_simulator.prepare_day(second_state)
	first_simulator.start_trading(first_state)
	second_simulator.start_trading(second_state)
	assert_true(TRADE_SERVICE.new().sabotage(first_state, "AUR")["success"])
	assert_true(TRADE_SERVICE.new().sabotage(second_state, "AUR")["success"])
	first_simulator.update_live_prices(first_state, 0.75)
	second_simulator.update_live_prices(second_state, 0.75)
	assert_eq(_prices(first_state), _prices(second_state))
	var first_resolution := first_simulator.resolve_day(first_state)[0]
	var second_resolution := second_simulator.resolve_day(second_state)[0]
	assert_eq(first_resolution, second_resolution)
	assert_true(first_resolution["sabotage_used"])
	assert_gt(float(first_resolution["sabotage_correction_percent"]), 0.0)

func test_fake_news_direction_changes_projection_and_reports_seeded_outcome() -> void:
	var first_state = GAME_STATE.new(919, 2)
	var second_state = GAME_STATE.new(919, 2)
	var first_simulator = MARKET_SIMULATOR.new(919)
	var second_simulator = MARKET_SIMULATOR.new(919)
	first_simulator.prepare_day(first_state)
	second_simulator.prepare_day(second_state)
	first_simulator.start_trading(first_state)
	second_simulator.start_trading(second_state)
	var first_stock: StockData = first_state.get_stock("AUR")
	var before_projection := first_stock.projection_change
	assert_true(TRADE_SERVICE.new().plant_fake_news(first_state, "AUR", 1)["success"])
	assert_true(TRADE_SERVICE.new().plant_fake_news(second_state, "AUR", 1)["success"])
	assert_gt(first_stock.projection_change, before_projection)
	assert_eq(first_stock.current_news, first_stock.planted_headline(1))
	var first_resolution := first_simulator.resolve_day(first_state)[0]
	var second_resolution := second_simulator.resolve_day(second_state)[0]
	assert_eq(first_resolution, second_resolution)
	assert_true(first_resolution["fake_news_used"])
	assert_true(["worked", "failed", "backfired"].has(first_resolution["fake_news_outcome"]))

func _prices(state) -> Array[int]:
	var prices: Array[int] = []
	for stock in state.stocks:
		prices.append(stock.current_price_pence)
	return prices
