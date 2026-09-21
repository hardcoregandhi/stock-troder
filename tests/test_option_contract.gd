@tool
extends McpTestSuite

const OPTION_CONTRACT = preload("res://scripts/simulation/option_contract.gd")
const GAME_STATE = preload("res://scripts/simulation/game_state.gd")
const TRADE_SERVICE = preload("res://scripts/application/trade_service.gd")

func suite_name() -> String:
	return "option_contract"

func test_call_and_put_pay_intrinsic_value() -> void:
	var call := OPTION_CONTRACT.new(OPTION_CONTRACT.CALL, "AUR", 5_000, 400, 2, 1)
	var put := OPTION_CONTRACT.new(OPTION_CONTRACT.PUT, "AUR", 5_000, 400, 2, 1)
	assert_eq(call.payoff_pence(6_000), 2_000)
	assert_eq(call.payoff_pence(4_000), 0)
	assert_eq(put.payoff_pence(4_000), 2_000)
	assert_eq(put.payoff_pence(6_000), 0)

func test_option_purchase_charges_eight_percent_premium() -> void:
	var state: GameState = GAME_STATE.new(42, 2)
	state.phase = GAME_STATE.Phase.TRADING
	var service: TradeService = TRADE_SERVICE.new()
	var result := service.buy_call(state, "AUR")
	assert_true(result["success"])
	assert_eq(result["strike_price_pence"], 5_000)
	assert_eq(result["premium_pence"], 400)
	assert_eq(state.cash_pence, state.starting_cash_pence - 400)
	assert_eq(state.option_positions.size(), 1)

func test_option_purchase_requires_trading_and_cash() -> void:
	var state: GameState = GAME_STATE.new(42, 2)
	var service: TradeService = TRADE_SERVICE.new()
	assert_false(service.buy_put(state, "AUR")["success"])
	state.phase = GAME_STATE.Phase.TRADING
	state.cash_pence = 399
	assert_false(service.buy_put(state, "AUR")["success"])
	assert_eq(state.option_positions.size(), 0)
