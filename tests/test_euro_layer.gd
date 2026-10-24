@tool
extends McpTestSuite

const GAME_STATE = preload("res://scripts/simulation/game_state.gd")
const MARKET_SIMULATOR = preload("res://scripts/simulation/market_simulator.gd")
const TRADE_SERVICE = preload("res://scripts/application/trade_service.gd")
const TRADING_SESSION = preload("res://scripts/application/trading_session.gd")
const ROUND_RESOLUTION_SERVICE = preload("res://scripts/application/round_resolution_service.gd")
const RUN_SETUP_SERVICE = preload("res://scripts/application/run_setup_service.gd")
const NETWORK_SNAPSHOT_SERVICE = preload("res://scripts/application/network_snapshot_service.gd")

func suite_name() -> String:
	return "euro_layer"

func test_roles_change_option_premiums() -> void:
	var stock: StockData = GAME_STATE.new(1, 2).get_stock("AUR")
	var base := TRADE_SERVICE.option_premium_pence(stock, 1.0, PlayerRole.NONE)
	assert_true(TRADE_SERVICE.option_premium_pence(stock, 1.0, PlayerRole.HEDGIE) < base)
	assert_true(TRADE_SERVICE.option_premium_pence(stock, 1.0, PlayerRole.PENSION) > base)

func test_redditor_is_cheap_and_belford_is_strong() -> void:
	var redditor := _trading_state(PlayerRole.REDDITOR)
	var belford := _trading_state(PlayerRole.BELFORD)
	var trader := _trading_state(PlayerRole.NONE)
	var service := TRADE_SERVICE.new()
	var redditor_result := service.plant_fake_news(redditor, "AUR", 1)
	var belford_result := service.plant_fake_news(belford, "AUR", 1)
	var trader_result := service.plant_fake_news(trader, "AUR", 1)
	assert_eq(redditor_result["cost_pence"], 4_000)
	assert_eq(belford_result["cost_pence"], 12_000)
	assert_true(float(belford_result["live_pressure"]) > float(trader_result["live_pressure"]))
	assert_eq(redditor.get_stock("AUR").fake_news_backfire_chance, 0.30)

func test_insider_cannot_plant_news() -> void:
	var state := _trading_state(PlayerRole.INSIDER)
	var result := TRADE_SERVICE.new().plant_fake_news(state, "AUR", 1)
	assert_false(result["success"])
	assert_eq(state.cash_pence, state.starting_cash_pence)
	assert_false(state.get_stock("AUR").fake_news_active)

func test_influence_builds_from_held_value_and_strengthens_hype() -> void:
	var weak := _trading_state(PlayerRole.NONE)
	var strong := _trading_state(PlayerRole.NONE)
	strong.holdings["FRB"] = 1
	for _day in 4:
		strong.add_credibility_from_holdings()
	assert_eq(strong.credibility, 16)
	assert_eq(strong.influence_level(), 4)
	var service := TRADE_SERVICE.new()
	var weak_weight := float(service.plant_fake_news(weak, "AUR", 1)["live_pressure"])
	var strong_weight := float(service.plant_fake_news(strong, "AUR", 1)["live_pressure"])
	assert_true(strong_weight > weak_weight)
	for _day in 10:
		strong.add_credibility_from_holdings()
	assert_eq(strong.influence_level(), GameState.MAX_INFLUENCE_LEVEL)

func test_pension_dividend_is_paid_at_close() -> void:
	var state := _trading_state(PlayerRole.PENSION)
	state.holdings["BRK"] = 5
	var cash_before := state.cash_pence
	ROUND_RESOLUTION_SERVICE.new().apply_close_effects(state)
	assert_eq(state.last_dividend_pence, 500)
	assert_eq(state.cash_pence, cash_before + 500)

func test_starting_hand_deals_stake_goals_and_return_baseline() -> void:
	var state: GameState = GAME_STATE.new(9, 10)
	RUN_SETUP_SERVICE.deal_starting_hand(state, 9, 0, PlayerRole.HEDGIE)
	assert_eq(state.role, PlayerRole.HEDGIE)
	assert_false(state.home_symbol.is_empty())
	var stake := int(state.holdings[state.home_symbol])
	assert_gt(stake, 0)
	assert_eq(state.cash_pence, GameState.STARTING_CASH_PENCE)
	assert_eq(state.total_return_pence(), 0)
	assert_eq(state.goals.size(), 2)
	assert_eq(state.goals[0]["type"], PlayerGoals.HOLD)
	assert_eq(state.goals[0]["target"], stake * 2)

