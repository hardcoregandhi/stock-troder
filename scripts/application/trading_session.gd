class_name TradingSession
extends Node

signal run_started(state_snapshot: Dictionary)
signal day_prepared(day_number: int, projections: Array[Dictionary], news: Array[Dictionary])
signal brief_started(day_number: int, projections: Array[Dictionary], news: Array[Dictionary])
signal time_updated(seconds_remaining: float)
signal market_updated(state_snapshot: Dictionary)
signal trade_completed(trade_result: Dictionary)
signal trade_rejected(trade_result: Dictionary)
signal pump_completed(pump_result: Dictionary)
signal pump_rejected(pump_result: Dictionary)
signal day_resolved(day_number: int, resolution_result: Array[Dictionary], state_snapshot: Dictionary)
signal run_completed(summary: Dictionary)
signal network_status_changed(message: String)
signal network_readiness_changed(ready_count: int, total_count: int, local_ready: bool)

const DEFAULT_SEED: int = 42_4242
const DAY_LENGTH_SECONDS: float = 30.0
const MARKET_SAMPLE_INTERVAL_SECONDS: float = 0.5

var game_state: GameState
var market_simulator: MarketSimulator
var trade_service: TradeService
var day_timer: DayTimer
var market_sample_elapsed: float = 0.0
var network_lobby: NetworkLobby
var network_mode := false
var network_is_host := false
var network_local_player_id := 1
var network_player_states: Dictionary = {}
var network_ready_players: Dictionary = {}
var network_trading_ready_count: int = 0
var network_trading_ready_total: int = 0
var network_local_trading_ready: bool = false
var network_rankings: Array[Dictionary] = []
var completed_rounds: Array[Dictionary] = []

func _ready() -> void:
	day_timer = DayTimer.new()
	day_timer.name = "DayTimer"
	add_child(day_timer)
	day_timer.time_updated.connect(_on_time_updated)
	day_timer.timed_out.connect(_on_day_timer_timed_out)

func start_run(run_seed: int = DEFAULT_SEED, run_total_days: int = GameState.DEFAULT_TOTAL_DAYS, stock_count: int = GameState.DEFAULT_STOCK_COUNT) -> void:
	if day_timer == null:
		return
	day_timer.stop()
	game_state = GameState.create_default(run_seed, run_total_days, stock_count)
	market_simulator = MarketSimulator.new(run_seed)
	trade_service = TradeService.new()
	market_sample_elapsed = 0.0
	completed_rounds.clear()
	run_started.emit(state_snapshot())
	_prepare_day()

func start_network_host(lobby: NetworkLobby, player_ids: Array[int], run_seed: int = DEFAULT_SEED) -> void:
	network_lobby = lobby
	network_mode = true
	network_is_host = true
	network_local_player_id = 1
	network_player_states.clear()
	network_ready_players.clear()
	network_trading_ready_count = 0
	network_trading_ready_total = player_ids.size()
	network_local_trading_ready = false
	network_rankings.clear()
	start_run(run_seed, GameState.DEFAULT_TOTAL_DAYS, GameState.DEFAULT_STOCK_COUNT)
	for player_id in player_ids:
		var player_state: GameState = game_state if player_id == network_local_player_id else GameState.create_default(run_seed, game_state.total_days)
		player_state.stocks = game_state.stocks
		player_state.phase = game_state.phase
		network_player_states[player_id] = player_state
		network_ready_players[player_id] = false
	_publish_network_state()
	if game_state != null and game_state.phase == GameState.Phase.BRIEF:
		brief_started.emit(game_state.current_day, [], [])

func start_network_client(lobby: NetworkLobby, player_id: int) -> void:
	network_lobby = lobby
	network_mode = true
	network_is_host = false
	network_local_player_id = player_id
	network_player_states.clear()
	game_state = GameState.create_default(0, GameState.DEFAULT_TOTAL_DAYS)
	trade_service = TradeService.new()
	market_simulator = null
	day_timer.stop()

