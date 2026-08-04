class_name BasicEnemy
extends Character

const EDGE_SCREEN_BUFFER := 10

@onready var hit_position: Marker2D = $HitPosition
@onready var blood_splatter_scene = preload("res://Scenes/VFX/blood_splatter.tscn")
@onready var blood_puddle_scene = preload("res://Scenes/VFX/blood_puddle.tscn")

@export_category("Durations")
## Длительность анимации или процесса появления (спавна) врага в секундах.
@export var duration_appear : float
## Задержка (кулдаун) между последовательными атаками ближнего боя.
@export var duration_between_melee_attacks : int
## Задержка (кулдаун) между последовательными атаками дальнего боя (выстрелами/бросками).
@export var duration_between_range_attacks : int
## Время подготовки (замаха/прицеливания) перед началом атаки дальнего боя.
@export var duration_prep_range_attacks : int
## Время подготовки (замаха/зарядки) перед началом атаки ближнего боя.
@export var duration_prep_melee_attacks : int

@export_category("Shake animation")
## Максимальная амплитуда (сила) тряски экрана или спрайта при получении урона/ударе.
@export var shake_strength := 6.0
## Длительность эффекта тряски в секундах.
@export var shake_duration := 0.08

@export var player : Player

var assigned_door_index := -1
var player_slot : EnemySlot = null
var time_since_last_melee_attack := Time.get_ticks_msec()
var time_since_prep_melee_attack := Time.get_ticks_msec()
var time_since_last_range_attack := Time.get_ticks_msec()
var time_since_prep_range_attack := Time.get_ticks_msec()
var time_since_start_appearing := Time.get_ticks_msec()


func _ready() -> void:
	super._ready()
	anim_attacks = ["punch", "punch_alt",]


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	process_appear() 
	
	# === ТАЙМЕР БЛОКА ДЛЯ ВРАГОВ ===
	if state == State.BLOCK:
		enemy_block_timer -= delta
		# Если время вышло или щит пробит — возвращаем врага в IDLE
		if enemy_block_timer <= 0 or block_broken:
			state = State.IDLE
	# Если враг оглушен, уменьшаем его таймер блока/оглушения
	if state == State.RECOVER:
		enemy_block_timer -= delta
		if enemy_block_timer <= 0:
			state = State.IDLE


func process_appear() -> void:
	if state == State.APPEARING:
		var progress := (Time.get_ticks_msec() - time_since_start_appearing) / duration_appear 
		if progress < 1:
			modulate.a = progress
		else:
			modulate.a = 1
			state = State.IDLE
			
			
func handle_input():
	if player != null and can_move():
		if can_respawn_knives or has_knife or has_gun:
			goto_range_position()
		else:
			goto_melee_position()


func goto_range_position() -> void:
	var camera := get_viewport().get_camera_2d()
	var screen_width := get_viewport_rect().size.x
	var screen_left_edge := camera.position.x - screen_width / 2
	var screen_right_edge := camera.position.x + screen_width / 2
	
	var left_destination := Vector2(screen_left_edge + EDGE_SCREEN_BUFFER, player.position.y)
	var right_destination := Vector2(screen_right_edge - EDGE_SCREEN_BUFFER, player.position.y)
	var closest_destination := Vector2.ZERO
	if (left_destination - position).length() < (right_destination - position).length():
		closest_destination = left_destination
	else:
		closest_destination = right_destination
	
	if (closest_destination - position).length() < 10:
		velocity = Vector2.ZERO
	else:
		velocity = (closest_destination - position).normalized() * speed
	
	if can_range_attack() and has_knife and projectile_aim.is_colliding():
		state = State.THROW
		time_since_knife_dismiss = Time.get_ticks_msec()
		time_since_last_range_attack = Time.get_ticks_msec()
	
	if can_range_attack() and has_gun and projectile_aim.is_colliding():
		state = State.PREP_SHOOT
		time_since_prep_range_attack = Time.get_ticks_msec()
		time_since_last_range_attack = Time.get_ticks_msec()


func handle_prep_shoot() -> void:
	if state == State.PREP_SHOOT and (Time.get_ticks_msec() - time_since_prep_range_attack > duration_prep_range_attacks):
		shot_gun()
		time_since_last_range_attack = Time.get_ticks_msec()


func assign_door(door: Door) -> void:
	if door.state != Door.State.OPENED:
		state = State.WAIT
		door.open()
		door.opened.connect(on_action_complete.bind())
	else:
		state = State.APPEARING
		modulate.a = 0
		time_since_start_appearing = Time.get_ticks_msec()


