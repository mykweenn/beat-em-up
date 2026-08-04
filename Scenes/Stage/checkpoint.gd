class_name Checkpoint
extends Node2D

@export var nb_simultaneous_enemies : int

# Добавляем опциональные ресурсы для кат-сцен
@export var intro_cutscene: CutsceneData
@export var outro_cutscene: CutsceneData

@onready var enemies: Node2D = $Enemies
@onready var player_detection_area: Area2D = $PlayerDetectionArea

var active_enemy_counter := 0
var enemy_data : Array[EnemyData] = []
var if_activated := false


func _ready() -> void:
	player_detection_area.body_entered.connect(on_player_enter.bind())
	EntityManager.death_enemy.connect(on_enemy_death.bind())


func _process(_delta: float) -> void:
	if if_activated and can_spawn_enemies():
		var enemy : EnemyData = enemy_data.pop_front()
		EntityManager.spawn_enemy.emit(enemy)
		active_enemy_counter += 1


func create_enemy_data() -> void:
	for enemy : Character in enemies.get_children():
		enemy_data.append(EnemyData.new(enemy.type, enemy.global_position, enemy.assigned_door_index))
		enemy.queue_free()


func can_spawn_enemies() -> bool:
	return enemy_data.size() > 0 and active_enemy_counter < nb_simultaneous_enemies 


func on_enemy_death(_enemy: Character) -> void:
	active_enemy_counter -= 1
	if active_enemy_counter == 0 and enemy_data.size() == 0:
		# Когда враги кончились, ждем, пока последний враг красиво упадет
		# 1.0 — это задержка в секундах. Подберите число под длину вашей анимации смерти (например, 0.8 или 1.5)
		await get_tree().create_timer(1.0).timeout
		
		# Только после этого проверяем кат-сцену
		if outro_cutscene:
			_play_cutscene(outro_cutscene, _on_outro_dialog_ended)
		else:
			_complete_checkpoint()



func on_player_enter(_player: Player) -> void:
	if not if_activated:
		StageManager.checkpoint_start.emit()
		active_enemy_counter = 0
		
		# Перед спавном врагов проверяем, нужно ли показать интро кат-сцену
		if intro_cutscene:
			_play_cutscene(intro_cutscene, _on_intro_dialog_ended)
		else:
			if_activated = true


# --- Логика автоматизации кат-сцен ---

func _play_cutscene(cutscene: CutsceneData, callback: Callable) -> void:
	GameManager.current_state = GameManager.GameState.CUTSCENE
	SproutyDialogs.dialog_ended.connect(callback)
	
	var dialog_player = DialogPlayer.new()
	add_child(dialog_player)
	dialog_player.set_dialog(cutscene.dialog_resource, cutscene.character_name)
	dialog_player.start()


func _on_intro_dialog_ended() -> void:
	SproutyDialogs.dialog_ended.disconnect(_on_intro_dialog_ended)
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	# Только теперь разрешаем `_process` спавнить врагов
	if_activated = true 


func _on_outro_dialog_ended() -> void:
	SproutyDialogs.dialog_ended.disconnect(_on_outro_dialog_ended)
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	_complete_checkpoint()


func _complete_checkpoint() -> void:
	StageManager.checkpoint_complete.emit(self)
	call_deferred("queue_free")
