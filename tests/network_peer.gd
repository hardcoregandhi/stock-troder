extends Node

const NETWORK_LOBBY = preload("res://scripts/application/network_lobby.gd")
const TRADING_SESSION = preload("res://scripts/application/trading_session.gd")

var role := ""
var player_name := ""
var port := 7000
var run_seed := 42_4242
var total_days := 3
var round_seconds := 0.1
var expected_players := 2
var report_path := ""
var lobby: NetworkLobby
var session: TradingSession
var deadline_msec := 0
var trading_ready_day := 0
var next_day_ready := 0
var trade_sent_day := 0
var report_written := false

func _ready() -> void:
	_parse_arguments()
	_start.call_deferred()

func _process(_delta: float) -> void:
	if report_written:
		return
	if Time.get_ticks_msec() >= deadline_msec:
		_finish(false, "Timed out at stage %s." % _stage())
		return
	if session == null or not session.network_mode:
		return
	if role == "client":
		_drive_client()
	else:
		_drive_host()

func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--name="):
			player_name = argument.trim_prefix("--name=")
		elif argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
		elif argument.begins_with("--seed="):
			run_seed = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--days="):
			total_days = int(argument.trim_prefix("--days="))
		elif argument.begins_with("--round-seconds="):
			round_seconds = float(argument.trim_prefix("--round-seconds="))
		elif argument.begins_with("--players="):
			expected_players = int(argument.trim_prefix("--players="))
		elif argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
	if role not in ["host", "client"] or report_path.is_empty():
		_finish(false, "Required arguments are --role and --report.")
		return
	deadline_msec = Time.get_ticks_msec() + 20_000

func _start() -> void:
	if report_written:
		return
	lobby = NETWORK_LOBBY.new()
	add_child(lobby)
	lobby.players_changed.connect(_on_players_changed)
	lobby.status_changed.connect(_on_status_changed)
	lobby.match_started.connect(_on_match_started)
	lobby.match_state_received.connect(_on_match_state_received)
	lobby.match_event_received.connect(_on_match_event_received)
	lobby.set_player_name(player_name if not player_name.is_empty() else "Harness Player")
	if role == "host":
		if not lobby.host(port):
			_finish(false, "Host could not bind port %d." % port)
	else:
		if not lobby.join("127.0.0.1", port):
			_finish(false, "Client could not start its ENet connection.")

func _on_players_changed(players: Array[Dictionary]) -> void:
	if role == "client" and players.size() >= 2 and lobby.is_lobby_connected() and not lobby.local_ready:
		lobby.set_ready(true)
	elif role == "host" and players.size() == expected_players and lobby.is_lobby_connected():
		var every_player_ready := true
		for player in players:
			every_player_ready = every_player_ready and bool(player["ready"])
		if every_player_ready and not lobby.match_active:
			lobby.request_start_match()

func _on_status_changed(_status: String) -> void:
	if role == "client" and lobby.is_lobby_connected() and not lobby.local_ready:
		lobby.set_ready(true)

func _on_match_started(player_ids: Array[int], host: bool) -> void:
	if session != null:
		return
	session = TRADING_SESSION.new()
	add_child(session)
	if host:
		lobby.intent_received.connect(session.receive_network_intent)
		session.day_length_seconds = round_seconds
		session.start_network_host(lobby, player_ids, run_seed, total_days)
	else:
		session.day_length_seconds = round_seconds
		session.start_network_client(lobby, lobby.multiplayer.get_unique_id())

func _on_match_state_received(snapshot: Dictionary) -> void:
	if session != null and not session.network_is_host:
		session.apply_network_snapshot(snapshot)

func _on_match_event_received(event: Dictionary) -> void:
	if session != null:
		session.apply_network_event(event)

func _drive_client() -> void:
	if session.game_state == null:
		return
	if session.game_state.phase == GameState.Phase.COMPLETE:
		_finish(_completed_round_count() == total_days, "Client completed the full network match.")
		return
	if session.game_state.phase == GameState.Phase.BRIEF and trading_ready_day != session.game_state.current_day:
		trading_ready_day = session.game_state.current_day
		session.start_trading_round()
	elif session.game_state.phase == GameState.Phase.TRADING and trade_sent_day != session.game_state.current_day:
		trade_sent_day = session.game_state.current_day
		session.buy("AUR", 1)
	elif session.game_state.phase == GameState.Phase.DEBRIEF and next_day_ready != session.game_state.current_day:
		next_day_ready = session.game_state.current_day
		session.continue_to_next_day()

func _drive_host() -> void:
	if session.game_state == null or session.network_player_states.size() < 2:
		return
	if session.game_state.phase == GameState.Phase.COMPLETE:
		_finish(_completed_round_count() == total_days, "Host completed the full network match.")
		return
	if session.game_state.phase == GameState.Phase.BRIEF and trading_ready_day != session.game_state.current_day:
		trading_ready_day = session.game_state.current_day
		session.start_trading_round()
		return
	if session.game_state.phase == GameState.Phase.DEBRIEF and next_day_ready != session.game_state.current_day:
		next_day_ready = session.game_state.current_day
		session.continue_to_next_day()
		return
	var remote_state := _remote_player_state()
	if remote_state == null:
		return

func _completed_round_count() -> int:
	return session.completed_rounds.size() if session != null else 0

func _stage() -> String:
	if lobby == null:
		return "startup"
	if session == null:
		return lobby.connection_state
	return GameState.Phase.keys()[session.game_state.phase] if session.game_state != null else "session"

func _remote_player_state() -> GameState:
	for player_id in session.network_player_states:
		if int(player_id) != session.network_local_player_id:
			return session.network_player_states[player_id]
	return null

func _finish(success: bool, message: String) -> void:
	if report_written:
		return
	report_written = true
	var report := {
		"success": success,
		"role": role,
		"message": message,
		"stage": _stage(),
		"pid": OS.get_process_id(),
	}
	if lobby != null:
		var player_names: Array[String] = []
		for player in lobby.player_list():
			player_names.append(str(player.get("name", "")))
		report["player_names"] = player_names
	if session != null and session.game_state != null:
		report["phase"] = GameState.Phase.keys()[session.game_state.phase]
		report["day"] = session.game_state.current_day
		report["local_holdings"] = int(session.game_state.holdings.get("AUR", 0))
		report["completed_rounds"] = _completed_round_count()
		if session.network_is_host:
			var remote_state := _remote_player_state()
			if remote_state != null:
				report["remote_holdings"] = int(remote_state.holdings.get("AUR", 0))
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report))
			file.close()
	get_tree().quit(0 if success else 1)
