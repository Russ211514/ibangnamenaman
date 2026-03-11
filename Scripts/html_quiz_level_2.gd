extends Control

@export var quiz: QuizTheme
@export var color_right: Color
@export var color_wrong: Color

@onready var RestartButton = $Restart
@onready var question_texts: Label = $Question/QuestionText
@onready var next_level_button = $GameOver/NextLevel
@onready var lock_in_button = $AnswerPanel/LockIn
@onready var next_button = $AnswerPanel/Next
@onready var answer_panel = $AnswerPanel

var buttons: Array[Button]
var index: int
var correct_question: int
var selected_button: Button = null

var currenct_quiz: QuizQuestion:
	get: return quiz.theme[index]

func _ready() -> void:
	correct_question = 0
	
	for button in $QuestionHolder.get_children():
		buttons.append(button)
	
	randomize_array(quiz.theme)
	load_quiz()

func load_quiz() -> void:
	if index >= quiz.theme.size():
		game_over()
		return
	
	question_texts.text = currenct_quiz.Question_Info
	
	var options = randomize_array(currenct_quiz.options)
	for i in buttons.size():
		buttons[i].text = options[i]
		buttons[i].pressed.connect(buttons_answer.bind(buttons[i]))
	
func buttons_answer(button) -> void:
	# If a button was previously selected, reset its color
	if selected_button != null and selected_button != button:
		selected_button.modulate = Color.WHITE
	
	# Set the new selected button
	selected_button = button
	button.modulate = Color.YELLOW  # Highlight selected button
	
	# Show lock in button (other buttons remain enabled for switching)
	answer_panel.show()
	lock_in_button.show()
	next_button.hide()

func next_question():
	selected_button = null
	
	for bt in buttons:
		bt.pressed.disconnect(buttons_answer)
		bt.disabled = false
	
	answer_panel.hide()
	lock_in_button.hide()
	next_button.hide()
	
	await get_tree().create_timer(1).timeout
	
	for bt in buttons:
		bt.modulate = Color.WHITE
		
	index += 1
	load_quiz()

func randomize_array(array: Array) -> Array:
	var array_temp = array
	array_temp.shuffle()
	return array_temp

func game_over() -> void:
	if correct_question != quiz.theme.size():
		$GameOver/Score.text = str("You got ", correct_question, "/", quiz.theme.size())
		$GameOver/Restart.show()
		$GameOver.show()
	else:
		$GameOver/Score.text = str("Congrats you got ", correct_question, "/", quiz.theme.size())
		$GameOver/Restart.hide()
		$GameOver.show()
		# Mark level 1 as completed and show next level button
		LevelCore.html_mini_quiz_completed = true
		if next_level_button:
			next_level_button.show()
			next_level_button.pressed.connect(_on_next_level_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/html_start_level2.tscn")

func _on_home_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_lock_in_pressed() -> void:
	if selected_button == null:
		return
	
	# Disable all buttons so player can't switch answers
	for bt in buttons:
		bt.disabled = true
	
	# Check if answer is correct
	if currenct_quiz.correct == selected_button.text:
		selected_button.modulate = color_right
		correct_question += 1
	else:
		selected_button.modulate = color_wrong
	
	# Show the correct answer for other buttons if they selected wrong
	if currenct_quiz.correct != selected_button.text:
		for bt in buttons:
			if bt.text == currenct_quiz.correct:
				bt.modulate = color_right
	
	# Hide lock in and show next button
	lock_in_button.hide()
	next_button.show()

func _on_next_pressed() -> void:
	next_question()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_next_level_pressed() -> void:
	get_tree().change_scene_to_file("res://Html Scenes/html tutorial start3.tscn")
