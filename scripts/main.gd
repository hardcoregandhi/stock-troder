extends Node

const TRADING_SESSION = preload("res://scripts/application/trading_session.gd")
const TRADING_DASHBOARD = preload("res://scripts/presentation/trading_dashboard.gd")

var session: TradingSession
var dashboard: TradingDashboard

func _ready() -> void:
	session = TRADING_SESSION.new()
	session.name = "TradingSession"
	add_child(session)
	dashboard = TRADING_DASHBOARD.new()
	dashboard.name = "TradingDashboard"
	dashboard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dashboard)
	dashboard.setup(session)
	session.start_run()