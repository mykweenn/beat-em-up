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

# running grab slide
var grab_slide_timer := 0.0
var grab_slide_duration := 0.15
var grab_slide_direction := 0.0

func _ready() -> void:
	super._ready()
	anim_attacks = ["punch", "punch_alt", "kick", "roundkick",]
	DamageManager.player_revive.connect(on_player_revive.bind())
	GameManager.cutscene_started.connect(_on_cutscene_started.bind())
	GameManager.cutscene_finished.connect(_on_cutscene_finished.bind())


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	procces_time_between_combos()
	_update_camera_effects()
	
	if state == State.DASH or state == State.SPRINT_ATTACK or state == State.DASH_KICK or state == State.RUNNING_GRAB:
		ghost(delta)
	if state == State.RUNNING_GRAB:
		handle_running_grab(delta)


## Поддерживает эффекты камеры, привязанные к состоянию игрока:
## - во время спринта (State.SPRINT) включается «ручная» тряска камеры
##   (имитация съёмки с рук при беге);
## - вне спринта тряска выключается.
func _update_camera_effects() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or not cam.has_method("set_handheld_shake"):
		return
	if state == State.SPRINT:
		cam.set_handheld_shake(true)
	else:
		cam.set_handheld_shake(false)


func procces_time_between_combos() -> void:
	if Time.get_ticks_msec() - time_since_last_successfull_attack > max_duration_between_successful_hits:
		attack_combo_index = 0
		#knife_sprite.flip_h = true


func on_player_revive() -> void:
	current_health = max_health
	state = State.JUMP
	height = REVIVE_HEIGHT


