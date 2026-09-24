class_name NetworkSnapshotService
extends RefCounted

static func market_snapshot(
	state: GameState,
	completed_rounds: Array[Dictionary],
	ready_count: int,
	ready_total: int
) -> Dictionary:
	var records: Array[Dictionary] = []
	for stock in state.stocks:
		records.append({
			"symbol": stock.symbol,
			"current_price_pence": stock.current_price_pence,
			"previous_price_pence": stock.previous_price_pence,
			"round_open_price_pence": stock.round_open_price_pence,
			"live_price_history_pence": stock.live_price_history_pence.duplicate(),
			"projection_change": stock.projection_change,
			"projection_low": stock.projection_low,
			"projection_high": stock.projection_high,
			"current_news": stock.current_news,
			"pump_used": state.has_pumped(stock.symbol),
			"pump_active": stock.pump_active,
			"pump_live_boost": stock.pump_live_boost,
			"sabotage_used": state.has_sabotaged(stock.symbol),
			"sabotage_active": stock.sabotage_active,
			"sabotage_live_pressure": stock.sabotage_live_pressure,
			"fake_news_used": state.has_planted_fake_news(stock.symbol),
			"fake_news_direction": stock.fake_news_direction,
			"fake_news_projection_weight": stock.fake_news_projection_weight,
			"fake_news_active": stock.fake_news_active,
			"projected_price_pence": stock.projected_price_pence,
			"projection_direction": stock.projection_direction,
			"projection_confidence": stock.projection_confidence,
		})
	return {
		"day": state.current_day,
		"total_days": state.total_days,
		"phase": GameState.Phase.keys()[state.phase],
		"stocks": records,
		"completed_rounds": completed_rounds.duplicate(true),
		"network_ready_count": ready_count,
		"network_ready_total": ready_total,
	}

static func apply_market_snapshot(state: GameState, market: Dictionary) -> void:
	state.current_day = int(market.get("day", state.current_day))
	state.total_days = int(market.get("total_days", state.total_days))
	state.phase = GameState.Phase.get(str(market.get("phase", "BRIEF")), GameState.Phase.BRIEF)
	state.pumped_symbols.clear()
	state.sabotaged_symbols.clear()
	state.fake_news_symbols.clear()
	for record in market.get("stocks", []):
		var stock := state.get_stock(str(record["symbol"]))
		if stock == null:
			continue
		stock.current_price_pence = int(record["current_price_pence"])
		stock.previous_price_pence = int(record.get("previous_price_pence", stock.previous_price_pence))
		stock.round_open_price_pence = int(record.get("round_open_price_pence", stock.current_price_pence))
		stock.projection_change = float(record.get("projection_change", 0.0))
		stock.projection_low = float(record.get("projection_low", 0.0))
		stock.projection_high = float(record.get("projection_high", 0.0))
		stock.current_news = str(record.get("current_news", ""))
		stock.projected_price_pence = int(record.get("projected_price_pence", stock.current_price_pence))
		stock.projection_direction = int(record.get("projection_direction", 0))
		stock.projection_confidence = str(record.get("projection_confidence", ""))
		stock.pump_active = bool(record.get("pump_active", false))
		stock.pump_live_boost = float(record.get("pump_live_boost", 0.0))
		stock.sabotage_active = bool(record.get("sabotage_active", false))
		stock.sabotage_live_pressure = float(record.get("sabotage_live_pressure", 0.0))
		stock.fake_news_direction = int(record.get("fake_news_direction", 0))
		stock.fake_news_projection_weight = float(record.get("fake_news_projection_weight", 0.0))
		stock.fake_news_active = bool(record.get("fake_news_active", false))
		if bool(record.get("pump_used", false)):
			state.mark_pumped(stock.symbol)
		if bool(record.get("sabotage_used", false)):
			state.mark_sabotaged(stock.symbol)
		if bool(record.get("fake_news_used", false)):
			state.mark_fake_news_planted(stock.symbol)
		stock.live_price_history_pence.clear()
		for price_pence in record.get("live_price_history_pence", []):
			stock.live_price_history_pence.append(int(price_pence))
		stock.round_history_pence.clear()
		for round_prices in record.get("round_history_pence", []):
			var typed_prices: Array[int] = []
			for price_pence in round_prices:
				typed_prices.append(int(price_pence))
			stock.round_history_pence.append(typed_prices)
