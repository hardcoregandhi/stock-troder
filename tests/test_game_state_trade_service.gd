@tool
extends McpTestSuite

const GAME_STATE = preload("res://scripts/simulation/game_state.gd")
const TRADE_SERVICE = preload("res://scripts/application/trade_service.gd")

func suite_name() -> String:
	return "game_state_trade_service"

func test_new_state_has_starting_cash_and_catalog() -> void:
	var state: GameState = GAME_STATE.new(123, 3)
	assert_eq(state.cash_pence, 100_000)
	assert_eq(state.starting_cash_pence, 100_000)
	assert_eq(state.stocks.size(), 6)
	assert_eq(state.current_day, 1)
	assert_eq(state.total_days, 3)
	for stock in state.stocks:
		assert_eq(state.holdings[stock.symbol], 0)

func test_default_catalog_uses_large_opening_price_scale() -> void:
	var state: GameState = GameState.create_default(123, 3)
	var expected_prices := [5_000, 10_000, 25_000, 50_000, 75_000, 100_000]
	var expected_symbols := ["AUR", "BRK", "CYN", "DSK", "EGF", "FRB"]
	for index in state.stocks.size():
		assert_eq(state.stocks[index].symbol, expected_symbols[index])
		assert_eq(state.stocks[index].current_price_pence, expected_prices[index])

func test_default_catalog_uses_e_and_f_names_for_fifth_and_sixth_stocks() -> void:
	var state: GameState = GAME_STATE.create_default(123, 3)
	assert_true(state.stocks[4].company_name.begins_with("E"))
	assert_true(state.stocks[5].company_name.begins_with("F"))
	assert_eq(state.stocks[4].symbol, "EGF")
	assert_eq(state.stocks[5].symbol, "FRB")

func test_stock_count_preserves_default_order_and_bounds() -> void:
	var short_state: GameState = GAME_STATE.create_default(123, 3, 3)
	assert_eq(short_state.stocks.size(), 3)
	assert_eq(short_state.stocks[0].symbol, "AUR")
	assert_eq(short_state.stocks[2].symbol, "CYN")
	var minimum_state: GameState = GAME_STATE.create_default(123, 3, 0)
	var maximum_state: GameState = GAME_STATE.create_default(123, 3, 99)
	assert_eq(minimum_state.stocks.size(), GameState.MIN_STOCK_COUNT)
	assert_eq(maximum_state.stocks.size(), GameState.MAX_STOCK_COUNT)

func test_valid_buy_and_sell_update_cash_and_holdings() -> void:
	var state: GameState = GAME_STATE.new(123, 3)
	state.phase = GAME_STATE.Phase.TRADING
	var stock = state.get_stock("AUR")
	var service: TradeService = TRADE_SERVICE.new()
	var starting_cash: int = state.cash_pence
	var buy_result: Dictionary = service.buy(state, "AUR", 2)
	assert_true(buy_result["success"])
	assert_eq(state.holdings["AUR"], 2)
	assert_eq(state.cash_pence, starting_cash - stock.current_price_pence * 2)
	var sell_result: Dictionary = service.sell(state, "AUR", 1)
	assert_true(sell_result["success"])
	assert_eq(state.holdings["AUR"], 1)

func test_invalid_trades_do_not_change_state() -> void:
	var state: GameState = GAME_STATE.new(123, 3)
	state.phase = GAME_STATE.Phase.TRADING
	var service: TradeService = TRADE_SERVICE.new()
	var starting_cash: int = state.cash_pence
	var overspend: Dictionary = service.buy(state, "AUR", 10_000)
	assert_false(overspend["success"])
	assert_eq(state.cash_pence, starting_cash)
	assert_eq(state.holdings["AUR"], 0)
	var oversell: Dictionary = service.sell(state, "AUR", 1)
	assert_false(oversell["success"])
	assert_eq(state.holdings["AUR"], 0)
	state.phase = GAME_STATE.Phase.DEBRIEF
	var outside_phase: Dictionary = service.buy(state, "AUR", 1)
	assert_false(outside_phase["success"])
	assert_eq(state.cash_pence, starting_cash)

