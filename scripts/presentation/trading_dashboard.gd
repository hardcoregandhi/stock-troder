class_name TradingDashboard
extends Control

signal exit_to_main_menu_requested

const BG := Color("0b0f17")
const PANEL := Color("11161f")
const PANEL_LIGHT := Color("171e29")
const TEXT := Color("edf2f7")
const MUTED := Color("7d899b")
const POSITIVE := Color("35d6ad")
const NEGATIVE := Color("f05c79")
const ACCENT := Color("48c7da")
const BORDER := Color("202938")

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
var news_filter: OptionButton
var opponent_holdings_label: Label
var news_history: Array[Dictionary] = []
var pause_layer: Control
var start_trading_button: Button
var responsive_page: Control
var dashboard_body: HBoxContainer
var secondary_tabs: TabContainer
var secondary_panel: Control
var chart_range: String = "ROUND"
var chart_range_buttons: Dictionary = {}

class ResponsiveShell extends Control:
	var content: Control
	var max_content_width: float = 2880.0
	var horizontal_gutter: float = 28.0

	func _notification(what: int) -> void:
		if what != NOTIFICATION_RESIZED or content == null:
			return
		_apply_content_layout()

	func _ready() -> void:
		_apply_content_layout()

	func _apply_content_layout() -> void:
		if content == null:
			return
		var available_width := maxf(0.0, size.x - horizontal_gutter * 2.0)
		var content_width := minf(max_content_width, available_width)
		content.position = Vector2((size.x - content_width) * 0.5, 22.0)
		content.size = Vector2(content_width, maxf(0.0, size.y - 44.0))

class StockHistoryChart extends Control:
	var series: Array[Dictionary] = []
	var grid_color := Color("2b4655")

	func set_series(new_series: Array[Dictionary]) -> void:
		series = new_series.duplicate(true)
		queue_redraw()

	func _draw() -> void:
		var area := Rect2(56.0, 34.0, size.x - 70.0, size.y - 74.0)
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
			draw_string(ThemeDB.fallback_font, Vector2(2.0, y + 4.0), _format_percentage(label_value), HORIZONTAL_ALIGNMENT_LEFT, 48.0, 10, MUTED)
		for index in range(1, 4):
			var x := area.position.x + area.size.x * float(index) / 4.0
			draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), grid_color, 1.0)
		draw_line(Vector2(area.position.x, area.end.y), Vector2(area.end.x, area.end.y), MUTED, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(area.position.x, size.y - 10.0), "ROUND OPEN", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, MUTED)
		draw_string(ThemeDB.fallback_font, Vector2(area.end.x - 24.0, size.y - 10.0), "NOW", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, MUTED)
		draw_string(ThemeDB.fallback_font, Vector2(area.position.x, 16.0), "% CHANGE FROM RANGE START", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, MUTED)
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
			var legend_x := area.position.x + drawable_series.find(item) * 86.0
			draw_line(Vector2(legend_x, 24.0), Vector2(legend_x + 16.0, 24.0), line_color, 2.0)
			draw_string(ThemeDB.fallback_font, Vector2(legend_x + 21.0, 28.0), str(item.get("symbol", "")), HORIZONTAL_ALIGNMENT_LEFT, 62.0, 10, line_color)

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
	session.sabotage_completed.connect(_on_trade_result)
	session.sabotage_rejected.connect(_on_trade_result)
	session.fake_news_completed.connect(_on_trade_result)
	session.fake_news_rejected.connect(_on_trade_result)
	session.option_completed.connect(_on_trade_result)
	session.option_rejected.connect(_on_trade_result)
	session.network_activity.connect(_on_network_activity)
	session.market_news_event.connect(_on_market_news_event)
	session.computer_action_completed.connect(_on_computer_action)
	session.run_completed.connect(_on_run_completed)
	session.network_status_changed.connect(_on_network_status_changed)
	session.network_readiness_changed.connect(_on_network_readiness_changed)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var shell := ResponsiveShell.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.clip_contents = true
	add_child(shell)
	responsive_page = Control.new()
	responsive_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.content = responsive_page
	shell.add_child(responsive_page)
	shell._apply_content_layout()
	var page_layout := VBoxContainer.new()
	page_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_layout.add_theme_constant_override("separation", 12)
	responsive_page.add_child(page_layout)
	page_layout.add_child(_build_status_bar())
	dashboard_body = HBoxContainer.new()
	dashboard_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dashboard_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dashboard_body.custom_minimum_size = Vector2.ZERO
	dashboard_body.add_theme_constant_override("separation", 14)
	page_layout.add_child(dashboard_body)
	var market_panel := _build_market_panel()
	market_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dashboard_body.add_child(market_panel)
	var news_panel := _build_news_panel()
	news_panel.custom_minimum_size.x = 280
	news_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	secondary_panel = news_panel
	dashboard_body.add_child(news_panel)
	_apply_responsive_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	if chart == null or dashboard_body == null:
		return
	var viewport_size := size
	var compact := viewport_size.x < 1500.0
	var narrow := viewport_size.x < 1350.0
	if secondary_panel != null:
		secondary_panel.visible = not narrow
		secondary_panel.custom_minimum_size.x = 280.0 if compact else 380.0
	var viewport_height := viewport_size.y
	chart.custom_minimum_size.y = 102.0 if compact else clampf(viewport_height * 0.38, 300.0, 520.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if pause_layer == null:
			_open_pause_menu()
		else:
			_close_pause_menu()
		get_viewport().set_input_as_handled()

func _build_status_bar() -> Control:
	var panel := _panel()
	panel.custom_minimum_size.y = 68
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 2)
	row.add_child(grid)
	day_label = _status_item(grid, "ROUND", "DAY 1 / 10", TEXT)
	clock_label = _status_item(grid, "ROUND ENDS IN", "30.0s", ACCENT)
	cash_label = _status_item(grid, "CASH", "£0.00", TEXT)
	portfolio_label = _status_item(grid, "PORTFOLIO VALUE", "£0.00", TEXT)
	return_label = _status_item(grid, "RETURN", "£0.00", POSITIVE)
	var status_spacer := Control.new()
	status_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status_spacer)
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
	var result := _label(value, 17, color)
	box.add_child(result)
	return result

