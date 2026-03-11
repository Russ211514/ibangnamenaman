extends Control

@onready var level1: TextureButton = $CanvasLayer/HBoxContainer/level1
@onready var level2: TextureButton = $CanvasLayer/HBoxContainer/level2
@onready var level3: TextureButton = $CanvasLayer/HBoxContainer/level3
@onready var level4: TextureButton = $CanvasLayer/HBoxContainer/level4
@onready var level5: TextureButton = $CanvasLayer/HBoxContainer/level5
@onready var level1_label: Label = $CanvasLayer/HBoxContainer/level1/Label
@onready var level2_label: Label = $CanvasLayer/HBoxContainer/level2/Label
@onready var level3_label: Label = $CanvasLayer/HBoxContainer/level3/Label
@onready var level4_label: Label = $CanvasLayer/HBoxContainer/level4/Label
@onready var level5_label: Label = $CanvasLayer/HBoxContainer/level5/Label

func _ready() -> void:
	update_level_buttons()
	
	# Connect level buttons
	if level1:
		level1.pressed.connect(_on_level_pressed.bind(1))
	if level2:
		level2.pressed.connect(_on_level_pressed.bind(2))
	if level3:
		level3.pressed.connect(_on_level_pressed.bind(3))

func update_level_buttons() -> void:
	# Level 1 is always available
	if level1:
		level1.disabled = false
		if level1_label:
			level1_label.visible = true
	
	# Level 2 unlocks after completing the html quiz part 2
	if level2:
		level2.disabled = not LevelCore.lvl1_completed
		if level2_label:
			level2_label.visible = not level2.disabled
	
	# Level 3 unlocks after level 2 is completed
	if level3:
		level3.disabled = not LevelCore.lvl2_completed
		if level3_label:
			level3_label.visible = not level3.disabled
	
	if level4:
		level4.disabled = not LevelCore.lvl3_completed
		if level4_label:
			level4_label.visible = not level4.disabled
	
	if level5:
		level5.disabled = not LevelCore.lvl4_completed
		if level5_label:
			level5_label.visible = not level5.disabled

func _on_level_pressed(level_number: int) -> void:
	match level_number:
		1:
			# Level 1 progression
			if LevelCore.html_mini_quiz_completed_2:
				# User has completed both mini quiz and part 2, go to start3
				get_tree().change_scene_to_file("res://Html Scenes/html tutorial start3.tscn")
			elif LevelCore.html_mini_quiz_completed:
				# User completed mini quiz, go to part 2
				get_tree().change_scene_to_file("res://Html Scenes/html tutorial start2.tscn")
			elif LevelCore.html_mini_quiz_completed_3:
				get_tree().change_scene_to_file("res://Html Scenes/final_level_html.tscn")
			else:
				# Start from the beginning
				get_tree().change_scene_to_file("res://Html Scenes/html tutorial start.tscn")
		2:
			if LevelCore.html_mini_quiz_completed:
				get_tree().change_scene_to_file("res://Html Scenes/html_topic2_level2.tscn")
			elif LevelCore.html_mini_quiz_completed_2:
				get_tree().change_scene_to_file("res://Html Scenes/final_mastery_test_level2.tscn")
			else:
				get_tree().change_scene_to_file("res://Html Scenes/html_start_level2.tscn")
		3:
			get_tree().change_scene_to_file("res://Html Scenes/html_battle.tscn")
		4:
			pass
		5:
			pass

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Language Selection.tscn")
