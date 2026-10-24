class_name TradingSession
extends Node

const NETWORK_SNAPSHOT_SERVICE = preload("res://scripts/application/network_snapshot_service.gd")
const ROUND_RESOLUTION_SERVICE = preload("res://scripts/application/round_resolution_service.gd")

signal run_started(state_snapshot: Dictionary)
signal day_prepared(day_number: int, projections: Array[Dictionary], news: Array[Dictionary])
signal brief_started(day_number: int, projections: Array[Dictionary], news: Array[Dictionary])
signal time_updated(seconds_remaining: float)
signal market_updated(state_snapshot: Dictionary)
signal trade_completed(trade_result: Dictionary)
signal trade_rejected(trade_result: Dictionary)
signal pump_completed(pump_result: Dictionary)
signal pump_rejected(pump_result: Dictionary)
signal sabotage_completed(sabotage_result: Dictionary)
signal sabotage_rejected(sabotage_result: Dictionary)
signal fake_news_completed(fake_news_result: Dictionary)
signal fake_news_rejected(fake_news_result: Dictionary)
signal option_completed(option_result: Dictionary)
signal option_rejected(option_result: Dictionary)
signal computer_action_completed(player_name: String, risk_profile: String, action_result: Dictionary)
signal day_resolved(day_number: int, resolution_result: Array[Dictionary], state_snapshot: Dictionary)
signal run_completed(summary: Dictionary)
signal network_status_changed(message: String)
signal network_readiness_changed(ready_count: int, total_count: int, local_ready: bool)
signal network_activity(player_id: int, activity_type: String, activity_result: Dictionary)
signal market_news_event(news_result: Dictionary)

const DEFAULT_SEED: int = 42_4242
const DAY_LENGTH_SECONDS: float = 30.0
const MARKET_SAMPLE_INTERVAL_SECONDS: float = 0.5
const MILLIONAIRE_TARGET_PENCE: int = 100_000_000

var game_state: GameState
var market_simulator: MarketSimulator
var trade_service: TradeService
var round_resolution_service: RoundResolutionService
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
var network_completed_rounds: Dictionary = {}
var completed_rounds: Array[Dictionary] = []
var victory_player_id: int = 0
var computer_players: Array[ComputerPlayer] = []
var computer_player_states: Dictionary = {}

func _ready() -> void:
	round_resolution_service = ROUND_RESOLUTION_SERVICE.new()
	day_timer = DayTimer.new()
	day_timer.name = "DayTimer"
	add_child(day_timer)
	day_timer.time_updated.connect(_on_time_updated)
	day_timer.timed_out.connect(_on_day_timer_timed_out)

func start_run(run_seed: int = DEFAULT_SEED, run_total_days: int = GameState.DEFAULT_TOTAL_DAYS, stock_count: int = GameState.DEFAULT_STOCK_COUNT, include_computer_players: bool = true) -> void:
	if day_timer == null:
		return
	day_timer.stop()
	game_state = GameState.create_default(run_seed, run_total_days, stock_count)
	market_simulator = MarketSimulator.new(run_seed)
	trade_service = TradeService.new()
	market_sample_elapsed = 0.0
	completed_rounds.clear()
	victory_player_id = 0
	computer_players.clear()
	computer_player_states.clear()
	if include_computer_players:
		_create_computer_players(run_seed)
	run_started.emit(state_snapshot())
	_prepare_day()

func _create_computer_players(run_seed: int) -> void:
	var profiles := ["CONSERVATIVE", "BALANCED", "AGGRESSIVE"]
	var names := ["Mara", "Quinn", "Rook"]
	for index in profiles.size():
		var player_id := index + 2
		var player := ComputerPlayer.new(player_id, names[index], profiles[index], run_seed + player_id * 997)
		var state: GameState = GameState.create_default(run_seed, game_state.total_days, game_state.stock_count)
		state.stocks = game_state.stocks
		state.phase = game_state.phase
		computer_players.append(player)
		computer_player_states[player_id] = state

