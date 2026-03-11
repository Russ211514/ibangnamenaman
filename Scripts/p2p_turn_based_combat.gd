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
@onready var turn_info_label: Label = $VBoxContainer/TurnInfoLabel
@onready var my_health_label: Label = $VBoxContainer/MyHealthLabel
@onready var opponent_health_label: Label = $VBoxContainer/OpponentHealthLabel
@onready var opponent_action_result: Label = $VBoxContainer/OpponentActionResultLabel
@onready var action_buttons_container: VBoxContainer = $VBoxContainer/ActionButtonsContainer
@onready var magic_cooldown_label: Label = $VBoxContainer/ActionButtonsContainer/MagicCooldownLabel
@onready var defend_cooldown_label: Label = $VBoxContainer/ActionButtonsContainer/DefendCooldownLabel
@onready var ultimate_cooldown_label: Label = $VBoxContainer/ActionButtonsContainer/UltimateCooldownLabel

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
	update_ui()
	setup_buttons()

func _process(delta: float) -> void:
	update_cooldowns(delta)
	update_ui()

func setup_buttons() -> void:
	"""Setup action button connections"""
	var fight_btn = $VBoxContainer/ActionButtonsContainer/FightButton
	var magic_btn = $VBoxContainer/ActionButtonsContainer/MagicButton
	var defend_btn = $VBoxContainer/ActionButtonsContainer/DefendButton
	var ultimate_btn = $VBoxContainer/ActionButtonsContainer/UltimateButton
	
	if fight_btn:
		fight_btn.pressed.connect(_on_fight_pressed)
	if magic_btn:
		magic_btn.pressed.connect(_on_magic_pressed)
	if defend_btn:
		defend_btn.pressed.connect(_on_defend_pressed)
	if ultimate_btn:
		ultimate_btn.pressed.connect(_on_ultimate_pressed)

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
	"""Start answer question - simplified for demo"""
	action_buttons_container.visible = false
	
	# Create simple question dialog (you can replace with your question system)
	var dialog = AlertDialog.new()
	dialog.dialog_text = "Answer the %s question correctly to use %s!" % [difficulty, current_action]
	dialog.confirmed.connect(_on_question_answered.bind(true))
	dialog.canceled.connect(_on_question_answered.bind(false))
	add_child(dialog)
	dialog.popup_centered_ratio(0.3)

func _on_question_answered(is_correct: bool) -> void:
	"""Handle question result and send to opponent via RPC"""
	answer_correct = is_correct
	question_answered = true
	action_buttons_container.visible = true
	
	if is_correct:
		print("[P2P Combat] Question answered correctly! Executing action: ", current_action)
		apply_action(current_action)
		rpc("receive_opponent_action", current_action, true)
	else:
		print("[P2P Combat] Question answered incorrectly! Action failed.")
		rpc("receive_opponent_action", current_action, false)
	
	end_turn()

func apply_action(action: String) -> void:
	"""Apply action damage to opponent"""
	var damage = get_action_damage(action)
	if answer_correct and damage > 0:
		opponent_health -= damage
		print("[P2P Combat] Dealt %d damage to opponent" % damage)
	
	opponent_health = max(0, opponent_health)
	
	if opponent_health <= 0:
		show_victory()

@rpc("any_peer")
func receive_opponent_action(action: String, is_correct: bool) -> void:
	"""Receive opponent's action result"""
	print("[P2P Combat] Opponent used: ", action, " | Correct: ", is_correct)
	
	if is_correct:
		var damage = get_action_damage(action)
		my_health -= damage
		my_health = max(0, my_health)
		opponent_action_result.text = "Opponent used %s! (-%.0f HP)" % [action.to_upper(), damage]
		print("[P2P Combat] Took %d damage from opponent" % damage)
	else:
		opponent_action_result.text = "Opponent's action FAILED! (0 damage)"
	
	opponent_action_result.show()
	await get_tree().create_timer(2.0).timeout
	opponent_action_result.hide()
	
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
			turn_info_label.text = "YOUR TURN"
			turn_info_label.add_theme_color_override("font_color", Color.GREEN)
			if action_buttons_container:
				action_buttons_container.visible = true
		else:
			turn_info_label.text = "OPPONENT'S TURN"
			turn_info_label.add_theme_color_override("font_color", Color.RED)
			if action_buttons_container:
				action_buttons_container.visible = false
	
	if my_health_label:
		my_health_label.text = "Your Health: %d/150" % my_health
	
	if opponent_health_label:
		opponent_health_label.text = "Opponent Health: %d/150" % opponent_health
	
	# Update button disabled states based on cooldowns
	var magic_btn = $VBoxContainer/ActionButtonsContainer/MagicButton
	var defend_btn = $VBoxContainer/ActionButtonsContainer/DefendButton
	var ultimate_btn = $VBoxContainer/ActionButtonsContainer/UltimateButton
	
	if magic_btn:
		magic_btn.disabled = magic_cooldown > 0 or not my_turn
	if defend_btn:
		defend_btn.disabled = defend_cooldown > 0 or not my_turn
	if ultimate_btn:
		ultimate_btn.disabled = ultimate_cooldown > 0 or not my_turn

func show_victory() -> void:
	"""Show victory screen"""
	combat_active = false
	if action_buttons_container:
		action_buttons_container.visible = false
	if turn_info_label:
		turn_info_label.text = "YOU WIN!"
		turn_info_label.add_theme_color_override("font_color", Color.GOLD)
	print("[P2P Combat] YOU WIN!")
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func show_defeat() -> void:
	"""Show defeat screen"""
	combat_active = false
	if action_buttons_container:
		action_buttons_container.visible = false
	if turn_info_label:
		turn_info_label.text = "YOU LOSE!"
		turn_info_label.add_theme_color_override("font_color", Color.RED)
	print("[P2P Combat] YOU LOSE!")
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
