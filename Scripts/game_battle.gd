extends Control

var current_turn: String = "player"
var player_defending = false
var opponent_defending = false
var player_defending_break_pending = false
var opponent_defending_break_pending = false

var paused = false

var my_peer_id: int = 0
var opponent_peer_id: int = 0
var my_health: int = 150
var opponent_health: int = 150
var my_turn: bool = true
var combat_active: bool = true

# Cooldowns
var magic_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0

# Turn timer
var player_turn_time: float = 0.0
var player_turn_max_time: float = 20.0

# Current action
var current_action: String = ""
var opponent_last_action: String = ""
var question_answered: bool = false
var answer_correct: bool = false

# Character animation references
var player_character
var opponent_character
var player_animator
var opponent_animator

# Projectile scene
var projectile_scene = preload("res://Art Assets/Wizard animations/projectile.tscn")

# UI References
@onready var info: Label = $BattleLayout/Info
@onready var my_health_bar = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/HealthBar
@onready var opponent_health_bar = $BattleLayout/Battle/Bottom/Enemy/MarginContainer/VBoxContainer/HealthBar
@onready var question_info: Label = $BattleLayout/QuestionInfo
@onready var lose_label: Label = $BattleLayout/Lose
@onready var win_label: Label = $BattleLayout/Win
@onready var _options_menu: Menu = $BattleLayout/Battle/Options/Options
@onready var html_game_controller: Control = $BattleLayout/Control

# Button references
@onready var magic_button = $BattleLayout/Battle/Options/Options/Magic
@onready var ultimate_button = $BattleLayout/Battle/Options/Options/Ultimate
@onready var fight_button = $BattleLayout/Battle/Options/Options/Fight
@onready var defend_button = $BattleLayout/Battle/Options/Options/Defend

# Cooldown labels
@onready var magic_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/MagicCooldownLabel
@onready var ultimate_cooldown_label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/UltimateCooldownLabel
@onready var defend_cooldown_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/DefendCooldownLabel
@onready var player_turn_timer_label: Label = $BattleLayout/Battle/Bottom/Player/MarginContainer/VBoxContainer/PlayerTurnTimerLabel

func _ready() -> void:
	# Use the existing Player and Enemy nodes from the scene instead of creating new ones
	player_character = $BattleLayout/Player
	opponent_character = $BattleLayout/Enemy
	
	# Get animators from existing nodes
	if player_character:
		player_animator = player_character.get_node_or_null("AnimatedSprite2D")
		if player_animator:
			print("[P2P Combat] Player animator found from scene")
			player_animator.visible = true
		else:
			print("[P2P Combat] Player animator NOT found in scene!")
	
	if opponent_character:
		opponent_animator = opponent_character.get_node_or_null("AnimatedSprite2D")
		if opponent_animator:
			print("[P2P Combat] Opponent animator found from scene")
			opponent_animator.visible = true
		else:
			print("[P2P Combat] Opponent animator NOT found in scene!")
	
	print("[P2P Combat] Animation setup - Player: ", player_animator != null, " Opponent: ", opponent_animator != null)
	
	# Verify BattleLayout exists
	var battle_layout = $BattleLayout
	if battle_layout:
		print("[BattleLayout] Exists and is visible: ", battle_layout.visible)
	
	if html_game_controller:
		html_game_controller.hide()
	
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
	
	# Initialize turn timer
	if my_turn:
		player_turn_time = player_turn_max_time
	else:
		player_turn_time = 0
	
	# Initialize UI
	if lose_label:
		lose_label.hide()
	if win_label:
		win_label.hide()
	if question_info:
		question_info.hide()
	
	# Show/hide options menu based on turn
	if not my_turn and _options_menu:
		_options_menu.hide()
	
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
	
	# Connect html game controller answer signal
	if html_game_controller:
		html_game_controller.answer_selected.connect(_on_answer_selected)

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
	
	# Update UI labels
	if magic_cooldown_label:
		if magic_cooldown > 0:
			magic_cooldown_label.text = "Magic CD: %.1fs" % magic_cooldown
			magic_cooldown_label.visible = true
		else:
			magic_cooldown_label.visible = false
	
	if defend_cooldown_label:
		defend_cooldown_label.visible = false
	
	if ultimate_cooldown_label:
		if ultimate_cooldown > 0:
			ultimate_cooldown_label.text = "Ultimate CD: %.1fs" % ultimate_cooldown
			ultimate_cooldown_label.visible = true
		else:
			ultimate_cooldown_label.visible = false
	
	# Update turn timer
	if player_turn_time > 0 and my_turn:
		player_turn_time -= delta
		if player_turn_timer_label:
			player_turn_timer_label.text = "Time: %.0fs" % max(0, player_turn_time)
			player_turn_timer_label.show()
		if player_turn_time <= 0:
			print("[Battle] Turn time expired! Ending turn.")
			end_turn()
	elif player_turn_timer_label and not my_turn:
		player_turn_timer_label.hide()

