@tool
extends McpTestSuite

const DAY_TIMER = preload("res://scripts/application/day_timer.gd")
const GAME_STATE = preload("res://scripts/simulation/game_state.gd")
const TRADING_SESSION = preload("res://scripts/application/trading_session.gd")

var timeout_count: int = 0
var last_summary: Dictionary = {}
var last_resolutions: Array[Dictionary] = []

func suite_name() -> String:
	return "day_timer_session"

func setup() -> void:
	timeout_count = 0
	last_summary = {}
	last_resolutions = []

func test_day_timer_runs_for_30_seconds_and_times_out_once() -> void:
	var timer = DAY_TIMER.new()
	track(timer)
	assert_eq(TRADING_SESSION.DAY_LENGTH_SECONDS, 30.0)
	assert_eq(TRADING_SESSION.MARKET_SAMPLE_INTERVAL_SECONDS, 0.5)
	timer.timed_out.connect(_on_timer_timeout)
	timer.start()
	assert_eq(timer.duration_seconds, 30.0)
	assert_eq(timer.seconds_remaining, 30.0)
	timer._process(29.9)
	assert_true(timer.running)
	timer._process(0.2)
	assert_false(timer.running)
	assert_eq(timer.seconds_remaining, 0.0)
	assert_eq(timeout_count, 1)
	timer._process(0.2)
	assert_eq(timeout_count, 1)

func test_non_final_timeout_enters_debrief_until_next_day() -> void:
	var session: TradingSession = _new_session()
	session.start_run(99, 2)
	assert_eq(session.game_state.phase, GAME_STATE.Phase.TRADING)
	assert_eq(session.game_state.current_day, 1)
	session._on_day_timer_timed_out()
	assert_eq(session.game_state.phase, GAME_STATE.Phase.DEBRIEF)
	assert_eq(session.game_state.current_day, 1)
	session._on_day_timer_timed_out()
	assert_eq(session.game_state.phase, GAME_STATE.Phase.DEBRIEF)
	assert_true(session.continue_to_next_day())
	assert_eq(session.game_state.current_day, 2)
	assert_eq(session.game_state.phase, GAME_STATE.Phase.TRADING)
	assert_false(session.continue_to_next_day())

func test_final_day_liquidates_holdings_and_emits_summary() -> void:
	var session: TradingSession = _new_session()
	session.run_completed.connect(_on_run_completed)
	session.start_run(7, 1)
	var buy_result: Dictionary = session.buy("AUR", 2)
	assert_true(buy_result["success"])
	assert_eq(session.game_state.holdings["AUR"], 2)
	session._on_day_timer_timed_out()
	assert_eq(session.game_state.phase, GAME_STATE.Phase.COMPLETE)
	for stock in session.game_state.stocks:
		assert_eq(session.game_state.holdings[stock.symbol], 0)
	assert_false(last_summary.is_empty())
	assert_eq(last_summary["final_cash_pence"], session.game_state.cash_pence)
	assert_eq(last_summary["profit_loss_pence"], session.game_state.total_return_pence())
	assert_eq(last_summary["days_completed"], 1)

func test_non_final_resolution_contains_debrief_data() -> void:
	var session: TradingSession = _new_session()
	session.day_resolved.connect(_on_day_resolved)
	session.start_run(11, 2)
	session._on_day_timer_timed_out()
	assert_eq(session.game_state.phase, GAME_STATE.Phase.DEBRIEF)
	assert_eq(last_resolutions.size(), session.game_state.stocks.size())
	for resolution in last_resolutions:
		assert_true(resolution.has("opening_price_pence"))
		assert_true(resolution.has("closing_price_pence"))
		assert_true(resolution.has("percentage_change"))
		assert_true(resolution.has("news"))

func _new_session() -> TradingSession:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	return session

func _on_timer_timeout() -> void:
	timeout_count += 1

func _on_run_completed(summary: Dictionary) -> void:
	last_summary = summary

func _on_day_resolved(_day: int, resolutions: Array[Dictionary], _snapshot: Dictionary) -> void:
	last_resolutions = resolutions
