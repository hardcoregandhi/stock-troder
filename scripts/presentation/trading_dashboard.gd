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
var stock_list: VBoxContainer
var detail_title: Label
var detail_price_caption: Label
var detail_price: Label
var detail_projection: Label
var detail_news: Label
var detail_shares: Label
var trade_feedback: Label
var quantity: SpinBox
var chart: StockHistoryChart
var summary_panel: PanelContainer
var summary_layer: Control
var debrief_panel: PanelContainer
var debrief_layer: Control
var selected_symbol := "AUR"
var row_labels: Dictionary = {}

class StockHistoryChart extends Control:
	var values: Array[int] = []
	var line_color := Color("65b9d6")
	var grid_color := Color("2b4655")

	func set_values(new_values: Array[int]) -> void:
		values = new_values.duplicate()
		queue_redraw()

	func _draw() -> void:
		var area := Rect2(58.0, 18.0, size.x - 70.0, size.y - 48.0)
		if area.size.x <= 0.0 or area.size.y <= 0.0:
			return
		if values.size() < 2:
			draw_string(ThemeDB.fallback_font, Vector2(66.0, size.y * 0.55), "History will appear after the first close", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, MUTED)
			return
		var minimum := float(values.min())
		var maximum := float(values.max())
		var spread := maxf(1.0, maximum - minimum)
		for index in range(5):
			var fraction := float(index) / 4.0
			var y := area.position.y + area.size.y * fraction
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), grid_color, 1.0)
			var label_value := maximum - spread * fraction
			draw_string(ThemeDB.fallback_font, Vector2(2.0, y + 4.0), _format_price(roundi(label_value)), HORIZONTAL_ALIGNMENT_LEFT, 52.0, 11, MUTED)
		for index in range(1, 4):
			var x := area.position.x + area.size.x * float(index) / 4.0
			draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), grid_color, 1.0)
		draw_line(Vector2(area.position.x, area.end.y), Vector2(area.end.x, area.end.y), MUTED, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(area.position.x, size.y - 10.0), "OLDER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, MUTED)
		draw_string(ThemeDB.fallback_font, Vector2(area.end.x - 30.0, size.y - 10.0), "NOW", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, MUTED)
		draw_string(ThemeDB.fallback_font, Vector2(area.position.x, 12.0), "PRICE (£)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, MUTED)
		var points := PackedVector2Array()
		for index in values.size():
			var x := area.position.x + area.size.x * float(index) / float(values.size() - 1)
			var y := area.end.y - area.size.y * (float(values[index]) - minimum) / spread
			points.append(Vector2(x, y))
		draw_polyline(points, line_color, 2.0, true)
		draw_circle(points[points.size() - 1], 4.0, line_color)

	func _format_price(price_pence: int) -> String:
		return "£%d.%02d" % [price_pence / 100, price_pence % 100]

func setup(new_session: TradingSession) -> void:
	session = new_session
	_build_ui()
	session.run_started.connect(_on_state_changed)
	session.day_prepared.connect(_on_day_prepared)
	session.time_updated.connect(_on_time_updated)
	session.market_updated.connect(_on_market_updated)
	session.day_resolved.connect(_on_day_resolved)
	session.trade_completed.connect(_on_trade_result)
	session.trade_rejected.connect(_on_trade_result)
	session.run_completed.connect(_on_run_completed)

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
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	page.add_child(body)
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
	panel.custom_minimum_size.x = 560
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	content.add_child(_label("MARKET", 13, MUTED))
	content.add_child(_label("Choose a stock to inspect, then trade before the clock runs out.", 12, MUTED))
	content.add_child(_build_stock_header())
	stock_list = VBoxContainer.new()
	stock_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stock_list.add_theme_constant_override("separation", 6)
	content.add_child(stock_list)
	return panel

func _build_detail_panel() -> Control:
	var panel := _panel()
	panel.custom_minimum_size.x = 460
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	detail_title = _label("AUR  Aurora Robotics", 22, TEXT)
	content.add_child(detail_title)
	detail_price_caption = _label("LIVE PRICE", 11, MUTED)
	content.add_child(detail_price_caption)
	detail_price = _label("£0.00", 30, TEXT)
	content.add_child(detail_price)
	detail_projection = _label("ESTIMATE  --", 14, ACCENT)
	detail_projection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_projection.custom_minimum_size.y = 30
	content.add_child(detail_projection)
	chart = StockHistoryChart.new()
	chart.custom_minimum_size.y = 135
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(chart)
	detail_news = _label("NEWS  --", 13, MUTED)
	detail_news.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	content.add_child(trade_feedback)
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

func _build_stock_header() -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.add_child(_column_label("STOCK", 54))
	line.add_child(_column_label("COMPANY", 142))
	line.add_child(_column_label("LIVE", 76))
	line.add_child(_column_label("EST. END", 70))
	line.add_child(_column_label("SHARES", 42))
	line.add_child(_column_label("TRADE", 72))
	return line

func _column_label(text: String, width: float) -> Label:
	var label := _label(text, 10, MUTED)
	label.custom_minimum_size.x = width
	return label

func _on_state_changed(_snapshot: Dictionary) -> void:
	_refresh()

func _on_day_prepared(_day: int, _projections: Array[Dictionary], _news: Array[Dictionary]) -> void:
	_refresh()

func _on_time_updated(seconds: float) -> void:
	if clock_label != null:
		clock_label.text = "%.1fs" % seconds
		clock_label.add_theme_color_override("font_color", NEGATIVE if seconds <= 5.0 else ACCENT)

func _on_market_updated(_snapshot: Dictionary) -> void:
	_refresh()

func _on_day_resolved(day: int, resolutions: Array[Dictionary], _snapshot: Dictionary) -> void:
	_refresh()
	if session.game_state.phase == GameState.Phase.DEBRIEF:
		_show_debrief(day, resolutions)

func _on_trade_result(result: Dictionary) -> void:
	trade_feedback.text = result["message"]
	trade_feedback.add_theme_color_override("font_color", POSITIVE if result["success"] else NEGATIVE)
	_refresh()

func _refresh() -> void:
	if session == null or session.game_state == null:
		return
	var state: GameState = session.game_state
	day_label.text = "DAY %d / %d" % [state.current_day, state.total_days]
	cash_label.text = _format_pence(state.cash_pence)
	portfolio_label.text = _format_pence(state.portfolio_value_pence())
	return_label.text = _signed_pence(state.total_return_pence())
	return_label.add_theme_color_override("font_color", POSITIVE if state.total_return_pence() >= 0 else NEGATIVE)
	if stock_list.get_child_count() == 0:
		_build_stock_rows(state)
	else:
		_update_stock_rows(state)
	_update_detail(state)

func _build_stock_rows(state: GameState) -> void:
	for stock in state.stocks:
		var row := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = PANEL_LIGHT
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 5
		row.add_theme_stylebox_override("panel", style)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		row.add_child(line)
		var select := Button.new()
		select.text = stock.symbol
		select.custom_minimum_size.x = 54
		select.pressed.connect(_select_stock.bind(stock.symbol))
		line.add_child(select)
		var company := _label(stock.company_name, 12, TEXT)
		company.custom_minimum_size.x = 142
		line.add_child(company)
		var price := _label("", 13, TEXT)
		price.custom_minimum_size.x = 76
		line.add_child(price)
		var change := _label("", 12, ACCENT)
		change.custom_minimum_size.x = 70
		line.add_child(change)
		var shares := _label("", 12, TEXT)
		shares.custom_minimum_size.x = 42
		line.add_child(shares)
		var buy := Button.new()
		buy.text = "+"
		buy.tooltip_text = "Buy one share"
		buy.custom_minimum_size.x = 32
		buy.pressed.connect(_quick_buy.bind(stock.symbol))
		line.add_child(buy)
		var sell := Button.new()
		sell.text = "-"
		sell.tooltip_text = "Sell one share"
		sell.custom_minimum_size.x = 32
		sell.pressed.connect(_quick_sell.bind(stock.symbol))
		line.add_child(sell)
		stock_list.add_child(row)
		row_labels[stock.symbol] = {"price": price, "change": change, "shares": shares}
	_update_stock_rows(state)

func _update_stock_rows(state: GameState) -> void:
	for stock in state.stocks:
		var labels: Dictionary = row_labels[stock.symbol]
		labels["price"].text = _format_pence(stock.current_price_pence)
		labels["change"].text = "%+.1f%%" % (stock.projection_change * 100.0)
		labels["change"].add_theme_color_override("font_color", POSITIVE if stock.projection_change >= 0 else NEGATIVE)
		labels["shares"].text = "%d sh" % int(state.holdings[stock.symbol])

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
	chart.set_values(stock.graph_history_pence())

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

func _show_debrief(day: int, resolutions: Array[Dictionary]) -> void:
	if debrief_panel != null:
		return
	debrief_layer = Control.new()
	debrief_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debrief_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(debrief_layer)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.05, 0.07, 0.78)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debrief_layer.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debrief_layer.add_child(center)
	debrief_panel = _panel()
	debrief_panel.custom_minimum_size = Vector2(620, 430)
	center.add_child(debrief_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	debrief_panel.add_child(content)
	content.add_child(_label("DAY %d DEBRIEF" % day, 24, TEXT))
	content.add_child(_label("Resolved prices and the news that affected each stock.", 12, MUTED))
	for resolution in resolutions:
		var change := float(resolution["percentage_change"]) * 100.0
		var change_color := POSITIVE if change >= 0.0 else NEGATIVE
		var row := _label(
			"%s  %s -> %s  %+.1f%%\nRESOLVED NEWS  %s" % [
				resolution["symbol"],
				_format_pence(int(resolution["opening_price_pence"])),
				_format_pence(int(resolution["closing_price_pence"])),
				change,
				resolution["news"],
			],
			12,
			change_color,
		)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(row)
	var portfolio := _label("Portfolio value: %s" % _format_pence(session.game_state.portfolio_value_pence()), 14, TEXT)
	content.add_child(portfolio)
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

func _on_run_completed(summary: Dictionary) -> void:
	if summary_panel != null:
		return
	summary_layer = Control.new()
	summary_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(summary_layer)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.05, 0.07, 0.78)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_layer.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary_layer.add_child(center)
	summary_panel = _panel()
	summary_panel.custom_minimum_size = Vector2(440, 290)
	center.add_child(summary_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	summary_panel.add_child(content)
	content.add_child(_label("RUN COMPLETE", 24, TEXT))
	content.add_child(_label("Starting cash: %s" % _format_pence(int(summary["starting_cash_pence"])), 14, TEXT))
	content.add_child(_label("Final cash: %s" % _format_pence(int(summary["final_cash_pence"])), 16, TEXT))
	var profit := int(summary["profit_loss_pence"])
	content.add_child(_label("Total return: %s" % _signed_pence(profit), 18, POSITIVE if profit >= 0 else NEGATIVE))
	content.add_child(_label("Days completed: %d" % int(summary["days_completed"]), 13, MUTED))
	var restart := Button.new()
	restart.text = "RESTART RUN"
	restart.pressed.connect(_restart_run)
	content.add_child(restart)

func _restart_run() -> void:
	if debrief_layer != null:
		debrief_layer.queue_free()
		debrief_layer = null
		debrief_panel = null
	if summary_layer != null:
		summary_layer.queue_free()
		summary_layer = null
	summary_panel = null
	row_labels.clear()
	for child in stock_list.get_children():
		child.queue_free()
	session.start_run()

static func _format_pence(value: int) -> String:
	var absolute_value := absi(value)
	var sign := "-" if value < 0 else ""
	return "%s£%d.%02d" % [sign, absolute_value / 100, absolute_value % 100]

static func _signed_pence(value: int) -> String:
	return ("+" if value >= 0 else "") + _format_pence(value)