func start_network_host(
	lobby: NetworkLobby,
	player_ids: Array[int],
	run_seed: int = DEFAULT_SEED,
	total_days: int = GameState.DEFAULT_TOTAL_DAYS
) -> void:
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
	network_completed_rounds.clear()
	start_run(run_seed, total_days, GameState.DEFAULT_STOCK_COUNT, false)
	for player_id in player_ids:
		var player_state: GameState = game_state if player_id == network_local_player_id else GameState.create_default(run_seed, game_state.total_days)
		player_state.stocks = game_state.stocks
		player_state.phase = game_state.phase
		network_player_states[player_id] = player_state
		network_ready_players[player_id] = false
		network_completed_rounds[player_id] = []
	_publish_network_state()

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

func receive_network_intent(peer_id: int, action: String, symbol: String, quantity: int) -> Dictionary:
	if not network_mode or not network_is_host or not network_player_states.has(peer_id):
		return _network_action_rejection(symbol, action)
	if action == "buy":
		return _execute_network_trade(peer_id, trade_service.buy(network_player_states[peer_id], symbol, quantity))
	elif action == "sell":
		return _execute_network_trade(peer_id, trade_service.sell(network_player_states[peer_id], symbol, quantity))
	elif action == "pump":
		return _execute_network_manipulation(peer_id, trade_service.pump(network_player_states[peer_id], symbol))
	elif action == "sabotage":
		return _execute_network_manipulation(peer_id, trade_service.sabotage(network_player_states[peer_id], symbol))
	elif action == "fake_news_positive" or action == "fake_news_negative":
		return _execute_network_manipulation(peer_id, trade_service.plant_fake_news(network_player_states[peer_id], symbol, quantity))
	elif action == "call":
		return _execute_network_option(peer_id, trade_service.buy_call(network_player_states[peer_id], symbol, quantity, option_time_remaining_ratio()))
	elif action == "put":
		return _execute_network_option(peer_id, trade_service.buy_put(network_player_states[peer_id], symbol, quantity, option_time_remaining_ratio()))
	elif action == "ready_for_next_day":
		_mark_network_player_ready(peer_id)
	elif action == "ready_for_trading":
		_mark_network_player_ready_for_trading(peer_id)
	return {"success": false, "message": "Unknown network action.", "action": action, "symbol": symbol}

func remove_network_player(peer_id: int) -> void:
	if not network_is_host:
		return
	network_player_states.erase(peer_id)
	network_ready_players.erase(peer_id)
	network_status_changed.emit("Player %d disconnected. Match continues." % peer_id)
	if game_state == null or not _all_network_players_ready():
		return
	if game_state.phase == GameState.Phase.DEBRIEF:
		continue_to_next_day()
	elif game_state.phase == GameState.Phase.BRIEF:
		start_trading_round()

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
	if network_mode and not network_is_host:
		network_lobby.submit_pump(symbol)
		return {"success": true, "pending": true, "message": "Pump sent to host.", "symbol": symbol}
	if network_mode:
		return _execute_network_manipulation(network_local_player_id, trade_service.pump(game_state, symbol))
	var result := trade_service.pump(game_state, symbol)
	if result["success"]:
		pump_completed.emit(result)
	else:
		pump_rejected.emit(result)
	return result

func sabotage(symbol: String) -> Dictionary:
	if network_mode and not network_is_host:
		network_lobby.submit_sabotage(symbol)
		return {"success": true, "pending": true, "message": "Sabotage sent to host.", "symbol": symbol}
	if network_mode:
		return _execute_network_manipulation(network_local_player_id, trade_service.sabotage(game_state, symbol))
	var result := trade_service.sabotage(game_state, symbol)
	if result["success"]:
		sabotage_completed.emit(result)
	else:
		sabotage_rejected.emit(result)
	market_updated.emit(state_snapshot())
	return result

func plant_fake_news(symbol: String, direction: int) -> Dictionary:
	if network_mode and not network_is_host:
		network_lobby.submit_fake_news(symbol, direction)
		return {"success": true, "pending": true, "message": "HYPE/FUD sent to host.", "symbol": symbol, "direction": direction}
	if network_mode:
		return _execute_network_manipulation(network_local_player_id, trade_service.plant_fake_news(game_state, symbol, direction))
	var result := trade_service.plant_fake_news(game_state, symbol, direction)
	if result["success"]:
		fake_news_completed.emit(result)
	else:
		fake_news_rejected.emit(result)
	market_updated.emit(state_snapshot())
	return result

