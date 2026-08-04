extends Node

signal cutscene_started
signal cutscene_finished

enum GameState {
	GAMEPLAY,
	CUTSCENE
}

var current_state := GameState.GAMEPLAY


func _ready() -> void:
	# Вместо прямого подключения используем .call_deferred
	# Это заставит функцию смены сцены выполниться в безопасное время
	StageManager.stage_complete.connect(func(): _on_stage_complete.call_deferred())



func start_cutscene():
	if current_state == GameState.CUTSCENE:
		return

	current_state = GameState.CUTSCENE
	cutscene_started.emit()


func end_cutscene():
	current_state = GameState.GAMEPLAY
	cutscene_finished.emit()


# Эта функция сработает автоматически, когда закончится финальный диалог последнего чекпоинта
func _on_stage_complete() -> void:
	print("GameManager: Уровень успешно завершен!")

	current_state = GameState.CUTSCENE
	var next_scene_path = "res://Scenes/UI/main_menu.tscn"
	
	if ResourceLoader.exists(next_scene_path):
		# Получаем глобальное дерево сцен напрямую у движка, минуя локальный get_tree()
		var global_tree = Engine.get_main_loop() as SceneTree
		if global_tree:
			global_tree.change_scene_to_file(next_scene_path)
		else:
			push_error("GameManager: Движок не смог вернуть Main Loop.")
	else:
		push_error("GameManager: Не удалось найти сцену по пути: ", next_scene_path)