func update_ui() -> void:
	"""Update all UI elements"""
	if info:
		if my_turn:
			info.text = "PLAYER'S TURN"
			info.add_theme_color_override("font_color", Color.GREEN)
		else:
			info.text = "OPPONENT'S TURN"
			info.add_theme_color_override("font_color", Color.RED)
	
	# Update health bars
	if my_health_bar:
		my_health_bar.value = my_health
	
	if opponent_health_bar:
		opponent_health_bar.value = opponent_health
	
	# Update button disabled states based on cooldowns and turn
	if magic_button:
		magic_button.disabled = magic_cooldown > 0 or not my_turn
	if defend_button:
		defend_button.disabled = player_defending or not my_turn
	if ultimate_button:
		ultimate_button.disabled = ultimate_cooldown > 0 or not my_turn
	if fight_button:
		fight_button.disabled = not my_turn

func get_action_damage(action: String) -> int:
	"""Get damage for action without setting cooldowns"""
	match action:
		"fight":
			return 10
		"magic":
			return 15
		"ultimate":
			return 25
		"defend":
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
	start_question(Enum.Difficulty.EASY)

func _on_magic_pressed() -> void:
	if not my_turn or not combat_active or magic_cooldown > 0:
		return
	current_action = "magic"
	start_question(Enum.Difficulty.MEDIUM)

func _on_defend_pressed() -> void:
	if not my_turn or not combat_active or player_defending:
		return
	current_action = "defend"
	player_defending = true
	
	print("[Battle] Player defending")
	
	# Play local animation
	play_action_animation("defend")
	# Send animation sync to opponent peer (without call_local so opponent sees it)
	rpc("sync_opponent_animation", "defend")
	
	# Defend doesn't need a question, send action immediately
	# is_correct = true because defend action always succeeds
	rpc("receive_opponent_action", "defend", true)
	# Disable defend button while defending (no cooldown)
	defend_button.disabled = true
	
	await get_tree().create_timer(1.0).timeout
	# End turn
	end_turn()

func _on_ultimate_pressed() -> void:
	if not my_turn or not combat_active or ultimate_cooldown > 0:
		return
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

func _on_answer_selected(is_correct: bool, _selected_text: String) -> void:
	"""Handle answer selection from the question buttons"""
	# Disable all buttons to prevent multiple clicks
	for btn in html_game_controller.html_question.get_children():
		if btn is Button:
			btn.disabled = true
	
	# Wait a moment for visual feedback
	await get_tree().create_timer(1.0).timeout
	
	# Hide question UI
	html_game_controller.hide()
	_options_menu.show()
	
	# Handle result
	if is_correct:
		print("[Battle] Answer CORRECT! Action: ", current_action)
		
		# Set cooldown for magic and ultimate actions
		if current_action == "magic":
			magic_cooldown = 20.0
		elif current_action == "ultimate":
			ultimate_cooldown = 60.0
		
		# Calculate and apply damage
		var damage = 0
		match current_action:
			"fight":
				damage = 10
			"magic":
				damage = 15
			"ultimate":
				damage = 25
		
		# Check if opponent is defending - if so, mark for break on projectile hit
		if opponent_defending and damage > 0:
			opponent_defending_break_pending = true
			print("[Defend] Opponent is defending - will break on projectile hit")
			damage = 0
		
		opponent_health -= damage
		opponent_health = max(0, opponent_health)
		print("[Battle] Dealt %d damage to opponent" % damage)
		
		if opponent_health <= 0:
			show_victory()
		
		# Play attack animation for fight action and sync to opponent
		if current_action == "fight":
			print("[Battle] Playing fight animation and spawning projectile")
			# Hide and stop the turn timer
			if player_turn_timer_label:
				player_turn_timer_label.hide()
			player_turn_time = 0.0
			combat_active = false  # Prevent actions until animation completes
			
			if player_animator:
				print("[Battle] Waiting for animation_finished signal")
				play_action_animation("fight")
				rpc("sync_opponent_animation", "fight")
				await player_animator.animation_finished
				print("[Battle] Animation finished, now spawning projectile")
				spawn_and_fire_projectile()
				# Send to opponent via RPC
				rpc("receive_opponent_action", current_action, true)
				# Don't end turn yet - wait for projectile collision
				return
			else:
				print("[Battle] ERROR: player_animator is null!")
		
		# Send to opponent via RPC (for non-fight actions)
		rpc("receive_opponent_action", current_action, true)
	else:
		print("[Battle] Answer WRONG! Action failed.")
		
		# Set cooldown for magic and ultimate actions
		if current_action == "magic":
			magic_cooldown = 20.0
		elif current_action == "ultimate":
			ultimate_cooldown = 60.0
		
		# Send to opponent via RPC
		rpc("receive_opponent_action", current_action, false)
	
	# End turn (right away for wrong answer, after damage for correct answer)
	end_turn()

