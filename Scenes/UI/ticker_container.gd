extends Panel

@export var scroll_speed: float = 100.0 # Скорость в пикселях в секунду

@onready var label: Label = $TickerLabel

func _ready() -> void:
	# Ждем один кадр, чтобы Godot успел посчитать реальный размер текста
	await get_tree().process_frame
	
	# Запускаем бесконечный цикл движения
	start_scrolling()

func start_scrolling() -> void:
	# 1. Сбрасываем текст в самое начало (в крайний правый угол контейнера)
	label.position.x = size.x
	
	# 2. Высчитываем конечную точку (текст полностью ушел за левый край)
	var target_x: float = -label.size.x
	
	# 3. Считаем расстояние и время пути, чтобы скорость была одинаковой для любого текста
	var distance: float = label.position.x - target_x
	var duration: float = distance / scroll_speed
	
	# 4. Создаем автоматический аниматор (Tween)
	var tween = create_tween()
	
	# Плавно двигаем свойство position:x нашего лейбла до конечной точки
	tween.tween_property(label, "position:x", target_x, duration)
	
	# Как только текст улетел — автоматически запускаем функцию заново
	tween.finished.connect(start_scrolling)
