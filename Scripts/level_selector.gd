extends Node2D

@onready var button: Button = %Button
@onready var button_2: Button = %Button2
@onready var button_3: Button = %Button3
@onready var lvl_1_locked: ColorRect = $lvl1_locked
@onready var lvl_2_locked: ColorRect = $lvl2_locked
@onready var lvl_3_locked: ColorRect = $lvl3_locked
@onready var lock_button_level_selection: Sprite2D = $LockButtonLevelSelection
@onready var lock_button_level_selection_2: Sprite2D = $LockButtonLevelSelection2
@onready var label_5: Label = $Label5

func _ready() -> void:
	button.grab_focus()

	if LevelCore.lvl1_completed == true:
		lvl_1_locked.visible = false
		lock_button_level_selection.visible = false
	if LevelCore.lvl1_completed == false:
		lvl_1_locked.visible = true
		lock_button_level_selection.visible = true
