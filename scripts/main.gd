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
	_show_main_menu()

func _show_main_menu() -> void:
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

func _start_single_player() -> void:
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
	session.start_run()