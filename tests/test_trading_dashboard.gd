@tool
extends McpTestSuite

const GAME_STATE = preload("res://scripts/simulation/game_state.gd")
const TRADING_DASHBOARD = preload("res://scripts/presentation/trading_dashboard.gd")
const TRADING_SESSION = preload("res://scripts/application/trading_session.gd")

func suite_name() -> String:
	return "trading_dashboard"

func test_trading_snapshot_dismisses_brief_overlay() -> void:
	var dashboard: TradingDashboard = TRADING_DASHBOARD.new()
	track(dashboard)
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.network_mode = true
	session.network_local_player_id = 2
	session.game_state = GAME_STATE.new(42, 2)
	session.game_state.phase = GAME_STATE.Phase.BRIEF
	dashboard.setup(session)

	var brief_market := session._network_market_snapshot()
	session.apply_network_snapshot({
		"market": brief_market,
		"portfolio": {"cash_pence": session.game_state.cash_pence, "holdings": {}},
		"players": [],
	})
	assert_true(dashboard.brief_layer != null)

	var trading_market := session._network_market_snapshot()
	trading_market["phase"] = "TRADING"
	session.apply_network_snapshot({
		"market": trading_market,
		"portfolio": {"cash_pence": session.game_state.cash_pence, "holdings": {}},
		"players": [],
	})
	assert_true(dashboard.brief_layer == null)
	assert_true(dashboard.brief_panel == null)
	assert_true(dashboard.start_trading_button == null)

func test_debrief_button_shows_ready_count_and_local_ready_state() -> void:
	var dashboard: TradingDashboard = TRADING_DASHBOARD.new()
	track(dashboard)
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	session.network_mode = true
	session.network_trading_ready_total = 2
	session.game_state = GAME_STATE.new(42, 2)
	session.game_state.phase = GAME_STATE.Phase.DEBRIEF
	dashboard.setup(session)
	dashboard._show_debrief(1, [])

	assert_eq(dashboard.next_day_button.text, "NEXT DAY (0/2)")
	session.network_trading_ready_count = 1
	session.network_readiness_changed.emit(1, 2, false)
	assert_eq(dashboard.next_day_button.text, "NEXT DAY (1/2)")
	assert_false(dashboard.next_day_button.disabled)
	session.network_local_trading_ready = true
	session.network_readiness_changed.emit(1, 2, true)
	assert_eq(dashboard.next_day_button.text, "WAITING (1/2)")
	assert_true(dashboard.next_day_button.disabled)

	var next_day_market := session._network_market_snapshot()
	next_day_market["day"] = 2
	next_day_market["phase"] = "BRIEF"
	next_day_market["network_ready_count"] = 0
	next_day_market["network_local_ready"] = false
	session.apply_network_snapshot({
		"market": next_day_market,
		"portfolio": {"cash_pence": session.game_state.cash_pence, "holdings": {}},
		"players": [],
	})
	assert_true(dashboard.debrief_layer == null)
	assert_true(dashboard.next_day_button == null)
	assert_true(dashboard.brief_layer != null)
