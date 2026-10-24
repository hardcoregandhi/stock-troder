class_name NetworkLobby
extends Node

const DEFAULT_PORT := 7000
const MAX_PLAYERS := 4

signal status_changed(status: String)
signal players_changed(players: Array[Dictionary])
signal match_start_status(message: String)
signal match_started(player_ids: Array[int], host: bool)
signal intent_received(peer_id: int, action: String, symbol: String, quantity: int)
signal match_state_received(snapshot: Dictionary)
signal match_event_received(event: Dictionary)
signal match_ended(reason: String)

var is_host := false
var connection_state := "Disconnected"
var local_ready := false
var players: Dictionary[int, Dictionary] = {}
var _peer: ENetMultiplayerPeer
var match_active := false
var _upnp_thread: Thread
var _upnp_generation := 0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host(port: int) -> bool:
	_disconnect(false)
	_log_network("host requested port=%d" % port)
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		_log_network("host failed port=%d error=%s" % [port, error_string(error)])
		_set_status("Host failed: %s" % error_string(error))
		return false
	multiplayer.multiplayer_peer = _peer
	is_host = true
	local_ready = true
	connection_state = "Connected as host"
	players = {1: {"id": 1, "name": "Host", "ready": true}}
	_log_network("host listening port=%d capacity=%d" % [port, MAX_PLAYERS])
	status_changed.emit(connection_state)
	players_changed.emit(player_list())
	_start_upnp_mapping(port)
	return true

func join(address: String, port: int) -> bool:
	_disconnect(false)
	_log_network("join requested port=%d" % port)
	if address.strip_edges().is_empty():
		_log_network("join rejected: empty server address")
		_set_status("Join failed: enter a server address.")
		return false
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(address.strip_edges(), port)
	if error != OK:
		_log_network("join failed port=%d error=%s" % [port, error_string(error)])
		_set_status("Join failed: %s" % error_string(error))
		return false
	multiplayer.multiplayer_peer = _peer
	is_host = false
	local_ready = false
	connection_state = "Connecting to %s:%d" % [address.strip_edges(), port]
	players.clear()
	_set_status(connection_state)
	return true

func set_ready(ready_value: bool) -> void:
	if not is_lobby_connected():
		_log_network("ready change ignored: lobby is not connected")
		return
	local_ready = ready_value
	_log_network("local readiness changed ready=%s" % str(ready_value).to_lower())
	if is_host:
		players[1]["ready"] = ready_value
		_broadcast_players()
	else:
		_submit_ready.rpc_id(1, ready_value)
		players[multiplayer.get_unique_id()] = {"id": multiplayer.get_unique_id(), "name": "Player %d" % multiplayer.get_unique_id(), "ready": ready}
	players_changed.emit(player_list())

func request_start_match() -> void:
	if not is_host:
		_log_network("match start rejected: requester is not host")
		match_start_status.emit("Only the host can start the match.")
		return
	if not is_lobby_connected() or players.is_empty():
		_log_network("match start rejected: no connected players")
		match_start_status.emit("Connect at least one player before starting.")
		return
	for player in players.values():
		if not player["ready"]:
			_log_network("match start rejected: players are not all ready")
			match_start_status.emit("Every player must be ready before the host starts.")
			return
	match_active = true
	_log_network("match starting players=%d" % players.size())
	_match_started.rpc(player_ids())

func player_ids() -> Array[int]:
	var ids: Array[int] = []
	for player in players.values():
		ids.append(int(player["id"]))
	ids.sort()
	return ids

func submit_buy(symbol: String, quantity: int) -> void:
	_submit_intent.rpc_id(1, "buy", symbol, quantity)

func submit_sell(symbol: String, quantity: int) -> void:
	_submit_intent.rpc_id(1, "sell", symbol, quantity)

func submit_pump(symbol: String) -> void:
	_submit_intent.rpc_id(1, "pump", symbol, 0)

func submit_sabotage(symbol: String) -> void:
	_submit_intent.rpc_id(1, "sabotage", symbol, 0)

func submit_fake_news(symbol: String, direction: int) -> void:
	_submit_intent.rpc_id(1, "fake_news_positive" if direction > 0 else "fake_news_negative", symbol, direction)

func submit_call(symbol: String) -> void:
	_submit_intent.rpc_id(1, "call", symbol, 1)

func submit_put(symbol: String) -> void:
	_submit_intent.rpc_id(1, "put", symbol, 1)

func submit_ready_for_next_day() -> void:
	_submit_intent.rpc_id(1, "ready_for_next_day", "", 0)

func submit_ready_for_trading() -> void:
	_submit_intent.rpc_id(1, "ready_for_trading", "", 0)

func broadcast_match_state(snapshot: Dictionary) -> void:
	if is_host:
		_receive_match_state.rpc(snapshot)

func send_match_state(snapshot: Dictionary, peer_id: int) -> void:
	if is_host:
		_receive_match_state.rpc_id(peer_id, snapshot)

func send_match_event(event: Dictionary, peer_id: int = 0) -> void:
	if not is_host:
		return
	if peer_id == 0:
		_receive_match_event.rpc(event)
	else:
		_receive_match_event.rpc_id(peer_id, event)

func disconnect_lobby() -> void:
	_disconnect(true)