func _build_market_panel() -> Control:
	var panel := _panel()
	panel.custom_minimum_size.x = 690
	panel.custom_minimum_size.y = 0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var chart_header := HBoxContainer.new()
	chart_header.add_theme_constant_override("separation", 8)
	content.add_child(chart_header)
	var chart_title := _label("LIVE MARKET CHART", 14, TEXT)
	chart_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_header.add_child(chart_title)
	for range_option in [["ROUND", "ROUND"], ["5 ROUNDS", "FIVE"], ["ALL", "ALL"]]:
		var range_button := Button.new()
		range_button.text = range_option[0]
		range_button.custom_minimum_size = Vector2(68, 26)
		range_button.toggle_mode = true
		range_button.pressed.connect(_on_chart_range_selected.bind(range_option[1]))
		_style_range_button(range_button, range_option[1] == chart_range)
		chart_range_buttons[range_option[1]] = range_button
		chart_header.add_child(range_button)
	chart = StockHistoryChart.new()
	chart.custom_minimum_size.y = 270
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(chart)
	stock_list = GridContainer.new()
	stock_list.columns = 3
	stock_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stock_list.add_theme_constant_override("h_separation", 10)
	stock_list.add_theme_constant_override("v_separation", 10)
	content.add_child(stock_list)
	trade_feedback = _label("Select a row to trade one share.", 12, MUTED)
	trade_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(trade_feedback)
	return panel