func goto_melee_position() -> void:
	if can_pickup_collectible():
		state = State.PICKUP
		if player_slot != null:
			player.free_slot(self)
	elif player_slot == null:
		player_slot = player.reserve_slot(self)
		
	if player_slot != null:
		var direction := (player_slot.global_position - global_position).normalized()
		if is_player_within_range():
			velocity = Vector2.ZERO
			if can_attack():
				state = State.PREP_ATTACK
				time_since_prep_melee_attack = Time.get_ticks_msec()
		else:
			velocity = direction * speed


func handle_prep_attack() -> void:
	if state == State.PREP_ATTACK and (Time.get_ticks_msec() - time_since_prep_melee_attack > duration_prep_melee_attacks):
		state = State.ATTACK
		time_since_last_melee_attack = Time.get_ticks_msec()
		anim_attacks.shuffle()


func is_player_within_range() -> bool:
	return (player_slot.global_position - global_position).length() < 5


func can_attack() -> bool:
	if (Time.get_ticks_msec() - time_since_last_melee_attack < duration_between_melee_attacks):
		return false
	return super.can_attack()


func can_range_attack() -> bool:
	if Time.get_ticks_msec() - time_since_last_range_attack < duration_between_range_attacks:
		return false
	return super.can_attack()


func set_heading() -> void:
	if player == null or not can_move():
		return
	heading = Vector2.LEFT if position.x > player.position.x else Vector2.RIGHT


func on_receive_damage(amount: int, direction: Vector2, hit_type: DamageReceiver.HitType, attacker: Character = null) -> void:
	# === ЗАПОМИНАЕМ, БЫЛ ЛИ ВРАГ ОГЛУШЕН ДО ВЫЗОВА SUPER ===
	var is_hit_from_behind : bool = sign(direction.x) == sign(heading.x)
	var was_stunned : bool = (state == State.RECOVER)
	# ======================================================

	# Вызываем родительский метод
	super.on_receive_damage(amount, direction, hit_type, attacker)
	
	# Если враг успешно заблокировал обычный удар
	if state == State.BLOCK and block_health > 0 and not is_hit_from_behind:
		play_hit_shake()
		return 
	
	# Всё, что ниже — реальное ранение
	ComboManager.register_hit.emit()
	
	# Спавним первую (основную) лужу и брызги крови
	var blood_node = blood_splatter_scene.instantiate()
	var puddle = blood_puddle_scene.instantiate()
	var spawn_offset := Vector2(randf_range(-30.0, 30.0), randf_range(-15.0, 15.0))
	blood_node.global_position = position + Vector2(0, -250) + spawn_offset
	var puddle_offset := Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 10.0))
	puddle.global_position = position + puddle_offset
	
	if direction.x != 0:
		var side = -sign(direction.x)
		blood_node.scale.x = -sign(direction.x)
		if hit_type == DamageReceiver.HitType.POWER or was_stunned: # <-- Добавили проверку на стан для масштаба
			blood_node.scale = Vector2(side * 1.8, 1.8)
			puddle.scale *= 1.7
		else:
			blood_node.scale = Vector2(side, 1.0)
		
	get_tree().current_scene.add_child(blood_node)
	get_tree().current_scene.add_child(puddle)
	
	# === ДОПОЛНИТЕЛЬНЫЙ ДВОЙНОЙ УДАР (СПАВН ВТОРОЙ ПАЧКИ КРОВИ) ===
	if was_stunned:
		var extra_blood = blood_splatter_scene.instantiate()
		# Смещаем вторую струю чуть в сторону для хаотичности
		var extra_offset := Vector2(randf_range(-40.0, 40.0), randf_range(-20.0, 20.0))
		extra_blood.global_position = position + Vector2(0, -230) + extra_offset
		
		if direction.x != 0:
			var side = -sign(direction.x)
			# Немного меняем размер второй струи, чтобы они не выглядели одинаково клонированными
			extra_blood.scale = Vector2(side * randf_range(1.3, 1.6), randf_range(1.3, 1.6))
			
		get_tree().current_scene.add_child(extra_blood)
		
		# Делаем тряску экрана в два раза мощнее
		play_hit_shake() 
	# ==============================================================
	
	play_hit_shake()
	
	if current_health == 0 or hit_type == DamageReceiver.HitType.POWER or was_stunned:
		EntityManager.spawn_spark.emit(position)
	if current_health == 0:
		player.free_slot(self)
		EntityManager.death_enemy.emit(self)


## Тряска узла с анимацией персонажа
func play_hit_shake() -> void:
	var original_pos := animated_sprite_2d.position

	for i in 4:
		animated_sprite_2d.position = original_pos + Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)

		await get_tree().create_timer(shake_duration / 4.0).timeout

	animated_sprite_2d.position = original_pos
