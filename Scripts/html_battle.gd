extends Control

@onready var _options: WindowDefault = $BattleLayout/Battle/Options
@onready var _options_menu: Menu = $BattleLayout/Battle/Options/Options
@onready var _enemy: Menu = $BattleLayout/Battle/Enemies
@onready var player_health_bar = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/HealthBar
@onready var enemy_health_bar = $BattleLayout/Battle/Bottom/Enemy/MarginContainer/VBoxContainer/HealthBar
@onready var magic_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/MagicCooldownLabel
@onready var ultimate_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/UltimateCooldownLabel
@onready var html_game_controller = $BattleLayout/Control
@onready var lose: Label = $BattleLayout/Lose
@onready var win: Label = $BattleLayout/Win
@onready var defend_cooldown_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/DefendCooldownLabel
@onready var player_turn_timer_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/PlayerTurnTimerLabel
@onready var info: Label = $BattleLayout/Info
@onready var question_info: Label = $BattleLayout/QuestionInfo
@onready var pause_menu: Control = $BattleLayout/PauseMenu

@onready var magic_button = $BattleLayout/Battle/Options/Options/Magic
@onready var ultimate_button = $BattleLayout/Battle/Options/Options/Ultimate
@onready var fight_button = $BattleLayout/Battle/Options/Options/Fight
@onready var defend_button = $BattleLayout/Battle/Options/Options/Defend

@onready var pause_menu_resume_button = $PauseMenu/MarginContainer/VBoxContainer/Resume
@onready var pause_menu_leave_button = $PauseMenu/MarginContainer/VBoxContainer/Leave

var magic_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0
var player_turn_time: float = 0.0
var player_turn_max_time: float = 35.0
var player_timeout_triggered: bool = false

var current_turn = "player"
var player_defending = false
var current_action = ""
var bot_difficulty: int = 1  # 0 = easy, 1 = normal, 2 = hard

var paused = false