func play_action_animation(action: String) -> void:
	"""Play animation for player's action"""
	if not player_animator:
		if player_character:
			player_animator = player_character.get_node_or_null("AnimatedSprite2D")
			if not player_animator:
				print("[Animation] Cannot find animator!")
				return
		else:
			print("[Animation] Player character is null!")
			return
	
	var animation_name = "Defend"
	match action:
		"fight":
			animation_name = "Attack"
		"defend":
			animation_name = "Defend"
		"magic":
			animation_name = "Attack"
		"ultimate":
			animation_name = "Attack"
	
	print("[Animation] Playing animation: ", animation_name)
	player_animator.play(animation_name)

@rpc("any_peer", "call_remote")
func sync_opponent_animation(action: String) -> void:
	"""Sync opponent's animation across network - plays on opponent peer only"""
	if not opponent_animator:
		if opponent_character:
			opponent_animator = opponent_character.get_node_or_null("AnimatedSprite2D")
			if not opponent_animator:
				print("[Animation] Cannot find opponent animator!")
				return
		else:
			print("[Animation] Opponent character is null!")
			return
	
	var animation_name = "Defend"
	match action:
		"fight":
			animation_name = "Attack"
		"defend":
			animation_name = "Defend"
		"magic":
			animation_name = "Attack"
		"ultimate":
			animation_name = "Attack"
	
	print("[Animation] Opponent playing animation: ", animation_name)
	opponent_animator.play(animation_name)

func play_defend_break_animation() -> void:
	"""Play Defend Break animation when player's defense is broken"""
	print("[Animation Debug] play_defend_break_animation called")
	print("[Animation Debug] player_animator: ", player_animator)
	if player_animator:
		print("[Animation Debug] Checking for Defend Break animation...")
		if player_animator.sprite_frames and player_animator.sprite_frames.has_animation("Defend Break"):
			player_animator.play("Defend Break")
			print("[Animation Debug] Now playing player Defend Break animation")
		else:
			print("[Animation Debug] Defend Break animation not found in sprite frames!")
			if player_animator.sprite_frames:
				print("[Animation Debug] Available animations: ", player_animator.sprite_frames.get_animation_names())
	else:
		print("[Animation Debug] Player animator is null!")

func play_opponent_defend_break_animation() -> void:
	"""Play Defend Break animation on opponent when their defense is broken"""
	print("[Animation Debug] play_opponent_defend_break_animation called")
	if opponent_animator:
		if opponent_animator.sprite_frames and opponent_animator.sprite_frames.has_animation("Defend Break"):
			opponent_animator.play("Defend Break")
			print("[Animation Debug] Now playing opponent Defend Break animation")
		else:
			print("[Animation Debug] Opponent Defend Break animation not found!")
	else:
		print("[Animation Debug] Opponent animator is null!")

func play_opponent_hit_animation() -> void:
	"""Play Hit animation on opponent when struck by projectile"""
	print("[Animation Debug] play_opponent_hit_animation called")
	if opponent_animator:
		if opponent_animator.sprite_frames and opponent_animator.sprite_frames.has_animation("Hit"):
			opponent_animator.play("Hit")
			print("[Animation Debug] Now playing opponent Hit animation")
		else:
			print("[Animation Debug] Opponent Hit animation not found!")
			if opponent_animator.sprite_frames:
				print("[Animation Debug] Available animations: ", opponent_animator.sprite_frames.get_animation_names())
	else:
		print("[Animation Debug] Opponent animator is null!")

