class_name TradingSession
extends Node

signal run_started(state_snapshot: Dictionary)
signal day_prepared(day_number: int, projections: Array[Dictionary], news: Array[Dictionary])
signal time_updated(seconds_remaining: float)
signal market_updated(state_snapshot: Dictionary)
signal trade_completed(trade_result: Dictionary)
signal trade_rejected(trade_result: Dictionary)
signal pump_completed(pump_result: Dictionary)
signal pump_rejected(pump_result: Dictionary)
signal day_resolved(day_number: int, resolution_result: Array[Dictionary], state_snapshot: Dictionary)
signal run_completed(summary: Dictionary)

const DEFAULT_SEED: int = 42_4242
const DAY_LENGTH_SECONDS: float = 30.0
const MARKET_SAMPLE_INTERVAL_SECONDS: float = 0.5

var game_state: GameState
var market_simulator: MarketSimulator
var trade_service: TradeService
var day_timer: DayTimer
var market_sample_elapsed: float = 0.0

func _ready() -> void:
	day_timer = DayTimer.new()
	day_timer.name = "DayTimer"
	add_child(day_timer)
	day_timer.time_updated.connect(_on_time_updated)
	day_timer.timed_out.connect(_on_day_timer_timed_out)

func start_run(run_seed: int = DEFAULT_SEED, run_total_days: int = GameState.DEFAULT_TOTAL_DAYS) -> void:
	if day_timer == null:
		return
	day_timer.stop()
	game_state = GameState.create_default(run_seed, run_total_days)
	market_simulator = MarketSimulator.new(run_seed)
	trade_service = TradeService.new()
	market_sample_elapsed = 0.0
	run_started.emit(state_snapshot())
	_prepare_day()

func buy(symbol: String, quantity: int) -> Dictionary:
	return _execute_trade(trade_service.buy(game_state, symbol, quantity))

func sell(symbol: String, quantity: int) -> Dictionary:
	return _execute_trade(trade_service.sell(game_state, symbol, quantity))

func pump(symbol: String) -> Dictionary:
	var result := trade_service.pump(game_state, symbol)
	if result["success"]:
		pump_completed.emit(result)
	else:
		pump_rejected.emit(result)
	return result

func continue_to_next_day() -> bool:
	if game_state == null or game_state.phase != GameState.Phase.DEBRIEF:
		return false
	game_state.current_day += 1
	game_state.phase = GameState.Phase.PREPARING
	game_state.reset_round_manipulations()
	_prepare_day()
	return true

func state_snapshot() -> Dictionary:
	if game_state == null:
		return {}
	var stock_records: Array[Dictionary] = []
	for stock in game_state.stocks:
		stock_records.append({
			"symbol": stock.symbol,
			"company_name": stock.company_name,
			"current_price_pence": stock.current_price_pence,
			"projection_change": stock.projection_change,
			"projection_low": stock.projection_low,
			"projection_high": stock.projection_high,
			"current_news": stock.current_news,
			"shares": int(game_state.holdings[stock.symbol]),
			"pump_used": game_state.has_pumped(stock.symbol),
		})
	return {
		"day": game_state.current_day,
		"total_days": game_state.total_days,
		"phase": GameState.Phase.keys()[game_state.phase],
		"cash_pence": game_state.cash_pence,
		"portfolio_value_pence": game_state.portfolio_value_pence(),
		"return_pence": game_state.total_return_pence(),
		"stocks": stock_records,
	}

func _prepare_day() -> void:
	market_sample_elapsed = 0.0
	var projections := market_simulator.prepare_day(game_state)
	var news: Array[Dictionary] = []
	for projection in projections:
		news.append({"symbol": projection["symbol"], "text": projection["news"]})
	day_prepared.emit(game_state.current_day, projections, news)
	day_timer.start(DAY_LENGTH_SECONDS)

func _process(delta: float) -> void:
	if game_state == null or game_state.phase != GameState.Phase.TRADING or not day_timer.running:
		return
	market_sample_elapsed += delta
	while market_sample_elapsed >= MARKET_SAMPLE_INTERVAL_SECONDS:
		market_sample_elapsed -= MARKET_SAMPLE_INTERVAL_SECONDS
		var progress := 1.0 - (day_timer.seconds_remaining / DAY_LENGTH_SECONDS)
		market_simulator.update_live_prices(game_state, progress)
		market_updated.emit(state_snapshot())

func _on_day_timer_timed_out() -> void:
	if game_state == null or game_state.phase != GameState.Phase.TRADING:
		return
	var resolved_day := game_state.current_day
	var resolutions := market_simulator.resolve_day(game_state)
	var is_final_day := game_state.phase == GameState.Phase.COMPLETE
	if is_final_day:
		trade_service.liquidate_all(game_state)
	day_resolved.emit(resolved_day, resolutions, state_snapshot())
	if is_final_day:
		_emit_run_completed()
		return

func _on_time_updated(seconds_remaining: float) -> void:
	time_updated.emit(seconds_remaining)

func _execute_trade(trade_result: Dictionary) -> Dictionary:
	if trade_result["success"]:
		trade_completed.emit(trade_result)
	else:
		trade_rejected.emit(trade_result)
	return trade_result

func _emit_run_completed() -> void:
	run_completed.emit({
		"starting_cash_pence": game_state.starting_cash_pence,
		"final_cash_pence": game_state.cash_pence,
		"profit_loss_pence": game_state.cash_pence - game_state.starting_cash_pence,
		"days_completed": game_state.total_days,
	})