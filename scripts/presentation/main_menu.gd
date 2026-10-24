class_name MainMenu
extends Control

const BACKGROUND := Color("101820")
const PANEL := Color("182733")
const TEXT := Color("edf4f6")
const MUTED := Color("9bb0b8")

signal single_player_requested(role_id: String)

var content: VBoxContainer
var network_lobby
var player_name_input: LineEdit
var address_input: LineEdit
var port_input: SpinBox
var lobby_status: Label
var player_list_label: Label
var ready_button: Button
var start_match_button: Button
var _last_lobby_state := ""
var _last_lobby_player_count := -1

func setup_network_lobby(lobby) -> void:
	network_lobby = lobby
	network_lobby.status_changed.connect(_on_network_status_changed)
	network_lobby.players_changed.connect(_on_players_changed)
	network_lobby.match_start_status.connect(_on_match_start_status)

func _ready() -> void:
	_build_menu()

func _build_menu() -> void:
	if content != null:
		_clear_content()
		_add_menu_actions()
		return
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := _panel(Vector2(420, 0))
	center.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	_add_menu_actions()

func _add_menu_actions() -> void:
	var title := _label("STOCKTRODER", 30, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle := _label("A short game of decisions under pressure.", 13, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	content.add_child(_spacer(10))
	content.add_child(_button("SINGLE PLAYER", _show_role_picker))
	content.add_child(_button("MULTIPLAYER", _show_lobby))
	content.add_child(_button("OPTIONS", _show_options))
	content.add_child(_button("QUIT", _show_quit_confirmation))

func _show_lobby() -> void:
	_log_menu("screen=lobby_opened")
	_clear_content()
	content.add_child(_label("MULTIPLAYER LOBBY", 24, TEXT))
	lobby_status = _label("Disconnected", 14, MUTED)
	content.add_child(lobby_status)
	var name_row := HBoxContainer.new()
	name_row.custom_minimum_size.y = 42
	name_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_label := _label("Name", 13, TEXT)
	name_label.custom_minimum_size.x = 70
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(name_label)
	player_name_input = LineEdit.new()
	player_name_input.text = network_lobby.local_player_name
	player_name_input.placeholder_text = "Your name"
	player_name_input.max_length = 20
	player_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name_input.custom_minimum_size.y = 36
	player_name_input.text_changed.connect(network_lobby.set_player_name)
	name_row.add_child(player_name_input)
	content.add_child(name_row)
	var address_row := HBoxContainer.new()
	address_row.custom_minimum_size.y = 42
	address_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var address_label := _label("Address", 13, TEXT)
	address_label.custom_minimum_size.x = 70
	address_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	address_row.add_child(address_label)
	address_input = LineEdit.new()
	address_input.text = "127.0.0.1"
	address_input.placeholder_text = "Server address"
	address_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	address_input.custom_minimum_size.y = 36
	address_row.add_child(address_input)
	content.add_child(address_row)
	var port_row := HBoxContainer.new()
	port_row.custom_minimum_size.y = 42
	port_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var port_label := _label("Port", 13, TEXT)
	port_label.custom_minimum_size.x = 70
	port_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	port_row.add_child(port_label)
	port_input = SpinBox.new()
	port_input.min_value = 1
	port_input.max_value = 65535
	port_input.value = 7000
	port_input.step = 1
	port_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	port_input.custom_minimum_size.y = 36
	port_row.add_child(port_input)
	content.add_child(port_row)
	var connection_row := HBoxContainer.new()
	connection_row.add_child(_button("HOST", _on_host))
	connection_row.add_child(_button("JOIN", _on_join))
	content.add_child(connection_row)
	player_list_label = _label("Players: none", 13, TEXT)
	content.add_child(player_list_label)
	ready_button = _button("READY", _on_ready_pressed)
	ready_button.disabled = true
	content.add_child(ready_button)
	start_match_button = _button("START MATCH", _on_start_match)
	start_match_button.disabled = true
	content.add_child(start_match_button)
	content.add_child(_spacer(12))
	content.add_child(_button("BACK", _on_lobby_back))
	_on_network_status_changed(network_lobby.connection_state)
	_on_players_changed(network_lobby.player_list())

func _on_host() -> void:
	_log_menu("action=host_requested")
	network_lobby.set_player_name(player_name_input.text)
	network_lobby.host(int(port_input.value))

func _on_join() -> void:
	_log_menu("action=join_requested")
	network_lobby.set_player_name(player_name_input.text)
	network_lobby.join(address_input.text, int(port_input.value))

func _on_ready_pressed() -> void:
	var ready: bool = not network_lobby.local_ready
	_log_menu("action=ready_toggled ready=%s" % str(ready).to_lower())
	network_lobby.set_ready(ready)

func _on_start_match() -> void:
	_log_menu("action=start_match_requested")
	network_lobby.request_start_match()

func _on_lobby_back() -> void:
	_log_menu("action=lobby_back")
	network_lobby.disconnect_lobby()
	_build_menu()

func _on_network_status_changed(status: String) -> void:
	var lobby_state := _lobby_state_label(status)
	if lobby_state != _last_lobby_state:
		_log_menu("lobby_status state=%s" % lobby_state)
		_last_lobby_state = lobby_state
	if lobby_status == null:
		return
	lobby_status.text = "Status: %s" % status
	var connected: bool = network_lobby.is_lobby_connected()
	if player_name_input != null:
		player_name_input.editable = not connected
	ready_button.disabled = not connected
	ready_button.text = "READY" if not network_lobby.local_ready else "READY (ON)"
	start_match_button.disabled = not network_lobby.is_host or not connected

func _on_players_changed(players: Array[Dictionary]) -> void:
	if players.size() != _last_lobby_player_count:
		_log_menu("lobby_player_count=%d" % players.size())
		_last_lobby_player_count = players.size()
	if player_list_label == null:
		return
	if players.is_empty():
		player_list_label.text = "Players: none"
		return
	var lines: Array[String] = ["Players (%d):" % players.size()]
	for player in players:
		var state := "ready" if player["ready"] else "not ready"
		lines.append("- %s: %s" % [player["name"], state])
	player_list_label.text = "\n".join(lines)

func _on_match_start_status(message: String) -> void:
	_log_menu("match_start_status=blocked")
	if lobby_status != null:
		lobby_status.text = message

func _show_options() -> void:
	_log_menu("screen=options_opened")
	_clear_content()
	content.add_child(_label("OPTIONS", 24, TEXT))
	content.add_child(_label("Local display settings", 14, MUTED))
	var window_mode := OptionButton.new()
	window_mode.name = "WindowMode"
	window_mode.add_item("Window mode: Windowed (placeholder)")
	window_mode.add_item("Window mode: Fullscreen (placeholder)")
	window_mode.tooltip_text = "Display settings will be connected in a later phase."
	content.add_child(window_mode)
	content.add_child(_label("These settings are placeholders and do not change game rules.", 12, MUTED))
	content.add_child(_button("OPEN LOG FOLDER", _open_log_folder))
	content.add_child(_label("This session: %s" % RuntimeLog.session_log_filename(), 11, MUTED))
	content.add_child(_label(RuntimeLog.log_directory_path(), 11, MUTED))
	content.add_child(_spacer(12))
	content.add_child(_button("BACK", _on_options_back))

func _on_options_back() -> void:
	_log_menu("action=options_back")
	_build_menu()

func _open_log_folder() -> void:
	var error := OS.shell_open(RuntimeLog.log_directory_path())
	_log_menu("action=open_log_folder result=%s" % ("opened" if error == OK else "failed:%d" % error))

func _show_quit_confirmation() -> void:
	_log_menu("screen=quit_confirmation_opened")
	_clear_content()
	content.add_child(_label("QUIT STOCKTRODER?", 24, TEXT))
	content.add_child(_label("Your current run will be closed.", 14, MUTED))
	content.add_child(_spacer(12))
	content.add_child(_button("CONFIRM QUIT", _confirm_quit))
	content.add_child(_button("CANCEL", _cancel_quit_confirmation))

func _show_role_picker() -> void:
	_log_menu("screen=role_picker_opened")
	_clear_content()
	content.add_child(_label("CHOOSE YOUR ROLE", 24, TEXT))
	content.add_child(_label("Each role has one strength and one drawback.", 13, MUTED))
	for role_id in PlayerRole.PLAYABLE:
		var button := _button(PlayerRole.display_name(role_id).to_upper(), _on_single_player.bind(role_id))
		button.tooltip_text = PlayerRole.summary(role_id)
		content.add_child(button)
		content.add_child(_label("%s Drawback: %s" % [str(PlayerRole.value(role_id, "ability")), str(PlayerRole.value(role_id, "tradeoff"))], 11, MUTED))
	content.add_child(_spacer(8))
	content.add_child(_button("BACK", _build_menu))

func _on_single_player(role_id: String) -> void:
	_log_menu("action=single_player_requested role=%s" % role_id)
	single_player_requested.emit(role_id)

func _confirm_quit() -> void:
	_log_menu("action=quit_confirmed")
	get_tree().quit()

func _cancel_quit_confirmation() -> void:
	_log_menu("action=quit_cancelled")
	_build_menu()

func _clear_content() -> void:
	for child in content.get_children():
		child.queue_free()

func _panel(minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 28
	style.content_margin_top = 28
	style.content_margin_right = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	return button

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer

func _lobby_state_label(status: String) -> String:
	if status.begins_with("Connected as host"):
		return "connected_host"
	if status.begins_with("Connecting to"):
		return "connecting"
	if status == "Connected":
		return "connected_client"
	if status.to_lower().contains("failed"):
		return "failed"
	if status.to_lower().contains("disconnected"):
		return "disconnected"
	return "updated"

func _log_menu(event: String) -> void:
	print("[menu] %s" % event)