func _style_range_button(button: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT if selected else Color("0d121b")
	style.border_color = ACCENT if selected else BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_color_override("font_color", BG if selected else MUTED)
	button.add_theme_font_size_override("font_size", 10)

func _on_chart_range_selected(new_range: String) -> void:
	chart_range = new_range
	for key in chart_range_buttons:
		var button: Button = chart_range_buttons[key]
		button.button_pressed = key == chart_range
		_style_range_button(button, key == chart_range)
	if session != null and session.game_state != null:
		_update_market_surface(session.game_state)

func _build_news_panel() -> Control:
	var panel := _panel()
	panel.custom_minimum_size.x = 380
	panel.custom_minimum_size.y = 0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	secondary_tabs = TabContainer.new()
	secondary_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	secondary_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(secondary_tabs)
	var news_tab := VBoxContainer.new()
	news_tab.name = "NEWS"
	news_tab.add_theme_constant_override("separation", 8)
	secondary_tabs.add_child(news_tab)
	news_tab.add_child(_label("MARKET FEED", 14, TEXT))
	news_filter = OptionButton.new()
	news_filter.add_item("ALL EVENTS", 0)
	news_filter.add_item("TRADES", 1)
	news_filter.add_item("ACTIONS", 2)
	news_filter.add_item("FORECASTS", 3)
	news_filter.add_item("RESOLVED", 4)
	news_filter.item_selected.connect(_on_news_filter_selected)
	news_tab.add_child(news_filter)
	news_feed = VBoxContainer.new()
	news_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	news_feed.custom_minimum_size.y = 0
	news_feed.add_theme_constant_override("separation", 5)
	news_tab.add_child(news_feed)
	var players_tab := VBoxContainer.new()
	players_tab.name = "PLAYERS"
	players_tab.add_theme_constant_override("separation", 8)
	secondary_tabs.add_child(players_tab)
	players_tab.add_child(_label("PLAYERS", 12, MUTED))
	players_tab.add_child(_label("Visible positions for counter-strategy.", 11, MUTED))
	opponent_holdings_label = _label("PLAYERS\nLoading portfolios...", 12, TEXT)
	opponent_holdings_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	players_tab.add_child(opponent_holdings_label)
	return panel

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
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
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	for header in [
		_column_label("STOCK", 100),
		_column_label("LIVE", 62),
		_column_label("ROUND", 58),
		_column_label("EST. RANGE", 90),
		_column_label("POSITION", 86),
		_column_label("TRADE", 96),
		_column_label("MARKET ACTIONS", 318),
	]:
		header_row.add_child(header)
	stock_list.add_child(header_row)

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
			"fake_news": bool(resolution.get("fake_news_used", false)),
			"source": "MARKET NEWS" if bool(resolution.get("fake_news_used", false)) else "MARKET STORY",
		})
	if news_history.size() > 18:
		news_history = news_history.slice(news_history.size() - 18)
	_refresh()
	if session.game_state.phase == GameState.Phase.DEBRIEF:
		_show_debrief(day, resolutions)

func _on_trade_result(result: Dictionary) -> void:
	trade_feedback.text = result["message"]
	trade_feedback.add_theme_color_override("font_color", POSITIVE if result["success"] else NEGATIVE)
	if bool(result.get("success", false)):
		_append_action_news(result)
	_refresh()

func _on_computer_action(player_name: String, risk_profile: String, result: Dictionary) -> void:
	news_history.append({
		"day": session.game_state.current_day,
		"symbol": str(result.get("symbol", "")),
		"text": "%s (%s): %s" % [player_name, risk_profile, str(result.get("message", ""))],
		"resolved": false,
		"change": 0.0,
		"source": "AI ACTION",
		"color": _stock_color(str(result.get("symbol", ""))),
	})
	if news_history.size() > 18:
		news_history = news_history.slice(news_history.size() - 18)
	_refresh()

func _on_network_activity(player_id: int, activity_type: String, result: Dictionary) -> void:
	var symbol := str(result.get("symbol", ""))
	var action := str(result.get("action", activity_type)).to_upper()
	var text := str(result.get("message", "%s activity on %s" % [action, symbol]))
	news_history.append({
		"day": session.game_state.current_day,
		"symbol": symbol,
		"text": "PLAYER %d: %s" % [player_id, text],
		"resolved": false,
		"change": 0.0,
		"source": "NETWORK %s" % action,
		"color": _stock_color(symbol),
	})
	if news_history.size() > 18:
		news_history = news_history.slice(news_history.size() - 18)
	_refresh()

