extends Control

# Combat state
var my_peer_id: int = 0
var opponent_peer_id: int = 0
var my_health: int = 150
var opponent_health: int = 150
var my_turn: bool = true
var combat_active: bool = true

# Cooldowns
var magic_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0
var defend_cooldown: float = 0.0

# Current action
var current_action: String = ""
var question_answered: bool = false
var answer_correct: bool = false

# UI References
@onready var turn_info_label: Label = $BattleLayout/Info
@onready var my_health_bar = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/HealthBar
@onready var opponent_health_bar = $BattleLayout/Battle/Bottom/Enemy/MarginContainer/VBoxContainer/HealthBar
@onready var question_info: Label = $BattleLayout/QuestionInfo
@onready var lose_label: Label = $BattleLayout/Lose
@onready var win_label: Label = $BattleLayout/Win

# Button references
@onready var magic_button = $BattleLayout/Battle/Options/Options/Magic
@onready var ultimate_button = $BattleLayout/Battle/Options/Options/Ultimate
@onready var fight_button = $BattleLayout/Battle/Options/Options/Fight
@onready var defend_button = $BattleLayout/Battle/Options/Options/Defend

# Cooldown labels
@onready var magic_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/MagicCooldownLabel
@onready var ultimate_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/UltimateCooldownLabel
@onready var defend_cooldown_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/DefendCooldownLabel

func _ready() -> void:
	my_peer_id = multiplayer.get_unique_id()
	print("[P2P Combat] My peer ID: ", my_peer_id)
	
	# Find opponent
	var peers = multiplayer.get_peers()
	if peers.size() > 0:
		opponent_peer_id = peers[0]
		print("[P2P Combat] Opponent peer ID: ", opponent_peer_id)
	
	# Determine turn order (lower peer ID goes first)
	my_turn = my_peer_id < opponent_peer_id
	print("[P2P Combat] My turn: ", my_turn)
	
	# Initialize UI
	if lose_label:
		lose_label.hide()
	if win_label:
		win_label.hide()
	if question_info:
		question_info.hide()
	
	update_ui()
	setup_buttons()

func _process(delta: float) -> void:
	update_cooldowns(delta)
	update_ui()

func setup_buttons() -> void:
	"""Setup action button connections"""
	if fight_button:
		fight_button.pressed.connect(_on_fight_pressed)
	if magic_button:
		magic_button.pressed.connect(_on_magic_pressed)
	if defend_button:
		defend_button.pressed.connect(_on_defend_pressed)
	if ultimate_button:
		ultimate_button.pressed.connect(_on_ultimate_pressed)

func update_cooldowns(delta: float) -> void:
	"""Update cooldown timers"""
	if magic_cooldown > 0:
		magic_cooldown -= delta
		if magic_cooldown <= 0:
			magic_cooldown = 0
	
	if ultimate_cooldown > 0:
		ultimate_cooldown -= delta
		if ultimate_cooldown <= 0:
			ultimate_cooldown = 0
	
	if defend_cooldown > 0:
		defend_cooldown -= delta
		if defend_cooldown <= 0:
			defend_cooldown = 0
	
	# Update UI labels
	if magic_cooldown_label:
		if magic_cooldown > 0:
			magic_cooldown_label.text = "Magic CD: %.1fs" % magic_cooldown
			magic_cooldown_label.visible = true
		else:
			magic_cooldown_label.visible = false
	
	if defend_cooldown_label:
		if defend_cooldown > 0:
			defend_cooldown_label.text = "Defend CD: %.1fs" % defend_cooldown
			defend_cooldown_label.visible = true
		else:
			defend_cooldown_label.visible = false
	
	if ultimate_cooldown_label:
		if ultimate_cooldown > 0:
			ultimate_cooldown_label.text = "Ultimate CD: %.1fs" % ultimate_cooldown
			ultimate_cooldown_label.visible = true
		else:
			ultimate_cooldown_label.visible = false