func buy_call(symbol: String, quantity: int = 1) -> Dictionary:
	if network_mode and not network_is_host:
		network_lobby.submit_call(symbol)
		return {"success": true, "pending": true, "message": "Call sent to host.", "symbol": symbol}
	if network_mode:
		return _execute_network_option(network_local_player_id, trade_service.buy_call(game_state, symbol, quantity, option_time_remaining_ratio()))
	var result := trade_service.buy_call(game_state, symbol, quantity, option_time_remaining_ratio())
	_emit_option_result(result)
	return result

func buy_put(symbol: String, quantity: int = 1) -> Dictionary:
	if network_mode and not network_is_host:
		network_lobby.submit_put(symbol)
		return {"success": true, "pending": true, "message": "Put sent to host.", "symbol": symbol}
	if network_mode:
		return _execute_network_option(network_local_player_id, trade_service.buy_put(game_state, symbol, quantity, option_time_remaining_ratio()))
	var result := trade_service.buy_put(game_state, symbol, quantity, option_time_remaining_ratio())
	_emit_option_result(result)
	return result

func option_time_remaining_ratio() -> float:
	if day_timer == null or not day_timer.running:
		return 1.0
	return clampf(day_timer.seconds_remaining / DAY_LENGTH_SECONDS, 0.0, 1.0)

func _emit_option_result(result: Dictionary) -> void:
	if bool(result.get("success", false)):
		option_completed.emit(result)
	else:
		option_rejected.emit(result)
	market_updated.emit(state_snapshot())

func continue_to_next_day() -> bool:
	if network_mode and not network_is_host:
		network_lobby.submit_ready_for_next_day()
		if not network_local_trading_ready:
			network_local_trading_ready = true
			network_trading_ready_count = mini(network_trading_ready_count + 1, network_trading_ready_total)
			network_readiness_changed.emit(network_trading_ready_count, network_trading_ready_total, true)
		return false
	if network_mode and network_is_host:
		network_ready_players[network_local_player_id] = true
		if not _all_network_players_ready():
			network_status_changed.emit("Waiting for every player to ready up.")
			_publish_network_state()
			return false
		for player_id in network_ready_players:
			network_ready_players[player_id] = false
	if game_state == null or game_state.phase != GameState.Phase.DEBRIEF:
		return false
	game_state.current_day += 1
	game_state.phase = GameState.Phase.PREPARING
	game_state.reset_round_manipulations()
	for player_state in network_player_states.values():
		player_state.current_day = game_state.current_day
		player_state.phase = game_state.phase
		player_state.reset_round_manipulations()
	for player_state in computer_player_states.values():
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
	for player_state in computer_player_states.values():
		player_state.phase = GameState.Phase.TRADING
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
			"sabotage_used": game_state.has_sabotaged(stock.symbol),
			"sabotage_active": stock.sabotage_active,
			"sabotage_live_pressure": stock.sabotage_live_pressure,
			"fake_news_used": game_state.has_planted_fake_news(stock.symbol),
			"fake_news_direction": stock.fake_news_direction,
			"fake_news_active": stock.fake_news_active,
			"round_history_pence": stock.round_history_pence.duplicate(true),
			"round_open_price_pence": stock.round_open_price_pence,
			"live_price_history_pence": stock.live_price_history_pence.duplicate(),
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
	NETWORK_SNAPSHOT_SERVICE.apply_market_snapshot(game_state, market)
	network_trading_ready_count = int(market.get("network_ready_count", 0))
	network_trading_ready_total = int(market.get("network_ready_total", 0))
	network_local_trading_ready = bool(market.get("network_local_ready", false))
	network_readiness_changed.emit(network_trading_ready_count, network_trading_ready_total, network_local_trading_ready)
	completed_rounds.clear()
	for round_record_value in market.get("completed_rounds", []):
		if typeof(round_record_value) == TYPE_DICTIONARY:
			completed_rounds.append(round_record_value.duplicate(true))
	game_state.cash_pence = int(portfolio.get("cash_pence", game_state.cash_pence))
	for symbol in game_state.holdings:
		game_state.holdings[symbol] = int(portfolio.get("holdings", {}).get(symbol, 0))
	network_rankings.clear()
	for player in snapshot.get("players", []):
		network_rankings.append(player.duplicate(true))
	market_updated.emit(state_snapshot())

