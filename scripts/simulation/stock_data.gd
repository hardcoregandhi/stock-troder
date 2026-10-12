class_name StockData
extends RefCounted

var symbol: String
var company_name: String
var personality: String
var current_price_pence: int
var previous_price_pence: int
var round_open_price_pence: int
var price_history_pence: Array[int] = []
var live_price_history_pence: Array[int] = []
var round_history_pence: Array = []
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
var pump_active: bool = false
var pump_live_boost: float = 0.0
var sabotage_active: bool = false
var sabotage_live_pressure: float = 0.0
var fake_news_direction: int = 0
var fake_news_projection_weight: float = 0.0
var fake_news_active: bool = false

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
	round_open_price_pence = initial_price_pence
	price_history_pence.append(initial_price_pence)
	volatility = stock_volatility
	trend = stock_trend
	news_events = stock_news_events.duplicate(true)

static func create_default_catalog(stock_count: int = 6) -> Array[StockData]:
	var catalog: Array[StockData] = [
		StockData.new("AUR", "Aurora Robotics", "Volatile growth stock", 5_000, 0.085, 0.012, [
			{"text": "Prototype demonstration draws attention", "impact": 0.035},
			{"text": "Manufacturing costs rise unexpectedly", "impact": -0.030},
		]),
		StockData.new("BRK", "Brickline Retail", "Stable consumer stock", 10_000, 0.035, 0.004, [
			{"text": "Quarterly sales remain steady", "impact": 0.012},
			{"text": "Retail footfall softens slightly", "impact": -0.010},
		]),
		StockData.new("CYN", "Cyanic Energy", "News-sensitive energy stock", 25_000, 0.075, 0.002, [
			{"text": "New energy contract announced", "impact": 0.040},
			{"text": "Regulatory review creates uncertainty", "impact": -0.045},
		]),
		StockData.new("DSK", "Deskbound Software", "Moderate technology stock", 50_000, 0.055, 0.008, [
			{"text": "Subscription growth beats expectations", "impact": 0.022},
			{"text": "A major client delays renewal", "impact": -0.020},
		]),
		StockData.new("EGF", "Evergreen Foods", "Defensive, slower-moving stock", 75_000, 0.022, 0.003, [
			{"text": "Staple food demand stays resilient", "impact": 0.010},
			{"text": "Input prices pressure margins", "impact": -0.012},
		]),
		StockData.new("FRB", "Frontier Biotech", "High-risk binary events", 100_000, 0.120, 0.0, [
			{"text": "Clinical trial results look promising", "impact": 0.095},
			{"text": "Clinical trial results disappoint", "impact": -0.110},
		]),
	]
	return catalog.slice(0, clampi(stock_count, 1, catalog.size()))

static func color_for_index(index: int) -> Color:
	var palette := [
		Color("65b9d6"),
		Color("f2c14e"),
		Color("e76f51"),
		Color("7bd389"),
		Color("c084fc"),
		Color("f78fb3"),
	]
	return palette[wrapi(index, 0, palette.size())]

func set_projection(change: float, low: float, high: float, news: String, impact: float) -> void:
	round_open_price_pence = current_price_pence
	live_price_history_pence.clear()
	live_price_history_pence.append(current_price_pence)
	pump_active = false
	pump_live_boost = 0.0
	sabotage_active = false
	sabotage_live_pressure = 0.0
	fake_news_direction = 0
	fake_news_projection_weight = 0.0
	fake_news_active = false
	projection_change = change
	projection_low = low
	projection_high = high
	projection_direction = signi(change)
	projection_confidence = _confidence_label()
	current_news = news
	news_impact = impact
	var projected_price: int = roundi(float(current_price_pence) * (1.0 + change))
	projected_price_pence = maxi(100, projected_price)

func set_live_price(price_pence: int) -> void:
	current_price_pence = maxi(100, price_pence)
	live_price_history_pence.append(current_price_pence)

func append_resolved_price(price_pence: int) -> void:
	previous_price_pence = current_price_pence
	current_price_pence = maxi(100, price_pence)
	price_history_pence.append(current_price_pence)
	live_price_history_pence.append(current_price_pence)
	round_history_pence.append(live_price_history_pence.duplicate())

func activate_pump(live_boost: float) -> void:
	pump_active = true
	pump_live_boost = live_boost

func activate_sabotage(live_pressure: float) -> void:
	sabotage_active = true
	sabotage_live_pressure = live_pressure

func activate_fake_news(direction: int, projection_weight: float, base_news: String) -> void:
	fake_news_direction = clampi(direction, -1, 1)
	fake_news_projection_weight = projection_weight
	fake_news_active = true
	if current_news.is_empty():
		current_news = base_news if not base_news.is_empty() else (str(news_events[0].get("text", "Market update")) if not news_events.is_empty() else "Market update")

func clear_pump() -> void:
	pump_active = false
	pump_live_boost = 0.0

func clear_manipulation() -> void:
	clear_pump()
	sabotage_active = false
	sabotage_live_pressure = 0.0
	fake_news_direction = 0
	fake_news_projection_weight = 0.0
	fake_news_active = false

func graph_history_pence() -> Array[int]:
	var history: Array[int] = []
	for round_prices in round_history_pence:
		history.append_array(round_prices)
	history.append_array(live_price_history_pence)
	return history

func recent_performance_weight(round_count: int = 3, response_weight: float = 0.18, maximum_weight: float = 0.025) -> float:
	if price_history_pence.size() < 2:
		return 0.0
	var first_round := maxi(1, price_history_pence.size() - round_count)
	var total_change := 0.0
	var sample_count := 0
	for index in range(first_round, price_history_pence.size()):
		var opening_price := price_history_pence[index - 1]
		if opening_price <= 0:
			continue
		total_change += float(price_history_pence[index] - opening_price) / float(opening_price)
		sample_count += 1
	if sample_count == 0:
		return 0.0
	return clampf((total_change / float(sample_count)) * response_weight, -maximum_weight, maximum_weight)

func _confidence_label() -> String:
	if volatility <= 0.03:
		return "High"
	if volatility <= 0.08:
		return "Moderate"
	return "Speculative"
