@tool
extends McpTestSuite

const OPTION_CONTRACT = preload("res://scripts/simulation/option_contract.gd")
const GAME_STATE = preload("res://scripts/simulation/game_state.gd")
const TRADE_SERVICE = preload("res://scripts/application/trade_service.gd")
const TRADING_SESSION = preload("res://scripts/application/trading_session.gd")

func suite_name() -> String:
	return "option_contract"

func test_call_and_put_pay_intrinsic_value() -> void:
	var call := OPTION_CONTRACT.new(OPTION_CONTRACT.CALL, "AUR", 5_000, 400, 2, 1)
	var put := OPTION_CONTRACT.new(OPTION_CONTRACT.PUT, "AUR", 5_000, 400, 2, 1)
	assert_eq(call.payoff_pence(6_000), 2_000)
	assert_eq(call.payoff_pence(4_000), 0)
	assert_eq(put.payoff_pence(4_000), 2_000)
	assert_eq(put.payoff_pence(6_000), 0)

func test_option_purchase_charges_volatility_based_premium() -> void:
	var state: GameState = GAME_STATE.new(42, 2)
	state.phase = GAME_STATE.Phase.TRADING
	var service: TradeService = TRADE_SERVICE.new()
	var result := service.buy_call(state, "AUR")
	assert_true(result["success"])
	assert_eq(result["strike_price_pence"], 5_000)
	assert_eq(result["premium_pence"], 313)
	assert_eq(state.cash_pence, state.starting_cash_pence - 313)
	assert_eq(state.option_positions.size(), 1)

func test_late_option_premium_reflects_time_remaining() -> void:
	var state: GameState = GAME_STATE.new(42, 2)
	var stock: StockData = state.get_stock("AUR")
	var opening_premium := TRADE_SERVICE.option_premium_pence(stock, 1.0)
	var late_premium := TRADE_SERVICE.option_premium_pence(stock, 0.0)
	assert_eq(opening_premium, 313)
	assert_true(late_premium < opening_premium)
	assert_eq(late_premium, 100)

func test_option_purchase_requires_trading_and_cash() -> void:
	var state: GameState = GAME_STATE.new(42, 2)
	var service: TradeService = TRADE_SERVICE.new()
	assert_false(service.buy_put(state, "AUR")["success"])
	state.phase = GAME_STATE.Phase.TRADING
	state.cash_pence = 300
	assert_false(service.buy_put(state, "AUR")["success"])
	assert_eq(state.option_positions.size(), 0)

func test_session_settles_call_before_round_completion() -> void:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.start_run(55, 1, 1, false)
	assert_true(session.start_trading_round())
	var purchase := session.buy_call("AUR")
	assert_true(purchase["success"])
	var cash_after_purchase := session.game_state.cash_pence
	session.game_state.get_stock("AUR").current_price_pence = 6_000
	var settlements := session._settle_options(session.game_state)
	assert_eq(settlements[0]["payout_pence"], 1_000)
	assert_eq(session.game_state.cash_pence, cash_after_purchase + 1_000)
	assert_eq(session.game_state.option_positions.size(), 0)