func receive_network_intent(peer_id: int, action: String, symbol: String, quantity: int) -> void:
	if not network_mode or not network_is_host or not network_player_states.has(peer_id):
		return
	if action == "buy":
		_execute_network_trade(peer_id, trade_service.buy(network_player_states[peer_id], symbol, quantity))
	elif action == "sell":
		_execute_network_trade(peer_id, trade_service.sell(network_player_states[peer_id], symbol, quantity))
	elif action == "ready_for_next_day":
		_mark_network_player_ready(peer_id)
	elif action == "ready_for_trading":
		_mark_network_player_ready_for_trading(peer_id)

func remove_network_player(peer_id: int) -> void:
	if not network_is_host:
		return
	network_player_states.erase(peer_id)
	network_ready_players.erase(peer_id)
	network_status_changed.emit("Player %d disconnected. Match continues." % peer_id)

func buy(symbol: String, quantity: int) -> Dictionary:
	if network_mode and not network_is_host:
		network_lobby.submit_buy(symbol, quantity)
		return _pending_network_trade(symbol, quantity)
	if network_mode:
		return _execute_network_trade(network_local_player_id, trade_service.buy(game_state, symbol, quantity))
	return _execute_trade(trade_service.buy(game_state, symbol, quantity))

func sell(symbol: String, quantity: int) -> Dictionary:
	if network_mode and not network_is_host:
		network_lobby.submit_sell(symbol, quantity)
		return _pending_network_trade(symbol, quantity)
	if network_mode:
		return _execute_network_trade(network_local_player_id, trade_service.sell(game_state, symbol, quantity))
	return _execute_trade(trade_service.sell(game_state, symbol, quantity))

func pump(symbol: String) -> Dictionary:
	if network_mode:
		return {"success": false, "message": "Pump is not available in multiplayer.", "symbol": symbol}
	var result := trade_service.pump(game_state, symbol)
	if result["success"]:
		pump_completed.emit(result)
	else:
		pump_rejected.emit(result)
	return result

func continue_to_next_day() -> bool:
	if network_mode and not network_is_host:
		network_lobby.submit_ready_for_next_day()
		return false
	if network_mode and network_is_host:
		network_ready_players[network_local_player_id] = true
		if not _all_network_players_ready():
			network_status_changed.emit("Waiting for every player to ready up.")
			return false
		for player_id in network_ready_players:
			network_ready_players[player_id] = false
		network_ready_players[network_local_player_id] = true
	if game_state == null or game_state.phase != GameState.Phase.DEBRIEF:
		return false
	game_state.current_day += 1
	game_state.phase = GameState.Phase.PREPARING
	game_state.reset_round_manipulations()
	for player_state in network_player_states.values():
		player_state.current_day = game_state.current_day
		player_state.phase = game_state.phase
		player_state.reset_round_manipulations()
	_prepare_day()
	if network_mode and network_is_host:
		_publish_network_state()
	return true

func start_trading_round() -> bool:
	if network_mode and not network_is_host:
		network_lobby.submit_ready_for_trading()
		return false
	if network_mode and network_is_host:
		network_ready_players[network_local_player_id] = true
		if not _all_network_players_ready():
			_publish_network_state()
			network_status_changed.emit("Waiting for every player to start trading.")
			return false
		for player_id in network_ready_players:
			network_ready_players[player_id] = false
	if game_state == null or game_state.phase != GameState.Phase.BRIEF:
		return false
	if not market_simulator.start_trading(game_state):
		return false
	day_timer.start(DAY_LENGTH_SECONDS)
	if network_mode and network_is_host:
		for player_state in network_player_states.values():
			player_state.phase = GameState.Phase.TRADING
		_publish_network_state()
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
			"pump_active": stock.pump_active,
			"pump_live_boost": stock.pump_live_boost,
		})
	return {
		"day": game_state.current_day,
		"total_days": game_state.total_days,
		"phase": GameState.Phase.keys()[game_state.phase],
		"cash_pence": game_state.cash_pence,
		"portfolio_value_pence": game_state.portfolio_value_pence(),
		"return_pence": game_state.total_return_pence(),
		"stocks": stock_records,
		"network_ready_count": network_trading_ready_count,
		"network_ready_total": network_trading_ready_total,
		"network_local_ready": network_local_trading_ready,
		"completed_rounds": completed_rounds.duplicate(true),
		"rankings": network_rankings.duplicate(true),
	}

