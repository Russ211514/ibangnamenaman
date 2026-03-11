extends Node

@export var quiz: BattleTheme
@export var color_right: Color
@export var color_wrong: Color

@onready var question: Label = %Question
@onready var python_question: VBoxContainer = %PythonQuestion

var buttons: Array[Button]
var index: int
var correct_question: int

var current_quiz: BattleQuestion:
	get: return quiz.theme[index]

func _ready() -> void:
	correct_question = 0
	
	if python_question:
		for button in python_question.get_children():
			buttons.append(button)
	
	if quiz and quiz.theme.size() > 0:
		randomize_array(quiz.theme)

func load_question(difficulty: Enum.Difficulty):
	if not quiz or quiz.theme.is_empty():
		return

	var filtered_questions = quiz.theme.filter(func(q): return q.difficulty == difficulty)
	
	var question_to_load: BattleQuestion
	if filtered_questions.is_empty():
		# Fallback to a random question if no question with that difficulty exists
		index = randi() % quiz.theme.size()
		question_to_load = current_quiz
	else:
		question_to_load = filtered_questions.pick_random()
		index = quiz.theme.find(question_to_load)

	question.text = question_to_load.Question_Info
	
	var options = question_to_load.options.duplicate()
	options.shuffle()
	
	for i in buttons.size():
		if i < options.size():
			buttons[i].text = options[i]
			buttons[i].show()
		else:
			buttons[i].hide()

func buttons_answer(button) -> void:
	if current_quiz.correct == button.text:
		button.modulate = color_right
	else:
		button.modulate = color_wrong

func randomize_array(array: Array) -> Array:
	var array_temp = array
	array_temp.shuffle()
	return array_temp
