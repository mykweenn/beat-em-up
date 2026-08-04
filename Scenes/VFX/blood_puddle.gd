extends Sprite2D

func _ready() -> void:
	# Случайный поворот лужи для разнообразия
	rotation = randf_range(0, 360)
	# Запускаем таймер перед исчезновением (например, лужа лежит 10 секунд)
	await get_tree().create_timer(10.0).timeout
	
	# Плавно растворяем пятно через Tween
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 2.0) # За 2 секунды в прозрачность
	await tween.finished
	queue_free()
