class_name TradingDashboard
extends Control

const BG := Color("101820")
const PANEL := Color("182733")
const PANEL_LIGHT := Color("203545")
const TEXT := Color("edf4f6")
const MUTED := Color("9bb0b8")
const POSITIVE := Color("55d6a3")
const NEGATIVE := Color("ff7b72")
const ACCENT := Color("65b9d6")

var session: TradingSession
var day_label: Label
var clock_label: Label
var cash_label: Label
var portfolio_label: Label
var return_label: Label
var stock_list: GridContainer
var detail_title: Label
var detail_price_caption: Label
var detail_price: Label
var detail_projection: Label
var detail_news: Label
var detail_shares: Label
var trade_feedback: Label
var quantity: SpinBox
var pump_button: Button
var pump_status: Label
var network_status: Label
var chart: StockHistoryChart
var chart_legend: Control
var summary_panel: PanelContainer
var summary_layer: Control
var debrief_panel: PanelContainer
var debrief_layer: Control
	var brief_panel: PanelContainer
	var brief_layer: Control
	var debrief_chart: StockHistoryChart
	var debrief_chart_tabs: HBoxContainer
	var debrief_day_series: Array[Dictionary] = []
	var debrief_game_series: Array[Dictionary] = []
var selected_symbol := "AUR"
var row_labels: Dictionary = {}
var news_feed: VBoxContainer
var news_history: Array[Dictionary] = []

class StockHistoryChart extends Control:
	var series: Array[Dictionary] = []
	var grid_color := Color("2b4655")

	func set_series(new_series: Array[Dictionary]) -> void:
		series = new_series.duplicate(true)
		queue_redraw()

	func _draw() -> void:
		var area := Rect2(58.0, 18.0, size.x - 70.0, size.y - 48.0)
		if area.size.x <= 0.0 or area.size.y <= 0.0:
			return
		var drawable_series: Array[Dictionary] = []
		var minimum := INF
		var maximum := -INF
		for item in series:
			var values: Array = item.get("values", [])
			if values.size() < 2:
				continue
			drawable_series.append(item)
			minimum = minf(minimum, float(values.min()))
			maximum = maxf(maximum, float(values.max()))
		if drawable_series.is_empty():
			draw_string(ThemeDB.fallback_font, Vector2(66.0, size.y * 0.55), "History will appear after the first close", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, MUTED)
			return
		var spread := maxf(1.0, maximum - minimum)
		for index in range(5):
			var fraction := float(index) / 4.0
			var y := area.position.y + area.size.y * fraction
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), grid_color, 1.0)
			var label_value := maximum - spread * fraction
			draw_string(ThemeDB.fallback_font, Vector2(2.0, y + 4.0), _format_percentage(label_value), HORIZONTAL_ALIGNMENT_LEFT, 52.0, 11, MUTED)
		for index in range(1, 4):
			var x := area.position.x + area.size.x * float(index) / 4.0
			draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), grid_color, 1.0)
		draw_line(Vector2(area.position.x, area.end.y), Vector2(area.end.x, area.end.y), MUTED, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(area.position.x, size.y - 10.0), "OLDER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, MUTED)
		draw_string(ThemeDB.fallback_font, Vector2(area.end.x - 30.0, size.y - 10.0), "NOW", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, MUTED)
		draw_string(ThemeDB.fallback_font, Vector2(area.position.x, 12.0), "% FROM ROUND OPEN", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, MUTED)
		for item in drawable_series:
			var values: Array = item["values"]
			var points := PackedVector2Array()
			for index in values.size():
				var x := area.position.x + area.size.x * float(index) / float(values.size() - 1)
				var y := area.end.y - area.size.y * (float(values[index]) - minimum) / spread
				points.append(Vector2(x, y))
			var line_color: Color = item["color"]
			draw_polyline(points, line_color, 2.0, true)
			draw_circle(points[points.size() - 1], 3.0, line_color)

	func _format_percentage(value: float) -> String:
		return "%+.1f%%" % value

func setup(new_session: TradingSession) -> void:
	session = new_session
	_build_ui()
	session.run_started.connect(_on_state_changed)
	session.day_prepared.connect(_on_day_prepared)
	session.brief_started.connect(_on_brief_started)
	session.time_updated.connect(_on_time_updated)
	session.market_updated.connect(_on_market_updated)
	session.day_resolved.connect(_on_day_resolved)
	session.trade_completed.connect(_on_trade_result)
	session.trade_rejected.connect(_on_trade_result)
	session.pump_completed.connect(_on_trade_result)
	session.pump_rejected.connect(_on_trade_result)
	session.run_completed.connect(_on_run_completed)
	session.network_status_changed.connect(_on_network_status_changed)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)
	page.add_child(_build_header())
	page.add_child(_build_status_bar())
	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(body_scroll)
	var body := HBoxContainer.new()
	body.custom_minimum_size.y = 470
	body.add_theme_constant_override("separation", 14)
	body_scroll.add_child(body)
	body.add_child(_build_market_panel())
	body.add_child(_build_detail_panel())

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 48
	var title := Label.new()
	title.text = "STOCKTRODER"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TEXT)
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	day_label = _label("DAY 1 / 10", 18, TEXT)
	row.add_child(day_label)
	network_status = _label("", 12, MUTED)
	network_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	network_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(network_status)
	return row