func test_same_seed_deals_same_hand_and_players_differ() -> void:
	var first: GameState = GAME_STATE.new(9, 10)
	var second: GameState = GAME_STATE.new(9, 10)
	var other: GameState = GAME_STATE.new(9, 10)
	RUN_SETUP_SERVICE.deal_starting_hand(first, 9, 0, PlayerRole.NONE)
	RUN_SETUP_SERVICE.deal_starting_hand(second, 9, 0, PlayerRole.NONE)
	RUN_SETUP_SERVICE.deal_starting_hand(other, 9, 1, PlayerRole.NONE)
	assert_eq(first.goals, second.goals)
	assert_ne(first.home_symbol, other.home_symbol)

func test_goal_rewards_are_paid_only_when_complete() -> void:
	var state: GameState = GAME_STATE.new(9, 10)
	state.goals = [
		{"type": PlayerGoals.HOLD, "symbol": "AUR", "target": 2, "reward_pence": 12_000, "text": "Hold 2 AUR"},
		{"type": PlayerGoals.SPREAD, "symbol": "", "target": 3, "reward_pence": 8_000, "text": "Hold 3 stocks"},
	]
	state.holdings["AUR"] = 2
	var cash_before := state.cash_pence
	ROUND_RESOLUTION_SERVICE.new().score_final_goals(state, {})
	assert_eq(state.cash_pence, cash_before + 12_000)
	assert_true(state.goal_results[0]["complete"])
	assert_false(state.goal_results[1]["complete"])

func test_research_reveals_tomorrows_story_privately() -> void:
	var session := _new_session()
	session.start_run(21, 3, GameState.DEFAULT_STOCK_COUNT, false)
	var cash_before := session.game_state.cash_pence
	var result := session.buy_research("CYN")
	assert_true(result["success"])
	assert_eq(session.game_state.cash_pence, cash_before - GameState.RESEARCH_COST_PENCE)
	var report: Dictionary = session.game_state.research_reports["CYN"]
	assert_eq(report["day"], 2)
	assert_false(session.buy_research("CYN")["success"])
	assert_true(session.start_trading_round())
	session._on_day_timer_timed_out()
	assert_true(session.continue_to_next_day())
	var stock := session.game_state.get_stock("CYN")
	assert_eq(stock.current_news, report["text"])
	assert_true(absf(stock.projection_change - float(report["base_change"])) <= MarketSimulator.MAX_HISTORY_INFLUENCE + 0.0001)

func test_research_is_unavailable_on_the_final_day() -> void:
	var session := _new_session()
	session.start_run(22, 1, GameState.DEFAULT_STOCK_COUNT, false)
	var result := session.buy_research("AUR")
	assert_false(result["success"])
	assert_eq(session.game_state.cash_pence, GameState.STARTING_CASH_PENCE)

func test_bellwether_breaking_its_floor_crashes_every_stock() -> void:
	var state: GameState = GAME_STATE.new(5, 3)
	var simulator: MarketSimulator = MARKET_SIMULATOR.new(5)
	simulator.prepare_day(state)
	simulator.start_trading(state)
	var calm_state: GameState = GAME_STATE.new(5, 3)
	var calm_simulator: MarketSimulator = MARKET_SIMULATOR.new(5)
	calm_simulator.prepare_day(calm_state)
	calm_simulator.start_trading(calm_state)
	state.cooperative_goal = RUN_SETUP_SERVICE.cooperative_goal(state, 5)
	state.cooperative_goal["floor_pence"] = 1_000_000
	var crashed := simulator.resolve_day(state)
	var calm := calm_simulator.resolve_day(calm_state)
	assert_true(crashed[0]["market_crash"])
	assert_false(calm[0]["market_crash"])
	for index in crashed.size():
		assert_true(int(crashed[index]["closing_price_pence"]) < int(calm[index]["closing_price_pence"]))
	assert_eq(state.cooperative_goal["crash_count"], 1)
	assert_true(int(state.cooperative_goal["floor_pence"]) < 1_000_000)

