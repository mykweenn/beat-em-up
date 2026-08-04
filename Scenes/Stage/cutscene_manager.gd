extends Node2D

# # Две кат-сцены для начала и конца
# @export var intro_cutscene: CutsceneData
# @export var outro_cutscene: CutsceneData

# func _ready() -> void:
# 	# 1. Подключаемся к вашей системе врагов (если она есть)
# 	# Предположим, у вас есть глобальный менеджер врагов или сигнал на уровне
# 	# EnemyManager.all_enemies_defeated.connect(_on_all_enemies_defeated)
	
# 	# 2. Сразу запускаем стартовую кат-сцену уровня
# 	if intro_cutscene:
# 		play_cutscene(intro_cutscene, _on_intro_ended)
# 	else:
# 		# Если стартовой кат-сцены нет, сразу включаем геймплей
# 		start_gameplay()

# # Универсальная функция для запуска любой кат-сцены
# func play_cutscene(cutscene: CutsceneData, callback_function: Callable) -> void:
# 	GameManager.current_state = GameManager.GameState.CUTSCENE
	
# 	# Подключаем сигнал окончания к переданной функции-коллбэку
# 	SproutyDialogs.dialog_ended.connect(callback_function)
	
# 	var dialog_player = DialogPlayer.new()
# 	add_child(dialog_player)
# 	dialog_player.set_dialog(cutscene.dialog_resource, cutscene.character_name)
# 	dialog_player.start()

# # Вызывается, когда закончился интро-диалог
# func _on_intro_ended() -> void:
# 	SproutyDialogs.dialog_ended.disconnect(_on_intro_ended)
# 	start_gameplay()

# # Перевод игры в режим драки
# func start_gameplay() -> void:
# 	GameManager.current_state = GameManager.GameState.GAMEPLAY
# 	print("ДРАКА НАЧАЛАСЬ!")
# 	# Здесь вы можете спавнить первую волну врагов

# # Этот метод должен вызываться, когда на арене умер последний враг
# func _on_all_enemies_defeated() -> void:
# 	if outro_cutscene:
# 		play_cutscene(outro_cutscene, _on_outro_ended)
# 	else:
# 		end_level()

# # Вызывается, когда закончился финальный диалог
# func _on_outro_ended() -> void:
# 	SproutyDialogs.dialog_ended.disconnect(_on_outro_ended)
# 	end_level()

# # Завершение уровня
# func end_level() -> void:
# 	print("Уровень пройден! Показываем экран результатов или загружаем следующий.")
# 	# GameManager.load_next_level()
# 	queue_free() # Удаляем менеджер, так как уровень завершен