func _on_market_news_event(result: Dictionary) -> void:
	news_history.append({
		"day": session.game_state.current_day,
		"symbol": str(result.get("symbol", "")),
		"text": str(result.get("news", "Market update")),
		"resolved": false,
		"change": float(result.get("impact", 0.0)),
		"source": "COMPANY NEWS",
		"color": _stock_color(str(result.get("symbol", ""))),
	})
	if news_history.size() > 24:
		news_history = news_history.slice(news_history.size() - 24)
	_refresh()

func _append_action_news(result: Dictionary) -> void:
	var action := str(result.get("action", "trade"))
	var symbol := str(result.get("symbol", ""))
	var text := str(result.get("message", ""))
	if action == "fake_news":
		text = "New market story reported for %s" % symbol
		news_history.append({
			"day": session.game_state.current_day,
			"symbol": symbol,
			"text": text,
			"resolved": false,
			"change": 0.0,
			"source": "MARKET NEWS",
			"color": _stock_color(symbol),
		})
		if news_history.size() > 24:
			news_history = news_history.slice(news_history.size() - 24)
		return
	if action == "trade":
		var verb := "BOUGHT" if int(result.get("quantity", 0)) > 0 and text.begins_with("Bought") else "SOLD"
		text = "%s %d %s" % [verb, absi(int(result.get("quantity", 0))), symbol]
		news_history.append({
			"day": session.game_state.current_day,
			"symbol": symbol,
			"text": text,
			"resolved": false,
			"change": 0.0,
			"source": "PLAYER TRADE",
			"color": _stock_color(symbol),
		})
	else:
		news_history.append({
			"day": session.game_state.current_day,
			"symbol": symbol,
			"text": text,
			"resolved": false,
			"change": 0.0,
			"source": action.to_upper(),
			"color": _stock_color(symbol),
		})
	if news_history.size() > 18:
		news_history = news_history.slice(news_history.size() - 18)

func _on_network_status_changed(message: String) -> void:
	if network_status != null:
		network_status.text = message

func _on_network_readiness_changed(_ready_count: int, _total_count: int, _local_ready: bool) -> void:
	_update_start_trading_button()

func _on_news_filter_selected(_index: int) -> void:
	if session != null and session.game_state != null:
		_update_news_feed(session.game_state)

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
	_update_opponent_holdings()

func _update_opponent_holdings() -> void:
	if opponent_holdings_label == null:
		return
	var lines: Array[String] = ["PLAYERS"]
	for player in _display_rankings():
		lines.append("%s: %s" % [str(player.get("display_name", "PLAYER %s" % str(player.get("player_id", "?")))), _holdings_text_from_dictionary(player.get("holdings", {}))])
	opponent_holdings_label.text = "\n".join(lines)