func apply_network_event(event: Dictionary) -> void:
	match str(event.get("type", "")):
		"trade":
			network_activity.emit(int(event.get("player_id", 0)), "trade", event["result"])
		"action":
			network_activity.emit(int(event.get("player_id", 0)), "action", event["result"])
		"option":
			network_activity.emit(int(event.get("player_id", 0)), "option", event["result"])
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
	return NETWORK_SNAPSHOT_SERVICE.market_snapshot(
		game_state,
		completed_rounds,
		_network_ready_count(),
		network_ready_players.size()
	)

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
		market_snapshot["completed_rounds"] = network_completed_rounds.get(player_id, completed_rounds).duplicate(true)
		market_snapshot["network_local_ready"] = bool(network_ready_players.get(player_id, false))
		var packet := {"market": market_snapshot, "portfolio": _network_portfolio_snapshot(player_id), "players": network_rankings.duplicate(true)}
		if player_id == network_local_player_id:
			apply_network_snapshot(packet)
		else:
			network_lobby.send_match_state(packet, player_id)

func _execute_network_trade(player_id: int, result: Dictionary) -> Dictionary:
	if player_id == network_local_player_id:
		_execute_trade(result)
	else:
		network_activity.emit(player_id, "trade", result)
	_broadcast_network_activity(player_id, "trade", result)
	_publish_network_state()
	return result

func _execute_network_manipulation(player_id: int, result: Dictionary) -> Dictionary:
	if player_id == network_local_player_id:
		_emit_manipulation_result(result)
	else:
		network_activity.emit(player_id, "action", result)
	_broadcast_network_activity(player_id, "action", result)
	_publish_network_state()
	return result

func _execute_network_option(player_id: int, result: Dictionary) -> Dictionary:
	if player_id == network_local_player_id:
		_emit_option_result(result)
	else:
		network_activity.emit(player_id, "option", result)
	_broadcast_network_activity(player_id, "option", result)
	_publish_network_state()
	return result

func _broadcast_network_activity(player_id: int, activity_type: String, result: Dictionary) -> void:
	if network_lobby == null:
		return
	for recipient_id in network_player_states:
		if recipient_id != network_local_player_id:
			network_lobby.send_match_event({"type": activity_type, "player_id": player_id, "result": result}, recipient_id)

func _emit_manipulation_result(result: Dictionary) -> void:
	var action := str(result.get("action", ""))
	if action == "pump":
		if bool(result.get("success", false)):
			pump_completed.emit(result)
		else:
			pump_rejected.emit(result)
	elif action == "sabotage":
		if bool(result.get("success", false)):
			sabotage_completed.emit(result)
		else:
			sabotage_rejected.emit(result)
	else:
		if bool(result.get("success", false)):
			fake_news_completed.emit(result)
		else:
			fake_news_rejected.emit(result)
	market_updated.emit(state_snapshot())