func _build_status_bar() -> Control:
	var panel := _panel()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 2)
	panel.add_child(grid)
	clock_label = _status_item(grid, "TIME LEFT", "30.0s", ACCENT)
	cash_label = _status_item(grid, "CASH", "£0.00", TEXT)
	portfolio_label = _status_item(grid, "PORTFOLIO", "£0.00", TEXT)
	return_label = _status_item(grid, "RETURN", "£0.00", POSITIVE)
	return panel

func _status_item(parent: Control, caption: String, value: String, color: Color) -> Label:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 150
	parent.add_child(box)
	box.add_child(_label(caption, 11, MUTED))
	var result := _label(value, 20, color)
	box.add_child(result)
	return result

func _build_market_panel() -> Control:
	var panel := _panel()
	panel.custom_minimum_size.x = 690
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	content.add_child(_label("LIVE MARKET", 13, MUTED))
	content.add_child(_label("All configured stocks. Select a row for detail, or trade one share now.", 12, MUTED))
	chart = StockHistoryChart.new()
	chart.custom_minimum_size.y = 155
	chart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(chart)
	chart_legend = FlowContainer.new()
	chart_legend.add_theme_constant_override("separation", 12)
	chart_legend.custom_minimum_size.y = 26
	content.add_child(chart_legend)
	stock_list = GridContainer.new()
	stock_list.columns = 9
	stock_list.add_theme_constant_override("h_separation", 6)
	stock_list.add_theme_constant_override("v_separation", 5)
	_build_stock_header()
	stock_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(stock_list)
	return panel