func test_pump_requires_trading_phase_and_costs_fixed_cash() -> void:
	var state: GameState = GAME_STATE.new(123, 3)
	var service: TradeService = TRADE_SERVICE.new()
	var outside_phase: Dictionary = service.pump(state, "AUR")
	assert_false(outside_phase["success"])
	assert_eq(state.cash_pence, state.starting_cash_pence)
	state.phase = GAME_STATE.Phase.TRADING
	var starting_cash := state.cash_pence
	var result: Dictionary = service.pump(state, "AUR")
	assert_true(result["success"])
	assert_eq(result["cost_pence"], GameState.PUMP_COST_PENCE)
	assert_eq(state.cash_pence, starting_cash - GameState.PUMP_COST_PENCE)
	assert_true(result["correction_risk"])
	assert_true(result["pump_active"])
	assert_eq(result["live_boost"], 0.04)
	assert_true(result["message"].contains("+4.0% live path"))

func test_pump_is_once_per_stock_and_never_makes_cash_negative() -> void:
	var state: GameState = GAME_STATE.new(123, 3)
	state.phase = GAME_STATE.Phase.TRADING
	var service: TradeService = TRADE_SERVICE.new()
	var first: Dictionary = service.pump(state, "AUR")
	var second: Dictionary = service.pump(state, "AUR")
	assert_true(first["success"])
	assert_false(second["success"])
	assert_eq(state.cash_pence, state.starting_cash_pence - GameState.PUMP_COST_PENCE)
	assert_true(state.cash_pence >= 0)

func test_sabotage_costs_fifty_pounds_is_trading_only_and_once_per_stock() -> void:
	var state: GameState = GAME_STATE.new(123, 3)
	var service: TradeService = TRADE_SERVICE.new()
	assert_false(service.sabotage(state, "AUR")["success"])
	state.phase = GameState.Phase.TRADING
	var result := service.sabotage(state, "AUR")
	assert_true(result["success"])
	assert_eq(result["cost_pence"], 5_000)
	assert_eq(state.cash_pence, 95_000)
	assert_true(state.has_sabotaged("AUR"))
	assert_false(service.sabotage(state, "AUR")["success"])

func test_fake_news_costs_seventy_five_pounds_preserves_direction_and_is_once_per_stock() -> void:
	var state: GameState = GAME_STATE.new(123, 3)
	var service: TradeService = TRADE_SERVICE.new()
	state.phase = GameState.Phase.TRADING
	var result := service.plant_fake_news(state, "AUR", -1)
	assert_true(result["success"])
	assert_eq(result["cost_pence"], 7_500)
	assert_eq(state.cash_pence, 92_500)
	assert_eq(state.get_stock("AUR").fake_news_direction, -1)
	assert_eq(state.get_stock("AUR").current_news, "Prototype demonstration draws attention")
	assert_false(service.plant_fake_news(state, "AUR", 1)["success"])

func test_fake_news_rejects_brief_without_charging_cash() -> void:
	var state: GameState = GAME_STATE.new(123, 3)
	var service: TradeService = TRADE_SERVICE.new()
	var starting_cash := state.cash_pence
	var result := service.plant_fake_news(state, "AUR", 1)
	assert_false(result["success"])
	assert_true(result["message"].contains("trading"))
	assert_eq(state.cash_pence, starting_cash)
	assert_false(state.has_planted_fake_news("AUR"))

func test_manipulation_usage_resets_between_rounds() -> void:
	var state: GameState = GAME_STATE.new(123, 3)
	state.phase = GameState.Phase.TRADING
	var service: TradeService = TRADE_SERVICE.new()
	assert_true(service.sabotage(state, "AUR")["success"])
	assert_true(service.plant_fake_news(state, "BRK", 1)["success"])
	state.reset_round_manipulations()
	assert_false(state.has_sabotaged("AUR"))
	assert_false(state.has_planted_fake_news("BRK"))
	assert_false(state.get_stock("AUR").sabotage_active)
	assert_false(state.get_stock("BRK").fake_news_active)
