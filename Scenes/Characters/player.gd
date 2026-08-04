class_name Player
extends Character

const REVIVE_HEIGHT := 80

@export var max_duration_between_successful_hits : int

@onready var enemy_slots: Array = $EnemySlots.get_children()

var time_since_last_successfull_attack := Time.get_ticks_msec()

var last_tap_time := 0.0
var last_tap_dir := 0

@export var double_tap_time := 0.25

@export var sprint_duration := 0.35

var sprint_timer := 0.0
var sprint_dir := 0
var sprint_attack_boost := 0.0

#dash
var effect_time := 1.0
var effect_delay := 0.04

func _ready() -> void:
	super._ready()
	anim_attacks = ["punch", "punch_alt", "kick", "roundkick",]
	DamageManager.player_revive.connect(on_player_revive.bind())
	GameManager.cutscene_started.connect(_on_cutscene_started.bind())
	GameManager.cutscene_finished.connect(_on_cutscene_finished.bind())


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	procces_time_between_combos()
	
	if state == State.DASH or state == State.SPRINT_ATTACK:
		ghost(delta)


func procces_time_between_combos() -> void:
	if Time.get_ticks_msec() - time_since_last_successfull_attack > max_duration_between_successful_hits:
		attack_combo_index = 0
		#knife_sprite.flip_h = true


func on_player_revive() -> void:
	current_health = max_health
	state = State.JUMP
	height = REVIVE_HEIGHT


func handle_input() -> void:
	# === ЛОГИКА БЛОКА ДЛЯ ИГРОКА ===
	if Input.is_action_pressed("block") and (state == State.BLOCK or can_block()):
		if state != State.BLOCK:
			state = State.BLOCK
			velocity = Vector2.ZERO # Останавливаем игрока только в ПЕРВЫЙ кадр входа в блок
			block_activated_time = Time.get_ticks_msec() # Фиксируем точное время для парирования
		return # Прерываем handle_input, блокируя атаки и ходьбу, но сохраняя импульс отброса

	# Если игрок удерживал блок, но отпустил кнопку — возвращаем в IDLE
	if state == State.BLOCK and Input.is_action_just_released("block"):
		state = State.IDLE
	# ===============================


	if can_move():
		var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		# Если игрок перешёл в спринт, даём ему повышенную скорость
		if state == State.SPRINT:
			# Умножаем обычную скорость на 1.6 (или используйте новую переменную sprint_speed)
			velocity = direction * (speed * 1.6) 
		else:
			velocity = direction * speed
	
	if can_attack() and Input.is_action_just_pressed("attack"):
		velocity = Vector2.ZERO
		if has_knife:
			state = State.THROW
		elif has_gun:
			if ammo_left > 0:
				shot_gun()
				ammo_left -= 1
			else:
				state = State.THROW
		else:
			if can_pickup_collectible():
				state = State.PICKUP
			else:
				state = State.ATTACK
				SoundPlayer.play(SoundManager.Sound.SWOOSH)
				if is_last_hit_successful:
					time_since_last_successfull_attack = Time.get_ticks_msec()
					attack_combo_index = (attack_combo_index + 1) % anim_attacks.size()
					is_last_hit_successful = false
				else:
					attack_combo_index = 0
	if can_jump() and Input.is_action_just_pressed("jump"):
		state = State.TAKEOFF
	if can_jumpkick() and Input.is_action_just_pressed("attack"):
		state = State.JUMPKICK
		SoundPlayer.play(SoundManager.Sound.SWOOSH)
	if (can_sprint_attack() or state == State.SPRINT) and Input.is_action_just_pressed("attack"):
		start_sprint_attack()



func set_heading() -> void:
	if can_move():
		if velocity.x > 0:
			heading = Vector2.RIGHT
		elif velocity.x < 0:
			heading = Vector2.LEFT

func reserve_slot(enemy: BasicEnemy) -> EnemySlot:
	var available_slots := enemy_slots.filter(
		func(slot): return slot.is_free()
	)
	if available_slots.is_empty(): # Используйте is_empty() вместо size() == 0
		return null
		
	# Оптимизированный поиск ближайшего слота без полной сортировки массива
	var closest_slot: EnemySlot = available_slots[0]
	var min_dist := (enemy.global_position - closest_slot.global_position).length_squared() # length_squared быстрее
	
	for i in range(1, available_slots.size()):
		var slot = available_slots[i]
		var dist = (enemy.global_position - slot.global_position).length_squared()
		if dist < min_dist:
			min_dist = dist
			closest_slot = slot
			
	closest_slot.occupy(enemy)
	return closest_slot

# Освобождение слота, который был занят врагом
func free_slot(enemy: BasicEnemy) -> void:
	# Ищем конкретный слот напрямую через find_custom
	var index := enemy_slots.find_custom(
		func(slot: EnemySlot): return slot.occupant == enemy
	)
	if index != -1:
		enemy_slots[index].free_up()




func handle_double_tap_dash():
	if not can_dash():
		return

	var current_time = Time.get_ticks_msec() / 1000.0

	# LEFT
	if Input.is_action_just_pressed("ui_left"):
		if current_time - last_left_press_time <= DOUBLE_TAP_TIME:
			if state == State.BLOCK:
				start_dash(Vector2.LEFT) # В блоке делаем дэш
			else:
				state = State.SPRINT # В обычном состоянии включаем бег
		last_left_press_time = current_time

	# RIGHT
	if Input.is_action_just_pressed("ui_right"):
		if current_time - last_right_press_time <= DOUBLE_TAP_TIME:
			if state == State.BLOCK:
				start_dash(Vector2.RIGHT) # В блоке делаем дэш
			else:
				state = State.SPRINT # В обычном состоянии включаем бег
		last_right_press_time = current_time


func start_dash(direction: Vector2):
	HitstopManager.freeze(0.03, 0.03)
	state = State.DASH
	dash_timer = DASH_DURATION
	dash_direction = direction.x
	
	# === ОБНОВЛЯЕМ НАПРАВЛЕНИЕ ВЗГЛЯДА ===
	if direction.x != 0:
		heading.x = sign(direction.x)
		# Разворачиваем спрайт в сторону рывка (выберите ваш вариант):
		# Вариант А (если управляете через scale):
		# character_sprite.scale.x = heading.x 
		# Вариант Б (если управляете через flip_h):
		# character_sprite.flip_h = (heading.x == -1)
	# =====================================

	effect_time = 0.0
	velocity = Vector2.ZERO



func start_sprint_attack() -> void:
	state = State.SPRINT_ATTACK
	# Заменили dash_direction на heading.x, чтобы импульс работал из спринта
	velocity.x = (heading.x * 2.5) * DASH_SPEED * 0.6



func _on_cutscene_started():
	pass


func _on_cutscene_finished():
	pass


func ghost(delta):
	if not [State.DASH, State.SPRINT_ATTACK].has(state):
		return

	effect_time -= delta

	if effect_time <= 0:
		effect_time = effect_delay
		ghost_dash()


func ghost_dash():
	var effect : Node2D = Node2D.new()
	var p : Node2D = self
	p.add_sibling(effect)
	effect.z_index = 0
	effect.global_position = p.global_position
	effect.modulate = Color(0.724, 1.385, 1.5, 0.55)
	
	var sprite_copy : Sprite2D = character_sprite.duplicate()
	effect.add_child(sprite_copy)
	
	var t : Tween = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(effect, "modulate", Color(1, 1, 1, 0), 0.2)
	t.chain().tween_callback(effect.queue_free)
	# print("ghost_dash effect is working")


func cutscene_state() -> void:
	state = State.CUTSCENE
	velocity = Vector2.ZERO