func apply_network_snapshot(snapshot: Dictionary) -> void:
	var market: Dictionary = snapshot.get("market", {})
	var portfolio: Dictionary = snapshot.get("portfolio", {})
	if game_state == null:
		game_state = GameState.create_default(0, int(market.get("total_days", GameState.DEFAULT_TOTAL_DAYS)))
	game_state.current_day = int(market.get("day", game_state.current_day))
	game_state.total_days = int(market.get("total_days", game_state.total_days))
	game_state.phase = GameState.Phase.get(str(market.get("phase", "BRIEF")), GameState.Phase.BRIEF)
	network_trading_ready_count = int(market.get("network_ready_count", 0))
	network_trading_ready_total = int(market.get("network_ready_total", 0))
	network_local_trading_ready = bool(market.get("network_local_ready", false))
	network_readiness_changed.emit(network_trading_ready_count, network_trading_ready_total, network_local_trading_ready)
	completed_rounds = market.get("completed_rounds", []).duplicate(true)
	game_state.cash_pence = int(portfolio.get("cash_pence", game_state.cash_pence))
	for symbol in game_state.holdings:
		game_state.holdings[symbol] = int(portfolio.get("holdings", {}).get(symbol, 0))
	for record in market.get("stocks", []):
		var stock := game_state.get_stock(str(record["symbol"]))
		if stock == null:
			continue
		stock.current_price_pence = int(record["current_price_pence"])
		stock.projection_change = float(record.get("projection_change", 0.0))
		stock.projection_low = float(record.get("projection_low", 0.0))
		stock.projection_high = float(record.get("projection_high", 0.0))
		stock.current_news = str(record.get("current_news", ""))
		stock.projected_price_pence = int(record.get("projected_price_pence", stock.current_price_pence))
		stock.projection_direction = int(record.get("projection_direction", 0))
		stock.projection_confidence = str(record.get("projection_confidence", ""))
		stock.pump_active = bool(record.get("pump_active", false))
		stock.pump_live_boost = float(record.get("pump_live_boost", 0.0))
	network_rankings.clear()
	for player in snapshot.get("players", []):
		network_rankings.append(player.duplicate(true))
	market_updated.emit(state_snapshot())

func apply_network_event(event: Dictionary) -> void:
	match str(event.get("type", "")):
		"trade":
			_execute_trade(event["result"])
		"day_resolved":
			day_resolved.emit(int(event["day"]), event["resolutions"], state_snapshot())
		"brief_started":
			brief_started.emit(int(event["day"]), event.get("projections", []), event.get("news", []))
		"run_completed":
			run_completed.emit(event["summary"])
		"time":
			time_updated.emit(float(event["seconds_remaining"]))
		"status":
			network_status_changed.emit(str(event["message"]))

func _network_market_snapshot() -> Dictionary:
	var records: Array[Dictionary] = []
	for stock in game_state.stocks:
		records.append({
			"symbol": stock.symbol,
			"current_price_pence": stock.current_price_pence,
			"projection_change": stock.projection_change,
			"projection_low": stock.projection_low,
			"projection_high": stock.projection_high,
			"current_news": stock.current_news,
			"projected_price_pence": stock.projected_price_pence,
			"projection_direction": stock.projection_direction,
			"projection_confidence": stock.projection_confidence,
		})
	return {
		"day": game_state.current_day,
		"total_days": game_state.total_days,
		"phase": GameState.Phase.keys()[game_state.phase],
		"stocks": records,
		"completed_rounds": completed_rounds.duplicate(true),
		"network_ready_count": _network_ready_count(),
		"network_ready_total": network_ready_players.size(),
	}

