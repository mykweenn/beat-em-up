extends Control

@onready var text_label: RichTextLabel = $NinePatchRect/RichTextLabel
@onready var arrow: TextureRect = $NinePatchRect/TextureRect

var dialog_lines: Array = []
var current_line: int = 0
var is_typing: bool = false
var target_marker: Node2D = null # Сюда мы передадим наш DialogPoint

func _ready() -> void:
	# Скрываем окно при старте игры, пока его не вызовут
	hide()
	arrow.visible = false

func start_dialogue(lines: Array, marker: Node2D) -> void:
	show() # Делаем окно видимым
	target_marker = marker
	dialog_lines = lines
	current_line = 0
	show_line()

func show_line() -> void:
	# [ИСПРАВЛЕНО] Вместо queue_free() просто скрываем окно (hide), 
	# чтобы не удалить узел DialogWindow из самого игрока навсегда
	if current_line >= dialog_lines.size():
		hide() 
		return
		
	text_label.text = dialog_lines[current_line]
	text_label.visible_characters = 0
	is_typing = true
	arrow.visible = false
	
	# Эффект плавного появления букв через Tween
	var tween = create_tween()
	var duration = text_label.text.length() * 0.04 # 0.04 секунды на один символ
	tween.tween_property(text_label, "visible_characters", text_label.text.length(), duration)
	tween.finished.connect(_on_line_finished)

func _on_line_finished() -> void:
	is_typing = false
	arrow.visible = true # Показываем стрелочку, когда текст полностью напечатан

func _process(_delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	# [ИСПРАВЛЕНО] Добавлена проверка 'if visible', чтобы нажатия на пробел/enter 
	# считывались только тогда, когда окно диалога открыто на экране
	if visible and event.is_action_pressed("ui_accept"):
		if is_typing:
			# Если текст еще печатается — пропускаем анимацию и показываем весь текст сразу
			text_label.visible_characters = text_label.text.length()
		else:
			# Если строка дочитана — переходим к следующей
			current_line += 1
			show_line()
