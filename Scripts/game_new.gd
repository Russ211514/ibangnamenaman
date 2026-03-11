extends Node

# Networking
var multiplayer_peer = ENetMultiplayerPeer.new()
const PORT = 9999
const ADDRESS = "localhost"

var room_code: String = ""
var is_host: bool = false
var my_peer_id: int = 0
var opponent_peer_id: int = 0

# UI References
@onready var room_label = $RoomLabel
@onready var network_info = $NetworkInfo
@onready var ui_panel = $UI
@onready var room_code_input = $UI/Multiplayer/OIDinput
@onready var copy_code_button = $UI/Multiplayer/CopyOID
@onready var host_button = $UI/Multiplayer/VBoxContainer/Host
@onready var join_button = $UI/Multiplayer/VBoxContainer/Join
@onready var back_button = $UI/Multiplayer/Back

func _ready() -> void:
	my_peer_id = multiplayer.get_unique_id()
	
	ui_panel.visible = true
	room_label.text = "CUSTOM LOBBY"
	network_info.text = "ID: " + str(my_peer_id)
	
	# Connect button signals
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	copy_code_button.pressed.connect(_on_copy_code_pressed)
	
	# Connect multiplayer signals
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_host_pressed() -> void:
	room_label.text = "SERVER"
	is_host = true
	room_code = _generate_room_code()
	
	# Create server
	multiplayer_peer.create_server(PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	network_info.text = "Code: " + room_code
	ui_panel.visible = true  # Keep UI to show code
	
	# Enable copy code button
	copy_code_button.disabled = false

func _on_join_pressed() -> void:
	var code = room_code_input.text.strip_edges()
	if code == "":
		room_label.text = "PLEASE ENTER A CODE"
		await get_tree().create_timer(2.0).timeout
		room_label.text = "CUSTOM LOBBY"
		return
	
	room_label.text = "CLIENT"
	# Connect to server (localhost:PORT)
	multiplayer_peer.create_client(ADDRESS, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	network_info.text = "Joining..."

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(room_code)
	copy_code_button.text = "COPIED!"
	await get_tree().create_timer(1.0).timeout
	copy_code_button.text = "COPY CODE"

func _generate_room_code() -> String:
	# Generate a 6-digit room code
	var code = ""
	for i in range(6):
		code += str(randi() % 10)
	return code

func _on_connected_to_server() -> void:
	room_label.text = "CLIENT (Connected)"
	network_info.text = "Connected to server"

func _on_peer_connected(peer_id: int) -> void:
	if is_host and opponent_peer_id == 0:
		opponent_peer_id = peer_id
		print("Host: Opponent connected with peer_id: ", peer_id)
		# Start the battle - both peers transition to game_battle.tscn
		await get_tree().create_timer(1.0).timeout
		transition_to_battle.rpc()

func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: ", peer_id)
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

@rpc("any_peer", "call_local")
func transition_to_battle() -> void:
	# Each peer transitions to their respective battle scene
	print("Transitioning to battle scene. Peer ID: ", my_peer_id, " Is Host: ", is_host)
	
	if is_host:
		# Host (Server) loads player battle scene
		get_tree().change_scene_to_file("res://Scenes/player_battle.tscn")
	else:
		# Client loads opponent battle scene
		get_tree().change_scene_to_file("res://Scenes/opponent_battle.tscn")