func _network_portfolio_snapshot(player_id: int) -> Dictionary:
	var state: GameState = network_player_states[player_id]
	return {"cash_pence": state.cash_pence, "holdings": state.holdings.duplicate(), "portfolio_value_pence": state.portfolio_value_pence(), "return_pence": state.total_return_pence()}

func _publish_network_state() -> void:
	if network_lobby == null or not network_is_host:
		return
	for player_id in network_player_states:
		network_trading_ready_count = _network_ready_count()
		network_trading_ready_total = network_ready_players.size()
		network_local_trading_ready = bool(network_ready_players.get(network_local_player_id, false))
		network_readiness_changed.emit(network_trading_ready_count, network_trading_ready_total, network_local_trading_ready)
		network_rankings = _network_rankings()
		var market_snapshot := _network_market_snapshot()
		market_snapshot["network_local_ready"] = bool(network_ready_players.get(player_id, false))
		var packet := {"market": market_snapshot, "portfolio": _network_portfolio_snapshot(player_id), "players": network_rankings.duplicate(true)}
		if player_id == network_local_player_id:
			apply_network_snapshot(packet)
		else:
			network_lobby.send_match_state(packet, player_id)

func _execute_network_trade(player_id: int, result: Dictionary) -> Dictionary:
	if player_id == network_local_player_id:
		_execute_trade(result)
	elif network_lobby != null:
		network_lobby.send_match_event({"type": "trade", "result": result}, player_id)
	_publish_network_state()
	return result

func _mark_network_player_ready(player_id: int) -> void:
	network_ready_players[player_id] = true
	if _all_network_players_ready():
		continue_to_next_day()
	else:
		network_lobby.send_match_event({"type": "status", "message": "Player %d is ready. Waiting for the rest." % player_id})

func _mark_network_player_ready_for_trading(player_id: int) -> void:
	if game_state == null or game_state.phase != GameState.Phase.BRIEF:
		return
	network_ready_players[player_id] = true
	if _all_network_players_ready():
		start_trading_round()
	else:
		_publish_network_state()
		network_lobby.send_match_event({"type": "status", "message": "Player %d is ready to trade. Waiting for the rest." % player_id})

func _network_ready_count() -> int:
	var ready_count := 0
	for player_id in network_ready_players:
		if bool(network_ready_players[player_id]):
			ready_count += 1
	return ready_count

func _all_network_players_ready() -> bool:
	for player_id in network_player_states:
		if not bool(network_ready_players.get(player_id, false)):
			return false
	return true

func _pending_network_trade(symbol: String, quantity: int) -> Dictionary:
	return {"success": true, "pending": true, "message": "Trade sent to host.", "symbol": symbol, "quantity": quantity}

func _prepare_day() -> void:
	market_sample_elapsed = 0.0
	var projections := market_simulator.prepare_day(game_state)
	var news: Array[Dictionary] = []
	for projection in projections:
		news.append({"symbol": projection["symbol"], "text": projection["news"]})
	day_prepared.emit(game_state.current_day, projections, news)
	brief_started.emit(game_state.current_day, projections, news)
	if network_mode and network_is_host:
		for player_state in network_player_states.values():
			player_state.phase = game_state.phase
		_publish_network_state()

func _process(delta: float) -> void:
	if game_state == null or game_state.phase != GameState.Phase.TRADING or not day_timer.running:
		return
	market_sample_elapsed += delta
	while market_sample_elapsed >= MARKET_SAMPLE_INTERVAL_SECONDS:
		market_sample_elapsed -= MARKET_SAMPLE_INTERVAL_SECONDS
		var progress := 1.0 - (day_timer.seconds_remaining / DAY_LENGTH_SECONDS)
		market_simulator.update_live_prices(game_state, progress)
		market_updated.emit(state_snapshot())
		if network_mode and network_is_host:
			_publish_network_state()
			for player_id in network_player_states:
				if player_id != network_local_player_id:
					network_lobby.send_match_event({"type": "time", "seconds_remaining": day_timer.seconds_remaining}, player_id)

