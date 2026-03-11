class_name PlayerSave
extends Resource

const SAVE_GAME_PATH: String = "user://savegame.json"

@export var PlayerName : String = "Anonymous"
@export var sfxVolume : float = 24.0
@export var musicVolume : float = 10.0
@export var play_tutorial : bool = true

var save_da

func write_savegame() -> void:
	ResourceLoader.exists(SAVE_GAME_PATH)

static func load_savegame() -> PlayerSave:
	if ResourceLoader.exists(SAVE_GAME_PATH):
		return ResourceLoader.load(SAVE_GAME_PATH) as PlayerSave
	return null
