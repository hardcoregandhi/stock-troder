class_name ComputerPlayer
extends RefCounted

const RISK_PROFILES := ["CONSERVATIVE", "BALANCED", "AGGRESSIVE"]

var player_id: int
var display_name: String
var risk_profile: String
var random := RandomNumberGenerator.new()
var decision_elapsed: float = 0.0
var decision_interval: float = 1.5

func _init(new_player_id: int, new_name: String, new_profile: String, seed: int) -> void:
	player_id = new_player_id
	display_name = new_name
	risk_profile = new_profile if new_profile in RISK_PROFILES else "BALANCED"
	random.seed = seed
	decision_interval = 1.0 + random.randf() * 0.8

func tick(delta: float, state: GameState, trade_service: TradeService, time_remaining_ratio: float = 1.0) -> Dictionary:
	if state.phase != GameState.Phase.TRADING:
		return {}
	decision_elapsed += delta
	if decision_elapsed < decision_interval:
		return {}
	decision_elapsed = 0.0
	return _make_decision(state, trade_service, time_remaining_ratio)

func _make_decision(state: GameState, trade_service: TradeService, time_remaining_ratio: float) -> Dictionary:
	var stock := _target_stock(state)
	if stock == null:
		return {}
	var manipulation_roll := random.randf()
	if risk_profile == "AGGRESSIVE" and random.randf() < 0.12:
		if stock.projection_change >= 0.03:
			var call_result := trade_service.buy_call(state, stock.symbol, 1, time_remaining_ratio)
			if bool(call_result.get("success", false)):
				return call_result
		elif stock.projection_change <= -0.03:
			var put_result := trade_service.buy_put(state, stock.symbol, 1, time_remaining_ratio)
			if bool(put_result.get("success", false)):
				return put_result
	if manipulation_roll < _manipulation_chance():
		var manipulation := _try_manipulation(state, trade_service, stock)
		if not manipulation.is_empty():
			return manipulation
	var projection := stock.projection_change
	var shares := int(state.holdings[stock.symbol])
	if projection > _buy_threshold() and state.cash_pence >= stock.current_price_pence:
		return trade_service.buy(state, stock.symbol, 1)
	if projection < _sell_threshold() and shares > 0:
		return trade_service.sell(state, stock.symbol, 1)
	if shares > 0 and random.randf() < _hold_sell_chance():
		return trade_service.sell(state, stock.symbol, 1)
	return {}

func _target_stock(state: GameState) -> StockData:
	var selected: StockData = null
	var selected_score := -INF
	for stock in state.stocks:
		var score := stock.projection_change + stock.volatility * _volatility_weight()
		if risk_profile == "CONSERVATIVE":
			score -= stock.volatility * 0.8
		if risk_profile == "AGGRESSIVE":
			score += stock.volatility * 0.8
		if score > selected_score:
			selected_score = score
			selected = stock
	return selected

func _try_manipulation(state: GameState, trade_service: TradeService, stock: StockData) -> Dictionary:
	if risk_profile == "CONSERVATIVE":
		return {}
	var action_roll := random.randf()
	if action_roll < 0.34 and state.cash_pence >= GameState.PUMP_COST_PENCE and not state.has_pumped(stock.symbol):
		return trade_service.pump(state, stock.symbol)
	if action_roll < 0.67 and state.cash_pence >= GameState.SABOTAGE_COST_PENCE and not state.has_sabotaged(stock.symbol):
		return trade_service.sabotage(state, stock.symbol)
	if state.cash_pence >= GameState.FAKE_NEWS_COST_PENCE and not state.has_planted_fake_news(stock.symbol):
		var direction := 1 if stock.projection_change >= 0.0 else -1
		return trade_service.plant_fake_news(state, stock.symbol, direction)
	return {}

func _manipulation_chance() -> float:
	match risk_profile:
		"CONSERVATIVE":
			return 0.02
		"AGGRESSIVE":
			return 0.28
	return 0.12

func _buy_threshold() -> float:
	match risk_profile:
		"CONSERVATIVE":
			return 0.04
		"AGGRESSIVE":
			return -0.01
	return 0.02

func _sell_threshold() -> float:
	match risk_profile:
		"CONSERVATIVE":
			return -0.01
		"AGGRESSIVE":
			return -0.05
	return -0.025

func _hold_sell_chance() -> float:
	match risk_profile:
		"CONSERVATIVE":
			return 0.08
		"AGGRESSIVE":
			return 0.02
	return 0.04

func _volatility_weight() -> float:
	match risk_profile:
		"CONSERVATIVE":
			return 0.05
		"AGGRESSIVE":
			return 0.25
	return 0.12
