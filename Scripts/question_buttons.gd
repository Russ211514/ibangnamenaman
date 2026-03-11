extends VBoxContainer

signal answer_given(correct: bool)

var correct_answer: String

func _on_a_pressed() -> void:
	check_answer($A)

func _on_b_pressed() -> void:
	check_answer($B)

func _on_c_pressed() -> void:
	check_answer($C)

func _on_d_pressed() -> void:
	check_answer($D)

func check_answer(button: Button) -> void:
	var correct = button.text == correct_answer
	var controller = get_parent().get_parent()  # Control
	button.modulate = controller.color_right if correct else controller.color_wrong
	answer_given.emit(correct)
