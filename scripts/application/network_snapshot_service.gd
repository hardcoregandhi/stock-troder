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
			"pump_active": stock.pump_active,
			"pump_live_boost": stock.pump_live_boost,
			"sabotage_active": stock.sabotage_active,
			"sabotage_live_pressure": stock.sabotage_live_pressure,
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
		"cooperative_goal": state.cooperative_goal.duplicate(),
	}

static func apply_market_snapshot(state: GameState, market: Dictionary) -> void:
	state.current_day = int(market.get("day", state.current_day))
	state.total_days = int(market.get("total_days", state.total_days))
	state.phase = GameState.Phase.get(str(market.get("phase", "BRIEF")), GameState.Phase.BRIEF)
	state.cooperative_goal = market.get("cooperative_goal", {}).duplicate()
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
		stock.live_price_history_pence.clear()
		for price_pence in record.get("live_price_history_pence", []):
			stock.live_price_history_pence.append(int(price_pence))
		stock.round_history_pence.clear()
		for round_prices in record.get("round_history_pence", []):
			var typed_prices: Array[int] = []
			for price_pence in round_prices:
				typed_prices.append(int(price_pence))
			stock.round_history_pence.append(typed_prices)

# Private per-player data: used-action flags, role, goals, and research notes.
static func portfolio_snapshot(state: GameState) -> Dictionary:
	return {
		"cash_pence": state.cash_pence,
		"holdings": state.holdings.duplicate(),
		"portfolio_value_pence": state.portfolio_value_pence(),
		"return_pence": state.total_return_pence(),
		"starting_value_pence": state.starting_value_pence,
		"role": state.role,
		"credibility": state.credibility,
		"home_symbol": state.home_symbol,
		"goals": state.goals.duplicate(true),
		"goal_results": state.goal_results.duplicate(true),
		"research_reports": state.research_reports.duplicate(true),
		"last_dividend_pence": state.last_dividend_pence,
		"cooperative_reward_pence": state.cooperative_reward_pence,
		"pumped_symbols": state.pumped_symbols.keys(),
		"sabotaged_symbols": state.sabotaged_symbols.keys(),
		"fake_news_symbols": state.fake_news_symbols.keys(),
	}

static func apply_portfolio_snapshot(state: GameState, portfolio: Dictionary) -> void:
	state.cash_pence = int(portfolio.get("cash_pence", state.cash_pence))
	for symbol in state.holdings:
		state.holdings[symbol] = int(portfolio.get("holdings", {}).get(symbol, 0))
	state.starting_value_pence = int(portfolio.get("starting_value_pence", state.starting_value_pence))
	state.role = str(portfolio.get("role", state.role))
	state.credibility = int(portfolio.get("credibility", state.credibility))
	state.home_symbol = str(portfolio.get("home_symbol", state.home_symbol))
	state.goals.assign(portfolio.get("goals", state.goals))
	state.goal_results.assign(portfolio.get("goal_results", state.goal_results))
	state.research_reports = portfolio.get("research_reports", state.research_reports).duplicate(true)
	state.last_dividend_pence = int(portfolio.get("last_dividend_pence", 0))
	state.cooperative_reward_pence = int(portfolio.get("cooperative_reward_pence", 0))
	state.pumped_symbols.clear()
	state.sabotaged_symbols.clear()
	state.fake_news_symbols.clear()
	for symbol in portfolio.get("pumped_symbols", []):
		state.mark_pumped(str(symbol))
	for symbol in portfolio.get("sabotaged_symbols", []):
		state.mark_sabotaged(str(symbol))
	for symbol in portfolio.get("fake_news_symbols", []):
		state.mark_fake_news_planted(str(symbol))

# Hides planted-story data on stocks the viewer did not plant on.
static func redact_planted_news(market: Dictionary, own_symbols: Dictionary) -> void:
	for record in market.get("stocks", []):
		if own_symbols.has(str(record["symbol"])):
			continue
		record["fake_news_active"] = false
		record["fake_news_direction"] = 0
		record["fake_news_projection_weight"] = 0.0

static func redact_resolutions(resolutions: Array[Dictionary], own_symbols: Dictionary) -> Array[Dictionary]:
	var redacted: Array[Dictionary] = []
	for resolution in resolutions:
		var copy := resolution.duplicate()
		if not own_symbols.has(str(copy.get("symbol", ""))):
			copy["fake_news_used"] = false
			copy["fake_news_direction"] = 0
			copy["fake_news_outcome"] = "none"
		redacted.append(copy)
	return redacted
