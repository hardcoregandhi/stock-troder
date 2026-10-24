@tool
extends McpTestSuite

const TRADING_SESSION = preload("res://scripts/application/trading_session.gd")
const GAME_STATE = preload("res://scripts/simulation/game_state.gd")
const NETWORK_LOBBY = preload("res://scripts/application/network_lobby.gd")

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

func test_disconnect_rechecks_readiness_for_current_phase() -> void:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.network_mode = true
	session.network_is_host = true
	session.network_local_player_id = 1
	session.game_state = GAME_STATE.new(42, 3)
	session.market_simulator = MarketSimulator.new(42)
	session.trade_service = TradeService.new()
	session.game_state.phase = GameState.Phase.BRIEF
	session.network_player_states = {1: session.game_state, 2: GAME_STATE.new(42, 3)}
	session.network_ready_players = {1: true, 2: false}

	session.remove_network_player(2)
	assert_eq(session.game_state.phase, GameState.Phase.TRADING)

	session.game_state.phase = GameState.Phase.DEBRIEF
	session.network_player_states = {1: session.game_state, 3: GAME_STATE.new(42, 3)}
	session.network_ready_players = {1: true, 3: false}
	session.remove_network_player(3)
	assert_eq(session.game_state.phase, GameState.Phase.BRIEF)
	assert_eq(session.game_state.current_day, 2)

func test_client_snapshot_restores_round_chart_state() -> void:
	var host: TradingSession = TRADING_SESSION.new()
	track(host)
	host._ready()
	host.network_mode = true
	host.network_is_host = true
	host.network_local_player_id = 1
	host.game_state = GAME_STATE.new(42, 2)
	host.market_simulator = MarketSimulator.new(42)
	host.trade_service = TradeService.new()
	host.game_state.phase = GameState.Phase.TRADING
	var host_stock := host.game_state.get_stock("AUR")
	host_stock.round_open_price_pence = 5_100
	host_stock.current_price_pence = 5_250
	host_stock.live_price_history_pence = [5_100, 5_180, 5_250]
	host.game_state.mark_pumped("AUR")
	host_stock.activate_pump(0.04)

	var client: TradingSession = TRADING_SESSION.new()
	track(client)
	client._ready()
	client.network_mode = true
	client.network_is_host = false
	client.network_local_player_id = 2
	client.game_state = GAME_STATE.new(0, 2)
	client.apply_network_snapshot({
		"market": host._network_market_snapshot(),
		"portfolio": {"cash_pence": 100_000, "holdings": {}},
		"players": [],
	})

	var client_stock := client.game_state.get_stock("AUR")
	assert_eq(client_stock.current_price_pence, 5_250)
	assert_eq(client_stock.round_open_price_pence, 5_100)
	assert_eq(client_stock.live_price_history_pence, [5_100, 5_180, 5_250])
	assert_true(client.game_state.has_pumped("AUR"))
	assert_true(client_stock.pump_active)
	assert_eq(client_stock.pump_live_boost, 0.04)

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

func test_remote_trade_emits_shared_activity_event() -> void:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.network_mode = true
	session.network_is_host = true
	session.network_local_player_id = 1
	session.game_state = GAME_STATE.new(42, 2)
	session.game_state.phase = GAME_STATE.Phase.TRADING
	session.market_simulator = MarketSimulator.new(42)
	session.trade_service = TradeService.new()
	var remote_state: GameState = GAME_STATE.new(42, 2)
	remote_state.stocks = session.game_state.stocks
	remote_state.phase = GAME_STATE.Phase.TRADING
	session.network_player_states = {1: session.game_state, 2: remote_state}
	var activities: Array = []
	session.network_activity.connect(func(player_id: int, activity_type: String, result: Dictionary) -> void: activities.append([player_id, activity_type, result]))
	session.receive_network_intent(2, "buy", "AUR", 1)
	assert_eq(activities.size(), 1)
	assert_eq(activities[0][0], 2)
	assert_eq(activities[0][1], "trade")

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

