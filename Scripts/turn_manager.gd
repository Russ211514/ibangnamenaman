## Turn Manager - Handles only turn-taking system
extends Control

# Signals for turn state changes
signal turn_changed(new_turn: String)
signal player_turn_started
signal enemy_turn_started

@onready var info: Label = $BattleLayout/Info

var current_turn: String = "player"
var bot_difficulty: int = 1  # 0 = easy, 1 = normal, 2 = hard

func _ready() -> void:
	# Capture bot difficulty from parent scene
	if has_meta("BotDifficulty"):
		bot_difficulty = get_meta("BotDifficulty")
	
	if info:
		info.show()
	
	# Randomize starting turn
	if randf() > 0.5:
		current_turn = "enemy"
		_start_enemy_turn()
	else:
		current_turn = "player"
		_start_player_turn()

## Switch turn from player to enemy or vice versa
func switch_turn() -> void:
	if current_turn == "player":
		current_turn = "enemy"
		_start_enemy_turn()
	else:
		current_turn = "player"
		_start_player_turn()

## Start player's turn - emit signal and update UI
func _start_player_turn() -> void:
	if info:
		info.text = "PLAYER'S TURN"
	turn_changed.emit("player")
	player_turn_started.emit()

## Start enemy's turn - emit signal and update UI
func _start_enemy_turn() -> void:
	if info:
		info.text = "ENEMY'S TURN"
	turn_changed.emit("enemy")
	enemy_turn_started.emit()

## Check if it's the player's turn
func is_player_turn() -> bool:
	return current_turn == "player"

## Check if it's the enemy's turn
func is_enemy_turn() -> bool:
	return current_turn == "enemy"

## Get the current turn
func get_current_turn() -> String:
	return current_turn

## Get the bot difficulty
func get_bot_difficulty() -> int:
	return bot_difficulty
