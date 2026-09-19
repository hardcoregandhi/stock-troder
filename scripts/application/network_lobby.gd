class_name NetworkLobby
extends Node

const DEFAULT_PORT := 7000
const MAX_PLAYERS := 6

signal status_changed(status: String)
signal players_changed(players: Array[Dictionary])
signal match_start_status(message: String)

var is_host := false
var connection_state := "Disconnected"
var local_ready := false
var players: Dictionary[int, Dictionary] = {}
var _peer: ENetMultiplayerPeer

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host(port: int) -> bool:
	_disconnect(false)
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		_set_status("Host failed: %s" % error_string(error))
		return false
	multiplayer.multiplayer_peer = _peer
	is_host = true
	local_ready = true
	connection_state = "Connected as host"
	players = {1: {"id": 1, "name": "Host", "ready": true}}
	status_changed.emit(connection_state)
	players_changed.emit(player_list())
	return true

func join(address: String, port: int) -> bool:
	_disconnect(false)
	if address.strip_edges().is_empty():
		_set_status("Join failed: enter a server address.")
		return false
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(address.strip_edges(), port)
	if error != OK:
		_set_status("Join failed: %s" % error_string(error))
		return false
	multiplayer.multiplayer_peer = _peer
	is_host = false
	local_ready = false
	connection_state = "Connecting to %s:%d" % [address.strip_edges(), port]
	players.clear()
	_set_status(connection_state)
	return true

func set_ready(ready: bool) -> void:
	if not is_lobby_connected():
		return
	local_ready = ready
	if is_host:
		players[1]["ready"] = ready
		_broadcast_players()
	else:
		_submit_ready.rpc_id(1, ready)
		players[multiplayer.get_unique_id()] = {"id": multiplayer.get_unique_id(), "name": "Player %d" % multiplayer.get_unique_id(), "ready": ready}
	players_changed.emit(player_list())

func request_start_match() -> void:
	if not is_host:
		match_start_status.emit("Only the host can start the match.")
		return
	if not is_lobby_connected():
		match_start_status.emit("Connect at least one lobby before starting.")
		return
	for player in players.values():
		if not player["ready"]:
			match_start_status.emit("Every player must be ready before the host starts.")
			return
	match_start_status.emit("Network match wiring next: lobby is ready, but the market is not connected yet.")

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
func _submit_ready(ready: bool) -> void:
	if not is_host or not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	players[peer_id] = {"id": peer_id, "name": "Player %d" % peer_id, "ready": ready}
	_broadcast_players()

@rpc("authority", "reliable", "call_local")
func _receive_players(network_players: Array[Dictionary]) -> void:
	players.clear()
	for player in network_players:
		players[int(player["id"])] = player
	players_changed.emit(player_list())

func _on_connected_to_server() -> void:
	connection_state = "Connected"
	_set_status(connection_state)
	players[multiplayer.get_unique_id()] = {"id": multiplayer.get_unique_id(), "name": "Player %d" % multiplayer.get_unique_id(), "ready": local_ready}
	_submit_ready.rpc_id(1, local_ready)
	players_changed.emit(player_list())

func _on_peer_connected(peer_id: int) -> void:
	if not is_host:
		return
	players[peer_id] = {"id": peer_id, "name": "Player %d" % peer_id, "ready": false}
	_broadcast_players()

func _on_peer_disconnected(peer_id: int) -> void:
	players.erase(peer_id)
	if is_host:
		_broadcast_players()
	else:
		players_changed.emit(player_list())

func _on_connection_failed() -> void:
	_disconnect(false)
	_set_status("Connection failed")

func _on_server_disconnected() -> void:
	_disconnect(false)
	_set_status("Server disconnected")

func _broadcast_players() -> void:
	players_changed.emit(player_list())
	if is_host and multiplayer.get_peers().size() > 0:
		_receive_players.rpc(player_list())

func _set_status(status: String) -> void:
	connection_state = status
	status_changed.emit(status)

func _disconnect(clear_status: bool) -> void:
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