func _build_detail_panel() -> Control:
	var panel := _panel()
	panel.custom_minimum_size.x = 360
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	detail_title = _label("AUR  Aurora Robotics", 22, TEXT)
	detail_title.custom_minimum_size.x = 300
	content.add_child(detail_title)
	detail_price_caption = _label("LIVE PRICE", 11, MUTED)
	content.add_child(detail_price_caption)
	detail_price = _label("£0.00", 30, TEXT)
	content.add_child(detail_price)
	detail_projection = _label("ESTIMATE  --", 14, ACCENT)
	detail_projection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_projection.custom_minimum_size = Vector2(300, 34)
	content.add_child(detail_projection)
	detail_news = _label("NEWS  --", 13, MUTED)
	detail_news.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_news.custom_minimum_size = Vector2(300, 42)
	content.add_child(detail_news)
	detail_shares = _label("Shares held: 0", 13, TEXT)
	content.add_child(detail_shares)
	var trade_row := HBoxContainer.new()
	trade_row.add_theme_constant_override("separation", 8)
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 999
	quantity.value = 1
	quantity.step = 1
	quantity.custom_minimum_size.x = 90
	trade_row.add_child(quantity)
	var buy_button := Button.new()
	buy_button.text = "BUY"
	buy_button.custom_minimum_size.x = 90
	buy_button.pressed.connect(_on_buy_detail)
	trade_row.add_child(buy_button)
	var sell_button := Button.new()
	sell_button.text = "SELL"
	sell_button.custom_minimum_size.x = 90
	sell_button.pressed.connect(_on_sell_detail)
	trade_row.add_child(sell_button)
	content.add_child(trade_row)
	trade_feedback = _label("Select a stock and place a trade.", 12, MUTED)
	trade_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trade_feedback.custom_minimum_size.x = 300
	content.add_child(trade_feedback)
	var pump_row := HBoxContainer.new()
	pump_row.add_theme_constant_override("separation", 8)
	pump_button = Button.new()
	pump_button.text = "PUMP"
	pump_button.tooltip_text = "Spend £25.00 to lift this stock's live path. Correction risk at resolution."
	pump_button.custom_minimum_size.x = 90
	pump_button.pressed.connect(_on_pump)
	pump_row.add_child(pump_button)
	pump_status = _label("PUMP COST £25.00 | Once per stock per round", 12, MUTED)
	pump_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pump_status.custom_minimum_size = Vector2(205, 38)
	pump_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pump_row.add_child(pump_status)
	content.add_child(pump_row)
	content.add_child(_label("NEWS FEED", 12, MUTED))
	var news_scroll := ScrollContainer.new()
	news_scroll.custom_minimum_size.y = 104
	news_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	news_feed = VBoxContainer.new()
	news_feed.custom_minimum_size.x = 300
	news_feed.add_theme_constant_override("separation", 5)
	news_scroll.add_child(news_feed)
	content.add_child(news_scroll)
	return panel

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_top = 14
	style.content_margin_right = 16
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _build_stock_header() -> void:
	for header in [
		_column_label("SYMBOL", 50),
		_column_label("COMPANY", 110),
		_column_label("LIVE", 68),
		_column_label("ROUND", 58),
		_column_label("EST. RANGE", 90),
		_column_label("SHARES", 42),
		_column_label("POSITION", 72),
		_column_label("BUY", 44),
		_column_label("SELL", 44),
	]:
		stock_list.add_child(header)

func _column_label(text: String, width: float) -> Label:
	var label := _label(text, 10, MUTED)
	label.custom_minimum_size.x = width
	label.clip_text = true
	return label

func _on_state_changed(_snapshot: Dictionary) -> void:
	_refresh()

func _on_day_prepared(_day: int, _projections: Array[Dictionary], _news: Array[Dictionary]) -> void:
	_refresh()

func _on_brief_started(day: int, _projections: Array[Dictionary], _news: Array[Dictionary]) -> void:
	_refresh()
	if session.game_state.phase == GameState.Phase.BRIEF:
		if brief_layer != null:
			brief_layer.free()
			brief_layer = null
			brief_panel = null
		_show_brief(day)

func _on_time_updated(seconds: float) -> void:
	if clock_label != null:
		clock_label.text = "%.1fs" % seconds
		clock_label.add_theme_color_override("font_color", NEGATIVE if seconds <= 5.0 else ACCENT)

func _on_market_updated(_snapshot: Dictionary) -> void:
	_refresh()
	if session.game_state.phase == GameState.Phase.BRIEF and brief_panel == null and summary_panel == null:
		_show_brief(session.game_state.current_day)

func _on_day_resolved(day: int, resolutions: Array[Dictionary], _snapshot: Dictionary) -> void:
	for resolution in resolutions:
		news_history.append({
			"day": day,
			"symbol": str(resolution["symbol"]),
			"text": str(resolution["news"]),
			"resolved": true,
			"change": float(resolution["percentage_change"]),
		})
	if news_history.size() > 18:
		news_history = news_history.slice(news_history.size() - 18)
	_refresh()
	if session.game_state.phase == GameState.Phase.DEBRIEF:
		_show_debrief(day, resolutions)