func test_network_host_validates_option_orders() -> void:
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
	var call_result := session.receive_network_intent(2, "call", "AUR", 1)
	var put_result := session.receive_network_intent(2, "put", "BRK", 1)
	assert_true(call_result["success"])
	assert_true(put_result["success"])
	assert_eq(remote_state.option_positions.size(), 2)

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
	var lobby := NETWORK_LOBBY.new()
	track(lobby)
	lobby.players = {
		1: {"id": 1, "name": "Morgan", "ready": true},
		2: {"id": 2, "name": "Riley", "ready": true},
	}
	session.network_lobby = lobby
	var rankings := session._network_rankings()
	assert_eq(rankings.size(), 2)
	assert_eq(rankings[0]["player_id"], 2)
	assert_eq(rankings[0]["cash_pence"], 120_000)
	assert_eq(rankings[0]["return_pence"], 20_000)
	assert_eq(rankings[0]["display_name"], "Riley")
	assert_eq(rankings[0]["risk_profile"], "HUMAN")
	assert_eq(rankings[1]["display_name"], "Morgan")

func test_lobby_uses_entered_names_and_hides_peer_ids() -> void:
	var lobby := NETWORK_LOBBY.new()
	track(lobby)
	lobby.players = {
		1: {"id": 1, "name": "Morgan", "ready": true},
		123_984_756: {"id": 123_984_756, "name": "Riley", "ready": false},
	}
	var players := lobby.player_list()
	assert_eq(players[0]["name"], "Morgan")
	assert_eq(players[1]["name"], "Riley")

func test_lobby_makes_duplicate_names_unique_case_insensitively() -> void:
	var lobby := NETWORK_LOBBY.new()
	track(lobby)
	lobby.players = {
		1: {"id": 1, "name": "Morgan", "ready": true},
		2: {"id": 2, "name": "morgan (2)", "ready": true},
		123_984_756: {"id": 123_984_756, "name": "", "ready": false},
	}
	assert_eq(lobby._unique_player_name(123_984_756, "MORGAN"), "MORGAN (3)")

func test_debrief_records_and_rankings_match_each_player_state() -> void:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.network_mode = true
	session.network_is_host = true
	session.network_local_player_id = 1
	session.game_state = GAME_STATE.new(42, 2)
	session.market_simulator = MarketSimulator.new(42)
	session.trade_service = TradeService.new()
	session.network_lobby = NETWORK_LOBBY.new()
	track(session.network_lobby)
	session.game_state.phase = GAME_STATE.Phase.BRIEF
	assert_true(session.market_simulator.start_trading(session.game_state))
	var remote_state: GameState = GAME_STATE.new(42, 2)
	remote_state.stocks = session.game_state.stocks
	remote_state.phase = GAME_STATE.Phase.TRADING
	remote_state.cash_pence = 50_000
	remote_state.holdings["AUR"] = 1
	session.network_player_states = {1: session.game_state, 2: remote_state}
	session.network_completed_rounds = {1: [], 2: []}

	session._on_day_timer_timed_out()

	var host_record: Dictionary = session.network_completed_rounds[1].back()
	var remote_record: Dictionary = session.network_completed_rounds[2].back()
	assert_eq(host_record["player_cash_pence"], session.game_state.cash_pence)
	assert_eq(remote_record["player_cash_pence"], remote_state.cash_pence)
	assert_eq(remote_record["player_portfolio_value_pence"], remote_state.portfolio_value_pence())
	assert_ne(host_record["player_cash_pence"], remote_record["player_cash_pence"])
	for ranking in session.network_rankings:
		var player_state: GameState = session.network_player_states[ranking["player_id"]]
		assert_eq(ranking["portfolio_value_pence"], player_state.portfolio_value_pence())
		assert_eq(ranking["return_pence"], player_state.total_return_pence())

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