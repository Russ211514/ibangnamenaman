extends Node

@export var quiz: BattleTheme
@export var color_right: Color
@export var color_wrong: Color

@onready var question: Label = %Question
@onready var html_question: VBoxContainer = %HtmlQuestion
@onready var image: TextureRect = $Question/Image/ImageHolder

var buttons: Array[Button]
var index: int
var correct_question: int

# Signal for when an answer is selected
signal answer_selected(is_correct: bool, selected_text: String)

var current_quiz: BattleQuestion:
	get: return quiz.theme[index]

func _ready() -> void:
	correct_question = 0
	
	if html_question:
		for button in html_question.get_children():
			if button is Button:
				buttons.append(button)
				button.pressed.connect(_on_button_pressed.bind(button))
	
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
			buttons[i].disabled = false
			buttons[i].modulate = Color.WHITE
			buttons[i].show()
		else:
			buttons[i].hide()
	
	match quiz.theme[index].type:
		Enum.QuestionType.TEXT:
			$Question/Image.hide()
		
		Enum.QuestionType.IMAGE:
			$Question/Image.show()
			if image:
				image.texture = quiz.theme[index].question_image

func buttons_answer(button) -> void:
	if current_quiz.correct == button.text:
		button.modulate = color_right
	else:
		button.modulate = color_wrong

func _on_button_pressed(button: Button) -> void:
	"""Handle button press and call buttons_answer"""
	buttons_answer(button)
	
	# Emit signal with whether answer is correct
	var is_correct = (current_quiz.correct == button.text)
	answer_selected.emit(is_correct, button.text)

func randomize_array(array: Array) -> Array:
	var array_temp = array
	array_temp.shuffle()
	return array_temp
