extends CharacterBody2D
class_name Player

#@onready var projectile = preload("res://player/projectile.tscn")

func _enter_tree() -> void:
	set_multiplayer_authority(int(str(name)))

func _ready() -> void:
	if !is_multiplayer_authority():
		return

#func _physics_process(delta: float) -> void:
	#var projectile_temp = projectile.instantiate()
	#add_child(projectile_temp)