func handle_input() -> void:
	# === СНАЧАЛА ОБРАБАТЫВАЕМ ТЕКУЩИЕ ТЯЖЕЛЫЕ СОСТОЯНИЯ ===
	# Если мы уже бьем тяжелым ударом — отключаем весь остальной ввод
	if state == State.HEAVY_ATTACK:
		return

	# Завершение dash_kick при остановке скольжения
	if state == State.DASH_KICK and abs(velocity.x) < 50.0:
		state = State.IDLE
		velocity.x = 0
		return

	# Running grab — весь ввод заблокирован пока идёт захват
	if state == State.RUNNING_GRAB:
		return

	# === УПРАВЛЕНИЕ В ПОСАДКЕ НА ВРАГА ===
	# Тап атаки — удар в седле (чередование finisher_1/finisher_2),
	# тап прыжка — спрыгнуть с жертвы. Остальной ввод игнорируется.
	if state == State.MOUNT:
		if Input.is_action_just_pressed("attack") and not is_carrying_weapon():
			start_mount_punch()
		elif Input.is_action_just_pressed("jump"):
			exit_mount_jump()
		return

	# === НАКОПЛЕНИЕ СИЛЫ ВО ВРЕМЯ СТЭЙТА ЗАРЯДКИ ===
	if state == State.PREPARE_HEAVY_ATTACK:
		charge_timer += get_physics_process_delta_time()

		# Тряска включается только если зажали кнопку дольше чем на 0.3 сек
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("set_charging_shake"):
			if charge_timer > 0.3:
				cam.set_charging_shake(true)
			else:
				cam.set_charging_shake(false)
		
		if charge_timer >= charge_required_time and not is_fully_charged:
			is_fully_charged = true

		# === ОТПУСКАНИЕ КНОПКИ (РАЗРЯДКА ИЛИ СБРОС) ===
		if Input.is_action_just_released("attack"):
			# Выключаем тряску камеры при любом исходе отпускания кнопки
			if cam and cam.has_method("set_charging_shake"):
				cam.set_charging_shake(false)
			
			# Возвращаем спрайт на место после тряски
			character_sprite.position = Vector2.ZERO
			
			if is_fully_charged:
				state = State.HEAVY_ATTACK
				SoundPlayer.play(SoundManager.Sound.SWOOSH)
				SoundPlayer.play(SoundManager.Sound.CHARGE_ATTACK)
			else:
				# Если отпустили слишком рано и не дозарядили — 
				# запускаем стандартную цепочку атак
				trigger_normal_attack()
				
			charge_timer = 0.0
			is_fully_charged = false
		return # Пока мы в режиме зарядки, код ниже (ходьба, прыжки) не выполняется!


	# === ЛОГИКА БЛОКА ДЛЯ ИГРОКА ===
	if Input.is_action_pressed("block") and (state == State.BLOCK or can_block()):
		if state != State.BLOCK:
			state = State.BLOCK
			velocity = Vector2.ZERO 
			block_activated_time = Time.get_ticks_msec() 
		return 

	if state == State.BLOCK and Input.is_action_just_released("block"):
		state = State.IDLE

	# === ОБЫЧНОЕ ДВИЖЕНИЕ ===
	if can_move():
		var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if state == State.SPRINT:
			velocity = direction * (speed * 1.6)
		else:
			velocity = direction * speed

	# === СТАРТ ОБЫЧНОЙ АТАКИ ИЛИ НАЧАЛО ЗАРЯДКИ ===
	if can_attack() and Input.is_action_just_pressed("attack"):
		# === ПОСАДКА НА ВРАГА (КОНТЕКСТНАЯ АТАКА, КАК В MOTHER RUSSIA BLEEDS) ===
		# Рядом с оглушённым (RECOVER) или лежащим (GROUNDED) врагом тап атаки
		# сажает игрока верхом на жертву. Дальше: атаки — удары в седле,
		# прыжок — спрыгнуть, долгое сидение — враг сбросит игрока.
		# С оружием в руках поведение не меняется — как обычно бросок/выстрел.
		if not is_carrying_weapon():
			var target := find_finisher_target()
			if target != null:
				start_mount(target)
				return
		# При первом нажатии мы переходим в режим подготовки тяжелого удара.
		# Если игрок сразу отпустит кнопку — сработает trigger_normal_attack и произойдет обычный удар.
		# Если зажмет — персонаж начнет копить силу.
		state = State.PREPARE_HEAVY_ATTACK
		charge_timer = 0.0
		is_fully_charged = false
		velocity = Vector2.ZERO # Останавливаем ходьбу для замаха
		return

	# === ПРЫЖОК / УДАР В ПРЫЖКЕ / АТАКА С РАЗБЕГА / ПИНЬК ===
	if can_jump() and Input.is_action_just_pressed("jump"):
		state = State.TAKEOFF
	if can_jumpkick() and Input.is_action_just_pressed("attack"):
		state = State.JUMPKICK
		SoundPlayer.play(SoundManager.Sound.SWOOSH)
	if can_sprint_attack() and Input.is_action_just_pressed("attack"):
		start_sprint_attack()
	if (state == State.SPRINT or state == State.DASH) and Input.is_action_just_pressed("uppercut"):
		start_running_grab()
		return
	if state == State.SPRINT and Input.is_action_just_pressed("kick"):
		state = State.DASH_KICK
		velocity.x = heading.x * speed * 1.6
		SoundPlayer.play(SoundManager.Sound.SWOOSH)
	if can_kick() and Input.is_action_just_pressed("kick"):
		state = State.KICK
		SoundPlayer.play(SoundManager.Sound.SWOOSH)
	if can_kick() and Input.is_action_just_pressed("uppercut"):
		state = State.UPPERCUT
		SoundPlayer.play(SoundManager.Sound.SWOOSH)


func trigger_normal_attack() -> void:
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



func set_heading() -> void:
	if can_move():
		if velocity.x > 0:
			heading = Vector2.RIGHT
		elif velocity.x < 0:
			heading = Vector2.LEFT
	elif state == State.BLOCK:
		var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if direction.x > 0:
			heading = Vector2.RIGHT
		elif direction.x < 0:
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

