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

func test_network_host_validates_sabotage_and_fake_news_actions() -> void:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.network_mode = true
	session.network_is_host = true
	session.game_state = GAME_STATE.new(42, 2)
	session.game_state.phase = GAME_STATE.Phase.TRADING
	session.trade_service = TradeService.new()
	var remote_state: GameState = GAME_STATE.new(42, 2)
	remote_state.stocks = session.game_state.stocks
	remote_state.phase = GAME_STATE.Phase.TRADING
	session.network_player_states = {1: session.game_state, 2: remote_state}
	var sabotage_result := session.receive_network_intent(2, "sabotage", "AUR", 0)
	var fake_result := session.receive_network_intent(2, "fake_news_positive", "BRK", 1)
	assert_true(sabotage_result["success"])
	assert_true(fake_result["success"])
	assert_true(remote_state.has_sabotaged("AUR"))
	assert_true(remote_state.has_planted_fake_news("BRK"))

func test_host_ranking_uses_authoritative_portfolio_values() -> void:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.network_mode = true
	session.network_is_host = true
	session.game_state = GAME_STATE.new(42, 1)
	session.game_state.phase = GAME_STATE.Phase.COMPLETE
	var remote_state: GameState = GAME_STATE.new(42, 1)
	remote_state.stocks = session.game_state.stocks
	remote_state.phase = GAME_STATE.Phase.COMPLETE
	remote_state.cash_pence = 120_000
	session.network_player_states = {1: session.game_state, 2: remote_state}
	var rankings := session._network_rankings()
	assert_eq(rankings.size(), 2)
	assert_eq(rankings[0]["player_id"], 2)
	assert_eq(rankings[0]["cash_pence"], 120_000)
	assert_eq(rankings[0]["return_pence"], 20_000)

func test_start_trading_waits_for_every_player_and_resets_readiness_after_start() -> void:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.network_mode = true
	session.network_is_host = true
	session.network_local_player_id = 1
	session.game_state = GAME_STATE.new(42, 2)
	session.market_simulator = MarketSimulator.new(42)
	session.trade_service = TradeService.new()
	session.game_state.phase = GAME_STATE.Phase.BRIEF
	session.network_player_states = {1: session.game_state, 2: GAME_STATE.new(42, 2)}
	session.network_ready_players = {1: false, 2: false}

	assert_false(session.start_trading_round())
	assert_eq(session._network_ready_count(), 1)
	assert_eq(session.game_state.phase, GAME_STATE.Phase.BRIEF)

	session._mark_network_player_ready_for_trading(2)
	assert_eq(session._network_ready_count(), 0)
	assert_eq(session.game_state.phase, GAME_STATE.Phase.TRADING)

func test_next_day_clears_readiness_for_new_brief_and_trading_round() -> void:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.network_mode = true
	session.network_is_host = true
	session.network_local_player_id = 1
	session.game_state = GAME_STATE.new(42, 3)
	session.game_state.phase = GAME_STATE.Phase.DEBRIEF
	session.market_simulator = MarketSimulator.new(42)
	session.trade_service = TradeService.new()
	var remote_state: GameState = GAME_STATE.new(42, 3)
	remote_state.phase = GAME_STATE.Phase.DEBRIEF
	remote_state.stocks = session.game_state.stocks
	session.network_player_states = {1: session.game_state, 2: remote_state}
	session.network_ready_players = {1: false, 2: true}

	assert_true(session.continue_to_next_day())
	assert_eq(session.game_state.current_day, 2)
	assert_eq(session.game_state.phase, GAME_STATE.Phase.BRIEF)
	assert_eq(session._network_ready_count(), 0)
	assert_false(session.start_trading_round())
	assert_eq(session._network_ready_count(), 1)
	session._mark_network_player_ready_for_trading(2)
	assert_eq(session.game_state.phase, GAME_STATE.Phase.TRADING)