func _mark_network_player_ready(player_id: int) -> void:
	network_ready_players[player_id] = true
	if _all_network_players_ready():
		continue_to_next_day()
	else:
		network_lobby.send_match_event({"type": "status", "message": "Player %d is ready. Waiting for the rest." % player_id})
		_publish_network_state()

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
	for player_state in computer_player_states.values():
		player_state.phase = game_state.phase
	network_rankings = _network_rankings()
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
	for computer_player in computer_players:
		var computer_state: GameState = computer_player_states[computer_player.player_id]
		var action_result := computer_player.tick(delta, computer_state, trade_service, option_time_remaining_ratio())
		if not action_result.is_empty() and bool(action_result.get("success", false)):
			computer_action_completed.emit(computer_player.display_name, computer_player.risk_profile, action_result)
			network_rankings = _network_rankings()
	market_sample_elapsed += delta
	while market_sample_elapsed >= MARKET_SAMPLE_INTERVAL_SECONDS:
		market_sample_elapsed -= MARKET_SAMPLE_INTERVAL_SECONDS
		var progress := 1.0 - (day_timer.seconds_remaining / DAY_LENGTH_SECONDS)
		market_simulator.update_live_prices(game_state, progress)
		for news_event in market_simulator.last_intraday_events:
			market_news_event.emit(news_event)
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
	var option_results := _settle_options(game_state)
	var option_results_by_player: Dictionary = {}
	if network_mode and network_is_host:
		option_results_by_player[network_local_player_id] = option_results
		for player_id in network_player_states:
			var player_state: GameState = network_player_states[player_id]
			if player_state == game_state:
				continue
			option_results_by_player[player_id] = _settle_options(player_state)
	for player_state in computer_player_states.values():
		_settle_options(player_state)
	var millionaire_player_id := _millionaire_player_id()
	if millionaire_player_id > 0:
		victory_player_id = millionaire_player_id
		game_state.phase = GameState.Phase.COMPLETE
		for player_state in network_player_states.values():
			player_state.phase = GameState.Phase.COMPLETE
		for player_state in computer_player_states.values():
			player_state.phase = GameState.Phase.COMPLETE
	var is_final_day := game_state.phase == GameState.Phase.COMPLETE
	completed_rounds.append(_round_record(resolved_day, resolutions, option_results))
	if network_mode and network_is_host:
		for player_id in network_player_states:
			var player_state: GameState = network_player_states[player_id]
			var player_rounds: Array = network_completed_rounds.get(player_id, []).duplicate(true)
			var player_options: Array = option_results_by_player.get(player_id, [])
			player_rounds.append(round_resolution_service.round_record(player_state, resolved_day, resolutions, player_options))
			network_completed_rounds[player_id] = player_rounds
	if is_final_day:
		trade_service.liquidate_all(game_state)
	if network_mode and network_is_host:
		for player_state in network_player_states.values():
			player_state.phase = game_state.phase
			if is_final_day:
				trade_service.liquidate_all(player_state)
	for player_state in computer_player_states.values():
		player_state.phase = game_state.phase
		if is_final_day:
			trade_service.liquidate_all(player_state)
	network_rankings = _network_rankings()
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
		"victory_player_id": victory_player_id,
		"completed_rounds": completed_rounds.duplicate(true),
	}

func _round_record(day: int, resolutions: Array[Dictionary], option_results: Array[Dictionary] = []) -> Dictionary:
	return round_resolution_service.round_record(game_state, day, resolutions, option_results)

func _settle_options(state: GameState) -> Array[Dictionary]:
	return round_resolution_service.settle_options(state)

func _network_action_rejection(symbol: String, action: String) -> Dictionary:
	var label := "Sabotage" if action == "sabotage" else "Fake News"
	return {
		"success": false,
		"action": action,
		"symbol": symbol,
		"message": "%s is a single-player action and is rejected in multiplayer." % label,
		"cost_pence": 0,
	}

func _network_rankings() -> Array[Dictionary]:
	var rankings: Array[Dictionary] = []
	var states: Dictionary = network_player_states if network_mode and network_is_host else {network_local_player_id: game_state}
	if not network_mode:
		for player_id in computer_player_states:
			states[player_id] = computer_player_states[player_id]
	for player_id in states:
		var player_state: GameState = states[player_id]
		rankings.append({
			"player_id": int(player_id),
			"display_name": "You" if int(player_id) == network_local_player_id else _computer_name(int(player_id)),
			"risk_profile": "HUMAN" if int(player_id) == network_local_player_id else _computer_profile(int(player_id)),
			"cash_pence": player_state.cash_pence,
			"portfolio_value_pence": player_state.portfolio_value_pence(),
			"return_pence": player_state.total_return_pence(),
			"holdings": player_state.holdings.duplicate(),
		})
	rankings.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["return_pence"]) > int(right["return_pence"]))
	return rankings

func _computer_name(player_id: int) -> String:
	for player in computer_players:
		if player.player_id == player_id:
			return player.display_name
	return "PLAYER %d" % player_id

func _computer_profile(player_id: int) -> String:
	for player in computer_players:
		if player.player_id == player_id:
			return player.risk_profile
	return "AI"

func _millionaire_player_id() -> int:
	var states: Dictionary = network_player_states if network_mode and network_is_host else {network_local_player_id: game_state}
	if not network_mode:
		for player_id in computer_player_states:
			states[player_id] = computer_player_states[player_id]
	var winner_id := 0
	var winner_value := 0
	for player_id in states:
		var portfolio_value: int = states[player_id].portfolio_value_pence()
		if portfolio_value >= MILLIONAIRE_TARGET_PENCE and portfolio_value > winner_value:
			winner_id = int(player_id)
			winner_value = portfolio_value
	return winner_id
