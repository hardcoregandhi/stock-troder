class_name TradingDashboard
extends Control

signal exit_to_main_menu_requested

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
var trade_feedback: Label
var network_status: Label
var chart: StockHistoryChart
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
var row_labels: Dictionary = {}
var news_feed: VBoxContainer
var news_history: Array[Dictionary] = []
var pause_layer: Control
var start_trading_button: Button

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
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	session.network_readiness_changed.connect(_on_network_readiness_changed)

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
	page.add_child(_build_status_bar())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	page.add_child(body)
	body.add_child(_build_market_panel())
	body.add_child(_build_news_panel())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if pause_layer == null:
			_open_pause_menu()
		else:
			_close_pause_menu()
		get_viewport().set_input_as_handled()

func _build_status_bar() -> Control:
	var panel := _panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 2)
	row.add_child(grid)
	day_label = _status_item(grid, "DAY / ROUND", "DAY 1 / 10", TEXT)
	clock_label = _status_item(grid, "TIME LEFT", "30.0s", ACCENT)
	cash_label = _status_item(grid, "CASH", "£0.00", TEXT)
	portfolio_label = _status_item(grid, "PORTFOLIO", "£0.00", TEXT)
	return_label = _status_item(grid, "RETURN", "£0.00", POSITIVE)
	network_status = _label("", 12, MUTED)
	network_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	network_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	network_status.custom_minimum_size.x = 180
	row.add_child(network_status)
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
	content.add_child(_label("All configured stocks. Compare the market and act from each row.", 12, MUTED))
	chart = StockHistoryChart.new()
	chart.custom_minimum_size.y = 155
	chart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(chart)
	stock_list = GridContainer.new()
	stock_list.columns = 11
	stock_list.custom_minimum_size.x = 758
	stock_list.add_theme_constant_override("h_separation", 6)
	stock_list.add_theme_constant_override("v_separation", 5)
	_build_stock_header()
	content.add_child(stock_list)
	trade_feedback = _label("Select a row to trade one share.", 12, MUTED)
	trade_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(trade_feedback)
	return panel

func _build_news_panel() -> Control:
	var panel := _panel()
	panel.custom_minimum_size.x = 360
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	content.add_child(_label("NEWS FEED", 12, MUTED))
	content.add_child(_label("Short signals and resolved market context.", 12, MUTED))
	news_feed = VBoxContainer.new()
	news_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	news_feed.add_theme_constant_override("separation", 5)
	content.add_child(news_feed)
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

