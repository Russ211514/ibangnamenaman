class_name Menu
extends Control

signal button_pressed(button: BaseButton)
signal button_focused(button: BaseButton)

var index: int = 0

func _ready() -> void:
	for button in get_buttons():
		button.focus_exited.connect(_on_button_focus_exited.bind(button))
		button.focus_entered.connect(_on_button_focused.bind(button))
		button.pressed.connect(_on_button_pressed.bind(button))
	
	button_enable_focus(false)

func get_buttons() -> Array:
	return get_children()

func connect_to_buttons(target: Object, _name: String = name) -> void:
	var callable: Callable = Callable()
	callable = Callable(target, "_on_" + _name + "_focused")
	button_focused.connect(callable)
	callable = Callable(target, "_on_" + _name + "_pressed")
	button_pressed.connect(callable)

func button_enable_focus(on: bool) -> void:
	var mode: FocusMode = FocusMode.FOCUS_ALL if on else FocusMode.FOCUS_NONE
	for button in get_buttons():
		button.set_focus_mode(mode)

func button_focus(n: int = index ) -> void:
	var button: BaseButton = get_buttons()[n]
	button.grab_focus()

func _on_button_focused(button: BaseButton) -> void:
	emit_signal("button_focused", button)

func _on_button_focus_exited(button: BaseButton) -> void:
	await get_tree().process_frame
	if not get_viewport().gui_get_focus_owner() in get_buttons():
		button_enable_focus(false)

func _on_button_pressed(button: BaseButton) -> void:
	emit_signal("button_pressed", button)