func _build_stock_rows(state: GameState) -> void:
	for stock in state.stocks:
		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = PANEL_LIGHT
		row_style.border_color = BORDER
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(8)
		row_style.content_margin_left = 12
		row_style.content_margin_top = 10
		row_style.content_margin_right = 12
		row_style.content_margin_bottom = 10
		row.add_theme_stylebox_override("panel", row_style)
		row.custom_minimum_size = Vector2(0, 142)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stock_list.add_child(row)
		var row_content := VBoxContainer.new()
		row_content.add_theme_constant_override("separation", 7)
		row.add_child(row_content)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 7)
		row_content.add_child(heading)
		var symbol := _label(stock.symbol, 12, StockData.color_for_index(state.stocks.find(stock)))
		symbol.text = stock.symbol
		symbol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		symbol.tooltip_text = stock.company_name
		heading.add_child(symbol)
		var company := _label(stock.company_name, 9, MUTED)
		company.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		heading.add_child(company)
		var metrics := HBoxContainer.new()
		metrics.add_theme_constant_override("separation", 8)
		metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_content.add_child(metrics)
		var price := _label("", 13, TEXT)
		price.custom_minimum_size.x = 76
		metrics.add_child(price)
		var change := _label("", 12, ACCENT)
		change.custom_minimum_size.x = 62
		metrics.add_child(change)
		var range := _label("", 11, ACCENT)
		range.custom_minimum_size.x = 112
		range.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		metrics.add_child(range)
		var position := _label("", 11, TEXT)
		position.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_content.add_child(position)
		var trade_actions := HBoxContainer.new()
		trade_actions.add_theme_constant_override("separation", 5)
		trade_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var buy := Button.new()
		buy.text = "+  Buy"
		buy.tooltip_text = "Buy one share"
		buy.custom_minimum_size = Vector2(0, 28)
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(buy, POSITIVE)
		buy.pressed.connect(_quick_buy.bind(stock.symbol))
		trade_actions.add_child(buy)
		var sell := Button.new()
		sell.text = "-  Sell"
		sell.tooltip_text = "Sell one share"
		sell.custom_minimum_size = Vector2(0, 28)
		sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(sell, NEGATIVE)
		sell.pressed.connect(_quick_sell.bind(stock.symbol))
		trade_actions.add_child(sell)
		row_content.add_child(trade_actions)
		var market_actions := HBoxContainer.new()
		market_actions.add_theme_constant_override("separation", 4)
		market_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pump := Button.new()
		pump.text = "Pump"
		pump.tooltip_text = "Spend £25.00 to lift this stock's live path."
		pump.custom_minimum_size = Vector2(0, 25)
		pump.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(pump, ACCENT)
		pump.pressed.connect(_quick_pump.bind(stock.symbol))
		market_actions.add_child(pump)
		var sabotage := Button.new()
		sabotage.text = "Sab"
		sabotage.tooltip_text = "Spend £50.00 to add negative live pressure. Resolution risk remains."
		sabotage.custom_minimum_size = Vector2(0, 25)
		sabotage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(sabotage, NEGATIVE)
		sabotage.pressed.connect(_quick_sabotage.bind(stock.symbol))
		market_actions.add_child(sabotage)
		var hype := Button.new()
		hype.text = "Hype"
		hype.tooltip_text = "Plant uncertain positive news for £75.00."
		hype.custom_minimum_size = Vector2(0, 25)
		hype.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(hype, POSITIVE)
		hype.pressed.connect(_quick_fake_news.bind(stock.symbol, 1))
		market_actions.add_child(hype)
		var fud := Button.new()
		fud.text = "FUD"
		fud.tooltip_text = "Plant uncertain negative news for £75.00."
		fud.custom_minimum_size = Vector2(0, 25)
		fud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(fud, NEGATIVE)
		fud.pressed.connect(_quick_fake_news.bind(stock.symbol, -1))
		market_actions.add_child(fud)
		var call := Button.new()
		call.text = "CALL"
		call.tooltip_text = "Buy a one-round call at the current price. Premium depends on volatility."
		call.custom_minimum_size = Vector2(0, 25)
		call.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(call, ACCENT)
		call.pressed.connect(_quick_call.bind(stock.symbol))
		var put := Button.new()
		put.text = "PUT"
		put.tooltip_text = "Buy a one-round put at the current price. Premium depends on volatility."
		put.custom_minimum_size = Vector2(0, 25)
		put.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(put, NEGATIVE)
		put.pressed.connect(_quick_put.bind(stock.symbol))
		market_actions.add_child(call)
		market_actions.add_child(put)
		row_content.add_child(market_actions)
		row_labels[stock.symbol] = {"price": price, "change": change, "range": range, "shares": null, "position": position, "buy": buy, "sell": sell, "pump": pump, "sabotage": sabotage, "hype": hype, "fud": fud, "call": call, "put": put}
	_update_stock_rows(state)

