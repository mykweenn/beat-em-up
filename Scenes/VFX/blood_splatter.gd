extends CPUParticles2D

func _ready() -> void:
	emitting = true
	# Удаляем узел сразу после того, как все частицы исчезнут
	await get_tree().create_timer(lifetime).timeout
	queue_free()
