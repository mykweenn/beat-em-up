class_name World
extends Node2D

const PLAYER_PREFAB := preload("res://Scenes/Characters/player.tscn")

@onready var camera := $Camera
@onready var stage_container: Node2D = $StageContainer
@onready var actors_container: Node2D = $ActorsContainer
@onready var stage_transition : StageTransition = $UI/MarginContainer/UIContainer/StageTransition

var camera_initial_position := Vector2.ZERO
var is_camera_locked := false
var is_stage_ready_for_loading := false
var player : Player = null
## Сколько пикселей от нижнего края кадра до линии земли игрока при
## вертикальном слежении. Камера всегда ведёт игрока вниз/вверх так,
## чтобы он оставался в кадре с этим запасом (важно для вертикальных уровней).
@export var camera_bottom_cushion := 90.0
## Вертикальный офсет камеры относительно линии земли игрока.
## Вычисляется при загрузке уровня.
var vertical_follow_offset := 0.0
## Во время кинематографичной смерти игрока камера не следует за игроком —
## её ведёт сценарий последовательности смерти (см. UI.start_death_sequence).
var is_death_sequence_active := false

func _ready() -> void:
	camera_initial_position = camera.position
	StageManager.checkpoint_start.connect(on_checkpoint_start.bind())
	StageManager.checkpoint_complete.connect(on_checkpoint_complete.bind())
	StageManager.stage_interim.connect(on_stage_complete_return_to_menu.bind())
	load_current_level()


func _process(_delta):
	if is_stage_ready_for_loading:
		is_stage_ready_for_loading = false
		var stage_scene = load(GameManager.current_level_path)
		if stage_scene == null:
			push_error("World: не удалось загрузить уровень: ", GameManager.current_level_path)
			return
		var stage : Stage = stage_scene.instantiate()
		stage_container.add_child(stage)
		player = PLAYER_PREFAB.instantiate()
		actors_container.add_child(player)
		player.position = stage.get_player_spawn_location()
		actors_container.player = player
		# Вертикальный офсет держит игрока в кадре у нижнего края
		# (camera_bottom_cushion) — как на исходных уровнях. Если точка
		# спавна лежит сильно ниже изначальной позиции камеры сцены,
		# офсет ограничивается, чтобы игрок не остался за нижней кромкой.
		var half_frame_height := get_viewport().get_visible_rect().size.y / 2.0
		vertical_follow_offset = maxf(
			camera_initial_position.y - player.position.y,
			-(half_frame_height - camera_bottom_cushion)
		)
		camera.position = Vector2(camera_initial_position.x, player.position.y + vertical_follow_offset)
		camera.reset_smoothing()
		stage_transition.end_transition()

	# Во время добивания камера фокусируется на игроке: центрируется по X
	# и ведёт Y по линии земли (finisher_focus_y_offset) + зум-наезд.
	# НО: во время боя на чекпоинте камера заблокирована (is_camera_locked) —
	# добивание не должно уводить кадр с арены, иначе смещаются границы экрана
	# и становятся видны соседние чекпоинты/спавны врагов. В этом случае
	# оставляем кадр на месте (работает только зум-приближение из camera.gd).
	if player != null and not is_death_sequence_active:
		if player.state == Player.State.MOUNT or player.state == Player.State.FINISHER:
			if not is_camera_locked:
				camera.position.x = player.position.x
				camera.position.y = player.position.y + camera.finisher_focus_y_offset
		else:
			# Горизонталь следует только вперёд и только если камера не
			# заблокирована чекпоинтом (во время боя рамка держится по X).
			if not is_camera_locked and player.position.x > camera.position.x:
				camera.position.x = player.position.x
			# Вертикаль ведётся за игроком всегда — иначе на вертикальных
			# уровнях камера застревает над игроком во время боя на чекпоинте.
			camera.position.y = player.position.y + vertical_follow_offset


func load_current_level() -> void:
	if GameManager.current_level_path.is_empty():
		# Нет уровня — возврат в меню
		get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
		return
	for actor : Node2D in actors_container.get_children():
		actor.queue_free()
	for existing_stage in stage_container.get_children():
		existing_stage.queue_free()
	is_stage_ready_for_loading = true


func on_checkpoint_start() -> void:
	is_camera_locked = true


func on_checkpoint_complete(_checkpoint: Checkpoint) -> void:
	is_camera_locked = false


func on_stage_complete_return_to_menu() -> void:
	GameManager.current_state = GameManager.GameState.CUTSCENE
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
