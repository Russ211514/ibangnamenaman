extends Control
class_name MultiplayerBattle

const PLAYER_SCENE = preload("res://player/player.tscn")

# UI References
@onready var player_healthbar = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/HealthBar
@onready var opponent_healthbar = $BattleLayout/Battle/Bottom/Enemy/MarginContainer/VBoxContainer/HealthBar
@onready var turn_label: Label = $BattleLayout/Info
@onready var timer_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/PlayerTurnTimerLabel
@onready var lose: Label = $BattleLayout/Lose
@onready var win: Label = $BattleLayout/Win
@onready var options_menu: VBoxContainer = $BattleLayout/Battle/Options/Options
@onready var background_sprite = $Background_Sprite
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var spawn_point_1 = $Background_Sprite/SpawnPoint
@onready var spawn_point_2 = $Background_Sprite/SpawnPoint2

# Action Buttons
@onready var fight_button = $BattleLayout/Battle/Options/Options/Fight
@onready var magic_button = $BattleLayout/Battle/Options/Options/Magic
@onready var defend_button = $BattleLayout/Battle/Options/Options/Defend
@onready var ultimate_button = $BattleLayout/Battle/Options/Options/Ultimate

# Cooldown Labels
@onready var magic_cooldown_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/MagicCooldownLabel
@onready var ultimate_cooldown_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/UltimateCooldownLabel
@onready var defend_cooldown_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/DefendCooldownLabel

# Question UI
@onready var question_control: Control = $BattleLayout/Control

# Game Manager
var game_manager: Node = null
var player: Player = null
var opponent: Player = null
var visual_player: CharacterBody2D = null
var visual_opponent: CharacterBody2D = null

# Managers
var player_questions: PlayerQuestions
var opponent_questions: OpponentQuestions

# Network
var my_peer_id: int = 0
var opponent_peer_id: int = 0

# Combat
var is_my_turn: bool = false
var current_action: String = ""
var current_attacker_peer_id: int = 0

# Constants
var magic_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0
var defend_cooldown: float = 0.0
var player_turn_time: float = 0.0
var player_turn_max_time: float = 35.0
var player_timeout_triggered: bool = false

signal turn_changed(is_player_turn: bool)
signal health_updated