func test_cooperative_reward_is_paid_when_target_is_met() -> void:
	var state: GameState = GAME_STATE.new(5, 3)
	var goal := RUN_SETUP_SERVICE.cooperative_goal(state, 5)
	state.get_stock(str(goal["symbol"])).current_price_pence = int(goal["target_pence"])
	var cash_before := state.cash_pence
	ROUND_RESOLUTION_SERVICE.new().score_final_goals(state, goal)
	assert_eq(state.cooperative_reward_pence, RunSetupService.COOPERATIVE_REWARD_PENCE)
	assert_eq(state.cash_pence, cash_before + RunSetupService.COOPERATIVE_REWARD_PENCE)

func test_final_day_pays_goals_before_liquidation() -> void:
	var session := _new_session()
	session.start_run(23, 1, GameState.DEFAULT_STOCK_COUNT, false)
	var home := session.game_state.home_symbol
	session.game_state.goals = [{"type": PlayerGoals.HOLD, "symbol": home, "target": 1, "reward_pence": 12_000, "text": "Hold 1"}]
	assert_true(session.start_trading_round())
	session._on_day_timer_timed_out()
	assert_true(session.game_state.goal_results[0]["complete"])
	assert_eq(session.game_state.holdings[home], 0)

func test_other_players_planted_news_looks_like_company_news() -> void:
	var session := _new_session()
	session.start_run(24, 2)
	var stories: Array[Dictionary] = []
	session.market_news_event.connect(func(story: Dictionary) -> void: stories.append(story))
	var result := {"symbol": "AUR", "headline": "Prototype demonstration draws attention", "live_pressure": 0.03, "direction": 1}
	session._announce_story(2, result)
	assert_eq(stories[0]["source"], "COMPANY NEWS")
	assert_false(stories[0].has("planted_direction"))
	session.game_state.role = PlayerRole.INSIDER
	session._announce_story(2, result)
	assert_eq(stories[1]["planted_direction"], 1)

func test_resolution_redaction_keeps_only_own_planted_outcomes() -> void:
	var resolutions: Array[Dictionary] = [
		{"symbol": "AUR", "fake_news_used": true, "fake_news_direction": 1, "fake_news_outcome": "worked"},
		{"symbol": "BRK", "fake_news_used": true, "fake_news_direction": -1, "fake_news_outcome": "backfired"},
	]
	var redacted := NETWORK_SNAPSHOT_SERVICE.redact_resolutions(resolutions, {"AUR": true})
	assert_true(redacted[0]["fake_news_used"])
	assert_false(redacted[1]["fake_news_used"])
	assert_eq(redacted[1]["fake_news_outcome"], "none")
	assert_true(resolutions[1]["fake_news_used"])

func test_portfolio_snapshot_round_trips_private_state() -> void:
	var host_state: GameState = GAME_STATE.new(9, 10)
	RUN_SETUP_SERVICE.deal_starting_hand(host_state, 9, 0, PlayerRole.REDDITOR)
	host_state.mark_fake_news_planted("BRK")
	host_state.credibility = 7
	host_state.research_reports["AUR"] = {"day": 2, "text": "Story", "impact": 0.0, "base_change": 0.01}
	var client_state: GameState = GAME_STATE.new(0, 10)
	NETWORK_SNAPSHOT_SERVICE.apply_portfolio_snapshot(client_state, NETWORK_SNAPSHOT_SERVICE.portfolio_snapshot(host_state))
	assert_eq(client_state.role, PlayerRole.REDDITOR)
	assert_eq(client_state.credibility, 7)
	assert_eq(client_state.goals, host_state.goals)
	assert_eq(client_state.starting_value_pence, host_state.starting_value_pence)
	assert_true(client_state.has_planted_fake_news("BRK"))
	assert_eq(client_state.research_reports["AUR"]["text"], "Story")

func test_network_host_deals_distinct_roles() -> void:
	var roles := RUN_SETUP_SERVICE.network_roles(42, 4)
	assert_eq(roles.size(), 4)
	var unique: Dictionary = {}
	for role_id in roles:
		unique[role_id] = true
	assert_eq(unique.size(), 4)

func _trading_state(role_id: String) -> GameState:
	var state: GameState = GAME_STATE.new(42, 3)
	state.role = role_id
	state.phase = GameState.Phase.TRADING
	return state

func _new_session() -> TradingSession:
	var session: TradingSession = TRADING_SESSION.new()
	track(session)
	session._ready()
	return session
