extends Control

@onready var host = $UI/Multiplayer/VBoxContainer/Host
@onready var join = $UI/Multiplayer/VBoxContainer/Join
@onready var start_server = $UI/Multiplayer/VBoxContainer/StartServer
@onready var oi_dinput = %OIDinput
@onready var ui = $UI
@onready var online_id_label = $UI/Multiplayer/OnlineID
@onready var copy_code_button = $UI/Multiplayer/CopyOID

const MAX_PLAYER = 2

# itch.io Web Compatibility: Use WebSocket server
# Replace with your own WebSocket relay server URL
@export var websocket_url = "ws://localhost:8080"  # Change this for production itch.io
@export var use_websocket = false  # Default to false for local testing

var peer
var room_code: String = ""
var active_room_codes: Dictionary = {}
var websocket_peer: WebSocketMultiplayerPeer
var is_web_build: bool = false
var connection_attempts: int = 0
var max_connection_attempts: int = 3
var players_ready: int = 0  # Track how many players are ready
var both_players_connected: bool = false  # Flag when both players connected

func _ready():
	# Detect if running on web (itch.io)
	is_web_build = OS.get_name() == "Web"
	if is_web_build:
		print("[Network] Web build detected - using WebSocket")
		use_websocket = true
	else:
		print("[Network] Desktop build - using ENet")
		use_websocket = false
	
	host.pressed.connect(_on_host_pressed)
	join.pressed.connect(_on_join_pressed)
	start_server.pressed.connect(_on_start_server_pressed)
	copy_code_button.pressed.connect(_on_copy_code_pressed)
	
	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)
	multiplayer.connected_to_server.connect(on_connected_to_server)
	multiplayer.connection_failed.connect(on_connection_failed)
	
func _on_host_pressed():
	if use_websocket:
		_host_websocket()
	else:
		_host_enet()

func _host_enet():
	# Original ENet hosting (for desktop local play)
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(9999)
	if error != OK:
		print('[Network] ERROR: Cannot host on port 9999 - error: ' + str(error))
		return
	
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.set_multiplayer_peer(peer)
	
	# Generate and display room code
	room_code = generate_room_code()
	active_room_codes[room_code] = true
	
	print("[Network] WAITING FOR OTHER PLAYER")
	print("[Network] HOSTING GAME - ROOM CODE: " + room_code)
	
	# Debug: check if label exists
	if online_id_label:
		online_id_label.text = room_code
		print("[Network] Label updated with code: " + room_code)
	else:
		print("[Network] ERROR: online_id_label is null!")
	
	send_player_info(oi_dinput.text, multiplayer.get_unique_id())

func _host_websocket():
	# WebSocket hosting for itch.io (acts as room host)
	# Note: This requires a WebSocket relay server running
	websocket_peer = WebSocketMultiplayerPeer.new()
	var url = websocket_url
	
	print("[Network] Attempting WebSocket connection to: " + url)
	var error = websocket_peer.create_client(url)
	if error != OK:
		print("[Network] WebSocket connection failed with error: " + str(error))
		print("[Network] Falling back to ENet for local testing...")
		use_websocket = false
		_host_enet()
		return
	
	multiplayer.set_multiplayer_peer(websocket_peer)
	
	# Generate and display room code
	room_code = generate_room_code()
	active_room_codes[room_code] = true
	
	print("[Network] HOSTING GAME - ROOM CODE: " + room_code)
	
	if online_id_label:
		online_id_label.text = room_code
		print("[Network] Label updated with code: " + room_code)
	else:
		print("[Network] ERROR: online_id_label is null!")
	
	# Notify server that this is a host (with delay to ensure connection)
	await get_tree().process_frame
	create_room.rpc_id(1, room_code, oi_dinput.text)

func _on_join_pressed():
	if use_websocket:
		_join_websocket()
	else:
		_join_enet()

func _join_enet():
	# Original ENet joining (for desktop local play)
	# Get room code from input
	var entered_room_code = ""
	
	# Get the room code from the OIDinput field
	if oi_dinput:
		entered_room_code = oi_dinput.text.to_upper()
		print("[Network] ENet join - Room code input found: " + entered_room_code)
	else:
		print("[Network] ERROR: oi_dinput not found")
		return
	
	# Validate room code is not empty
	if entered_room_code.is_empty():
		print("[Network] ERROR: Room code cannot be empty")
		return
	
	# Store the room code for this session
	room_code = entered_room_code
	
	# Connect to server
	peer = ENetMultiplayerPeer.new()
	print("[Network] Attempting ENet connection to 127.0.0.1:9999")
	peer.create_client("127.0.0.1", 9999)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	print("[Network] Joining room with code: " + room_code)

