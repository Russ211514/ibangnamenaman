extends Control

@onready var edit = $NameEdit
@onready var sfx_volume = $"Sfx volume"
@onready var master_volume = $"Master volume"


func _ready() -> void:
	edit.placeholder_text = DataSave.data.PlayerName
	sfx_volume.value = DataSave.data.sfxVolume
	master_volume.value = DataSave.data.musicVolume
	
	set_focus_mode(Control.FOCUS_ALL)

func _on_name_edit_text_submitted(new_text: String) -> void:
	if new_text.length() > 16 || new_text.contains("\n"):
		$Error.visible = true
		return
	DataSave.data.PlayerName = new_text
	DataSave.data.write_savegame()
	edit.placeholder_text = new_text
	grab_focus()
	$Error.visible = false
