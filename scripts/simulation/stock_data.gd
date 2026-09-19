class_name StockData
extends RefCounted

var symbol: String
var company_name: String
var personality: String
var current_price_pence: int
var previous_price_pence: int
var price_history_pence: Array[int] = []
var volatility: float
var trend: float
var news_events: Array[Dictionary] = []
var projection_change: float = 0.0
var projection_low: float = 0.0
var projection_high: float = 0.0
var projection_direction: int = 0
var projection_confidence: String = ""
var current_news: String = ""
var news_impact: float = 0.0
var projected_price_pence: int = 0

func _init(
	stock_symbol: String,
	stock_company_name: String,
	stock_personality: String,
	initial_price_pence: int,
	stock_volatility: float,
	stock_trend: float,
	stock_news_events: Array[Dictionary] = []
) -> void:
	symbol = stock_symbol
	company_name = stock_company_name
	personality = stock_personality
	current_price_pence = initial_price_pence
	previous_price_pence = initial_price_pence
	price_history_pence.append(initial_price_pence)
	volatility = stock_volatility
	trend = stock_trend
	news_events = stock_news_events.duplicate(true)

static func create_default_catalog() -> Array[StockData]:
	return [
		StockData.new("AUR", "Aurora Robotics", "Volatile growth stock", 1_250, 0.085, 0.012, [
			{"text": "Prototype demonstration draws attention", "impact": 0.035},
			{"text": "Manufacturing costs rise unexpectedly", "impact": -0.030},
		]),
		StockData.new("BRK", "Brickline Retail", "Stable consumer stock", 850, 0.035, 0.004, [
			{"text": "Quarterly sales remain steady", "impact": 0.012},
			{"text": "Retail footfall softens slightly", "impact": -0.010},
		]),
		StockData.new("CYN", "Cyanic Energy", "News-sensitive energy stock", 1_420, 0.075, 0.002, [
			{"text": "New energy contract announced", "impact": 0.040},
			{"text": "Regulatory review creates uncertainty", "impact": -0.045},
		]),
		StockData.new("DSK", "Deskbound Software", "Moderate technology stock", 1_100, 0.055, 0.008, [
			{"text": "Subscription growth beats expectations", "impact": 0.022},
			{"text": "A major client delays renewal", "impact": -0.020},
		]),
		StockData.new("HBR", "Harbor Foods", "Defensive, slower-moving stock", 680, 0.022, 0.003, [
			{"text": "Staple food demand stays resilient", "impact": 0.010},
			{"text": "Input prices pressure margins", "impact": -0.012},
		]),
		StockData.new("NOV", "Nova Biotech", "High-risk binary events", 2_100, 0.120, 0.0, [
			{"text": "Clinical trial results look promising", "impact": 0.095},
			{"text": "Clinical trial results disappoint", "impact": -0.110},
		]),
	]

func set_projection(change: float, low: float, high: float, news: String, impact: float) -> void:
	projection_change = change
	projection_low = low
	projection_high = high
	projection_direction = signi(change)
	projection_confidence = _confidence_label()
	current_news = news
	news_impact = impact
	projected_price_pence = maxi(100, roundi(float(current_price_pence) * (1.0 + change)))

func append_resolved_price(price_pence: int) -> void:
	previous_price_pence = current_price_pence
	current_price_pence = maxi(100, price_pence)
	price_history_pence.append(current_price_pence)

func _confidence_label() -> String:
	if volatility <= 0.03:
		return "High"
	if volatility <= 0.08:
		return "Moderate"
	return "Speculative"
