class_name BasicEnemy
extends Character

const EDGE_SCREEN_BUFFER := 10

@onready var hit_position: Marker2D = $HitPosition
@onready var blood_effect_scene = preload("res://Scenes/VFX/blood_effect.tscn")

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

@export_category("Player down reaction")
## Радиус «кольца» вокруг лежащего игрока: ближники держат дистанцию, а не занимают слоты.
@export var down_ring_radius := 110.0
## Множитель скорости при отходе / кружении вокруг лежащего игрока.
@export var down_ring_speed_scale := 0.55
## Краткий шок сразу после лонча/нокдауна игрока.
@export var launch_shock_min := 0.15
@export var launch_shock_max := 0.45
## Персональная задержка перед повторным заходом после подъёма игрока.
@export var getup_stagger_min := 0.3
@export var getup_stagger_max := 0.8

var assigned_door_index := -1
var player_slot : EnemySlot = null
var time_since_last_melee_attack := Time.get_ticks_msec()
var time_since_prep_melee_attack := Time.get_ticks_msec()
var time_since_last_range_attack := Time.get_ticks_msec()
var time_since_prep_range_attack := Time.get_ticks_msec()
var time_since_start_appearing := Time.get_ticks_msec()

# Шок после лонча / stagger после подъёма. Не полный стоп ИИ.
var player_down_delay : float = 0.0
var _was_player_down := false
var _ring_side := 1.0


func _ready() -> void:
	super._ready()
	anim_attacks = ["punch", "punch_alt",]
	_ring_side = 1.0 if randf() < 0.5 else -1.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	process_appear()
	if player_down_delay > 0.0:
		player_down_delay -= delta
	# === ТАЙМЕР БЛОКА ДЛЯ ВРАГОВ ===
	if state == State.BLOCK:
		enemy_block_timer -= delta
		# Если время вышло или щит пробит — возвращаем врага в IDLE
		if enemy_block_timer <= 0 or block_broken:
			state = State.IDLE
	# Если враг оглушен, уменьшаем его таймер блока/оглушения
	if state == State.RECOVER:
		enemy_block_timer -= delta
		if enemy_block_timer <= 0.0:
			enemy_block_timer = 0.0
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
		if _should_give_player_space():
			if can_respawn_knives or has_knife or has_gun:
				goto_range_position()
			else:
				_hold_back_from_player()
			return
		if can_respawn_knives or has_knife or has_gun:
			goto_range_position()
		else:
			goto_melee_position()


func on_player_knocked_down() -> void:
	player_down_delay = randf_range(launch_shock_min, launch_shock_max)
	_was_player_down = true
	_release_player_slot()


func _is_player_down() -> bool:
	return player != null and (player.state == State.FALL or player.state == State.GROUNDED)


func _should_give_player_space() -> bool:
	if _is_player_down():
		_was_player_down = true
		return true
	if _was_player_down:
		_was_player_down = false
		if player_down_delay <= 0.0:
			player_down_delay = randf_range(getup_stagger_min, getup_stagger_max)
	return player_down_delay > 0.0


func _release_player_slot() -> void:
	if player_slot != null and player != null:
		player.free_slot(self)
		player_slot = null


func _hold_back_from_player() -> void:
	_release_player_slot()
	if player_down_delay > 0.0:
		velocity = Vector2.ZERO
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist < 1.0:
		velocity = Vector2.LEFT * _ring_side * speed * down_ring_speed_scale
		return

	var away := -to_player / dist
	if dist < down_ring_radius:
		velocity = away * speed * down_ring_speed_scale
	elif dist > down_ring_radius + 24.0:
		velocity = (to_player / dist) * speed * down_ring_speed_scale
	else:
		var tangent := Vector2(-away.y, away.x) * _ring_side
		velocity = tangent * speed * down_ring_speed_scale * 0.45



func goto_range_position() -> void:
	if player_down_delay > 0.0:
		velocity = Vector2.ZERO
		return

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

	# Пока игрок лежит — занимаем край экрана, без выстрела/броска.
	if _is_player_down():
		return
	
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
	return (player_slot.global_position - global_position).length() < 30.0


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

	# === РЕАКЦИЯ ИИ ВРАГА ===
	# Добавляем условие "not is_hit_from_behind", чтобы враг не мог среагировать на удар со спины
	if type != Type.PLAYER and state != State.BLOCK and can_block() and not is_hit_from_behind:
		if randf() < block_chance:
			state = State.BLOCK
			enemy_block_timer = block_duration
			velocity = Vector2.ZERO

	# Вызываем родительский метод
	super.on_receive_damage(amount, direction, hit_type, attacker)
	
		# === ЕСЛИ ВРАГ УСПЕШНО ЗАБЛОКИРОВАЛ УДАР ===
	# Учитываем, что от тяжелого удара блок ломается, и прерывать функцию НЕ нужно
	var is_hit_by_heavy : bool = (attacker != null and attacker.state == State.HEAVY_ATTACK)
	
	if state == State.BLOCK and block_health > 0 and not is_hit_from_behind and not is_hit_by_heavy:
		play_hit_shake()
		return 

	# === РАЗВОРОТ ВРАГА ПРИ DASH_KICK ===
	# Враги летят за спину игрока и смотрят в противоположную сторону
	if attacker != null and attacker.state == State.DASH_KICK:
		heading.x = -direction.x
	
	
	# Всё, что ниже — реальное ранение
	ComboManager.register_hit.emit()
	
	# Спавним эффект крови (струя + всплеск + лужа)
	var blood = blood_effect_scene.instantiate()
	blood.global_position = position
	blood.setup(direction, hit_type)
	get_tree().current_scene.add_child(blood)
	
	# === ДОПОЛНИТЕЛЬНЫЙ ДВОЙНОЙ УДАР (СПАВН ВТОРОЙ ПАЧКИ КРОВИ) ===
	if was_stunned:
		var extra_blood = blood_effect_scene.instantiate()
		extra_blood.global_position = position + Vector2(randf_range(-40.0, 40.0), randf_range(-20.0, 20.0))
		extra_blood.setup(direction, hit_type)
		get_tree().current_scene.add_child(extra_blood)
		play_hit_shake()
	# ==============================================================
	
	play_hit_shake()
	
	if current_health == 0 or hit_type == DamageReceiver.HitType.POWER or was_stunned:
		EntityManager.spawn_spark.emit(position)
	if current_health == 0:
		if player != null:
			player.free_slot(self)
		EntityManager.death_enemy.emit(self)


## Тряска узла с анимацией персонажа
func play_hit_shake() -> void:
	pass
	# var original_pos = character_sprite.position

	# for i in 4:
	# 	character_sprite.position = original_pos + Vector2(
	# 		randf_range(-shake_strength, shake_strength),
	# 		randf_range(-shake_strength, shake_strength)
	# 	)

	# 	await get_tree().create_timer(shake_duration / 4.0).timeout

	# character_sprite.position = original_pos
