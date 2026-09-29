extends Node2D

const SHOT_PREFAB := preload("res://Scenes/Props/shot.tscn")
const SPARK_PREFAB := preload("res://Scenes/Props/spark.tscn")
const SPARK_3D_PREFAB := preload("res://Scenes/VFX/hit_particle_2d_from_3d.tscn")
## Словарь префабов предметов
const PREFAB_MAP := {
	Collectible.Type.KNIFE: preload("res://Scenes/Props/knife.tscn"),
	Collectible.Type.GUN: preload("res://Scenes/Props/gun.tscn"),
	Collectible.Type.FOOD: preload("res://Scenes/Props/food.tscn")
}

## Словарь сцен врагов
const ENEMY_MAP := {
	Character.Type.PUNK: preload("res://Scenes/Characters/basic_enemy.tscn"),
	Character.Type.GOON: preload("res://Scenes/Characters/goon_enemy.tscn"),
	Character.Type.THUG: preload("res://Scenes/Characters/thug_enemy.tscn"),
	Character.Type.BOUNCER: preload("res://Scenes/Characters/igor_boss.tscn"),
	Character.Type.HEAVY: preload("res://Scenes/Characters/big_enemy.tscn"),
	Character.Type.LEAPER: preload("res://Scenes/Characters/leaper_enemy.tscn"),
}

@export var player : Player

var doors : Array[Door] = []

func _init() -> void:
	EntityManager.orphan_actor.connect(on_orphan_actor.bind())
	EntityManager.spawn_collectible.connect(on_spawn_collectible.bind())
	EntityManager.spawn_shot.connect(on_spawn_shot.bind())
	EntityManager.spawn_enemy.connect(on_spawn_enemy.bind())
	EntityManager.spawn_spark.connect(on_spawn_spark.bind())
	EntityManager.spawn_3d_spark.connect(on_spawn_3d_spark.bind())
	DamageManager.player_revive.connect(on_player_revive.bind())


func on_spawn_collectible(type: Collectible.Type, initial_state: Collectible.State, collectible_global_position: Vector2, collectible_direction: Vector2, initial_height: float, autodestroy: bool):
	var collectible : Collectible = PREFAB_MAP[type].instantiate()
	collectible.state = initial_state
	collectible.height = initial_height
	collectible.global_position = collectible_global_position
	collectible.direction = collectible_direction
	collectible.autodestroy = autodestroy
	call_deferred("add_child", collectible)


func on_spawn_shot(gun_root_position: Vector2, distance_traveled: float, height: float) -> void:
	var shot : Shot = SHOT_PREFAB.instantiate()
	add_child(shot)
	shot.position = gun_root_position
	shot.initialize(distance_traveled, height)


func on_spawn_enemy(enemy_data: EnemyData):
	var enemy : Character = ENEMY_MAP[enemy_data.type].instantiate()
	enemy.global_position = enemy_data.global_position
	enemy.player = player
	enemy.height = enemy_data.height
	enemy.state = enemy_data.state
	if enemy_data.door_index > -1:
		enemy.assign_door(doors[enemy_data.door_index])
	add_child(enemy)


func on_orphan_actor(orphan: Node2D) -> void:
	if orphan is Door:
		doors.append(orphan)
	orphan.reparent(self)


func on_spawn_spark(spark_position: Vector2) -> void:
	var spark_instance := SPARK_PREFAB.instantiate()
	spark_instance.position = spark_position
	add_child(spark_instance)


func on_spawn_3d_spark(spark_position: Vector2) -> void:
	var spark_3d_instance := SPARK_3D_PREFAB.instantiate()
	spark_3d_instance.position = spark_position
	add_child(spark_3d_instance)


func on_player_revive() -> void:
	for child in get_children():
		if child is Character:
			var character : Character = child as Character
			if character.type != Character.Type.PLAYER:
				character.on_receive_damage(0, Vector2.ZERO, DamageReceiver.HitType.KNOCKDOWN)