func is_lobby_connected() -> bool:
	return _peer != null and multiplayer.multiplayer_peer != null and connection_state in ["Connected as host", "Connected"]

func player_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in players.values():
		result.append(player.duplicate())
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["id"]) < int(right["id"]))
	return result

@rpc("any_peer", "reliable")
func _submit_ready(ready_value: bool) -> void:
	if not is_host or not multiplayer.is_server():
		_log_network("remote readiness rejected: receiver is not host")
		return
	var peer_id := multiplayer.get_remote_sender_id()
	players[peer_id] = {"id": peer_id, "name": "Player %d" % peer_id, "ready": ready_value}
	_log_network("player readiness changed player=%d ready=%s" % [peer_id, str(ready_value).to_lower()])
	_broadcast_players()

@rpc("any_peer", "reliable")
func _submit_intent(action: String, symbol: String, quantity: int) -> void:
	if not is_host or not match_active or not multiplayer.is_server():
		_log_network("remote action rejected: match is not accepting actions")
		return
	intent_received.emit(multiplayer.get_remote_sender_id(), action, symbol, quantity)

@rpc("authority", "reliable", "call_local")
func _match_started(network_players: Array[int]) -> void:
	match_active = true
	_log_network("match started role=%s players=%d" % ["host" if is_host else "client", network_players.size()])
	match_started.emit(network_players, is_host)

@rpc("authority", "reliable")
func _receive_match_state(snapshot: Dictionary) -> void:
	match_state_received.emit(snapshot)

@rpc("authority", "reliable")
func _receive_match_event(event: Dictionary) -> void:
	match_event_received.emit(event)

@rpc("authority", "reliable", "call_local")
func _receive_players(network_players: Array[Dictionary]) -> void:
	players.clear()
	for player in network_players:
		players[int(player["id"])] = player
	players_changed.emit(player_list())

func _on_connected_to_server() -> void:
	connection_state = "Connected"
	_log_network("connected to host player=%d" % multiplayer.get_unique_id())
	_set_status(connection_state)
	players[multiplayer.get_unique_id()] = {"id": multiplayer.get_unique_id(), "name": "Player %d" % multiplayer.get_unique_id(), "ready": local_ready}
	_submit_ready.rpc_id(1, local_ready)
	players_changed.emit(player_list())

func _on_peer_connected(peer_id: int) -> void:
	if not is_host:
		return
	_log_network("peer connected player=%d" % peer_id)
	players[peer_id] = {"id": peer_id, "name": "Player %d" % peer_id, "ready": false}
	_broadcast_players()

func _on_peer_disconnected(peer_id: int) -> void:
	_log_network("peer disconnected player=%d" % peer_id)
	players.erase(peer_id)
	if is_host:
		if match_active:
			match_event_received.emit({"type": "player_disconnected", "player_id": peer_id})
		_broadcast_players()
	else:
		players_changed.emit(player_list())

func _on_connection_failed() -> void:
	_log_network("connection failed before lobby was established")
	_disconnect(false)
	_set_status("Connection failed")

func _on_server_disconnected() -> void:
	_log_network("host connection lost")
	match_active = false
	match_ended.emit("Host disconnected")
	_disconnect(false)
	_set_status("Server disconnected")

func _broadcast_players() -> void:
	players_changed.emit(player_list())
	if is_host and multiplayer.get_peers().size() > 0:
		_receive_players.rpc(player_list())

func _set_status(status: String) -> void:
	connection_state = status
	status_changed.emit(status)

func _start_upnp_mapping(port: int) -> void:
	_upnp_generation += 1
	_upnp_thread = Thread.new()
	_upnp_thread.start(_discover_upnp.bind(port, _upnp_generation))

func _discover_upnp(port: int, generation: int) -> void:
	var upnp := UPNP.new()
	var discovery_error := upnp.discover()
	if discovery_error != UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_complete_upnp_mapping", generation, false, "discovery failed (%d)" % discovery_error)
		return
	var gateway := upnp.get_gateway()
	if gateway == null or not gateway.is_valid_gateway():
		call_deferred("_complete_upnp_mapping", generation, false, "no compatible gateway")
		return
	var mapping_error := upnp.add_port_mapping(port, port, "StockTroder", "UDP")
	if mapping_error == UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_complete_upnp_mapping", generation, true, "UDP %d mapped" % port)
	else:
		call_deferred("_complete_upnp_mapping", generation, false, "mapping failed (%d)" % mapping_error)

func _complete_upnp_mapping(generation: int, success: bool, message: String) -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if generation != _upnp_generation or not is_host:
		return
	if success:
		_log_network("upnp mapping ready: %s" % message)
		status_changed.emit("Connected as host; UPnP %s" % message)
	else:
		_log_network("upnp mapping unavailable: %s" % message)
		status_changed.emit("Connected as host; UPnP unavailable: %s" % message)

func _disconnect(clear_status: bool) -> void:
	if clear_status and _peer != null:
		_log_network("lobby disconnected by local request")
	_upnp_generation += 1
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	match_active = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_peer = null
	is_host = false
	local_ready = false
	players.clear()
	if clear_status:
		_set_status("Disconnected")
		players_changed.emit(player_list())

func _log_network(message: String) -> void:
	print("[network] " + message)