func _forward_button(text: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("315f4d")
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	var hover := normal.duplicate()
	hover.bg_color = Color("3d7960")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("244838")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", TEXT)
	return button

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
		_column_label("PUMP", 52),
		_column_label("SABOTAGE", 70),
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

func _on_network_readiness_changed(_ready_count: int, _total_count: int, _local_ready: bool) -> void:
	_update_start_trading_button()

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
	_update_market_surface(state)

func _build_stock_rows(state: GameState) -> void:
	for stock in state.stocks:
		var symbol := _label(stock.symbol, 12, StockData.color_for_index(state.stocks.find(stock)))
		symbol.custom_minimum_size.x = 50
		stock_list.add_child(symbol)
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
		var pump := Button.new()
		pump.text = "PUMP"
		pump.tooltip_text = "Spend £25.00 to lift this stock's live path."
		pump.custom_minimum_size.x = 52
		pump.pressed.connect(_quick_pump.bind(stock.symbol))
		stock_list.add_child(pump)
		var sabotage := Button.new()
		sabotage.text = "SABOTAGE"
		sabotage.tooltip_text = "Sabotage is not available in this build."
		sabotage.custom_minimum_size.x = 70
		sabotage.disabled = true
		stock_list.add_child(sabotage)
		row_labels[stock.symbol] = {"price": price, "change": change, "range": range, "shares": shares, "position": position, "buy": buy, "sell": sell, "pump": pump}
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
		var pump_active := state.has_pumped(stock.symbol) and stock.pump_active
		labels["pump"].text = "PUMP ON" if pump_active else "PUMP"
		labels["pump"].tooltip_text = "ACTIVE: +4.0% live path; correction risk remains." if pump_active else "Spend £25.00 to lift this stock's live path."
		labels["pump"].disabled = session.network_mode or not can_trade or pump_active or state.cash_pence < GameState.PUMP_COST_PENCE

func _update_market_surface(state: GameState) -> void:
	var chart_series: Array[Dictionary] = []
	for index in state.stocks.size():
		var chart_stock: StockData = state.stocks[index]
		chart_series.append({
			"symbol": chart_stock.symbol,
			"values": _graph_history_percentage(chart_stock),
			"color": StockData.color_for_index(index),
		})
	chart.set_series(chart_series)
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

func _quick_buy(symbol: String) -> void:
	session.buy(symbol, 1)

func _quick_sell(symbol: String) -> void:
	session.sell(symbol, 1)

func _quick_pump(symbol: String) -> void:
	session.pump(symbol)

func _open_pause_menu() -> void:
	if pause_layer != null:
		return
	pause_layer = Control.new()
	pause_layer.name = "PauseMenu"
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pause_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.08, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(center)
	var panel := _panel()
	panel.custom_minimum_size = Vector2(280, 0)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	content.add_child(_label("PAUSED" if not session.network_mode else "MATCH MENU", 22, TEXT))
	var resume := Button.new()
	resume.text = "RESUME"
	resume.pressed.connect(_close_pause_menu)
	content.add_child(resume)
	var exit := Button.new()
	exit.text = "EXIT TO MAIN MENU"
	exit.pressed.connect(_exit_to_main_menu)
	content.add_child(exit)
	if not session.network_mode:
		get_tree().paused = true

func _close_pause_menu() -> void:
	if not session.network_mode:
		get_tree().paused = false
	if pause_layer != null:
		pause_layer.queue_free()
		pause_layer = null

func _exit_to_main_menu() -> void:
	if session.network_mode and session.network_lobby != null:
		session.network_lobby.disconnect_lobby()
	_close_pause_menu()
	exit_to_main_menu_requested.emit()

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
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(page)
	debrief_panel = _panel()
	debrief_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debrief_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(debrief_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	debrief_panel.add_child(content)
	var title := _label("DAY %d DEBRIEF" % day, 22, TEXT)
	title.custom_minimum_size.y = 28
	content.add_child(title)
	content.add_child(_label("Resolved prices, player result, action markers, and ranking.", 12, MUTED))
	debrief_day_series = _day_graph_series(resolutions)
	debrief_game_series = _game_graph_series()
	var chart_panel := _build_debrief_chart()
	chart_panel.custom_minimum_size.y = 214
	chart_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(chart_panel)
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 10)
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(lower)
	lower.add_child(_build_debrief_news_panel(resolutions))
	lower.add_child(_build_debrief_details_panel(resolutions))
	var action_bar := HBoxContainer.new()
	action_bar.custom_minimum_size.y = 42
	action_bar.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(action_bar)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_bar.add_child(action_spacer)
	if session.game_state.phase == GameState.Phase.DEBRIEF:
		var next_day := _forward_button("NEXT DAY", Vector2(150, 38))
		next_day.pressed.connect(_continue_after_debrief)
		action_bar.add_child(next_day)

func _build_debrief_news_panel(resolutions: Array[Dictionary]) -> Control:
	var panel := _panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	content.add_child(_label("NEWS FEED", 12, MUTED))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 5)
	for header in [
		_column_label("STOCK", 62),
		_column_label("RESOLVED STORY", 230),
		_column_label("RESULT", 82),
		_column_label("ACTION", 120),
	]:
		grid.add_child(header)
	for resolution in resolutions:
		var symbol := str(resolution["symbol"])
		var color := _stock_color(symbol)
		var stock_label := _label(symbol, 11, color)
		stock_label.custom_minimum_size.x = 62
		grid.add_child(stock_label)
		var story := _label(str(resolution["news"]), 11, TEXT)
		story.custom_minimum_size.x = 230
		story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(story)
		var change := float(resolution["percentage_change"]) * 100.0
		var result := _label("%+.1f%%" % change, 11, POSITIVE if change >= 0.0 else NEGATIVE)
		result.custom_minimum_size.x = 82
		grid.add_child(result)
		var action_text := "PUMP CORRECTION" if bool(resolution.get("pump_correction", false)) else ("PUMP USED" if bool(resolution.get("pump_used", false)) else "NONE")
		var action := _label(action_text, 10, ACCENT if bool(resolution.get("pump_used", false)) else MUTED)
		action.custom_minimum_size.x = 120
		grid.add_child(action)
	content.add_child(grid)
	return panel

