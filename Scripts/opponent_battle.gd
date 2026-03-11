extends Control

@onready var _options: WindowDefault = $BattleLayout/Battle/Options
@onready var _options_menu: Menu = $BattleLayout/Battle/Options/Options
@onready var _enemy: Menu = $BattleLayout/Battle/Enemies
@onready var player_health_bar = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/HealthBar
@onready var enemy_health_bar = $BattleLayout/Battle/Bottom/Enemy/MarginContainer/VBoxContainer/HealthBar
@onready var magic_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/MagicCooldownLabel
@onready var ultimate_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/UltimateCooldownLabel
@onready var python_game_controller = $BattleLayout/Control
@onready var lose: Label = $BattleLayout/Lose
@onready var win: Label = $BattleLayout/Win
@onready var defend_cooldown_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/DefendCooldownLabel
@onready var player_turn_timer_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/PlayerTurnTimerLabel
@onready var info: Label = $BattleLayout/Info
@onready var question_info: Label = $BattleLayout/QuestionInfo

@onready var magic_button = $BattleLayout/Battle/Options/Options/Magic
@onready var ultimate_button = $BattleLayout/Battle/Options/Options/Ultimate
@onready var fight_button = $BattleLayout/Battle/Options/Options/Fight
@onready var defend_button = $BattleLayout/Battle/Options/Options/Defend

var magic_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0
var defend_cooldown: float = 0.0
var opponent_turn_time: float = 0.0
var opponent_turn_max_time: float = 35.0
var opponent_timeout_triggered: bool = false

var is_my_turn: bool = false  # Wait for player's turn to finish first
var opponent_defending: bool = false
var player_defending: bool = false
var current_action: String = ""
var my_peer_id: int = 0
var player_peer_id: int = 0

# Health tracking (local)
var my_health: int = 150
var player_health: int = 150
var game_over: bool = false

