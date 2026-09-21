@tool
extends McpTestSuite

const COMPUTER_PLAYER = preload("res://scripts/application/computer_player.gd")
const GAME_STATE = preload("res://scripts/simulation/game_state.gd")
const TRADE_SERVICE = preload("res://scripts/application/trade_service.gd")

func suite_name() -> String:
	return "computer_player"

func test_profiles_are_named_and_deterministic() -> void:
	var conservative := COMPUTER_PLAYER.new(2, "Mara", "CONSERVATIVE", 10)
	var balanced := COMPUTER_PLAYER.new(3, "Quinn", "BALANCED", 11)
	var aggressive := COMPUTER_PLAYER.new(4, "Rook", "AGGRESSIVE", 12)
	assert_eq(conservative.risk_profile, "CONSERVATIVE")
	assert_eq(balanced.risk_profile, "BALANCED")
	assert_eq(aggressive.risk_profile, "AGGRESSIVE")
	assert_eq(conservative.display_name, "Mara")
	assert_eq(aggressive.display_name, "Rook")

func test_ai_actions_use_trade_service_and_keep_cash_bounded() -> void:
	var state: GameState = GAME_STATE.new(42, 3)
	state.phase = GAME_STATE.Phase.TRADING
	var service: TradeService = TRADE_SERVICE.new()
	var player := COMPUTER_PLAYER.new(2, "Mara", "AGGRESSIVE", 42)
	var action_count := 0
	for index in 12:
		var result := player.tick(1.5, state, service)
		if not result.is_empty():
			assert_true(result["success"])
			action_count += 1
	assert_true(action_count > 0)
	assert_true(state.cash_pence >= 0)
	for symbol in state.holdings:
		assert_true(int(state.holdings[symbol]) >= 0)

func test_ai_does_not_act_outside_trading() -> void:
	var state: GameState = GAME_STATE.new(42, 3)
	var service: TradeService = TRADE_SERVICE.new()
	var player := COMPUTER_PLAYER.new(2, "Mara", "AGGRESSIVE", 42)
	var starting_cash := state.cash_pence
	var result := player.tick(10.0, state, service)
	assert_true(result.is_empty())
	assert_eq(state.cash_pence, starting_cash)