func update_ui() -> void:
	"""Update all UI elements"""
	if turn_info_label:
		if my_turn:
			turn_info_label.text = "PLAYER'S TURN"
			turn_info_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			turn_info_label.text = "OPPONENT'S TURN"
			turn_info_label.add_theme_color_override("font_color", Color.RED)
	
	# Update health bars
	if my_health_bar:
		my_health_bar.value = my_health
	
	if opponent_health_bar:
		opponent_health_bar.value = opponent_health
	
	# Update button disabled states based on cooldowns and turn
	if magic_button:
		magic_button.disabled = magic_cooldown > 0 or not my_turn
	if defend_button:
		defend_button.disabled = defend_cooldown > 0 or not my_turn
	if ultimate_button:
		ultimate_button.disabled = ultimate_cooldown > 0 or not my_turn
	if fight_button:
		fight_button.disabled = not my_turn

func get_action_damage(action: String) -> int:
	"""Get damage for action and apply cooldowns"""
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

func show_victory() -> void:
	"""Show victory screen"""
	combat_active = false
	if win_label:
		win_label.show()
	if fight_button:
		fight_button.disabled = true
	if magic_button:
		magic_button.disabled = true
	if defend_button:
		defend_button.disabled = true
	if ultimate_button:
		ultimate_button.disabled = true
	print("[P2P Combat] YOU WIN!")
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func show_defeat() -> void:
	"""Show defeat screen"""
	combat_active = false
	if lose_label:
		lose_label.show()
	if fight_button:
		fight_button.disabled = true
	if magic_button:
		magic_button.disabled = true
	if defend_button:
		defend_button.disabled = true
	if ultimate_button:
		ultimate_button.disabled = true
	print("[P2P Combat] YOU LOSE!")
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_fight_pressed() -> void:
	if not my_turn or not combat_active:
		return
	current_action = "fight"
	start_question("EASY")

func _on_magic_pressed() -> void:
	if not my_turn or not combat_active or magic_cooldown > 0:
		return
	current_action = "magic"
	start_question("MEDIUM")

func _on_defend_pressed() -> void:
	if not my_turn or not combat_active or defend_cooldown > 0:
		return
	current_action = "defend"
	start_question("EASY")

func _on_ultimate_pressed() -> void:
	if not my_turn or not combat_active or ultimate_cooldown > 0:
		return
	current_action = "ultimate"
	start_question("HARD")

func start_question(difficulty: String) -> void:
	"""Start answer question"""
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Answer the %s question correctly to use %s!" % [difficulty, current_action.to_upper()]
	dialog.confirmed.connect(_on_question_answered.bind(true))
	dialog.canceled.connect(_on_question_answered.bind(false))
	add_child(dialog)
	dialog.popup_centered_ratio(0.3)

func _on_question_answered(is_correct: bool) -> void:
	"""Handle question result and send to opponent via RPC"""
	answer_correct = is_correct
	question_answered = true
	
	if is_correct:
		print("[P2P Combat] Question answered correctly! Executing action: ", current_action)
		var damage = get_action_damage(current_action)
		if damage > 0:
			opponent_health -= damage
			print("[P2P Combat] Dealt %d damage to opponent" % damage)
		opponent_health = max(0, opponent_health)
		if opponent_health <= 0:
			show_victory()
		rpc("receive_opponent_action", current_action, true)
	else:
		print("[P2P Combat] Question answered incorrectly! Action failed.")
		rpc("receive_opponent_action", current_action, false)
	
	end_turn()

@rpc("any_peer")
func receive_opponent_action(action: String, is_correct: bool) -> void:
	"""Receive opponent's action result"""
	print("[P2P Combat] Opponent used: ", action, " | Correct: ", is_correct)
	
	if is_correct:
		var damage = get_action_damage(action)
		my_health -= damage
		my_health = max(0, my_health)
		if question_info:
			question_info.text = "OPPONENT GOT IT RIGHT! -%d HP" % damage
		print("[P2P Combat] Took %d damage from opponent" % damage)
	else:
		if question_info:
			question_info.text = "OPPONENT GOT IT WRONG!"
	
	if question_info:
		question_info.show()
		await get_tree().create_timer(2.0).timeout
		question_info.hide()
	
	if my_health <= 0:
		show_defeat()

func end_turn() -> void:
	"""End current turn and switch to opponent"""
	my_turn = false
	rpc("set_opponent_turn")

@rpc("any_peer")
func set_opponent_turn() -> void:
	"""Set opponent's turn"""
	my_turn = true
	print("[P2P Combat] Now my turn!")