func _join_websocket():
	# WebSocket joining for itch.io
	var entered_room_code = ""
	
	if oi_dinput:
		entered_room_code = oi_dinput.text.to_upper()
		print("[Network] WebSocket join - Room code input found: " + entered_room_code)
	else:
		print("[Network] ERROR: oi_dinput not found")
		return
	
	if entered_room_code.is_empty():
		print("[Network] ERROR: Room code cannot be empty")
		return
	
	room_code = entered_room_code
	
	# Connect to WebSocket relay server
	websocket_peer = WebSocketMultiplayerPeer.new()
	print("[Network] Attempting WebSocket connection to: " + websocket_url)
	var error = websocket_peer.create_client(websocket_url)
	if error != OK:
		print("[Network] WebSocket connection failed with error: " + str(error))
		print("[Network] Falling back to ENet for local testing...")
		use_websocket = false
		_join_enet()
		return
	
	multiplayer.set_multiplayer_peer(websocket_peer)
	
	# Notify server that we're joining this room
	await get_tree().process_frame
	join_room.rpc_id(1, room_code, oi_dinput.text)
	print("[Network] Joining room with code: " + room_code)

func _on_start_server_pressed():
	# Validate connection before starting game
	if not multiplayer.has_multiplayer_peer():
		print("[Network] ERROR: Not connected to any peer")
		return
	
	if not is_connected_to_peer():
		print("[Network] ERROR: Not fully connected to opponent yet")
		return
	
	print("[Network] Both players ready - starting game...")
	start_game.rpc()

@rpc("any_peer", "call_local")
func start_game():
	print("[Network] Loading game_battle scene...")
	var scene = load("res://Scenes/game_battle.tscn")
	if scene == null:
		print("[Network] ERROR: Failed to load game_battle.tscn")
		return
	
	var game_instance = scene.instantiate()
	if game_instance == null:
		print("[Network] ERROR: Failed to instantiate game_battle scene")
		return
	
	get_tree().root.add_child(game_instance)
	print("[Network] Game scene loaded and added to tree")
	hide()
	ui.hide()

func on_peer_connected(id):
	print('[Network] Player connected - ID: ' + str(id))
	players_ready += 1
	if players_ready >= 2:
		both_players_connected = true
		print('[Network] Both players connected - game is ready to start')

func on_peer_disconnected(id):
	print('[Network] Player disconnected - ID: ' + str(id))
	players_ready -= 1
	both_players_connected = false
	print('[Network] Waiting for players to reconnect...')

func on_connected_to_server():
	print("[Network] Successfully connected to server")
	send_player_info.rpc_id(1, oi_dinput.text, multiplayer.get_unique_id())

func on_connection_failed():
	connection_attempts += 1
	if connection_attempts < max_connection_attempts:
		print('[Network] Connection failed (attempt ' + str(connection_attempts) + '/' + str(max_connection_attempts) + ') - Retrying...')
	else:
		print('[Network] Connection failed - Max attempts reached')
		if use_websocket:
			print('[Network] WebSocket failed - make sure relay server is running at: ' + websocket_url)
			print('[Network] Or deploy to production and update websocket_url export variable')

@rpc("any_peer")
func create_room(code: String, host_name: String):
	"""Create a new room on the relay server"""
	if !GameManager.players.has(multiplayer.get_unique_id()):
		GameManager.players[multiplayer.get_unique_id()] = {
			"name": host_name,
			"id": multiplayer.get_unique_id()
		}
	print("[Network] Room created: " + code)

@rpc("any_peer")
func join_room(code: String, player_name: String):
	"""Join an existing room on the relay server"""
	if !GameManager.players.has(multiplayer.get_unique_id()):
		GameManager.players[multiplayer.get_unique_id()] = {
			"name": player_name,
			"id": multiplayer.get_unique_id()
		}
	print("[Network] Player joined room: " + code)

@rpc("any_peer")
func send_player_info(name, id):
	if !GameManager.players.has(id):
		GameManager.players[id] = {
			"name": name,
			"id": id
		}
	
	if multiplayer.is_server():
		for i in GameManager.players:
			send_player_info.rpc(GameManager.players[i].name, i)

func is_connected_to_peer() -> bool:
	"""Check if we're properly connected to at least one peer"""
	if not multiplayer.has_multiplayer_peer():
		return false
	
	var peer = multiplayer.multiplayer_peer
	if peer == null:
		return false
	
	# For servers, check if at least one client is connected
	if multiplayer.is_server():
		return players_ready >= 1  # At least one player connected
	
	# For clients, check if connected to server
	return both_players_connected

func generate_room_code() -> String:
	const CHARACTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var code = ""
	
	# Generate 8-character unique code
	for i in range(8):
		code += CHARACTERS[randi() % CHARACTERS.length()]
	
	return code

func _on_copy_code_pressed() -> void:
	if room_code.is_empty():
		print("[Network] No room code to copy")
		return
	
	# On web/itch.io, clipboard access is restricted
	if is_web_build:
		print("[Network] Web build - clipboard direct access not available")
		print("[Network] Room code to share: " + room_code)
		# Try to select the text in the label for manual copy
		if online_id_label:
			online_id_label.select_all()
		print("[Network] Room code selected in label - press Ctrl+C to copy")
	else:
		# Desktop build - use clipboard
		DisplayServer.clipboard_set(room_code)
		print("[Network] Room code copied to clipboard: " + room_code)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/pvp language selection.tscn")
