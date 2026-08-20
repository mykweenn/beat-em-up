extends Control

@onready var text_label: RichTextLabel = $NinePatchRect/RichTextLabel
@onready var arrow: TextureRect = $NinePatchRect/TextureRect

var dialog_lines: Array = []
var current_line: int = 0
var is_typing: bool = false
var target_marker: Node2D = null # Сюда мы передадим наш DialogPoint
var text_tween: Tween = null # Ссылка на текущий твин, чтобы управлять им


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
	# Если старый текст еще печатался, принудительно останавливаем прошлый Tween
	if text_tween and text_tween.is_valid():
		text_tween.kill()

	# Если реплики закончились — полностью скрываем окно и выходим из функции
	if current_line >= dialog_lines.size():
		close_dialogue()
		return
		
	text_label.text = dialog_lines[current_line]
	text_label.visible_characters = 0
	is_typing = true
	arrow.visible = false
	
	# Эффект плавного появления букв через Tween
	text_tween = create_tween()
	var duration = text_label.text.length() * 0.04 # 0.04 секунды на один символ
	text_tween.tween_property(text_label, "visible_characters", text_label.text.length(), duration)
	text_tween.finished.connect(_on_line_finished)


# Отдельная функция для чистого закрытия диалога
func close_dialogue() -> void:
	hide()
	target_marker = null
	dialog_lines.clear()
	current_line = 0
	is_typing = false


func _on_line_finished() -> void:
	is_typing = false
	arrow.visible = true # Показываем стрелочку, когда текст полностью напечатан


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		if is_typing:
			# Если текст еще печатается — останавливаем Tween и показываем весь текст сразу
			if text_tween and text_tween.is_valid():
				text_tween.kill()
			text_label.visible_characters = text_label.text.length()
			_on_line_finished() # Вручную вызываем завершение строки, чтобы показать стрелочку
		else:
			# Если строка дочитана — переходим к следующей
			current_line += 1
			show_line()
