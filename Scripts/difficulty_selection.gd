extends Control

@export var game_scene: PackedScene
var bot_diff : int = 1

func select_difficulty(num):
	bot_diff = num
	if num == 0:
		$CanvasLayer/info.text = "- Enemy bot often gets the question wrong"
	if num == 1:
		$CanvasLayer/info.text = "- Enemy bot occasionally gets the question wrong\n- Player turn timer 35 seconds"
	if num == 2:
		$CanvasLayer/info.text = "- Enemy bot never misses a question\n- Player turn timer 25 seconds"

func _ready() -> void:
	select_difficulty(1)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/offline selection.tscn")

func _on_start_pressed() -> void:
	print("Game Started\n-------------")
	var game_instance = game_scene.instantiate()
	game_instance.set("IsServer", true)
	game_instance.set("IsBot", true)
	game_instance.set("PlayerName", DataSave.data.PlayerName)
	game_instance.set("BotDifficulty", bot_diff)
	game_instance.set_meta("BotDifficulty", bot_diff)
	get_tree().current_scene.add_child(game_instance)
	$CanvasLayer.visible = false

func _on_easy_pressed() -> void:
	select_difficulty(0)

func _on_normal_pressed() -> void:
	select_difficulty(1)

func _on_hard_pressed() -> void:
	select_difficulty(2)
