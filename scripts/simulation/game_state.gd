class_name GameState
extends RefCounted

enum Phase {
	PREPARING,
	TRADING,
	RESOLVING,
	COMPLETE,
}

const STARTING_CASH_PENCE: int = 1_000_000
const DEFAULT_TOTAL_DAYS: int = 10

var starting_cash_pence: int = STARTING_CASH_PENCE
var cash_pence: int = STARTING_CASH_PENCE
var current_day: int = 1
var total_days: int = DEFAULT_TOTAL_DAYS
var phase: Phase = Phase.PREPARING
var stocks: Array[StockData] = []
var holdings: Dictionary = {}
var seed: int

const TRADE_SERVICE = preload("res://scripts/application/trade_service.gd")

func _init(run_seed: int = 0, run_total_days: int = DEFAULT_TOTAL_DAYS) -> void:
	seed = run_seed
	total_days = maxi(1, run_total_days)
	stocks = StockData.create_default_catalog()
	for stock in stocks:
		holdings[stock.symbol] = 0

static func create_default(run_seed: int = 0, run_total_days: int = DEFAULT_TOTAL_DAYS) -> GameState:
	return GameState.new(run_seed, run_total_days)

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

func portfolio_value_pence() -> int:
	var value := cash_pence
	for stock in stocks:
		value += stock.current_price_pence * int(holdings[stock.symbol])
	return value

func total_return_pence() -> int:
	return portfolio_value_pence() - starting_cash_pence