func _on_trade_result(result: Dictionary) -> void:
	trade_feedback.text = result["message"]
	trade_feedback.add_theme_color_override("font_color", POSITIVE if result["success"] else NEGATIVE)
	_refresh()

func _on_network_status_changed(message: String) -> void:
	if network_status != null:
		network_status.text = message

func _refresh() -> void:
	if session == null or session.game_state == null:
		return
	var state: GameState = session.game_state
	day_label.text = "DAY %d / %d" % [state.current_day, state.total_days]
	cash_label.text = _format_pence(state.cash_pence)
	portfolio_label.text = _format_pence(state.portfolio_value_pence())
	return_label.text = _signed_pence(state.total_return_pence())
	return_label.add_theme_color_override("font_color", POSITIVE if state.total_return_pence() >= 0 else NEGATIVE)
	if row_labels.is_empty():
		_build_stock_rows(state)
	else:
		_update_stock_rows(state)
	_update_detail(state)

func _build_stock_rows(state: GameState) -> void:
	for stock in state.stocks:
		var select := Button.new()
		select.text = stock.symbol
		select.add_theme_color_override("font_color", StockData.color_for_index(state.stocks.find(stock)))
		select.custom_minimum_size.x = 50
		select.pressed.connect(_select_stock.bind(stock.symbol))
		stock_list.add_child(select)
		var company := _label(stock.company_name, 12, TEXT)
		company.add_theme_color_override("font_color", StockData.color_for_index(state.stocks.find(stock)))
		company.custom_minimum_size.x = 110
		company.clip_text = true
		company.tooltip_text = stock.company_name
		stock_list.add_child(company)
		var price := _label("", 13, TEXT)
		price.custom_minimum_size.x = 68
		stock_list.add_child(price)
		var change := _label("", 12, ACCENT)
		change.custom_minimum_size.x = 58
		stock_list.add_child(change)
		var range := _label("", 11, ACCENT)
		range.custom_minimum_size.x = 90
		range.clip_text = true
		stock_list.add_child(range)
		var shares := _label("", 11, TEXT)
		shares.custom_minimum_size.x = 42
		stock_list.add_child(shares)
		var position := _label("", 11, TEXT)
		position.custom_minimum_size.x = 72
		position.clip_text = true
		stock_list.add_child(position)
		var buy := Button.new()
		buy.text = "BUY"
		buy.tooltip_text = "Buy one share"
		buy.custom_minimum_size.x = 44
		buy.pressed.connect(_quick_buy.bind(stock.symbol))
		stock_list.add_child(buy)
		var sell := Button.new()
		sell.text = "SELL"
		sell.tooltip_text = "Sell one share"
		sell.custom_minimum_size.x = 44
		sell.pressed.connect(_quick_sell.bind(stock.symbol))
		stock_list.add_child(sell)
		row_labels[stock.symbol] = {"price": price, "change": change, "range": range, "shares": shares, "position": position, "buy": buy, "sell": sell}
	_update_stock_rows(state)

func _update_stock_rows(state: GameState) -> void:
	for stock in state.stocks:
		var labels: Dictionary = row_labels[stock.symbol]
		labels["price"].text = _format_pence(stock.current_price_pence)
		var round_change := _round_change(stock)
		labels["change"].text = "%+.1f%%" % round_change
		labels["change"].add_theme_color_override("font_color", POSITIVE if round_change >= 0 else NEGATIVE)
		labels["range"].text = "%+.1f%% to %+.1f%%" % [stock.projection_low * 100.0, stock.projection_high * 100.0]
		var shares := int(state.holdings[stock.symbol])
		labels["shares"].text = "%d" % shares
		labels["position"].text = _format_pence(stock.current_price_pence * shares)
		var can_trade := state.phase == GameState.Phase.TRADING
		labels["buy"].disabled = not can_trade
		labels["sell"].disabled = not can_trade or shares <= 0