func play_player_hit_animation() -> void:
	"""Play Hit animation on player when struck by projectile"""
	print("[Animation Debug] play_player_hit_animation called")
	if player_animator:
		if player_animator.sprite_frames and player_animator.sprite_frames.has_animation("Hit"):
			player_animator.play("Hit")
			print("[Animation Debug] Now playing player Hit animation")
		else:
			print("[Animation Debug] Player Hit animation not found!")
			if player_animator.sprite_frames:
				print("[Animation Debug] Available animations: ", player_animator.sprite_frames.get_animation_names())
	else:
		print("[Animation Debug] Player animator is null!")

@rpc("any_peer", "call_remote")
func sync_opponent_defend_break() -> void:
	"""Sync opponent's Defend Break animation across network"""
	print("[Animation Debug] sync_opponent_defend_break called on remote peer")
	# On the remote peer, play THEIR OWN player defend break animation
	play_defend_break_animation()

func spawn_and_fire_projectile() -> void:
	"""Spawn and fire a projectile from player to opponent"""
	print("[Projectile] spawn_and_fire_projectile called")
	
	if not projectile_scene or not player_character or not opponent_character:
		print("[Projectile] ERROR: Missing resources")
		print("[Projectile]   projectile_scene: ", projectile_scene)
		print("[Projectile]   player_character: ", player_character)
		print("[Projectile]   opponent_character: ", opponent_character)
		return
	
	# Create projectile instance
	var projectile = projectile_scene.instantiate()
	print("[Projectile] Created projectile instance")
	
	# Position at player's weapon spawnpoint
	var spawn_point = player_character.get_node_or_null("ProjectileSpawnPoint")
	if spawn_point:
		projectile.global_position = spawn_point.global_position
		print("[Projectile] Using weapon spawnpoint at ", spawn_point.global_position)
	else:
		projectile.global_position = player_character.global_position
		print("[Projectile] No spawnpoint found, using character position")
	
	# Rotate toward opponent
	var direction = (opponent_character.global_position - projectile.global_position).normalized()
	projectile.global_rotation = direction.angle()
	projectile.SPEED = 1000.0
	projectile.visible = true
	projectile.modulate = Color.WHITE
	
	# Connect collision signal
	projectile.hit_target.connect(_on_projectile_hit.bindv([projectile]))
	
	# Add to scene
	$BattleLayout.add_child(projectile)
	print("[Projectile] Projectile added to scene at ", projectile.global_position, " visible: ", projectile.visible)
	print("[Projectile] Parent (BattleLayout) visible: ", $BattleLayout.visible)
	print("[Projectile] Parent parent visible: ", $BattleLayout.get_parent().visible if $BattleLayout.get_parent() else "N/A")
	
	# Wait for projectile to reach enemy or timeout
	var distance = player_character.global_position.distance_to(opponent_character.global_position)
	var travel_time = distance / 300.0
	
	await get_tree().create_timer(travel_time + 0.5).timeout
	
	# Clean up
	if is_instance_valid(projectile):
		projectile.queue_free()

@rpc("any_peer")
func spawn_opponent_projectile() -> void:
	"""Spawn opponent's projectile (called via RPC)"""
	if not projectile_scene or not opponent_character or not player_character:
		return
	
	var projectile = projectile_scene.instantiate()
	
	# Position at opponent's weapon spawnpoint
	var spawn_point = opponent_character.get_node_or_null("ProjectileSpawnPoint")
	if spawn_point:
		projectile.global_position = spawn_point.global_position
	else:
		projectile.global_position = opponent_character.global_position
	
	var direction = (player_character.global_position - projectile.global_position).normalized()
	projectile.global_rotation = direction.angle()
	projectile.SPEED = 1000.0
	projectile.visible = true
	projectile.modulate = Color.WHITE
	
	projectile.hit_target.connect(_on_opponent_projectile_hit.bindv([projectile]))
	
	$BattleLayout.add_child(projectile)
	
	print("[Projectile] Opponent fired projectile at ", projectile.global_position, " visible: ", projectile.visible)
	
	var distance = projectile.global_position.distance_to(player_character.global_position)
	var travel_time = distance / 300.0
	await get_tree().create_timer(travel_time + 0.5).timeout
	
	if is_instance_valid(projectile):
		projectile.queue_free()

