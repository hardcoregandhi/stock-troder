@tool
extends McpTestSuite

const GAME_STATE = preload("res://scripts/simulation/game_state.gd")
const TRADE_SERVICE = preload("res://scripts/application/trade_service.gd")

func suite_name() -> String:
	return "game_state_trade_service"

func test_new_state_has_starting_cash_and_catalog() -> void:
	var state: GameState = GAME_STATE.new(123, 3)
	assert_eq(state.cash_pence, 1_000_000)
	assert_eq(state.starting_cash_pence, 1_000_000)
	assert_eq(state.stocks.size(), 6)
	assert_eq(state.current_day, 1)
	assert_eq(state.total_days, 3)
	for stock in state.stocks:
		assert_eq(state.holdings[stock.symbol], 0)

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