func _ready() -> void:
	my_peer_id = multiplayer.get_unique_id()
	print("[OpponentBattle] My peer ID: ", my_peer_id, " - I am OPPONENT")
	
	if question_info:
		question_info.hide()
	if info:
		info.show()
	if player_turn_timer_label:
		player_turn_timer_label.hide()
	lose.visible = false
	win.visible = false
	python_game_controller.visible = false
	
	_options_menu.button_focus(0)
	player_health_bar.init_health(150)
	enemy_health_bar.init_health(150)
	
	# Connect action buttons
	fight_button.pressed.connect(_on_fight_pressed)
	magic_button.pressed.connect(_on_magic_pressed)
	ultimate_button.pressed.connect(_on_ultimate_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	
	# Connect answer buttons
	if python_game_controller and python_game_controller.python_question:
		for button in python_game_controller.python_question.get_children():
			if button is Button:
				button.pressed.connect(_on_answer_button_pressed.bind(button))
	
	# Get player peer ID
	var peers = multiplayer.get_peers()
	if peers.size() > 0:
		player_peer_id = peers[0]
		print("[OpponentBattle] Player peer ID: ", player_peer_id)
	
	# Initialize state - opponent starts waiting for player to finish their turn
	is_my_turn = false
	my_health = 150
	player_health = 150
	game_over = false
	opponent_timeout_triggered = false
	
	# Show waiting UI
	if info:
		info.text = "OPPONENT'S TURN"
	_options_menu.hide()

func _process(delta: float) -> void:
	# Update cooldown displays
	_update_cooldowns(delta)
	
	# Handle turn timer when it's my turn
	if is_my_turn and _options_menu.visible and not game_over:
		opponent_turn_time -= delta
		if player_turn_timer_label:
			player_turn_timer_label.text = "Time: %.0f s" % max(0, opponent_turn_time)
		
		# Timeout - skip turn
		if opponent_turn_time <= 0 and not opponent_timeout_triggered:
			opponent_timeout_triggered = true
			print("[OpponentBattle] Turn timeout!")
			_on_turn_ended(false)  # false = didn't perform action

func _update_cooldowns(delta: float) -> void:
	"""Update all cooldown timers"""
	if magic_cooldown > 0:
		magic_cooldown -= delta
		if magic_cooldown <= 0:
			magic_cooldown = 0
			if current_turn == "opponent" and _options_menu.visible:
				magic_button.disabled = false
	
	if ultimate_cooldown > 0:
		ultimate_cooldown -= delta
		if ultimate_cooldown <= 0:
			ultimate_cooldown = 0
			if current_turn == "opponent" and _options_menu.visible:
				ultimate_button.disabled = false
	
	if defend_cooldown > 0:
		defend_cooldown -= delta
		if defend_cooldown <= 0:
			defend_cooldown = 0
			if current_turn == "opponent" and _options_menu.visible:
				defend_button.disabled = false

func _on_fight_pressed() -> void:
	if not is_my_turn:
		return
	current_action = "fight"
	start_question(Enum.Difficulty.EASY)

func _on_magic_pressed() -> void:
	if not is_my_turn:
		return
	current_action = "magic"
	start_question(Enum.Difficulty.MEDIUM)

func _on_defend_pressed() -> void:
	if not is_my_turn:
		return
	current_action = "defend"
	opponent_defending = true
	defend_cooldown = 15.0
	_on_turn_ended(true)  # true = action performed (defend doesn't need question)

func _on_ultimate_pressed() -> void:
	if not is_my_turn:
		return
	current_action = "ultimate"
	start_question(Enum.Difficulty.HARD)

func start_question(difficulty: Enum.Difficulty) -> void:
	"""Show question to opponent and wait for answer"""
	_options_menu.hide()
	python_game_controller.load_question(difficulty)
	
	# Enable buttons and reset colors
	for button in python_game_controller.python_question.get_children():
		if button is Button:
			button.disabled = false
			button.modulate = Color.WHITE
	
	python_game_controller.show()

func _on_answer_button_pressed(button: Button) -> void:
	"""Opponent answered a question"""
	var is_correct = button.text == "Correct"  # Adjust based on your question structure
	
	python_game_controller.hide()
	
	if is_correct:
		question_info.show()
		question_info.text = "YOU GOT IT RIGHT!"
		await get_tree().create_timer(1.0).timeout
		question_info.hide()
		
		# Deal damage to player
		var damage = get_action_damage(current_action)
		player_health -= damage
		print("[OpponentBattle] Action correct! Damage: ", damage, " to player")
	else:
		question_info.show()
		question_info.text = "YOU GOT IT WRONG!"
		await get_tree().create_timer(1.0).timeout
		question_info.hide()
		print("[OpponentBattle] Action failed!")
	
	# End my turn
	_on_turn_ended(is_correct)

func _on_turn_ended(action_performed: bool) -> void:
	"""End my turn and notify player"""
	print("[OpponentBattle] My turn ending")
	
	# Check for game over
	if player_health <= 0:
		player_health = 0
		game_over = true
		show_victory()
		return
	
	# Hide my options
	_options_menu.hide()
	if player_turn_timer_label:
		player_turn_timer_label.hide()
	if info:
		info.text = "OPPONENT'S TURN"
	
	# Switch to player's turn
	is_my_turn = false
	opponent_defending = false
	current_action = ""
	opponent_timeout_triggered = false
	
	# Notify player about my action
	enemy_action_received.rpc(current_action, action_performed, player_health)

func get_action_damage(action: String) -> int:
	"""Get damage and apply cooldown for my action"""
	match action:
		"fight":
			return 10
		"magic":
			magic_cooldown = 20.0
			return 15
		"ultimate":
			ultimate_cooldown = 60.0
			return 25
		"defend":
			defend_cooldown = 15.0
			return 0
		_:
			return 0

func get_action_damage_value(action: String) -> int:
	"""Get damage value for player's action (no cooldown)"""
	match action:
		"fight":
			return 10
		"magic":
			return 15
		"ultimate":
			return 25
		"defend":
			player_defending = true
			return 0
		_:
			return 0

func show_victory() -> void:
	"""Show victory screen"""
	win.visible = true
	_options_menu.hide()
	print("[OpponentBattle] VICTORY!")
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func show_defeat() -> void:
	"""Show defeat screen"""
	lose.visible = true
	_options_menu.hide()
	print("[OpponentBattle] DEFEAT!")
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

@rpc("any_peer", "call_local", "reliable")
func enemy_action_received(action: String, action_performed: bool, new_player_health: int) -> void:
	"""Receive notification that player finished their turn"""
	print("[OpponentBattle] Received player action: ", action, " Success: ", action_performed)
	
	# Update player's health from their report
	player_health = new_player_health
	enemy_health_bar.health = player_health
	
	# If they dealt damage and were successful, show message
	if action_performed and action != "defend":
		question_info.show()
		question_info.text = "OPPONENT GOT IT RIGHT!"
		await get_tree().create_timer(1.0).timeout
		question_info.hide()
		
		# Calculate damage and apply it
		var damage = get_action_damage_value(action)
		my_health -= damage
		player_health_bar.health = my_health
		print("[OpponentBattle] Took ", damage, " damage! My health: ", my_health)
	else:
		question_info.show()
		question_info.text = "OPPONENT GOT IT WRONG!"
		await get_tree().create_timer(1.0).timeout
		question_info.hide()
	
	# Check if I'm defeated
	if my_health <= 0:
		my_health = 0
		game_over = true
		show_defeat()
		return
	
	# It's now my turn
	is_my_turn = true
	if info:
		info.text = "YOUR TURN"
	_options_menu.show()
	
	# Reset cooldowns display
	magic_button.disabled = (magic_cooldown > 0)
	ultimate_button.disabled = (ultimate_cooldown > 0)
	defend_button.disabled = (defend_cooldown > 0)
	
	# Start turn timer
	opponent_timeout_triggered = false
	opponent_turn_time = opponent_turn_max_time
	if player_turn_timer_label:
		player_turn_timer_label.show()
	
	_options_menu.button_focus(0)
