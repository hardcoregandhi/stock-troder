class_name GameState
extends RefCounted

enum Phase {
	PREPARING,
	BRIEF,
	TRADING,
	RESOLVING,
	DEBRIEF,
	COMPLETE,
}

const STARTING_CASH_PENCE: int = 100_000
const DEFAULT_TOTAL_DAYS: int = 10
const DEFAULT_STOCK_COUNT: int = 6
const MIN_STOCK_COUNT: int = 1
const MAX_STOCK_COUNT: int = 6
const PUMP_COST_PENCE: int = 2_500
const SABOTAGE_COST_PENCE: int = 5_000
const FAKE_NEWS_COST_PENCE: int = 7_500
const RESEARCH_COST_PENCE: int = 3_000
const MANIPULATION_COOLDOWN_DAYS: int = 1
const CREDIBILITY_PER_LEVEL: int = 4
const MAX_INFLUENCE_LEVEL: int = 5
const CREDIBILITY_HELD_VALUE_STEP_PENCE: int = 25_000

var starting_cash_pence: int = STARTING_CASH_PENCE
var starting_value_pence: int = STARTING_CASH_PENCE
var cash_pence: int = STARTING_CASH_PENCE
var current_day: int = 1
var total_days: int = DEFAULT_TOTAL_DAYS
var phase: Phase = Phase.PREPARING
var stocks: Array[StockData] = []
var holdings: Dictionary = {}
var option_positions: Array[OptionContract] = []
var pumped_symbols: Dictionary = {}
var sabotaged_symbols: Dictionary = {}
var fake_news_symbols: Dictionary = {}
var manipulation_cooldowns: Dictionary = {}
var stock_count: int = DEFAULT_STOCK_COUNT
var role: String = PlayerRole.NONE
var credibility: int = 0
var home_symbol: String = ""
var goals: Array[Dictionary] = []
var goal_results: Array[Dictionary] = []
var research_reports: Dictionary = {}
var last_dividend_pence: int = 0
var cooperative_reward_pence: int = 0
# Shared market-stability goal; only the authoritative market state mutates it.
var cooperative_goal: Dictionary = {}

const TRADE_SERVICE = preload("res://scripts/application/trade_service.gd")

func _init(run_seed: int = 0, run_total_days: int = DEFAULT_TOTAL_DAYS, run_stock_count: int = DEFAULT_STOCK_COUNT) -> void:
	total_days = maxi(1, run_total_days)
	stock_count = clampi(run_stock_count, MIN_STOCK_COUNT, MAX_STOCK_COUNT)
	stocks = StockData.create_default_catalog(stock_count)
	for stock in stocks:
		holdings[stock.symbol] = 0

static func create_default(run_seed: int = 0, run_total_days: int = DEFAULT_TOTAL_DAYS, run_stock_count: int = DEFAULT_STOCK_COUNT) -> GameState:
	return GameState.new(run_seed, run_total_days, run_stock_count)

func get_stock(symbol: String) -> StockData:
	for stock in stocks:
		if stock.symbol == symbol:
			return stock
	return null

func buy_shares(symbol: String, quantity: int) -> Dictionary:
	return TRADE_SERVICE.new().buy(self, symbol, quantity)

func sell_shares(symbol: String, quantity: int) -> Dictionary:
	return TRADE_SERVICE.new().sell(self, symbol, quantity)

func apply_buy_shares(symbol: String, quantity: int) -> void:
	var stock := get_stock(symbol)
	cash_pence -= stock.current_price_pence * quantity
	holdings[symbol] += quantity

func apply_sell_shares(symbol: String, quantity: int) -> void:
	var stock := get_stock(symbol)
	cash_pence += stock.current_price_pence * quantity
	holdings[symbol] -= quantity

func add_option_position(option: OptionContract) -> void:
	option_positions.append(option)

func clear_option_positions() -> void:
	option_positions.clear()

func mark_pumped(symbol: String) -> void:
	pumped_symbols[symbol] = true

func has_pumped(symbol: String) -> bool:
	return bool(pumped_symbols.get(symbol, false))

func action_on_cooldown(action: String, symbol: String) -> bool:
	return current_day < int(manipulation_cooldowns.get("%s:%s" % [action, symbol], 0))

func set_action_cooldown(action: String, symbol: String) -> void:
	manipulation_cooldowns["%s:%s" % [action, symbol]] = current_day + MANIPULATION_COOLDOWN_DAYS + 1

func mark_sabotaged(symbol: String) -> void:
	sabotaged_symbols[symbol] = true

func has_sabotaged(symbol: String) -> bool:
	return bool(sabotaged_symbols.get(symbol, false))

func mark_fake_news_planted(symbol: String) -> void:
	fake_news_symbols[symbol] = true

func has_planted_fake_news(symbol: String) -> bool:
	return bool(fake_news_symbols.get(symbol, false))

func reset_round_manipulations() -> void:
	pumped_symbols.clear()
	sabotaged_symbols.clear()
	fake_news_symbols.clear()
	for stock in stocks:
		stock.clear_manipulation()

func portfolio_value_pence() -> int:
	return cash_pence + held_share_value_pence()

func held_share_value_pence() -> int:
	var value := 0
	for stock in stocks:
		value += stock.current_price_pence * int(holdings[stock.symbol])
	return value

func total_return_pence() -> int:
	return portfolio_value_pence() - starting_value_pence

func grant_starting_shares(symbol: String, quantity: int) -> void:
	holdings[symbol] = int(holdings.get(symbol, 0)) + quantity
	starting_value_pence = portfolio_value_pence()

func influence_level() -> int:
	return mini(MAX_INFLUENCE_LEVEL, credibility / CREDIBILITY_PER_LEVEL)

func add_credibility_from_holdings() -> int:
	var maximum := MAX_INFLUENCE_LEVEL * CREDIBILITY_PER_LEVEL
	var gained := mini(held_share_value_pence() / CREDIBILITY_HELD_VALUE_STEP_PENCE, maximum - credibility)
	credibility += maxi(0, gained)
	return maxi(0, gained)
