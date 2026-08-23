extends Node

var active := false
var camera: Camera2D

func freeze(duration := 0.03, scale := 0.0) -> void:
	if active:
		return
	active = true
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	active = false


# Кинематографичная смерть босса
func boss_death_freeze(boss_global_position: Vector2, duration := 1.5) -> void:
	if active:
		return
	active = true
	
	# Ищем камеру в сцене (убедитесь, что у вашей Camera2D задано имя "Camera2D" или нужная группа)
	# is_instance_valid защищает от протухшей ссылки после смены сцены
	if not is_instance_valid(camera):
		camera = get_tree().current_scene.find_child("Camera", true, false) as Camera2D

	# 1. Замедляем время, но не до нуля (чтобы камера могла двигаться)
	Engine.time_scale = 0.15 
	
	if camera:
		# Временно отключаем скрипт следования камеры за игроком, если он есть
		camera.set_process(false) 
		
		# Плавный наезд камеры на босса через Tween
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		# Двигаем камеру к боссу
		tween.tween_property(camera, "global_position", boss_global_position, 0.3)
		# Увеличиваем зум (стандартный 1.0 меняем на 1.5)
		tween.tween_property(camera, "zoom", Vector2(1.5, 1.5), 0.3)

	# 2. Ждем указанное время. 
	# Четвертый аргумент `true` в create_timer крайне важен — он заставляет таймер игнорировать замедление времени
	await get_tree().create_timer(duration, true, false, true).timeout
	
	# 3. Возвращаем всё назад
	if is_instance_valid(camera):
		var tween_back = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween_back.tween_property(camera, "zoom", Vector2(1.0, 1.0), 0.4)
		
		# Ищем игрока, чтобы вернуть камеру к нему перед тем, как включить её скрипт обратно
		var player = get_tree().current_scene.find_child("Player", true, false)
		if player:
			tween_back.tween_property(camera, "global_position", player.global_position, 0.4)
		
		await tween_back.finished
		camera.set_process(true) # Включаем обычную логику следования камеры обратно

	Engine.time_scale = 1.0
	active = false