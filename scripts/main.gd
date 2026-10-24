extends Node

const TRADING_SESSION = preload("res://scripts/application/trading_session.gd")
const NETWORK_LOBBY = preload("res://scripts/application/network_lobby.gd")
const TRADING_DASHBOARD = preload("res://scripts/presentation/trading_dashboard.gd")
const MAIN_MENU = preload("res://scripts/presentation/main_menu.gd")

var session: TradingSession
var dashboard: TradingDashboard
var menu: MainMenu
var network_lobby: NetworkLobby

func _ready() -> void:
	network_lobby = NETWORK_LOBBY.new()
	network_lobby.name = "NetworkLobby"
	add_child(network_lobby)
	network_lobby.match_started.connect(_on_network_match_started)
	network_lobby.intent_received.connect(_on_network_intent_received)
	network_lobby.match_state_received.connect(_on_network_state_received)
	network_lobby.match_event_received.connect(_on_network_event_received)
	network_lobby.match_ended.connect(_on_network_match_ended)
	_show_main_menu()

func _show_main_menu() -> void:
	print("[menu] flow=main_menu_opened")
	get_tree().paused = false
	if session != null:
		session.queue_free()
		session = null
	if dashboard != null:
		dashboard.queue_free()
		dashboard = null
	menu = MAIN_MENU.new()
	menu.name = "MainMenu"
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	menu.setup_network_lobby(network_lobby)
	menu.single_player_requested.connect(_start_single_player)

func _start_single_player(role_id: String = PlayerRole.NONE) -> void:
	print("[menu] flow=single_player_started role=%s" % role_id)
	if menu != null:
		menu.queue_free()
		menu = null
	session = TRADING_SESSION.new()
	session.name = "TradingSession"
	add_child(session)
	dashboard = TRADING_DASHBOARD.new()
	dashboard.name = "TradingDashboard"
	dashboard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dashboard)
	dashboard.setup(session)
	dashboard.exit_to_main_menu_requested.connect(_show_main_menu)
	session.start_run(TradingSession.DEFAULT_SEED, GameState.DEFAULT_TOTAL_DAYS, GameState.DEFAULT_STOCK_COUNT, true, role_id)

func _on_network_match_started(player_ids: Array[int], host: bool) -> void:
	print("[menu] flow=multiplayer_match_started role=%s players=%d" % ["host" if host else "client", player_ids.size()])
	if menu != null:
		menu.queue_free()
		menu = null
	session = TRADING_SESSION.new()
	session.name = "TradingSession"
	add_child(session)
	dashboard = TRADING_DASHBOARD.new()
	dashboard.name = "TradingDashboard"
	dashboard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dashboard)
	dashboard.setup(session)
	dashboard.exit_to_main_menu_requested.connect(_show_main_menu)
	if host:
		session.start_network_host(network_lobby, player_ids)
	else:
		session.start_network_client(network_lobby, multiplayer.get_unique_id())
	session.network_status_changed.emit("Multiplayer match connected.")

func _on_network_state_received(snapshot: Dictionary) -> void:
	if session != null and session.network_mode and not session.network_is_host:
		session.apply_network_snapshot(snapshot)

func _on_network_intent_received(peer_id: int, action: String, symbol: String, quantity: int) -> void:
	if session != null and session.network_mode and session.network_is_host:
		session.receive_network_intent(peer_id, action, symbol, quantity)

func _on_network_event_received(event: Dictionary) -> void:
	if session == null or not session.network_mode:
		return
	if event.get("type", "") == "player_disconnected" and session.network_is_host:
		session.remove_network_player(int(event["player_id"]))
	else:
		session.apply_network_event(event)

func _on_network_match_ended(_reason: String) -> void:
	print("[menu] flow=multiplayer_match_ended")
	if session != null:
		network_lobby.disconnect_lobby()
	_show_main_menu()
