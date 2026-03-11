extends Node

var data : PlayerSave

func _ready() -> void:
	data = PlayerSave.load_savegame()
	if data == null:
		data = PlayerSave.new()