func _build_debrief_details_panel(resolutions: Array[Dictionary]) -> Control:
	var panel := _panel()
	panel.custom_minimum_size.x = 430
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(content)
	content.add_child(_label("RESULT AND HOLDINGS", 12, MUTED))
	var round_record: Dictionary = session.completed_rounds.back() if not session.completed_rounds.is_empty() else {}
	var player_result := int(round_record.get("player_return_pence", session.game_state.total_return_pence()))
	content.add_child(_label("PLAYER RESULT  %s" % _signed_pence(player_result), 13, POSITIVE if player_result >= 0 else NEGATIVE))
	content.add_child(_label("PORTFOLIO  %s    CASH  %s" % [
		_format_pence(int(round_record.get("player_portfolio_value_pence", session.game_state.portfolio_value_pence()))),
		_format_pence(int(round_record.get("player_cash_pence", session.game_state.cash_pence))),
	], 11, TEXT))
	content.add_child(_label("SABOTAGE: unavailable in this build", 10, MUTED))
	var result_grid := GridContainer.new()
	result_grid.columns = 4
	result_grid.add_theme_constant_override("h_separation", 7)
	result_grid.add_theme_constant_override("v_separation", 4)
	for header in [
		_column_label("STOCK", 55),
		_column_label("OPEN", 76),
		_column_label("CLOSE", 76),
		_column_label("CHANGE", 70),
	]:
		result_grid.add_child(header)
	for resolution in resolutions:
		var symbol := str(resolution["symbol"])
		var change := float(resolution["percentage_change"]) * 100.0
		for value in [
			_label(symbol, 10, _stock_color(symbol)),
			_label(_format_pence(int(resolution["opening_price_pence"])), 10, TEXT),
			_label(_format_pence(int(resolution["closing_price_pence"])), 10, TEXT),
			_label("%+.1f%%" % change, 10, POSITIVE if change >= 0.0 else NEGATIVE),
		]:
			result_grid.add_child(value)
	content.add_child(result_grid)
	content.add_child(_build_rankings_panel(_display_rankings()))
	return panel

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
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(page)
	brief_panel = _panel()
	brief_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(brief_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	brief_panel.add_child(content)
	var title := _label("DAY %d BRIEF" % day, 22, TEXT)
	title.custom_minimum_size.y = 28
	content.add_child(title)
	content.add_child(_label("Review the next market stories, your holdings, and the match before trading starts.", 12, MUTED))
	content.add_child(_next_day_outlook())
	content.add_child(_label("YOUR HOLDINGS  |  CASH %s  |  %s" % [_format_pence(session.game_state.cash_pence), _holdings_text(session.game_state)], 13, TEXT))
	content.add_child(_build_rankings_panel(_display_rankings()))
	var action_bar := HBoxContainer.new()
	action_bar.custom_minimum_size.y = 42
	action_bar.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(action_bar)
	var start_button := _forward_button("START TRADING", Vector2(170, 38))
	start_trading_button = start_button
	start_button.pressed.connect(_start_trading_from_brief)
	action_bar.add_child(start_button)
	_update_start_trading_button()

func _update_start_trading_button() -> void:
	if start_trading_button == null or session == null:
		return
	if not session.network_mode:
		start_trading_button.text = "START TRADING"
		start_trading_button.disabled = false
		return
	var ready_count := session.network_trading_ready_count
	var total_count := session.network_trading_ready_total
	start_trading_button.text = "START TRADING (%d/%d)" % [ready_count, total_count]
	start_trading_button.disabled = session.network_local_trading_ready or total_count <= 0

func _start_trading_from_brief() -> void:
	if session.start_trading_round() and brief_panel != null:
		brief_layer.queue_free()
		brief_layer = null
		brief_panel = null
		start_trading_button = null

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
	var action_bar := HBoxContainer.new()
	action_bar.custom_minimum_size.y = 42
	action_bar.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(action_bar)
	var restart := _forward_button("RESTART", Vector2(150, 38))
	restart.pressed.connect(_restart_run)
	action_bar.add_child(restart)

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
	for child in news_feed.get_children():
		child.free()
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
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	for header in [
		_column_label("STOCK", 70),
		_column_label("STORY", 0),
		_column_label("FORECAST", 150),
	]:
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(header)
	for stock_index in session.game_state.stocks.size():
		var stock: StockData = session.game_state.stocks[stock_index]
		var symbol := _label(stock.symbol, 11, StockData.color_for_index(stock_index))
		symbol.custom_minimum_size.x = 70
		grid.add_child(symbol)
		var story := _label(stock.current_news, 11, StockData.color_for_index(stock_index))
		story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		story.clip_text = true
		story.tooltip_text = stock.current_news
		grid.add_child(story)
		var forecast := _label("%+.1f%%  |  %+.1f%% to %+.1f%%" % [stock.projection_change * 100.0, stock.projection_low * 100.0, stock.projection_high * 100.0], 11, POSITIVE if stock.projection_change >= 0.0 else NEGATIVE)
		forecast.custom_minimum_size.x = 150
		grid.add_child(forecast)
	content.add_child(grid)
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
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 4)
	for header in [
		_column_label("#", 24),
		_column_label("PLAYER", 70),
		_column_label("CASH", 82),
		_column_label("PORTFOLIO", 95),
		_column_label("RETURN", 82),
		_column_label("HOLDINGS", 0),
	]:
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(header)
	var rank := 1
	for player in rankings:
		for value in [
			_label("%d" % rank, 10, TEXT),
			_label("PLAYER %s" % str(player.get("player_id", "?")), 10, TEXT),
			_label(_format_pence(int(player.get("cash_pence", 0))), 10, TEXT),
			_label(_format_pence(int(player.get("portfolio_value_pence", 0))), 10, TEXT),
			_label(_signed_pence(int(player.get("return_pence", 0))), 10, POSITIVE if int(player.get("return_pence", 0)) >= 0 else NEGATIVE),
			_label(_holdings_text_from_dictionary(player.get("holdings", {})), 10, TEXT),
		]:
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(value)
		rank += 1
	content.add_child(grid)
	panel.add_child(content)
	return panel

func _stock_color(symbol: String) -> Color:
	for index in session.game_state.stocks.size():
		if session.game_state.stocks[index].symbol == symbol:
			return StockData.color_for_index(index)
	return MUTED

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