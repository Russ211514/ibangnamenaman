extends Sprite2D

var textures := [
	preload("res://Art Assets/backgrounds/bground.png"),
	preload("res://Art Assets/backgrounds/bg1.png"),
	preload("res://Art Assets/backgrounds/bg2.png"),
	preload("res://Art Assets/backgrounds/bg3.png")
]

func _ready() -> void:
	texture = textures.pick_random()