func _ready() -> void:
	#$BattleLayout/Player/AnimatedSprite2D.play("Idle")
	# Capture bot difficulty from parent scene
	if has_meta("BotDifficulty"):
		bot_difficulty = get_meta("BotDifficulty")
	
	if question_info:
		question_info.hide()
	if info:
		info.show()
	if player_turn_timer_label:
		player_turn_timer_label.hide()
	lose.visible = false
	win.visible = false
	html_game_controller.visible = false
	
	pause_menu.hide()
	
	_options_menu.button_focus(0)
	player_health_bar.init_health(150)
	enemy_health_bar.init_health(150)
	
	# Connect action buttons to display questions
	fight_button.pressed.connect(_on_fight_pressed)
	magic_button.pressed.connect(_on_magic_pressed)
	ultimate_button.pressed.connect(_on_ultimate_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	
	
	# Connect answer buttons
	if html_game_controller and html_game_controller.html_question:
		for button in html_game_controller.html_question.get_children():
			if button is Button:
				button.pressed.connect(_on_answer_button_pressed.bind(button))
	
	# Randomize starting turn
	if randf() > 0.5:
		current_turn = "enemy"
		if info:
			info.text = "ENEMY'S TURN"
		_options_menu.hide()
		enemy_turn()
	else:
		current_turn = "player"
		# Set timer for player's first turn
		match bot_difficulty:
			0:
				player_turn_max_time = 0.0
			1:
				player_turn_max_time = 35.0
			2:
				player_turn_max_time = 25.0
			_:
				player_turn_max_time = 35.0
		player_turn_time = player_turn_max_time
		if player_turn_timer_label and player_turn_max_time > 0:
			player_turn_timer_label.show()
		if info:
			info.text = "PLAYER'S TURN"

func _process(delta):
	if magic_cooldown > 0:
		magic_cooldown -= delta
		magic_cooldown_label.text = "Magic: %.1f" % magic_cooldown
		magic_cooldown_label.show()
		if magic_cooldown <= 0:
			magic_cooldown = 0
			magic_cooldown_label.hide()
			if current_turn == "player" and _options_menu.visible:
				magic_button.disabled = false
	else:
		magic_cooldown_label.hide()
	
	if ultimate_cooldown > 0:
		ultimate_cooldown -= delta
		ultimate_cooldown_label.text = "Ult: %.1f" % ultimate_cooldown
		ultimate_cooldown_label.show()
		if ultimate_cooldown <= 0:
			ultimate_cooldown = 0
			ultimate_cooldown_label.hide()
			if current_turn == "player" and _options_menu.visible:
				ultimate_button.disabled = false
	else:
		ultimate_cooldown_label.hide()
	
	defend_cooldown_label.hide()
	
	if player_turn_time > 0 and current_turn == "player":
		player_turn_time -= delta
		if player_turn_timer_label:
			player_turn_timer_label.text = "Time: %.0fs" % max(0, player_turn_time)
			player_turn_timer_label.show()
		if player_turn_time <= 0 and not player_timeout_triggered:
			player_turn_time = 0
			player_timeout_triggered = true
			if player_turn_timer_label:
				player_turn_timer_label.hide()
			# Show timeout message
			if question_info:
				question_info.text = "TIME RAN OUT"
				question_info.show()
				# Wait 2 seconds then lose turn
				await get_tree().create_timer(2.0).timeout
				question_info.hide()
				lose_turn()
	elif current_turn == "enemy":
		if player_turn_timer_label:
			player_turn_timer_label.hide()
	
	if Input.is_action_just_pressed("pause"):
		PauseMenu()

func PauseMenu():
	if paused:
		# Resume the game
		pause_menu.hide()
		Engine.time_scale = 1
		enable_option_menu_buttons()
	else:
		# Pause the game
		disable_option_menu_buttons()
		pause_menu.show()
		Engine.time_scale = 0
	
	paused = !paused

func disable_option_menu_buttons():
	for child in _options_menu.get_children():
		if child is Button:
			child.disabled = true

func enable_option_menu_buttons():
	if _options_menu.visible:
		for child in _options_menu.get_children():
			if child is Button:
				child.disabled = false

func _on_pause_menu_resume() -> void:
	PauseMenu()

func _on_pause_menu_leave() -> void:
	get_tree().change_scene_to_file("res://Scenes/offline selection.tscn")

func _on_options_button_pressed(button: BaseButton) -> void:
	match button.text:
		"Fight":
			_enemy.button_focus()

func _on_fight_pressed() -> void:
	current_action = "fight"
	start_question(Enum.Difficulty.EASY)

func _on_magic_pressed() -> void:
	current_action = "magic"
	start_question(Enum.Difficulty.MEDIUM)

func _on_defend_pressed() -> void:
	current_action = "defend"
	player_defending = true
	_options_menu.hide()
	$BattleLayout/Player/AnimatedSprite2D.play("Defend")
	await $BattleLayout/Player/AnimatedSprite2D.animation_finished
	# Disable defend button while defending
	defend_button.disabled = true
	switch_turn()

func _on_ultimate_pressed() -> void:
	current_action = "ultimate"
	start_question(Enum.Difficulty.HARD)

func start_question(difficulty: Enum.Difficulty) -> void:
	_options_menu.hide()
	html_game_controller.load_question(difficulty)
	
	# Enable buttons and reset colors
	for button in html_game_controller.html_question.get_children():
		if button is Button:
			button.disabled = false
			button.modulate = Color.WHITE
			
	html_game_controller.show()

func _on_answer_button_pressed(button: Button) -> void:
	# Check if the answer is correct
	var current_question = html_game_controller.current_quiz
	var is_correct = (button.text == current_question.correct)
	
	# Disable all buttons to prevent multiple clicks
	for btn in html_game_controller.html_question.get_children():
		if btn is Button:
			btn.disabled = true
	
	# Visual feedback
	if is_correct:
		button.modulate = html_game_controller.color_right
	else:
		button.modulate = html_game_controller.color_wrong
	
	# Wait a moment for visual feedback
	await get_tree().create_timer(1.0).timeout
	
	# Hide question UI
	html_game_controller.hide()
	
	# Handle result
	if is_correct:
		# Set cooldown for magic and ultimate actions
		if current_action == "magic":
			magic_cooldown = 20.0
		elif current_action == "ultimate":
			ultimate_cooldown = 60.0
		
		if not perform_action():
			switch_turn()
	else:
		if current_action == "magic":
			magic_cooldown = 20.0
		elif current_action == "ultimate":
			ultimate_cooldown = 60.0
		lose_turn()

func perform_action() -> bool:
	var damage = 0
	match current_action:
		"fight":
			damage = 10
		"magic":
			damage = 15
		"ultimate":
			damage = 25
	if current_turn == "player":
		enemy_health_bar.health -= damage
	else:
		player_health_bar.health -= damage
	return check_victory()

func check_victory() -> bool:
	if player_health_bar.health <= 0:
		lose.visible = true
		# Handle lose
		get_tree().create_timer(2.0).timeout.connect(func(): get_tree().change_scene_to_file("res://Scenes/offline selection.tscn"))
		return true
	elif enemy_health_bar.health <= 0:
		win.visible = true
		# Handle win
		get_tree().create_timer(2.0).timeout.connect(func(): get_tree().change_scene_to_file("res://Scenes/offline selection.tscn"))
		return true
	return false

func switch_turn() -> void:
	if current_turn == "player":
		_options_menu.hide()
		current_turn = "enemy"
		if info:
			info.text = "ENEMY'S TURN"
		if player_turn_timer_label:
			player_turn_timer_label.hide()
		enemy_turn()
	else:
		current_turn = "player"
		# Don't reset player_defending here - let it persist until the player is damaged
		_options_menu.show()
		if info:
			info.text = "PLAYER'S TURN"
		
		# Set timer based on difficulty
		match bot_difficulty:
			0:  # Easy - no timer
				player_turn_max_time = 0.0
			1:  # Normal - 35 seconds
				player_turn_max_time = 35.0
			2:  # Hard - 25 seconds
				player_turn_max_time = 25.0
			_:
				player_turn_max_time = 35.0
		
		# Start player turn timer
		player_timeout_triggered = false
		player_turn_time = player_turn_max_time
		if player_turn_timer_label and player_turn_max_time > 0:
			player_turn_timer_label.show()
		
		magic_button.disabled = (magic_cooldown > 0)
		ultimate_button.disabled = (ultimate_cooldown > 0)
		
		_options_menu.button_focus(0)

func enemy_turn() -> void:
	if not is_inside_tree(): return
	# Wait 2 seconds before attacking
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree(): return
	
	# Enemy chooses an action based on difficulty
	var enemy_action = "fight"
	if randf() > 0.25:
		enemy_action = "magic"
	if randf() > 0.25:
		enemy_action = "ultimate"
	
	# Enemy answers question with accuracy based on difficulty
	var is_correct = _enemy_answer_correct(bot_difficulty, enemy_action)
	
	# Display result in question info label
	if question_info:
		if is_correct:
			question_info.text = "ENEMY GOT IT RIGHT"
		else:
			question_info.text = "ENEMY GOT IT WRONG"
		question_info.show()
		await get_tree().create_timer(2.0).timeout
		question_info.hide()
	
	var damage = 0
	if is_correct:
		match enemy_action:
			"fight":
				damage = 10
			"magic":
				damage = 15
			"ultimate":
				damage = 25
	else:
		# Enemy gets question wrong, minimal/no damage
		damage = 0
	
	# If player is defending, only break defense if there's actual damage (> 0)
	if player_defending and damage > 0:
		# Play Defend Break animation when the enemy's attack would hit
		$BattleLayout/Player/AnimatedSprite2D.play("Defend Break")
		print("[Battle] Player defending - Shield broken!")
		player_defending = false  # Defense is broken after blocking an attack
		# Re-enable defend button after defense breaks
		defend_button.disabled = false
		if not check_victory():
			switch_turn()
		return
	
	player_health_bar.health -= damage
	if not check_victory():
		switch_turn()

func _enemy_answer_correct(difficulty: int, _action: String) -> bool:
	# Based on difficulty, determine if enemy answers correctly
	# 0 = easy (often wrong), 1 = normal (occasionally wrong), 2 = hard (never wrong)
	match difficulty:
		0:  # Easy - enemy gets it wrong 70% of the time
			return randf() > 0.6
		1:  # Normal - enemy gets it wrong 40% of the time
			return randf() > 0.4
		2:  # Hard - enemy never gets it wrong
			return true
		_:  # Default to normal
			return randf() > 0.4

func lose_turn() -> void:
	# Player loses their turn without taking action
	_options_menu.hide()
	html_game_controller.hide()
	# Enemy still gets their turn
	switch_turn()