func _style_action_button(button: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color, 0.09)
	normal.border_color = Color(color, 0.34)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	var hover := normal.duplicate()
	hover.bg_color = Color(color, 0.2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", color)
	button.add_theme_font_size_override("font_size", 10)

func _update_stock_rows(state: GameState) -> void:
	for stock in state.stocks:
		var labels: Dictionary = row_labels[stock.symbol]
		labels["price"].text = _format_pence(stock.current_price_pence)
		var round_change := _round_change(stock)
		labels["change"].text = "%+.1f%%" % round_change
		labels["change"].add_theme_color_override("font_color", POSITIVE if round_change >= 0 else NEGATIVE)
		labels["range"].text = "%+.1f%% to %+.1f%%" % [stock.projection_low * 100.0, stock.projection_high * 100.0]
		var shares := int(state.holdings[stock.symbol])
		labels["position"].text = "%d shares  %s" % [shares, _format_pence(stock.current_price_pence * shares)]
		var can_trade := state.phase == GameState.Phase.TRADING
		labels["buy"].disabled = not can_trade
		labels["sell"].disabled = not can_trade or shares <= 0
		var pump_active := state.has_pumped(stock.symbol) and stock.pump_active
		labels["pump"].text = "PUMP ON" if pump_active else "PUMP"
		labels["pump"].tooltip_text = "ACTIVE: +4.0% live path; correction risk remains." if pump_active else "Spend £25.00 to lift this stock's live path."
		labels["pump"].disabled = not can_trade or pump_active or state.action_on_cooldown("pump", stock.symbol) or state.cash_pence < GameState.PUMP_COST_PENCE
		var sabotage_active := state.has_sabotaged(stock.symbol) and stock.sabotage_active
		labels["sabotage"].text = "SAB ON" if sabotage_active else "SAB"
		labels["sabotage"].tooltip_text = "ACTIVE: negative live pressure; resolution risk remains." if sabotage_active else "Spend £50.00 to add negative live pressure."
		labels["sabotage"].disabled = not can_trade or sabotage_active or state.action_on_cooldown("sabotage", stock.symbol) or state.cash_pence < GameState.SABOTAGE_COST_PENCE
		var fake_news_active := state.has_planted_fake_news(stock.symbol) and stock.fake_news_active
		labels["hype"].text = "HYPE ON" if fake_news_active and stock.fake_news_direction > 0 else "HYPE"
		labels["hype"].tooltip_text = "ACTIVE: uncertain positive planted news." if fake_news_active and stock.fake_news_direction > 0 else "Plant uncertain positive news for £75.00."
		labels["hype"].disabled = not can_trade or fake_news_active or state.action_on_cooldown("fake_news", stock.symbol) or state.cash_pence < GameState.FAKE_NEWS_COST_PENCE
		labels["fud"].text = "FUD ON" if fake_news_active and stock.fake_news_direction < 0 else "FUD"
		labels["fud"].tooltip_text = "ACTIVE: uncertain negative planted news." if fake_news_active and stock.fake_news_direction < 0 else "Plant uncertain negative news for £75.00."
		labels["fud"].disabled = not can_trade or fake_news_active or state.action_on_cooldown("fake_news", stock.symbol) or state.cash_pence < GameState.FAKE_NEWS_COST_PENCE
		var option_premium := TradeService.option_premium_pence(stock)
		labels["call"].disabled = not can_trade or state.cash_pence < option_premium
		labels["put"].disabled = not can_trade or state.cash_pence < option_premium

func _update_market_surface(state: GameState) -> void:
	var chart_series: Array[Dictionary] = []
	for index in state.stocks.size():
		var chart_stock: StockData = state.stocks[index]
		chart_series.append({
			"symbol": chart_stock.symbol,
			"values": _chart_prices(chart_stock),
			"color": StockData.color_for_index(index),
		})
	chart.set_series(chart_series)
	_update_news_feed(state)

func _round_change(stock: StockData) -> float:
	if stock.round_open_price_pence <= 0:
		return 0.0
	return (float(stock.current_price_pence - stock.round_open_price_pence) / float(stock.round_open_price_pence)) * 100.0

func _chart_prices(stock: StockData) -> Array[float]:
	var prices: Array[int] = []
	if chart_range == "ROUND":
		prices = stock.live_price_history_pence.duplicate()
	else:
		var history_start := 0
		if chart_range == "FIVE":
			history_start = maxi(0, stock.round_history_pence.size() - 5)
		for index in range(history_start, stock.round_history_pence.size()):
			prices.append_array(stock.round_history_pence[index])
		prices.append_array(stock.live_price_history_pence)
	var values: Array[float] = []
	if prices.is_empty() or prices[0] <= 0:
		return values
	var opening_price := float(prices[0])
	for price_pence in prices:
		values.append((float(price_pence) - opening_price) / opening_price * 100.0)
	return values

func _update_news_feed(state: GameState) -> void:
	if news_feed == null:
		return
	for child in news_feed.get_children():
		child.free()
	var entries: Array[Dictionary] = []
	for item in news_history.slice(maxi(0, news_history.size() - 10)):
		if _news_entry_matches_filter(item):
			entries.append(item)
	if entries.size() < 10:
		for index in state.stocks.size():
			if entries.size() >= 10:
				break
			var stock: StockData = state.stocks[index]
			var forecast := {
				"day": state.current_day,
				"symbol": stock.symbol,
				"text": stock.current_news,
				"resolved": false,
				"change": stock.projection_change,
				"color": StockData.color_for_index(index),
			}
			if _news_entry_matches_filter(forecast) and not _has_feed_symbol(entries, stock.symbol):
				entries.append(forecast)
	for entry in entries:
		var color: Color = entry.get("color", NEGATIVE if float(entry["change"]) < 0.0 else POSITIVE)
		var source := str(entry.get("source", "PLAYER-PLANTED FAKE" if bool(entry.get("fake_news", false)) else ("SIGNAL" if not bool(entry["resolved"]) else "MARKET STORY")))
		var status := "RESOLVED %+.1f%%" % (float(entry["change"]) * 100.0) if bool(entry["resolved"]) else ("ACTIVITY" if source == "AI ACTION" or source.begins_with("NETWORK") else ("NEWS" if source == "COMPANY NEWS" or source == "MARKET NEWS" else "FORECAST"))
		news_feed.add_child(_build_feed_card(entry, status, source, color))

func _has_feed_symbol(entries: Array[Dictionary], symbol: String) -> bool:
	for entry in entries:
		if str(entry.get("symbol", "")) == symbol:
			return true
	return false

func _build_feed_card(entry: Dictionary, status: String, source: String, color: Color) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111a25")
	style.border_color = Color("263548")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	var text := _label("ROUND %d  %s  %s\n%s  %s" % [int(entry["day"]), str(entry["symbol"]), status, source, str(entry["text"])], 11, color)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 64
	card.add_child(text)
	return card

func _news_entry_matches_filter(entry: Dictionary) -> bool:
	if news_filter == null or news_filter.selected == 0:
		return true
	var resolved := bool(entry.get("resolved", false))
	var source := str(entry.get("source", ""))
	match news_filter.selected:
		1:
			return source == "PLAYER TRADE"
		2:
			return source in ["PUMP", "SABOTAGE", "FAKE_NEWS", "AI ACTION"] or source.begins_with("NETWORK")
		3:
			return not resolved and source not in ["PLAYER TRADE", "PUMP", "SABOTAGE", "FAKE_NEWS"]
		4:
			return resolved
	return true

func _quick_buy(symbol: String) -> void:
	session.buy(symbol, 1)

func _quick_sell(symbol: String) -> void:
	session.sell(symbol, 1)

func _quick_pump(symbol: String) -> void:
	session.pump(symbol)

func _quick_sabotage(symbol: String) -> void:
	session.sabotage(symbol)

func _quick_fake_news(symbol: String, direction: int) -> void:
	session.plant_fake_news(symbol, direction)

func _quick_call(symbol: String) -> void:
	session.buy_call(symbol)

func _quick_put(symbol: String) -> void:
	session.buy_put(symbol)

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
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	debrief_panel.add_child(content)
	var title := _label("DAY %d DEBRIEF" % day, 22, TEXT)
	title.custom_minimum_size.y = 28
	content.add_child(title)
	content.add_child(_label("Resolved prices, player result, action markers, and ranking.", 12, MUTED))
	debrief_day_series = _day_graph_series(resolutions)
	debrief_game_series = _game_graph_series()
	var upper := HBoxContainer.new()
	upper.add_theme_constant_override("separation", 10)
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper.size_flags_stretch_ratio = 2.0
	upper.custom_minimum_size.y = 180
	var chart_panel := _build_debrief_chart(resolutions)
	chart_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_panel.size_flags_stretch_ratio = 1.0
	upper.add_child(chart_panel)
	var details_panel := _build_debrief_details_panel(resolutions)
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_panel.size_flags_stretch_ratio = 1.0
	upper.add_child(details_panel)
	content.add_child(upper)
	var action_bar := HBoxContainer.new()
	action_bar.custom_minimum_size.y = 42
	action_bar.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(action_bar)
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
		var action_text := _action_marker_text(resolution)
		var action := _label(action_text, 10, ACCENT if action_text != "NONE" else MUTED)
		action.custom_minimum_size.x = 170
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
	content.add_child(_label("Actions are paid, once per stock per round, and never guarantee a price result.", 10, MUTED))
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

func _action_marker_text(resolution: Dictionary) -> String:
	var markers: Array[String] = []
	if bool(resolution.get("pump_used", false)):
		markers.append("PUMP CORRECTION" if bool(resolution.get("pump_correction", false)) else "PUMP USED")
	if bool(resolution.get("sabotage_used", false)):
		markers.append("SABOTAGE CORRECTION" if bool(resolution.get("sabotage_correction", false)) else "SABOTAGE USED")
	if bool(resolution.get("fake_news_used", false)):
		markers.append("FAKE NEWS %s" % str(resolution.get("fake_news_outcome", "failed")).to_upper())
	return ", ".join(markers) if not markers.is_empty() else "NONE"

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
	var winner_id := int(summary.get("victory_player_id", 0))
	if winner_id > 0:
		content.add_child(_label("MILLIONAIRE VICTORY: PLAYER %d" % winner_id, 15, POSITIVE))
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

func _build_debrief_chart(resolutions: Array[Dictionary]) -> Control:
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
	var news_panel := _build_debrief_news_panel(resolutions)
	news_panel.custom_minimum_size.y = 112
	news_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_child(news_panel)
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
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	for header in [
		_column_label("STOCK", 70),
		_column_label("STORY", 0),
		_column_label("FORECAST", 150),
		_column_label("HYPE", 60),
		_column_label("FUD", 60),
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
		var fake_positive := Button.new()
		fake_positive.text = "HYPE"
		fake_positive.custom_minimum_size.x = 60
		fake_positive.tooltip_text = "Available during trading: plant uncertain positive news for £75.00."
		fake_positive.pressed.connect(_quick_fake_news.bind(stock.symbol, 1))
		fake_positive.disabled = true
		grid.add_child(fake_positive)
		var fake_negative := Button.new()
		fake_negative.text = "FUD"
		fake_negative.custom_minimum_size.x = 60
		fake_negative.tooltip_text = "Available during trading: plant uncertain negative news for £75.00."
		fake_negative.pressed.connect(_quick_fake_news.bind(stock.symbol, -1))
		fake_negative.disabled = true
		grid.add_child(fake_negative)
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
			_label("%s  [%s]" % [str(player.get("display_name", "PLAYER %s" % str(player.get("player_id", "?")))), str(player.get("risk_profile", "HUMAN"))], 10, TEXT),
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