# Возвращает ближайший СВОБОДНЫЙ слот к врагу (без занятия его).
# Используется врагом, чтобы переоценивать, не появился ли слот ближе текущего.
func get_closest_free_slot(enemy: BasicEnemy) -> EnemySlot:
	var closest_slot: EnemySlot = null
	var min_dist := INF
	for slot: EnemySlot in enemy_slots:
		if slot.is_free():
			var dist := (enemy.global_position - slot.global_position).length_squared()
			if dist < min_dist:
				min_dist = dist
				closest_slot = slot
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

	# UP — рывок вглубь сцены (вверх по экрану): быстрый рывок, как горизонтальный дэш
	if Input.is_action_just_pressed("ui_up"):
		if current_time - last_up_press_time <= DOUBLE_TAP_TIME:
			start_dash(Vector2.UP)
		last_up_press_time = current_time

	# DOWN — рывок вглубь сцены (вниз по экрану): быстрый рывок, как горизонтальный дэш
	if Input.is_action_just_pressed("ui_down"):
		if current_time - last_down_press_time <= DOUBLE_TAP_TIME:
			start_dash(Vector2.DOWN)
		last_down_press_time = current_time


func start_dash(direction: Vector2):
	HitstopManager.freeze(0.03, 0.03)
	state = State.DASH
	dash_timer = DASH_DURATION
	dash_direction = direction
	
	# === ОБНОВЛЯЕМ НАПРАВЛЕНИЕ ВЗГЛЯДА ===
	if direction.x != 0:
		heading.x = sign(direction.x)
	# =====================================

	effect_time = 0.0
	velocity = Vector2.ZERO



func start_sprint_attack() -> void:
	state = State.SPRINT_ATTACK
	# Заменили dash_direction на heading.x, чтобы импульс работал из спринта
	velocity.x = (heading.x * 2.5) * DASH_SPEED * 0.6


func start_running_grab() -> void:
	state = State.RUNNING_GRAB
	velocity.x = heading.x * speed * 1.6
	SoundPlayer.play(SoundManager.Sound.SWOOSH)


func handle_running_grab(delta: float) -> void:
	# Фаза скольжения: протаскиваем врага по инерции
	if grab_slide_timer > 0.0:
		grab_slide_timer -= delta
		# Привязываем врага к позиции игрока
		if finisher_target != null and is_instance_valid(finisher_target):
			finisher_target.global_position.x = global_position.x
			finisher_target.velocity = Vector2.ZERO
			finisher_target.enemy_block_timer = 0.5
		# Торможение
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
		# Скольжение закончилось → mount
		if grab_slide_timer <= 0.0:
			velocity.x = 0
			if finisher_target != null and is_instance_valid(finisher_target):
				start_mount(finisher_target)
			else:
				state = State.IDLE
			return
		return
	# Если анимация завершилась и мы не попали ни в кого — возврат в IDLE
	if not animation_player.is_playing():
		state = State.IDLE
		velocity.x = 0
		finisher_target = null


## Переопределение: при попадании running_grab — захват врага и фаза скольжения
func on_emit_damage(receiver: DamageReceiver) -> void:
	if state == State.RUNNING_GRAB:
		var grabbed_enemy := receiver.get_parent() as Character
		if grabbed_enemy != null and grabbed_enemy.current_health > 0:
			# Оглушаем врага для mount
			grabbed_enemy.state = State.RECOVER
			grabbed_enemy.enemy_block_timer = 0.5
			grabbed_enemy.velocity = Vector2.ZERO
			finisher_target = grabbed_enemy
			# Запускаем фазу скольжения — протаскиваем врага по инерции
			grab_slide_timer = grab_slide_duration
			grab_slide_direction = heading.x
			velocity.x = heading.x * speed * 0.8
			SoundPlayer.play(SoundManager.Sound.HIT1)
			return
	# Обычная обработка урона
	super.on_emit_damage(receiver)



func _on_cutscene_started():
	pass


func _on_cutscene_finished():
	pass


func ghost(delta):
	if not [State.DASH, State.SPRINT_ATTACK, State.DASH_KICK, State.RUNNING_GRAB].has(state):
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


func cutscene_state() -> void:
	state = State.CUTSCENE
	velocity = Vector2.ZERO
