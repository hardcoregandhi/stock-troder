@tool
extends McpTestSuite

const TRADING_SESSION = preload("res://scripts/application/trading_session.gd")
const GAME_STATE = preload("res://scripts/simulation/game_state.gd")

func suite_name() -> String:
	return "network_match"

func test_host_keeps_separate_portfolios_for_each_peer() -> void:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.network_mode = true
	session.network_is_host = true
	session.network_local_player_id = 1
	session.game_state = GAME_STATE.new(42, 2)
	session.market_simulator = MarketSimulator.new(42)
	session.trade_service = TradeService.new()
	session.game_state.phase = GAME_STATE.Phase.TRADING
	var remote_state: GameState = GAME_STATE.new(42, 2)
	remote_state.stocks = session.game_state.stocks
	remote_state.phase = GAME_STATE.Phase.TRADING
	session.network_player_states = {1: session.game_state, 2: remote_state}
	var result := session.trade_service.buy(remote_state, "AUR", 2)
	assert_true(result["success"])
	assert_eq(session.game_state.holdings["AUR"], 0)
	assert_eq(remote_state.holdings["AUR"], 2)

func test_host_validates_remote_intent_against_remote_state() -> void:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.network_mode = true
	session.network_is_host = true
	session.network_local_player_id = 2
	session.game_state = GAME_STATE.new(42, 2)
	session.market_simulator = MarketSimulator.new(42)
	session.trade_service = TradeService.new()
	session.game_state.phase = GAME_STATE.Phase.TRADING
	var remote_state: GameState = GAME_STATE.new(42, 2)
	remote_state.stocks = session.game_state.stocks
	remote_state.phase = GAME_STATE.Phase.TRADING
	session.network_player_states = {1: session.game_state, 2: remote_state}
	session.receive_network_intent(2, "buy", "AUR", 10_000)
	assert_eq(remote_state.holdings["AUR"], 0)
	assert_eq(remote_state.cash_pence, remote_state.starting_cash_pence)

func test_unknown_peer_intent_cannot_change_host_state() -> void:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.network_mode = true
	session.network_is_host = true
	session.game_state = GAME_STATE.new(42, 2)
	session.trade_service = TradeService.new()
	session.receive_network_intent(99, "buy", "AUR", 1)
	assert_eq(session.game_state.holdings["AUR"], 0)