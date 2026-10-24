class_name RoundResolutionService
extends RefCounted

func settle_options(state: GameState) -> Array[Dictionary]:
	var settlements: Array[Dictionary] = []
	for option in state.option_positions:
		var stock := state.get_stock(option.symbol)
		if stock == null:
			continue
		var payout := option.payoff_pence(stock.current_price_pence)
		state.cash_pence += payout
		settlements.append({
			"type": option.option_type,
			"symbol": option.symbol,
			"strike_price_pence": option.strike_price_pence,
			"payout_pence": payout,
			"quantity": option.quantity,
		})
	state.clear_option_positions()
	return settlements

# Runs after every close, before any final liquidation.
func apply_close_effects(state: GameState) -> void:
	state.last_dividend_pence = roundi(float(state.held_share_value_pence()) * float(PlayerRole.value(state.role, "daily_dividend_rate")))
	state.cash_pence += state.last_dividend_pence
	state.add_credibility_from_holdings()

# Must run before liquidation because goals score held positions.
func score_final_goals(state: GameState, cooperative_goal: Dictionary) -> void:
	state.goal_results = PlayerGoals.evaluate(state)
	for result in state.goal_results:
		if bool(result["complete"]):
			state.cash_pence += int(result["reward_pence"])
	state.cooperative_reward_pence = 0
	if cooperative_goal.is_empty():
		return
	var bellwether := state.get_stock(str(cooperative_goal.get("symbol", "")))
	if bellwether != null and bellwether.current_price_pence >= int(cooperative_goal.get("target_pence", 0)):
		state.cooperative_reward_pence = int(cooperative_goal.get("reward_pence", 0))
		state.cash_pence += state.cooperative_reward_pence

func round_record(
	state: GameState,
	day: int,
	resolutions: Array[Dictionary],
	option_results: Array[Dictionary] = []
) -> Dictionary:
	var records: Array[Dictionary] = []
	for stock in state.stocks:
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
		"player_cash_pence": state.cash_pence,
		"player_portfolio_value_pence": state.portfolio_value_pence(),
		"player_return_pence": state.total_return_pence(),
		"player_holdings": state.holdings.duplicate(),
		"player_dividend_pence": state.last_dividend_pence,
		"player_influence_level": state.influence_level(),
		"market_crash": resolutions.any(func(item: Dictionary) -> bool: return bool(item.get("market_crash", false))),
		"pump_markers": resolutions.filter(func(item: Dictionary) -> bool: return bool(item.get("pump_used", false))),
		"sabotage_markers": resolutions.filter(func(item: Dictionary) -> bool: return bool(item.get("sabotage_used", false))),
		"fake_news_markers": resolutions.filter(func(item: Dictionary) -> bool: return bool(item.get("fake_news_used", false))),
		"option_settlements": option_results.duplicate(true),
	}

func _percentage_change(opening_price_pence: int, closing_price_pence: int) -> float:
	if opening_price_pence <= 0:
		return 0.0
	return float(closing_price_pence - opening_price_pence) / float(opening_price_pence)