func _ready() -> void:
	lose.visible = false
	win.visible = false
	
	my_peer_id = multiplayer.get_unique_id()
	print("[MultiplayerBattle] Starting - my peer id: ", my_peer_id)
	
	# Get game manager and players
	game_manager = get_tree().root.get_child(0)  # Get root game scene
	if not game_manager or not game_manager.has_method("get_players"):
		print("[ERROR] Could not find game manager with get_players method!")
		return
	
	var players_array = game_manager.get_players()
	if players_array.size() != 2:
		print("[ERROR] Expected 2 players, got: ", players_array.size())
		return
	
	# Determine which player is mine
	player = players_array[0]
	opponent = players_array[1]
	opponent_peer_id = multiplayer.get_peers()[0] if multiplayer.get_peers().size() > 0 else 1
	
	print("[MultiplayerBattle] Player 1 peer: ", player.peer_id, " Player 2 peer: ", opponent.peer_id)
	print("[MultiplayerBattle] My peer id: ", my_peer_id, " Opponent peer id: ", opponent_peer_id)
	
	# Set up MultiplayerSpawner
	spawner.spawn_function = _spawn_player
	
	# Spawn both players visually
	if multiplayer.is_server():
		visual_player = _spawn_player_at_point(player.peer_id, spawn_point_1.global_position)
		visual_opponent = _spawn_player_at_point(opponent.peer_id, spawn_point_2.global_position)
	
	# Initialize question managers
	player_questions = question_control as PlayerQuestions
	if not player_questions:
		print("[ERROR] Could not find PlayerQuestions!")
	
	opponent_questions = OpponentQuestions.new()
	add_child(opponent_questions)
	
	# Initialize UI
	player_healthbar.init_health(150)
	opponent_healthbar.init_health(150)
	
	fight_button.pressed.connect(_on_fight_pressed)
	magic_button.pressed.connect(_on_magic_pressed)
	ultimate_button.pressed.connect(_on_ultimate_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	
	# Connect answer buttons
	if question_control and question_control.html_question:
		for button in question_control.html_question.get_children():
			if button is Button:
				button.pressed.connect(_on_answer_button_pressed.bind(button))
	
	# Start battle - server decides who goes first and picks background
	if multiplayer.is_server():
		# Pick a random background
		var random_bg_index = randi() % 4  # 0-3 for 4 backgrounds
		background_sprite.set_background.rpc(random_bg_index)
		
		var first_peer = my_peer_id if randf() > 0.5 else opponent_peer_id
		start_turn.rpc(first_peer)

func _spawn_player(peer_id: int) -> CharacterBody2D:
	"""Spawn function callback for MultiplayerSpawner"""
	print("[MultiplayerBattle] Spawning player for peer: ", peer_id)
	
	# Determine which spawn point to use
	var spawn_pos = spawn_point_1.global_position if peer_id == player.peer_id else spawn_point_2.global_position
	
	var new_player = PLAYER_SCENE.instantiate()
	new_player.position = spawn_pos
	new_player.peer_id = peer_id
	new_player.name = str(peer_id)
	
	return new_player

func _spawn_player_at_point(peer_id: int, spawn_pos: Vector2) -> CharacterBody2D:
	"""Spawn a player at a specific position via MultiplayerSpawner"""
	print("[MultiplayerBattle] Spawning player visual at position: ", spawn_pos)
	
	var new_player = spawner.spawn(peer_id)
	if new_player:
		new_player.global_position = spawn_pos
		
		# If this is my player, store reference
		if peer_id == my_peer_id:
			visual_player = new_player
		else:
			visual_opponent = new_player
	
	return new_player

func _process(delta: float) -> void:
	if not player or not opponent:
		return
	
	# Update player cooldowns
	player.update_cooldowns(delta)
	opponent.update_cooldowns(delta)
	
	# Update display
	var cooldown_info = player.get_cooldown_info()
	
	if cooldown_info["magic"] > 0:
		magic_cooldown_label.text = "Magic: %.1f" % cooldown_info["magic"]
		magic_cooldown_label.show()
		magic_button.disabled = true
	else:
		magic_cooldown_label.hide()
		magic_button.disabled = false
	
	if cooldown_info["ultimate"] > 0:
		ultimate_cooldown_label.text = "Ult: %.1f" % cooldown_info["ultimate"]
		ultimate_cooldown_label.show()
		ultimate_button.disabled = true
	else:
		ultimate_cooldown_label.hide()
		ultimate_button.disabled = false
	
	if cooldown_info["defend"] > 0:
		defend_cooldown_label.text = "Defend: %.1f" % cooldown_info["defend"]
		defend_cooldown_label.show()
		defend_button.disabled = true
	else:
		defend_cooldown_label.hide()
		defend_button.disabled = false

func _on_fight_pressed() -> void:
	if not is_my_turn or not player:
		return
	print("[MultiplayerBattle] Fight pressed")
	current_action = "fight"
	current_attacker_peer_id = my_peer_id
	execute_action.rpc(my_peer_id, "fight")
	options_menu.hide()
	start_question(Enum.Difficulty.EASY)

func _on_magic_pressed() -> void:
	if not is_my_turn or not player or not player.is_action_available("magic"):
		return
	print("[MultiplayerBattle] Magic pressed")
	current_action = "magic"
	current_attacker_peer_id = my_peer_id
	player.use_action("magic")
	execute_action.rpc(my_peer_id, "magic")
	options_menu.hide()
	start_question(Enum.Difficulty.MEDIUM)

func _on_defend_pressed() -> void:
	if not is_my_turn or not player or not player.is_action_available("defend"):
		return
	print("[MultiplayerBattle] Defend pressed")
	player.use_action("defend")
	execute_action.rpc(my_peer_id, "defend")
	defend_cooldown = 15
	end_turn()

func _on_ultimate_pressed() -> void:
	if not is_my_turn or not player or not player.is_action_available("ultimate"):
		return
	print("[MultiplayerBattle] Ultimate pressed")
	current_action = "ultimate"
	current_attacker_peer_id = my_peer_id
	player.use_action("ultimate")
	execute_action.rpc(my_peer_id, "ultimate")
	options_menu.hide()
	start_question(Enum.Difficulty.HARD)

func start_question(difficulty: Enum.Difficulty) -> void:
	options_menu.hide()
	question_control.load_question(difficulty)
	
	# Enable buttons and reset colors
	for button in question_control.html_question.get_children():
		if button is Button:
			button.disabled = false
			button.modulate = Color.WHITE
			
	question_control.show()

func _on_answer_button_pressed(button: Button) -> void:
	# Check if the answer is correct
	var current_question = question_control.current_quiz
	var is_correct = (button.text == current_question.correct)
	
	# Disable all buttons to prevent multiple clicks
	for btn in question_control.html_question.get_children():
		if btn is Button:
			btn.disabled = true
	
	# Visual feedback
	if is_correct:
		button.modulate = question_control.color_right
	else:
		button.modulate = question_control.color_wrong
	
	# Wait a moment for visual feedback
	await get_tree().create_timer(1.0).timeout
	
	# Hide question UI
	question_control.hide()
	
	# Handle result
	if is_correct:
		# Set cooldown for magic and ultimate actions
		if current_action == "magic":
			magic_cooldown = 20.0
		elif current_action == "ultimate":
			ultimate_cooldown = 60.0
		
		if not execute_action(my_peer_id, current_action):
			end_turn()
	else:
		if current_action == "magic":
			magic_cooldown = 20.0
		elif current_action == "ultimate":
			ultimate_cooldown = 60.0
		end_turn()

func _on_player_answer_selected(_button: Button, is_correct: bool) -> void:
	"""Handle player's answer"""
	print("[MultiplayerBattle] Answer selected - correct: ", is_correct)
	
	if not is_my_turn:
		return
	
	# Server processes the answer
	if multiplayer.is_server():
		process_action_answer(my_peer_id, is_correct)
	else:
		# Client sends to server
		process_action_answer.rpc_id(1, my_peer_id, is_correct)

@rpc("any_peer", "call_local", "reliable")
func execute_action(peer_id: int, action: String):
	"""Broadcast action to both players"""
	print("[MultiplayerBattle] Execute action - peer: ", peer_id, " action: ", action)
	
	if peer_id == my_peer_id:
		# My action - wait for answer
		pass
	else:
		# Opponent's action
		if opponent_questions:
			opponent_questions.show_waiting()

@rpc("authority", "call_local", "reliable")
func process_action_answer(peer_id: int, is_correct: bool) -> void:
	"""Server-only: Process answer and apply damage"""
	if not multiplayer.is_server() or not opponent:
		return
	
	print("[MultiplayerBattle] Processing answer - peer: ", peer_id, " correct: ", is_correct)
	
	var damage = 0
	
	if is_correct:
		match current_action:
			"fight":
				damage = 10  # FIGHT_DAMAGE
			"magic":
				damage = 15  # MAGIC_DAMAGE
			"ultimate":
				damage = 25  # ULTIMATE_DAMAGE
	
	# Apply damage to opponent
	opponent.take_damage(damage)
	print("[MultiplayerBattle] Damage dealt: ", damage, " - opponent health: ", opponent.health)
	
	# Sync health to both players
	sync_health.rpc(player.health, opponent.health)
	
	if check_victory():
		return
	
	# Switch turns
	end_turn()

@rpc("any_peer", "call_local", "reliable")
func start_turn(peer_id: int) -> void:
	"""Start a player's turn"""
	print("[MultiplayerBattle] Starting turn for peer: ", peer_id)
	
	is_my_turn = (peer_id == my_peer_id)
	current_action = ""
	
	update_turn_display()
	
	if is_my_turn:
		options_menu.show()
		timer_label.show()
	else:
		options_menu.hide()
		timer_label.hide()
		if opponent_questions:
			opponent_questions.show_waiting()
	
	turn_changed.emit(is_my_turn)

func end_turn() -> void:
	"""End current turn and switch to opponent"""
	if not multiplayer.is_server():
		return
	
	# Switch to opponent
	var next_peer = opponent_peer_id if is_my_turn else my_peer_id
	start_turn.rpc(next_peer)

@rpc("any_peer", "call_local", "reliable")
func sync_health(p_health: int, o_health: int) -> void:
	"""Sync health between both players"""
	if not player or not opponent:
		return
	
	print("[MultiplayerBattle] Syncing health - player: ", p_health, " opponent: ", o_health)
	
	player.health = p_health
	opponent.health = o_health
	update_health_display()
	health_updated.emit()

func update_turn_display() -> void:
	"""Update turn indicator"""
	if is_my_turn:
		turn_label.text = "YOUR TURN"
	else:
		turn_label.text = "OPPONENT'S TURN"

func update_health_display() -> void:
	"""Update health bars"""
	if player and player_healthbar:
		player_healthbar.health = player.health
	if opponent and opponent_healthbar:
		opponent_healthbar.health = opponent.health

func check_victory() -> bool:
	"""Check if battle is over"""
	if not player or not opponent:
		return false
		
	if opponent.health <= 0:
		show_victory()
		return true
	if player.health <= 0:
		show_defeat()
		return true
	return false

func show_victory() -> void:
	"""Show victory screen"""
	print("[MultiplayerBattle] Victory!")
	win.visible = true
	options_menu.hide()
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

func show_defeat() -> void:
	"""Show defeat screen"""
	print("[MultiplayerBattle] Defeat!")
	lose.visible = true
	options_menu.hide()
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Scenes/game.tscn")
