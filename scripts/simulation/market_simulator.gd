class_name MarketSimulator
extends RefCounted

const PRICE_FLOOR_PENCE: int = 100
const PUMP_CORRECTION_CHANCE: float = 0.65
const PUMP_CORRECTION_PERCENT: float = 0.08
const LIVE_NOISE_VOLATILITY_FACTOR: float = 0.35
const MAX_LIVE_NOISE: float = 0.04

var random: RandomNumberGenerator = RandomNumberGenerator.new()
var seed: int

func _init(run_seed: int = 0) -> void:
	seed = run_seed
	random.seed = run_seed

func prepare_day(state: GameState) -> Array[Dictionary]:
	if state.phase == GameState.Phase.COMPLETE:
		return []
	state.phase = GameState.Phase.PREPARING
	var projections: Array[Dictionary] = []
	for stock in state.stocks:
		var event := _choose_event(stock)
		var news_impact: float = float(event.get("impact", 0.0))
		var random_shock := random.randf_range(-stock.volatility, stock.volatility)
		var projection := stock.trend + news_impact + random_shock
		var forecast_noise := stock.volatility * 0.35
		var low := projection - forecast_noise
		var high := projection + forecast_noise
		stock.set_projection(projection, low, high, str(event.get("text", "Quiet trading day")), news_impact)
		projections.append(_projection_record(stock))
	state.phase = GameState.Phase.TRADING
	return projections

func update_live_prices(state: GameState, progress: float) -> Array[Dictionary]:
	if state.phase != GameState.Phase.TRADING:
		return []
	var updates: Array[Dictionary] = []
	var clamped_progress := clampf(progress, 0.0, 1.0)
	for stock in state.stocks:
		var target_price := maxi(PRICE_FLOOR_PENCE, stock.projected_price_pence)
		if stock.pump_active:
			target_price = maxi(PRICE_FLOOR_PENCE, roundi(float(target_price) * (1.0 + stock.pump_live_boost)))
		var path_price := lerpf(float(stock.round_open_price_pence), float(target_price), clamped_progress)
		var live_noise_limit := minf(stock.volatility * LIVE_NOISE_VOLATILITY_FACTOR, MAX_LIVE_NOISE)
		var live_noise := random.randf_range(-live_noise_limit, live_noise_limit)
		var live_price := maxi(PRICE_FLOOR_PENCE, roundi(path_price * (1.0 + live_noise)))
		stock.set_live_price(live_price)
		updates.append({
			"symbol": stock.symbol,
			"current_price_pence": stock.current_price_pence,
			"progress": clamped_progress,
		})
	return updates

func resolve_day(state: GameState) -> Array[Dictionary]:
	if state.phase != GameState.Phase.TRADING:
		return []
	state.phase = GameState.Phase.RESOLVING
	var resolutions: Array[Dictionary] = []
	for stock in state.stocks:
		var opening_price_pence := stock.round_open_price_pence
		var resolution_noise := random.randf_range(-stock.volatility * 0.35, stock.volatility * 0.35)
		var actual_change := stock.projection_change + resolution_noise
		var pump_correction := false
		var pump_correction_percent := 0.0
		if stock.pump_active:
			pump_correction = random.randf() < PUMP_CORRECTION_CHANCE
			pump_correction_percent = PUMP_CORRECTION_PERCENT if pump_correction else 0.02
			actual_change -= pump_correction_percent
		var next_price := maxi(PRICE_FLOOR_PENCE, roundi(float(opening_price_pence) * (1.0 + actual_change)))
		stock.append_resolved_price(next_price)
		var percentage_change := float(next_price - opening_price_pence) / float(opening_price_pence)
		resolutions.append({
			"symbol": stock.symbol,
			"opening_price_pence": opening_price_pence,
			"closing_price_pence": stock.current_price_pence,
			"percentage_change": percentage_change,
			"news": stock.current_news,
			"pump_used": stock.pump_active,
			"pump_correction": pump_correction,
			"pump_correction_percent": pump_correction_percent,
		})
	if state.current_day >= state.total_days:
		state.phase = GameState.Phase.COMPLETE
	else:
		state.phase = GameState.Phase.DEBRIEF
	return resolutions

func _choose_event(stock: StockData) -> Dictionary:
	if stock.news_events.is_empty() or random.randf() > 0.45:
		return {"text": "Quiet trading day", "impact": 0.0}
	return stock.news_events[random.randi_range(0, stock.news_events.size() - 1)]

func _projection_record(stock: StockData) -> Dictionary:
	return {
		"symbol": stock.symbol,
		"projection_change": stock.projection_change,
		"projection_low": stock.projection_low,
		"projection_high": stock.projection_high,
		"projected_price_pence": stock.projected_price_pence,
		"direction": stock.projection_direction,
		"confidence": stock.projection_confidence,
		"news": stock.current_news,
	}