func _update_detail(state: GameState) -> void:
	var stock := state.get_stock(selected_symbol)
	if stock == null:
		return
	detail_title.text = "%s  %s" % [stock.symbol, stock.company_name]
	detail_price.text = _format_pence(stock.current_price_pence)
	detail_projection.text = "ESTIMATE  %+.1f%%  |  END RANGE %+.1f%% to %+.1f%%  |  %s" % [stock.projection_change * 100.0, stock.projection_low * 100.0, stock.projection_high * 100.0, stock.projection_confidence]
	detail_projection.add_theme_color_override("font_color", POSITIVE if stock.projection_change >= 0 else NEGATIVE)
	detail_news.text = "FORECAST NEWS  %s" % stock.current_news
	detail_shares.text = "Shares held: %d" % int(state.holdings[stock.symbol])
	if pump_button != null:
		pump_button.disabled = session.network_mode or state.phase != GameState.Phase.TRADING or state.has_pumped(stock.symbol) or state.cash_pence < GameState.PUMP_COST_PENCE
	if pump_status != null:
		if session.network_mode:
			pump_status.text = "PUMP unavailable in multiplayer"
		elif state.phase != GameState.Phase.TRADING:
			pump_status.text = "PUMP UNAVAILABLE outside the trading phase"
		elif state.has_pumped(stock.symbol):
			pump_status.text = "PUMP USED for %s this round" % stock.symbol
		elif state.cash_pence < GameState.PUMP_COST_PENCE:
			pump_status.text = "PUMP UNAVAILABLE | Need £25.00 cash"
		else:
			pump_status.text = "PUMP COST £25.00 | Once per stock per round"
	var chart_series: Array[Dictionary] = []
	for index in state.stocks.size():
		var chart_stock: StockData = state.stocks[index]
		chart_series.append({
			"symbol": chart_stock.symbol,
			"values": _graph_history_percentage(chart_stock),
			"color": StockData.color_for_index(index),
		})
	chart.set_series(chart_series)
	_update_chart_legend(state)
	_update_news_feed(state)

func _round_change(stock: StockData) -> float:
	if stock.round_open_price_pence <= 0:
		return 0.0
	return (float(stock.current_price_pence - stock.round_open_price_pence) / float(stock.round_open_price_pence)) * 100.0

func _graph_history_percentage(stock: StockData) -> Array[float]:
	var values: Array[float] = []
	if stock.round_open_price_pence <= 0:
		return values
	for price_pence in stock.graph_history_pence():
		values.append((float(price_pence - stock.round_open_price_pence) / float(stock.round_open_price_pence)) * 100.0)
	return values

func _update_news_feed(state: GameState) -> void:
	if news_feed == null:
		return
	for child in news_feed.get_children():
		child.queue_free()
	var entries: Array[Dictionary] = []
	for item in news_history:
		entries.append(item)
	for index in state.stocks.size():
		var stock: StockData = state.stocks[index]
		entries.append({
			"day": state.current_day,
			"symbol": stock.symbol,
			"text": stock.current_news,
			"resolved": false,
			"change": stock.projection_change,
			"color": StockData.color_for_index(index),
		})
	var first_entry := maxi(0, entries.size() - 8)
	for entry in entries.slice(first_entry):
		var color: Color = entry.get("color", NEGATIVE if float(entry["change"]) < 0.0 else POSITIVE)
		var status := "RESOLVED %+.1f%%" % (float(entry["change"]) * 100.0) if bool(entry["resolved"]) else "FORECAST"
		var item := _label("ROUND %d  %s  %s\n%s: %s" % [int(entry["day"]), str(entry["symbol"]), status, "" if bool(entry["resolved"]) else "SIGNAL", str(entry["text"])], 11, color)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.custom_minimum_size.x = 300
		news_feed.add_child(item)

