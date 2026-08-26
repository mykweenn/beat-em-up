extends Node

signal cutscene_started
signal cutscene_finished

enum GameState {
	GAMEPLAY,
	CUTSCENE
}

var current_state := GameState.GAMEPLAY

# === СИСТЕМА УРОВНЕЙ ===
## Реестр всех доступных уровней. Порядок = порядок в селекторе.
## Добавляйте новые уровни через add_level().
var level_registry: Array[Dictionary] = []
## Индекс текущего загруженного уровня (-1 = нет уровня)
var current_level_index := -1
## Путь к текущему уровню (для передачи в world.gd)
var current_level_path := ""

# === СОХРАНЕНИЕ ===
const SAVE_PATH := "user://save_game.dat"
## Индекс последнего пройденного уровня (-1 = ничего не пройдено)
var last_completed_level := -1


func _ready() -> void:
	StageManager.stage_complete.connect(func(): _on_stage_complete.call_deferred())
	load_save()
	# Дефолтный уровень (всегда доступен)
	if level_registry.is_empty():
		add_level("STAGE 1: УЛИЦЫ", "res://Scenes/Stage/streets.tscn")


## Добавляет уровень в реестр. Вызывайте из main_menu.gd или из кода.
func add_level(level_name: String, scene_path: String) -> void:
	level_registry.append({"name": level_name, "path": scene_path})


## Возвращает количество доступных (разблокированных) уровней.
func get_unlocked_level_count() -> int:
	return mini(level_registry.size(), last_completed_level + 2)


## Загружает уровень по индексу из реестра.
func load_level(index: int) -> void:
	if index < 0 or index >= level_registry.size():
		push_error("GameManager: неверный индекс уровня: %d" % index)
		return
	current_level_index = index
	current_level_path = level_registry[index]["path"]
	var global_tree = Engine.get_main_loop() as SceneTree
	if global_tree:
		global_tree.change_scene_to_file("res://Scenes/world.tscn")
	else:
		push_error("GameManager: не удалось получить Main Loop")


## Начинает новую игру (с первого уровня).
func start_new_game() -> void:
	delete_save()
	load_level(0)


## Продолжает игру (загружает уровень после последнего пройденного).
func continue_game() -> void:
	load_save()
	var next_index := last_completed_level + 1
	if next_index >= level_registry.size():
		next_index = 0
	load_level(next_index)


# === СОХРАНЕНИЕ / ЗАГРУЗКА ===

func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(last_completed_level)
		file.close()


func load_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			last_completed_level = file.get_var()
			file.close()


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	last_completed_level = -1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


# === КОТСЦЕНЫ И ИГРОВОЙ ЦИКЛ ===

func start_cutscene():
	if current_state == GameState.CUTSCENE:
		return
	current_state = GameState.CUTSCENE
	cutscene_started.emit()


func end_cutscene():
	current_state = GameState.GAMEPLAY
	cutscene_finished.emit()


func _on_stage_complete() -> void:
	current_state = GameState.CUTSCENE
	# Сохраняем прогресс
	if current_level_index >= 0:
		last_completed_level = maxi(last_completed_level, current_level_index)
		save_game()
	# Возвращаемся в меню
	var next_scene_path = "res://Scenes/UI/main_menu.tscn"
	if ResourceLoader.exists(next_scene_path):
		var global_tree = Engine.get_main_loop() as SceneTree
		if global_tree:
			global_tree.change_scene_to_file(next_scene_path)
		else:
			push_error("GameManager: не удалось получить Main Loop.")
	else:
		push_error("GameManager: сцена не найдена: ", next_scene_path)