func _on_day_timer_timed_out() -> void:
	if game_state == null or game_state.phase != GameState.Phase.TRADING:
		return
	var resolved_day := game_state.current_day
	var resolutions := market_simulator.resolve_day(game_state)
	var is_final_day := game_state.phase == GameState.Phase.COMPLETE
	completed_rounds.append(_round_record(resolved_day, resolutions))
	if is_final_day:
		trade_service.liquidate_all(game_state)
	if network_mode and network_is_host:
		for player_state in network_player_states.values():
			player_state.phase = game_state.phase
			if is_final_day:
				trade_service.liquidate_all(player_state)
	day_resolved.emit(resolved_day, resolutions, state_snapshot())
	if network_mode and network_is_host:
		_publish_network_state()
		for player_id in network_player_states:
			if player_id != network_local_player_id:
				network_lobby.send_match_event({"type": "day_resolved", "day": resolved_day, "resolutions": resolutions}, player_id)
	if is_final_day:
		_emit_run_completed()
		if network_mode and network_is_host:
			for player_id in network_player_states:
				if player_id != network_local_player_id:
					network_lobby.send_match_event({"type": "run_completed", "summary": _run_summary_for(network_player_states[player_id])}, player_id)
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
	run_completed.emit(_run_summary_for(game_state))

func _run_summary_for(state: GameState) -> Dictionary:
	return {
		"starting_cash_pence": state.starting_cash_pence,
		"final_cash_pence": state.cash_pence,
		"profit_loss_pence": state.cash_pence - state.starting_cash_pence,
		"days_completed": state.total_days,
		"holdings": state.holdings.duplicate(),
		"ranking": _network_rankings(),
		"completed_rounds": completed_rounds.duplicate(true),
	}

func _round_record(day: int, resolutions: Array[Dictionary]) -> Dictionary:
	var records: Array[Dictionary] = []
	for stock in game_state.stocks:
		records.append({
			"symbol": stock.symbol,
			"opening_price_pence": stock.round_open_price_pence,
			"closing_price_pence": stock.current_price_pence,
			"percentage_change": _percentage_change(stock.round_open_price_pence, stock.current_price_pence),
			"game_so_far_percentage": _percentage_change(stock.price_history_pence[0], stock.current_price_pence),
		})
	return {
		"day": day,
		"resolutions": resolutions.duplicate(true),
		"stocks": records,
		"player_cash_pence": game_state.cash_pence,
		"player_portfolio_value_pence": game_state.portfolio_value_pence(),
		"player_return_pence": game_state.total_return_pence(),
		"player_holdings": game_state.holdings.duplicate(),
		"pump_markers": resolutions.filter(func(item: Dictionary) -> bool: return bool(item.get("pump_used", false))),
		"sabotage_markers": [],
	}

func _percentage_change(opening_price_pence: int, closing_price_pence: int) -> float:
	if opening_price_pence <= 0:
		return 0.0
	return float(closing_price_pence - opening_price_pence) / float(opening_price_pence)

func _network_rankings() -> Array[Dictionary]:
	var rankings: Array[Dictionary] = []
	var states := network_player_states if network_mode and network_is_host else {network_local_player_id: game_state}
	for player_id in states:
		var player_state: GameState = states[player_id]
		rankings.append({
			"player_id": int(player_id),
			"cash_pence": player_state.cash_pence,
			"portfolio_value_pence": player_state.portfolio_value_pence(),
			"return_pence": player_state.total_return_pence(),
			"holdings": player_state.holdings.duplicate(),
		})
	rankings.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["return_pence"]) > int(right["return_pence"]))
	return rankings