func _on_projectile_hit(target: Node, _projectile: Node) -> void:
	"""Handle player's projectile hitting something"""
	print("[Projectile] Player projectile hit: ", target.name)
	print("[Projectile] opponent_defending_break_pending: ", opponent_defending_break_pending)
	print("[Projectile] opponent_defending: ", opponent_defending)
	
	# Play hit animation on opponent locally
	play_opponent_hit_animation()
	
	# Check if opponent was defending and should break now
	if opponent_defending_break_pending:
		print("[Defend] Opponent defend break triggered by projectile hit")
		# Play defend break on opponent's animator locally
		play_opponent_defend_break_animation()
		# Tell opponent peer to show our character breaking
		rpc("sync_opponent_defend_break")
		opponent_defending = false
		opponent_defending_break_pending = false
		if question_info:
			question_info.text = "YOUR PROJECTILE BROKE SHIELD"
	
	# Wait 2 seconds before allowing next turn
	await get_tree().create_timer(2.0).timeout
	combat_active = true
	# Now end turn after collision and delay
	end_turn()

func _on_opponent_projectile_hit(target: Node, _projectile: Node) -> void:
	"""Handle opponent's projectile hitting something"""
	print("[Projectile] Opponent projectile hit: ", target.name)
	
	# Play hit animation on player locally
	play_player_hit_animation()
	
	# Check if player was defending and should break now
	if player_defending_break_pending:
		print("[Defend] Player defend break triggered by projectile hit")
		play_defend_break_animation()
		player_defending = false
		defend_button.disabled = false  # Re-enable defend button after defense breaks
		player_defending_break_pending = false
		if question_info:
			question_info.text = "YOUR SHIELD WAS BROKEN"
	
	# Wait 2 seconds before allowing next turn
	await get_tree().create_timer(2.0).timeout
	combat_active = true

@rpc("any_peer")
func receive_opponent_action(action: String, is_correct: bool) -> void:
	"""Receive opponent's action result"""
	print("[P2P Combat] Opponent used: ", action, " | Correct: ", is_correct)
	# Track opponent's action for Defend Break checks
	opponent_last_action = action
	
	var damage = 0
	if action == "defend":
		# Show opponent used defend message
		opponent_defending = true
		if question_info:
			question_info.text = "OPPONENT USED DEFEND"
		print("[P2P Combat] Opponent is defending")
	elif is_correct:
		damage = get_action_damage(action)
		if question_info:
			question_info.text = "OPPONENT GOT IT RIGHT! -%d HP" % damage
		print("[P2P Combat] Opponent dealt %d damage" % damage)
		
		# Show opponent's attack projectile on our screen if they're attacking
		if action == "fight":
			spawn_opponent_projectile()
	else:
		if question_info:
			question_info.text = "OPPONENT GOT IT WRONG!"
	
	# Only break defense if damage > 0 (not from wrong answers or defend action)
	if player_defending and damage > 0:
		# Mark that defend should break when projectile hits
		player_defending_break_pending = true
		print("[Defend] Player defend break pending - will trigger on projectile collision")
		damage = 0  # Negate all damage when defending
		if question_info:
			question_info.text = "OPPONENT ATTACKING YOUR SHIELD"
	
	# Apply damage only if not defending
	if player_defending:
		damage = 0
	
	my_health -= damage
	my_health = max(0, my_health)
	if damage > 0:
		print("[P2P Combat] Took %d damage" % damage)
	
	if question_info:
		question_info.show()
		await get_tree().create_timer(2.0).timeout
		question_info.hide()
	
	if my_health <= 0:
		show_defeat()

func end_turn() -> void:
	"""End current turn and switch to opponent"""
	if _options_menu:
		_options_menu.hide()
	my_turn = false
	rpc("set_opponent_turn")

@rpc("any_peer")
func set_opponent_turn() -> void:
	"""Set opponent's turn"""
	my_turn = true
	player_turn_time = player_turn_max_time
	
	if _options_menu:
		_options_menu.show()
	print("[P2P Combat] Now my turn!")
