extends Control
class_name PlayerQuestions

@export var quiz: BattleTheme
@export var color_right: Color = Color.GREEN
@export var color_wrong: Color = Color.RED

@onready var question_label: Label = %Question
@onready var html_question_container: VBoxContainer = %HtmlQuestion

var buttons: Array[Button] = []
var index: int = 0
var correct_question: int = 0

signal answer_selected(button: Button, is_correct: bool)

var current_quiz: BattleQuestion:
	get: 
		if index < quiz.theme.size():
			return quiz.theme[index]
		return null

func _ready() -> void:
	correct_question = 0
	
	if html_question_container:
		for button in html_question_container.get_children():
			if button is Button:
				buttons.append(button)
				button.pressed.connect(_on_button_pressed.bindv([button]))
	
	if quiz and quiz.theme.size() > 0:
		quiz.theme.shuffle()
	
	# Hide initially
	hide()

func load_question(difficulty: int) -> void:
	"""Load a question of the specified difficulty (0=Easy, 1=Medium, 2=Hard)"""
	if not quiz or quiz.theme.is_empty():
		print("[PlayerQuestions] No quiz loaded!")
		return
	
	var filtered_questions = quiz.theme.filter(func(q): return q.difficulty == difficulty)
	
	var question_to_load: BattleQuestion
	if filtered_questions.is_empty():
		# Fallback to random question
		index = randi() % quiz.theme.size()
		question_to_load = current_quiz
	else:
		question_to_load = filtered_questions.pick_random()
		index = quiz.theme.find(question_to_load)
	
	if question_to_load:
		question_label.text = question_to_load.Question_Info
		
		var options = question_to_load.options.duplicate()
		options.shuffle()
		
		for i in buttons.size():
			if i < options.size():
				buttons[i].text = options[i]
				buttons[i].show()
				buttons[i].modulate = Color.WHITE
			else:
				buttons[i].hide()
		
		show()

func _on_button_pressed(button: Button) -> void:
	"""Handle button press"""
	if not current_quiz:
		return
	
	var is_correct = current_quiz.correct == button.text
	
	# Show correct/wrong color
	if is_correct:
		button.modulate = color_right
	else:
		button.modulate = color_wrong
	
	# Disable buttons
	for btn in buttons:
		btn.disabled = true
	
	print("[PlayerQuestions] Answer selected - correct: ", is_correct)
	answer_selected.emit(button, is_correct)
	
	await get_tree().create_timer(1.0).timeout
	hide()
	
	# Reset buttons
	for btn in buttons:
		btn.disabled = false
		btn.modulate = Color.WHITE

func show_waiting() -> void:
	"""Show waiting state"""
	question_label.text = "Opponent is answering..."
	hide_buttons()
	show()

func hide_buttons() -> void:
	"""Hide all answer buttons"""
	for btn in buttons:
		btn.hide()
