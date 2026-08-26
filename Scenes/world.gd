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
		camera.position = camera_initial_position
		camera.reset_smoothing()
		stage_transition.end_transition()
	
	if player != null and not is_camera_locked and player.position.x > camera.position.x:
		camera.position.x = player.position.x


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