func _update_chart_legend(state: GameState) -> void:
	if chart_legend == null:
		return
	for child in chart_legend.get_children():
		child.queue_free()
	for index in state.stocks.size():
		var stock: StockData = state.stocks[index]
		var item := _label("%s  %s  %s" % [stock.symbol, stock.company_name, _format_pence(stock.current_price_pence)], 11, StockData.color_for_index(index))
		item.custom_minimum_size.x = 145
		item.clip_text = true
		item.tooltip_text = "%s %s" % [stock.symbol, stock.company_name]
		chart_legend.add_child(item)

func _select_stock(symbol: String) -> void:
	selected_symbol = symbol
	_refresh()

func _quick_buy(symbol: String) -> void:
	selected_symbol = symbol
	session.buy(symbol, 1)

func _quick_sell(symbol: String) -> void:
	selected_symbol = symbol
	session.sell(symbol, 1)

func _on_buy_detail() -> void:
	session.buy(selected_symbol, int(quantity.value))

func _on_sell_detail() -> void:
	session.sell(selected_symbol, int(quantity.value))

func _on_pump() -> void:
	session.pump(selected_symbol)

func _show_debrief(day: int, resolutions: Array[Dictionary]) -> void:
	if debrief_panel != null:
		return
	debrief_layer = Control.new()
	debrief_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debrief_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(debrief_layer)
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debrief_layer.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	debrief_layer.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	debrief_panel = _panel()
	debrief_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(debrief_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	debrief_panel.add_child(content)
	content.add_child(_label("DAY %d DEBRIEF" % day, 24, TEXT))
	content.add_child(_label("Resolved prices, player result, action markers, and ranking.", 12, MUTED))
	debrief_day_series = _day_graph_series(resolutions)
	debrief_game_series = _game_graph_series()
	content.add_child(_build_debrief_chart())
	var results := VBoxContainer.new()
	results.add_theme_constant_override("separation", 4)
	content.add_child(results)
	results.add_child(_label("RESOLVED NEWS AND ACTION MARKERS", 12, MUTED))
	var round_record: Dictionary = session.completed_rounds.back() if not session.completed_rounds.is_empty() else {}
	var player_result := int(round_record.get("player_return_pence", session.game_state.total_return_pence()))
	results.add_child(_label("PLAYER RESULT  %s  |  PORTFOLIO %s  |  CASH %s" % [
		_signed_pence(player_result),
		_format_pence(int(round_record.get("player_portfolio_value_pence", session.game_state.portfolio_value_pence()))),
		_format_pence(int(round_record.get("player_cash_pence", session.game_state.cash_pence))),
	], 13, POSITIVE if player_result >= 0 else NEGATIVE))
	results.add_child(_label("SABOTAGE: unavailable in this build", 11, MUTED))
	for resolution in resolutions:
		var change := float(resolution["percentage_change"]) * 100.0
		var change_color := POSITIVE if change >= 0.0 else NEGATIVE
		var row := _label(
			"%s  %s -> %s  %+.1f%%\nRESOLVED NEWS  %s%s" % [
				resolution["symbol"],
				_format_pence(int(resolution["opening_price_pence"])),
				_format_pence(int(resolution["closing_price_pence"])),
				change,
				resolution["news"],
				"\nPUMP CORRECTION AFFECTED RESULT" if bool(resolution.get("pump_correction", false)) else ("\nPUMP RESOLVED WITHOUT CORRECTION" if bool(resolution.get("pump_used", false)) else ""),
			],
			12,
			change_color,
		)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		results.add_child(row)
		results.add_child(_label("PUMP MARKER: %s" % resolution["symbol"] if bool(resolution.get("pump_used", false)) else "PUMP MARKER: none", 11, ACCENT if bool(resolution.get("pump_used", false)) else MUTED))
	content.add_child(_build_rankings_panel(_display_rankings()))
	if session.game_state.phase == GameState.Phase.DEBRIEF:
		var next_day := Button.new()
		next_day.text = "NEXT DAY"
		next_day.custom_minimum_size.y = 38
		next_day.pressed.connect(_continue_after_debrief)
		content.add_child(next_day)

func _continue_after_debrief() -> void:
	if session.continue_to_next_day() and debrief_panel != null:
		debrief_layer.queue_free()
		debrief_layer = null
		debrief_panel = null

func _show_brief(day: int) -> void:
	if brief_panel != null or summary_panel != null:
		return
	brief_layer = Control.new()
	brief_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brief_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(brief_layer)
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brief_layer.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	brief_layer.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	brief_panel = _panel()
	brief_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(brief_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	brief_panel.add_child(content)
	content.add_child(_label("DAY %d BRIEF" % day, 24, TEXT))
	content.add_child(_label("Review the next market stories, your holdings, and the match before trading starts.", 12, MUTED))
	content.add_child(_next_day_outlook())
	content.add_child(_label("YOUR HOLDINGS  |  CASH %s  |  %s" % [_format_pence(session.game_state.cash_pence), _holdings_text(session.game_state)], 13, TEXT))
	content.add_child(_build_rankings_panel(_display_rankings()))
	var start_button := Button.new()
	start_button.text = "START TRADING"
	start_button.custom_minimum_size.y = 38
	start_button.pressed.connect(_start_trading_from_brief)
	content.add_child(start_button)

func _start_trading_from_brief() -> void:
	if session.start_trading_round() and brief_panel != null:
		brief_layer.queue_free()
		brief_layer = null
		brief_panel = null

func _on_run_completed(summary: Dictionary) -> void:
	if summary_panel != null:
		return
	summary_layer = Control.new()
	summary_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(summary_layer)
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_layer.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	summary_layer.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	summary_panel = _panel()
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(summary_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	summary_panel.add_child(content)
	content.add_child(_label("RUN COMPLETE", 24, TEXT))
	content.add_child(_label("Starting cash: %s" % _format_pence(int(summary["starting_cash_pence"])), 14, TEXT))
	content.add_child(_label("Final cash: %s" % _format_pence(int(summary["final_cash_pence"])), 16, TEXT))
	var profit := int(summary["profit_loss_pence"])
	content.add_child(_label("Total return: %s" % _signed_pence(profit), 18, POSITIVE if profit >= 0 else NEGATIVE))
	content.add_child(_label("Days completed: %d" % int(summary["days_completed"]), 13, MUTED))
	content.add_child(_label("Final holdings: %s" % _holdings_text_from_dictionary(summary.get("holdings", {})), 13, TEXT))
	content.add_child(_build_rankings_panel(summary.get("ranking", [])))
	var restart := Button.new()
	restart.text = "RESTART"
	restart.pressed.connect(_restart_run)
	content.add_child(restart)

func _restart_run() -> void:
	if debrief_layer != null:
		debrief_layer.free()
		debrief_layer = null
		debrief_panel = null
	if summary_layer != null:
		summary_layer.free()
		summary_layer = null
	summary_panel = null
	if brief_layer != null:
		brief_layer.free()
		brief_layer = null
	brief_panel = null
	row_labels.clear()
	news_history.clear()
	for child in stock_list.get_children():
		child.free()
	for child in chart_legend.get_children():
		child.free()
	for child in news_feed.get_children():
		child.free()
	selected_symbol = "AUR"
	session.start_run()

func _build_debrief_chart() -> Control:
	var panel := _panel()
	var content := VBoxContainer.new()
	debrief_chart_tabs = HBoxContainer.new()
	debrief_chart_tabs.add_theme_constant_override("separation", 8)
	var day_tab := Button.new()
	day_tab.text = "DAY RESULTS"
	day_tab.pressed.connect(_show_debrief_chart.bind(false))
	debrief_chart_tabs.add_child(day_tab)
	var game_tab := Button.new()
	game_tab.text = "GAME SO FAR"
	game_tab.pressed.connect(_show_debrief_chart.bind(true))
	debrief_chart_tabs.add_child(game_tab)
	content.add_child(debrief_chart_tabs)
	debrief_chart = StockHistoryChart.new()
	debrief_chart.custom_minimum_size = Vector2(0, 190)
	debrief_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(debrief_chart)
	panel.add_child(content)
	_show_debrief_chart(false)
	return panel

func _show_debrief_chart(game_so_far: bool) -> void:
	if debrief_chart == null:
		return
	debrief_chart.set_series(debrief_game_series if game_so_far else debrief_day_series)

func _day_graph_series(resolutions: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in resolutions.size():
		var resolution: Dictionary = resolutions[index]
		result.append({
			"symbol": resolution["symbol"],
			"values": [0.0, float(resolution["percentage_change"]) * 100.0],
			"color": StockData.color_for_index(index),
		})
	return result

func _game_graph_series() -> Array[Dictionary]:
	var by_symbol: Dictionary = {}
	for index in session.game_state.stocks.size():
		by_symbol[session.game_state.stocks[index].symbol] = {
			"symbol": session.game_state.stocks[index].symbol,
			"values": [0.0],
			"color": StockData.color_for_index(index),
		}
	for round_record in session.completed_rounds:
		for stock_record in round_record.get("stocks", []):
			var symbol := str(stock_record["symbol"])
			if by_symbol.has(symbol):
				by_symbol[symbol]["values"].append(float(stock_record.get("game_so_far_percentage", 0.0)) * 100.0)
	var result: Array[Dictionary] = []
	for item in by_symbol.values():
		result.append(item)
	return result

func _next_day_outlook() -> Control:
	var panel := _panel()
	var content := VBoxContainer.new()
	content.add_child(_label("NEXT DAY STOCK STORIES / PROJECTIONS", 12, MUTED))
	for stock in session.game_state.stocks:
		content.add_child(_label("%s  %+.1f%% estimate  |  %s" % [stock.symbol, stock.projection_change * 100.0, stock.current_news], 11, TEXT))
	panel.add_child(content)
	return panel

func _display_rankings() -> Array[Dictionary]:
	if not session.network_rankings.is_empty():
		return session.network_rankings
	return [{
		"player_id": session.network_local_player_id,
		"cash_pence": session.game_state.cash_pence,
		"portfolio_value_pence": session.game_state.portfolio_value_pence(),
		"return_pence": session.game_state.total_return_pence(),
		"holdings": session.game_state.holdings.duplicate(),
	}]

func _build_rankings_panel(rankings: Array) -> Control:
	var panel := _panel()
	var content := VBoxContainer.new()
	content.add_child(_label("RANKING", 12, MUTED))
	var rank := 1
	for player in rankings:
		content.add_child(_label("%d. PLAYER %s  CASH %s  PORTFOLIO %s  RETURN %s  HOLDINGS %s" % [
			rank,
			str(player.get("player_id", "?")),
			_format_pence(int(player.get("cash_pence", 0))),
			_format_pence(int(player.get("portfolio_value_pence", 0))),
			_signed_pence(int(player.get("return_pence", 0))),
			_holdings_text_from_dictionary(player.get("holdings", {})),
		], 11, TEXT))
		rank += 1
	panel.add_child(content)
	return panel

func _holdings_text(state: GameState) -> String:
	return _holdings_text_from_dictionary(state.holdings)

func _holdings_text_from_dictionary(holdings: Dictionary) -> String:
	var entries: Array[String] = []
	for symbol in holdings:
		var shares := int(holdings[symbol])
		if shares > 0:
			entries.append("%s %d" % [symbol, shares])
	return ", ".join(entries) if not entries.is_empty() else "none"

static func _format_pence(value: int) -> String:
	var absolute_value := absi(value)
	var sign := "-" if value < 0 else ""
	return "%s£%d.%02d" % [sign, absolute_value / 100, absolute_value % 100]

static func _signed_pence(value: int) -> String:
	return ("+" if value >= 0 else "") + _format_pence(value)