class_name Character
extends CharacterBody2D

const GRAVITY := 3800.0

## Префаб всплывающего текста («БАМ!» и т.п.) для эффектных ударов
const FLOATING_TEXT_PREFAB := preload("res://Scenes/VFX/floating_text.tscn")
const DEATH_SPRITE_PREFAB := preload("res://Scenes/VFX/death_sprite.tscn")

#new dash

## Настройки возрождения. Если true, враг/персонаж может ожить после смерти.
@export var can_respawn : bool
## Базовый урон, наносимый в ближнем бою или при обычном столкновении.
@export var damage : int
## Максимальный запас здоровья персонажа.
@export var max_health : int
## Тип персонажа или врага (например, Обычный, Босс, Летающий), определяющий его поведение.
@export var type : Type

@export_group("Movement")
## Скорость обычного перемещения по земле.
@export var speed : float
## Скорость спринта
@export var sprint_speed : float = 650.0 # Сделайте её заметно выше обычной speed
## Время (в секундах), которое персонаж проводит на земле (например, перед следующим прыжком или после падения).
@export var duration_grounded : float
## Скорость перемещения в воздухе или в режиме полета.
@export var flight_speed : float
## Сила прыжка вверх. Чем выше значение, тем выше прыгает персонаж.
@export var jump_intesnity : float
## Сила отдачи (отбрасывания) при получении обычного урона.
@export var knockback_intensity : float
## Сила тяжелого отбрасывания, которое сбивает персонажа с ног (вводит в нокдаун).
@export var knockdown_intensity : float
## Скорость персонажа во время совершения рывка (даша).
@export var DASH_SPEED := 1050.0
## Длительность рывка в секундах.
@export var DASH_DURATION := 0.08
## Максимальное время (в секундах) между нажатиями клавиш для засчитывания двойного тапа (например, для даша).
@export var DOUBLE_TAP_TIME := 0.25
@export var launch_vertical_intensity: float = 1200.0   # Сила подбрасывания вверх
@export var launch_horizontal_intensity: float = 650.0 # Сила отлета в сторону
## Сколько секунд нужно удерживать кнопку для полной зарядки удара
@export var charge_required_time : float = 0.80

@export_group("Weapons")
## Если true, выброшенное или выпавшее оружие автоматически уничтожается.
@export var autodestroy_on_drop : bool
## Разрешает ли система автоматически восполнять (респавнить) запасные ножи.
@export var can_respawn_knives : bool
## Урон, наносимый одним выстрелом из огнестрельного оружия.
@export var damage_gun_shot : int
## Урон от усиленной (заряженной) атаки ближнего или дальнего боя.
@export var damage_power : int
## Время (в секундах) между автоматическим появлением новых ножей.
@export var duration_between_knife_respawn : int
## Флаг наличия ножа в арсенале или в руках.
@export var has_knife : bool
## Флаг наличия огнестрельного оружия в арсенале или в руках.
@export var has_gun : bool
## Максимальное количество патронов, которое вмещает один пистолет/автомат.
@export var max_ammo_per_gun : int

@export_group("Block")
@export var max_block_health : float = 10.0
@export var block_regen_rate : float = 20.0
## Шанс (от 0.0 до 1.0), что враг решит заблокировать удар вместо получения урона
@export var block_chance : float = 0.4 
## Как долго враг будет удерживать блок (в секундах) после активации
@export var block_duration : float = 0.8 
## Окно времени (в секундах), в течение которого блок считается идеальным парированием.
@export var parry_window : float = 0.15
## Сколько секунд атакующий стоит в RECOVER после успешного парирования.
@export var parry_stun_duration : float = 1.2

@export_group("Finisher")
## Множитель урона добивания (от damage_power).
@export var finisher_damage_multiplier : float = 2.0
## Задержка (в секундах) от начала добивания до момента удара — подбирается под кадр удара анимации "finisher".
@export var finisher_hit_delay : float = 0.25
## Страховочная длительность добивания: если анимация не вызвала on_action_complete,
## состояние принудительно завершится по истечении этого времени.
@export var finisher_max_duration : float = 1.0
## Множитель урона одного удара в посадке на врага (от damage_power).
@export var mount_punch_damage_multiplier : float = 0.6
## Сколько секунд можно сидеть на враге без ударов, прежде чем он сбросит игрока.
@export var mount_throw_delay : float = 4.0
## Высота (в пикселях), на которую поднимается спрайт игрока при посадке на врага.
@export var mount_height : float = 55.0
## Дальность поиска цели для добивания по горизонтали (пиксели).
const FINISHER_RANGE_X := 120.0
## Допуск по глубине (ось Y) при поиске цели для добивания (пиксели).
const FINISHER_RANGE_Y := 60.0

@onready var animation_player := $AnimationPlayer
@onready var character_sprite := $CharacterSprite
@onready var collateral_damage_emitter: Area2D = $CollateralDamageEmitter
@onready var collectible_sensor: Area2D = $CollectibleSensor
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var damage_emitter: Area2D = $DamageEmitter
@onready var damage_receiver: DamageReceiver = $DamageReceiver
@onready var gun_sprite: Sprite2D = $GunSprite
@onready var knife_sprite: Sprite2D = $KnifeSprite
@onready var projectile_aim: RayCast2D = $ProjectileAim
@onready var weapon_position: Node2D = $KnifeSprite/WeaponPosition


enum State {IDLE, WALK, ATTACK, TAKEOFF, JUMP, LAND, JUMPKICK, HURT, FALL, GROUNDED, DEATH, FLY, PREP_ATTACK, 
THROW, PICKUP, SHOOT, PREP_SHOOT, RECOVER, DROP, WAIT, APPEARING, SPRINT, DASH, SPRINT_ATTACK, CUTSCENE, BLOCK, 
KICK, PREPARE_HEAVY_ATTACK, HEAVY_ATTACK, FINISHER, MOUNT, UPPERCUT, DASH_KICK, RUNNING_GRAB}
enum Type {PLAYER, PUNK, GOON, THUG, BOUNCER, HEAVY}

var ammo_left := 0
var anim_attacks := []
var anim_map : Dictionary = {
	State.IDLE: "idle",
	State.WALK: "walk",
	State.TAKEOFF: "takeoff",
	State.JUMP: "jump",
	State.LAND: "land",
	State.JUMPKICK: "jumpkick",
	State.HURT: "hurt",
	State.FALL: "fall",
	State.GROUNDED: "grounded",
	State.DEATH: "grounded",
	State.FLY: "fly",
	State.PREP_ATTACK: "idle", # можно дополишить этот момент
	State.THROW: "throw",
	State.PICKUP: "pickup",
	State.SHOOT: "shoot",
	State.PREP_SHOOT: "idle",
	State.RECOVER: "recover",
	State.DROP: "idle",
	State.WAIT: "idle",
	State.APPEARING: "idle",
	State.SPRINT: "sprint",
	State.DASH: "dash",
	State.SPRINT_ATTACK: "dash_attack",
	State.CUTSCENE: "cutscene",
	State.BLOCK: "block",
	State.KICK: "kick_power",
	State.PREPARE_HEAVY_ATTACK: "prepare_heavy_attack",
	State.HEAVY_ATTACK: "heavy_attack",
	State.FINISHER: "finisher",
	State.MOUNT: "mount",
	State.UPPERCUT: "uppercut",
	State.DASH_KICK: "slide_attack",
	State.RUNNING_GRAB: "running_grab",
}

var attack_combo_index := 0
var current_health := 0
var heading := Vector2.RIGHT
var height := 0.0
var height_speed := 0.0
var is_last_hit_successful := false
var state = State.IDLE
var time_since_grounded := Time.get_ticks_msec()
var time_since_knife_dismiss := Time.get_ticks_msec()

#new dash
var dash_timer := 0.0
var dash_direction := 0.0
var last_left_press_time := -1.0
var last_right_press_time := -1.0

# block
var block_health : float = 0.0
var block_broken : bool = false
var enemy_block_timer : float = 1.0
# Время в миллисекундах, когда персонаж вошел в состояние блока
var block_activated_time : float = 0.0

# stunlock exit
# Счетчик ударов для защиты игрока от станлока
var combo_hurt_count := 0
# Время в миллисекундах, когда персонаж в последний раз получал урон
var last_hurt_time : float = 0.0

# Внутренний таймер удержания кнопки
var charge_timer : float = 0.0
# Флаг, что удар полностью зарядился
var is_fully_charged : bool = false

# finisher
# Цель добивания, выбранная в момент нажатия атаки
var finisher_target : Character = null
# Таймер до момента удара (подгоняется под кадр удара анимации)
var finisher_hit_timer : float = 0.0
# Сколько секунд уже длится текущее добивание (страховка на случай анимации без callback-трека)
var finisher_elapsed := 0.0
# Индекс чередующейся анимации добивания (0 -> "finisher_1", 1 -> "finisher_2")
var finisher_anim_index := 0
# Имя анимации, выбранное для текущего удара в седле
var finisher_anim_current := ""
# Флаг активной посадки на врага: удары в седле и возврат в MOUNT вместо IDLE
var is_mounting := false
# Сколько секунд игрок уже сидит на враге без ударов (до сброса врагом)
var mount_idle_timer := 0.0

# Кэш последней проигранной анимации: не дергаем AnimationPlayer без необходимости
var _current_animation := ""
# Кэш физических флагов: присваиваем только при изменении (дешевле для физического движка)
var _cached_collision_disabled := false
var _cached_damage_emitter_monitoring := false
var _cached_receiver_monitorable := false
var _cached_collateral_monitoring := false
# Направление взгляда после последнего обновления спрайтов
var _facing_right := true
var _death_sprite_spawned := false


func _ready():
	damage_emitter.area_entered.connect(on_emit_damage.bind())
	damage_receiver.damage_received.connect(on_receive_damage.bind())
	collateral_damage_emitter.area_entered.connect(on_emit_collateral_damage.bind())
	collateral_damage_emitter.body_entered.connect(on_wall_hit.bind())
	set_health(max_health, type == Character.Type.PLAYER)
	set_sprite_height_position()
	block_health = max_block_health
	_cached_collision_disabled = collision_shape.disabled
	_cached_damage_emitter_monitoring = damage_emitter.monitoring
	_cached_receiver_monitorable = damage_receiver.monitorable
	_cached_collateral_monitoring = collateral_damage_emitter.monitoring


func _physics_process(delta: float) -> void:
	# Плавно гасим скорость отброса как для блока, так и для оглушения
	if state == State.BLOCK or state == State.RECOVER:
		if is_on_floor():
			# На земле тормозим быстро
			velocity = velocity.move_toward(Vector2.ZERO, 9000 * delta)
		else:
			# В воздухе тормозим гораздо слабее (воздушное сопротивление)
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)

	if GameManager.current_state == GameManager.GameState.CUTSCENE:
		cutscene_state()
	elif GameManager.current_state == GameManager.GameState.GAMEPLAY:
		handle_input()

	#block
	if state != State.BLOCK and block_health < max_block_health:
		block_health += block_regen_rate * delta
		if block_health >= max_block_health:
			block_health = max_block_health
			block_broken = false # Щит полностью восстановился и снова готов к работе

	#methods
	handle_double_tap_dash()
	handle_movement(delta)
	handle_finisher(delta)
	handle_mount(delta)
	handle_animations()
	handle_air_time(delta)
	handle_prep_attack()
	handle_prep_shoot()
	handle_grounded()
	handle_knife_respawn()
	handle_death(delta)
	set_heading()
	flip_sprites()
	set_sprite_visibility()
	set_sprite_height_position()
	if state == State.BLOCK:
		velocity = velocity.move_toward(Vector2.ZERO, GRAVITY * delta)
	setup_collisions()
	move_and_slide()


func set_sprite_visibility() -> void:
	knife_sprite.visible = has_knife
	gun_sprite.visible = has_gun

##Обновляет вертикальную позицию всех визуальных элементов персонажа.
## Используется для корректировки высоты спрайтов относительно точки персонажа.
##
## Например:
## - при разной высоте персонажей
## - смене стойки
## - корректировке хитбоксов/анимаций
func set_sprite_height_position() -> void:
	character_sprite.position = Vector2.UP * height
	knife_sprite.position = Vector2.UP * height
	# knife_sprite.position = weapon_position.global_position
	gun_sprite.position = Vector2.UP * height


## Настраивает состояние коллизий и зон взаимодействия персонажа.
##
## В зависимости от текущего состояния персонажа:
## - включает/отключает основную коллизию
## - активирует зону нанесения урона во время атаки
## - разрешает получение урона
## - активирует зону побочного урона в полёте
func setup_collisions() -> void:
	var value := is_collision_disabled()
	if value != _cached_collision_disabled:
		_cached_collision_disabled = value
		collision_shape.disabled = value
	value = is_attacking()
	if value != _cached_damage_emitter_monitoring:
		_cached_damage_emitter_monitoring = value
		damage_emitter.monitoring = value
	value = can_get_hurt() and state != State.GROUNDED
	if value != _cached_receiver_monitorable:
		_cached_receiver_monitorable = value
		damage_receiver.monitorable = value
	value = state == State.FLY
	if value != _cached_collateral_monitoring:
		_cached_collateral_monitoring = value
		collateral_damage_emitter.monitoring = value


func handle_movement(delta: float): # Добавили delta в аргументы
# Если персонаж заблокирован физикой — не даем коду ниже занулять скорость
	match state:
		State.HURT, State.FALL, State.FLY, State.BLOCK, State.PREPARE_HEAVY_ATTACK, State.HEAVY_ATTACK, State.FINISHER, State.DASH_KICK, State.RUNNING_GRAB:
			return
	if state == State.DASH:
		velocity.x = dash_direction * DASH_SPEED
		dash_timer -= delta
		if dash_timer <= 0:
			state = State.IDLE
			velocity.x = 0
			# === СБРАСЫВАЕМ НАПРАВЛЕНИЕ ДЭША ===
			dash_direction = 0.0 
			# ===================================
		return

	if state == State.SPRINT_ATTACK:
		# Плавно тормозим персонажа во время удара, чтобы он не улетал за экран
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
		return

	if state == State.DASH_KICK:
		velocity.x = move_toward(velocity.x, 0.0, 2200.0 * delta)
		return

	if state == State.RUNNING_GRAB:
		velocity.x = move_toward(velocity.x, 0.0, 2500.0 * delta)
		return
	
	if can_move():
		if velocity.length() == 0:
			state = State.IDLE
		else:
			# Переключаем в WALK только если мы НЕ находимся в состоянии SPRINT
			if state != State.SPRINT:
				state = State.WALK




## Обрабатывает нахождение персонажа в воздухе.
##
## Управляет:
## - изменением высоты прыжка
## - ускорением падения под действием гравитации
## - приземлением персонажа
## - сменой состояний после касания земли
##
## При достижении земли:
## - FALL -> переход в состояние GROUNDED
## - остальные воздушные состояния -> LAND
func handle_air_time(delta: float) -> void:
	match state:
		State.JUMP, State.JUMPKICK, State.FALL, State.DROP:
			height += height_speed * delta
			if height < 0:
				height = 0
				if state == State.FALL:
					state = State.GROUNDED
					time_since_grounded = Time.get_ticks_msec()
				else:
					state = State.LAND
				velocity = Vector2.ZERO
			else:
				height_speed -= GRAVITY * delta



func handle_input():
	pass


func handle_prep_attack() -> void:
	pass


func handle_prep_shoot() -> void:
	pass


## Обрабатывает состояние персонажа после "падения" на землю.
##
## После окончания времени нахождения в состоянии GROUNDED:
## - переводит персонажа в DEATH, если здоровье закончилось
## - иначе запускает анимацию/состояние приземления LAND
func handle_grounded() -> void:
	if state == State.GROUNDED and (Time.get_ticks_msec() - time_since_grounded > duration_grounded):
		if current_health == 0:
			state = State.DEATH
		else:
			state = State.LAND


## Обрабатывает автоматическое восстановление ножа у персонажа.
##
## Если включено восстановление ножей и персонаж сейчас без ножа,
## то после окончания таймера ожидания оружие возвращается.
func handle_knife_respawn() -> void:
	if can_respawn_knives and not has_knife and (Time.get_ticks_msec() - time_since_knife_dismiss > duration_between_knife_respawn):
		has_knife = true
	

## Обрабатывает окончательную смерть персонажа.
##
## Если персонаж не может возродиться:
## - спавнит статичный спрайт с текущим кадром анимации
## - запускает обесцвечивание через шейдер
## - удаляет оригинальный узел персонажа
func handle_death(_delta) -> void:
	if state == State.DEATH and not can_respawn and not _death_sprite_spawned:
		_death_sprite_spawned = true
		var death_sprite = DEATH_SPRITE_PREFAB.instantiate()
		death_sprite.setup_from_character(self)
		get_tree().current_scene.add_child(death_sprite)
		queue_free()


## Обрабатывает проигрывание анимаций персонажа.
##
## Логика работы:
## - во время атаки проигрывается анимация текущего комбо-удара
## - в остальных случаях проигрывается анимация,
##   соответствующая текущему состоянию персонажа
##
## Анимации синхронно запускаются как в AnimationPlayer,
## так и в AnimatedSprite2D.
func handle_animations() -> void:
	# if state == State.BLOCK:
	# 	# print("Текущая анимация: ", animation_player.current_animation, " | Играет: ", animation_player.is_playing())
	# 	pass
		# 1. Специфичная логика для блока
	if state == State.BLOCK:
		# Если персонаж только что получил удар и играет анимация дёргания
		if animation_player.current_animation == "block_damage":
			return # Просто выходим и даем анимации block_damage доиграть до конца
			
		# Если анимация block_damage ЗАВЕРШИЛАСЬ, плавно возвращаем персонажа в обычную стойку
		if animation_player.assigned_animation == "block_damage" and not animation_player.is_playing():
			play_animation("block")
			animation_player.seek(0.3, true) # Сразу перематываем на финальный статичный кадр блока
			return
			
		# Если обычная анимация блока завершилась и замерла, удерживаем её на финальной позиции
		if animation_player.assigned_animation == "block" and not animation_player.is_playing():
			animation_player.seek(0.3, true)
		# Иначе, если играет что-то другое (например, вошли из IDLE), запускаем блок
		elif animation_player.current_animation != "block":
			play_animation("block")
		return


	# 2. Логика обычных атак
	if state == State.ATTACK:
		play_animation(anim_attacks[attack_combo_index])
	# 3. Добивание: чередуем finisher_1 / finisher_2
	elif state == State.FINISHER:
		play_finisher_animation()
	# 4. Все остальные стандартные анимации из словаря
	elif animation_player.has_animation(anim_map[state]):
		play_animation(anim_map[state])


## Проигрывает анимацию удара в седле, выбранную заранее в start_mount_punch
## (чередование finisher_1 / finisher_2). Если вариантной анимации нет в
## библиотеке — откатывается на старую "finisher".
func play_finisher_animation() -> void:
	var anim_name := finisher_anim_current
	if not animation_player.has_animation(anim_name):
		anim_name = anim_map[State.FINISHER]
	if animation_player.has_animation(anim_name):
		play_animation(anim_name)


## Проигрывает анимацию только если она сменилась или завершилась.
## Вызов animation_player.play() каждый кадр — лишняя работа для горячего пути.
func play_animation(anim_name: String) -> void:
	if _current_animation != anim_name or not animation_player.is_playing():
		_current_animation = anim_name
		animation_player.play(anim_name)


	 


func set_heading() -> void:
	pass


func flip_sprites():
	var faces_right := heading == Vector2.RIGHT
	if faces_right == _facing_right:
		return
	_facing_right = faces_right
	character_sprite.flip_h = not faces_right
	var side := 1.0 if faces_right else -1.0
	knife_sprite.scale.x = side
	gun_sprite.scale.x = side
	projectile_aim.scale.x = side
	damage_emitter.scale.x = side


func can_move() -> bool:
	return state == State.IDLE or state == State.WALK or state == State.SPRINT


func can_attack() -> bool:
	return state == State.IDLE or state == State.WALK


func can_jump() -> bool:
	return state == State.IDLE or state == State.WALK or state == State.SPRINT
	

func can_block() -> bool:
	# Блокировать можно из спокойных состояний, если щит не сломан
	match state:
		State.IDLE, State.WALK, State.SPRINT, State.PREP_ATTACK:
			return not block_broken
		_:
			return false



func can_get_hurt() -> bool:
	match state:
		State.IDLE, State.WALK, State.TAKEOFF, State.LAND, State.PREP_ATTACK, State.BLOCK, State.RECOVER, State.PREPARE_HEAVY_ATTACK:
			return true
		_:
			pass
	# Лежачий враг (GROUNDED) уязвим только для добивания: прямой вызов
	# on_receive_damage проходит, а обычные атаки его не достают — в
	# setup_collisions() receiver остаётся monitorable = false.
	# Игрок исключён: лежащий игрок неуязвим для прямых выстрелов врагов (как и раньше).
	if state == State.GROUNDED and type != Type.PLAYER:
		return true
	return false


func can_dash() -> bool:
	match state:
		State.IDLE, State.WALK, State.BLOCK:
			return true
		_:
			return false


func can_sprint_attack() -> bool:
	return state == State.DASH or state == State.SPRINT

func can_kick() -> bool:
	return state == State.IDLE or state == State.WALK

#func can_sprint_attack() -> bool:
	#return state == State.IDLE or state == State.WALK

### Если атакует, возвращаем список состояний боевых
func is_attacking() -> bool:
	match state:
		State.ATTACK, State.JUMPKICK, State.SPRINT_ATTACK, State.KICK, State.HEAVY_ATTACK, State.UPPERCUT, State.DASH_KICK, State.RUNNING_GRAB:
			return true
		_:
			return false


func is_carrying_weapon() -> bool:
	return has_knife or has_gun


func can_pickup_collectible() -> bool:
	if can_respawn_knives:
		return false
	if Time.get_ticks_msec() - time_since_knife_dismiss < duration_between_knife_respawn:
		return false
	var collectible_areas := collectible_sensor.get_overlapping_areas()
	if collectible_areas.size() == 0:
		return false
	var collectible : Collectible = collectible_areas[0]
	if collectible.type == Collectible.Type.KNIFE and not has_knife:
		return true
	if collectible.type == Collectible.Type.GUN and not has_gun:
		return true
	if collectible.type == Collectible.Type.FOOD:
		return true
	return false


## Выполняет выстрел из огнестрельного оружия.
##
## Во время выстрела:
## - персонаж переходит в состояние SHOOT
## - останавливается движение
## - определяется точка попадания
## - наносится урон цели при попадании
## - создаются визуальные эффекты выстрела и искр
## - воспроизводится звук оружия
func shot_gun() -> void:
	state = State.SHOOT
	velocity = Vector2.ZERO
	var target_point := heading * (global_position.x + get_viewport_rect().size.x)
	var target := projectile_aim.get_collider()
	if target != null:
		target_point = projectile_aim.get_collision_point()
		target.on_receive_damage(damage_gun_shot, heading, DamageReceiver.HitType.KNOCKDOWN)
		EntityManager.spawn_spark.emit(target.position)
	SoundPlayer.play(SoundManager.Sound.GUNSHOT)
	var weapon_root_position := Vector2(weapon_position.global_position.x, position.y)
	var weapon_height := -weapon_position.position.y
	var distance := target_point.x - weapon_position.global_position.x
	EntityManager.spawn_shot.emit(weapon_root_position, distance, weapon_height)


## Ищет ближайшую цель для добивания.
##
## Подходят только обычные враги (группа "enemy"), которые:
## - живы (current_health > 0)
## - оглушены после парирования (RECOVER) или лежат на земле (GROUNDED)
## - находятся в пределах FINISHER_RANGE_X / FINISHER_RANGE_Y от персонажа
## Босс (BOUNCER) исключён — он не должен добиваться.
func find_finisher_target() -> Character:
	var best_target : Character = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("enemy"):
		var candidate := node as Character
		if candidate == null:
			continue
		if candidate.type == Type.BOUNCER:
			continue
		if candidate.current_health <= 0:
			continue
		if candidate.state != State.RECOVER and candidate.state != State.GROUNDED:
			continue
		var offset := candidate.global_position - global_position
		if absf(offset.x) > FINISHER_RANGE_X or absf(offset.y) > FINISHER_RANGE_Y:
			continue
		var distance := absf(offset.x)
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	return best_target


## Сажает персонажа верхом на лежачую/оглушённую жертву.
##
## Персонаж прилипает к позиции жертвы, поднимается на mount_height
## и переходит в состояние MOUNT. Удары в седле запускаются отдельно
## через start_mount_punch().
func start_mount(target: Character) -> void:
	finisher_target = target
	finisher_hit_timer = INF
	finisher_elapsed = 0.0
	mount_idle_timer = 0.0
	is_mounting = true
	state = State.MOUNT
	velocity = Vector2.ZERO
	height = mount_height
	heading = Vector2.LEFT if target.global_position.x < global_position.x else Vector2.RIGHT
	# Враг поворачивается лицом к игроку
	target.heading.x = -heading.x


## Запускает один удар в посадке: работает как добивание (State.FINISHER),
## но после анимации on_action_complete вернёт в MOUNT, а не в IDLE.
func start_mount_punch() -> void:
	if state != State.MOUNT or finisher_target == null or not is_instance_valid(finisher_target):
		return
	finisher_hit_timer = finisher_hit_delay
	finisher_elapsed = 0.0
	mount_idle_timer = 0.0
	# Выбираем анимацию текущего удара, затем чередуем индекс на следующий
	finisher_anim_current = "finisher_" + str(finisher_anim_index + 1)
	finisher_anim_index = (finisher_anim_index + 1) % 2
	state = State.FINISHER


## Обрабатывает активное добивание (вызывается из _physics_process).
##
## Логика:
## - во время посадки удерживает персонажа на жертве
## - отменяет добивание, если цель исчезла из мира
## - наносит урон, когда истёк таймер удара
## - принудительно завершает состояние по страховочному таймеру,
##   если анимация "finisher" не вызвала on_action_complete
func handle_finisher(delta: float) -> void:
	if state != State.FINISHER:
		return
	if is_mounting and finisher_target != null and is_instance_valid(finisher_target):
		global_position.x = finisher_target.global_position.x
		global_position.y = finisher_target.global_position.y
		height = mount_height
	velocity = Vector2.ZERO
	finisher_elapsed += delta
	if finisher_target == null or not is_instance_valid(finisher_target):
		if is_mounting:
			dismount_calmly()
		else:
			on_action_complete()
		return
	finisher_hit_timer -= delta
	if finisher_hit_timer <= 0.0:
		_apply_finisher_damage()
	if finisher_elapsed >= finisher_max_duration and state == State.FINISHER:
		on_action_complete()


## Обрабатывает посадку на врага (вызывается из _physics_process).
##
## Логика:
## - страховочно разбирает маунт, если состояние сбито извне (катсцена и т.п.)
## - каждый кадр прилипает к жертве и пиннит её таймеры подъёма,
##   чтобы она не встала, пока на ней сидят
## - по истечении mount_throw_delay без ударов жертва сбрасывает игрока
func handle_mount(delta: float) -> void:
	# Страховка: внешнее воздействие сменило состояние — тихо освобождаем маунт
	if is_mounting and state != State.MOUNT and state != State.FINISHER:
		is_mounting = false
		finisher_target = null
		return
	if state != State.MOUNT:
		return
	var target := finisher_target
	if target == null or not is_instance_valid(target) or target.current_health <= 0:
		dismount_calmly()
		return
	global_position.x = target.global_position.x
	global_position.y = target.global_position.y
	velocity = Vector2.ZERO
	height = mount_height
	# Поворачиваем врага лицом к игроку (они смотрят друг на друга)
	target.heading.x = -heading.x
	target.time_since_grounded = Time.get_ticks_msec()
	target.enemy_block_timer = maxf(target.enemy_block_timer, 1.0)
	mount_idle_timer += delta
	if mount_idle_timer >= mount_throw_delay:
		throw_player_off()


## Жертва сбрасывает игрока: подбрасывает его в полёт назад без урона.
func throw_player_off() -> void:
	is_mounting = false
	finisher_target = null
	state = State.FALL
	height_speed = launch_vertical_intensity * 0.5
	velocity = -heading * launch_horizontal_intensity * 0.6
	HitstopManager.freeze(0.15, 0.15)
	SoundPlayer.play(SoundManager.Sound.HIT1, true)
	combo_hurt_count = 0
	_notify_enemies_player_down()


## Игрок спрыгивает с жертвы по кнопке прыжка: обычная цепочка TAKEOFF -> JUMP -> LAND.
func exit_mount_jump() -> void:
	is_mounting = false
	finisher_target = null
	state = State.TAKEOFF
	velocity = -heading * speed * 0.5
	SoundPlayer.play(SoundManager.Sound.SWOOSH)


## Мягкое завершение посадки (жертва умерла или исчезла): игрок спокойно слезает рядом.
func dismount_calmly() -> void:
	is_mounting = false
	finisher_target = null
	height = 0.0
	velocity = Vector2.ZERO
	global_position.x += heading.x * 40.0
	state = State.IDLE


## Наносит урон цели добивания в момент удара.
##
## Урон отправляется прямым вызовом on_receive_damage (как при выстреле),
## поэтому кровь, очки, комбо и смерть обрабатываются логикой жертвы автоматически.
func _apply_finisher_damage() -> void:
	if state != State.FINISHER:
		return
	var target := finisher_target
	finisher_hit_timer = INF # удар наносится один раз за добивание
	if not is_instance_valid(target):
		return
	# Цель могла умереть или сменить состояние за время замаха — тогда промах
	if target.current_health <= 0 or (target.state != State.RECOVER and target.state != State.GROUNDED):
		return
	var direction := Vector2.LEFT if target.global_position.x < global_position.x else Vector2.RIGHT
	var multiplier := mount_punch_damage_multiplier if is_mounting else finisher_damage_multiplier
	var amount := int(damage_power * multiplier)
	mount_idle_timer = 0.0 # попадание продлевает время сидения
	HitstopManager.freeze(0.12, 0.12)
	SoundPlayer.play(SoundManager.Sound.FINISHER)

	# spawn_finisher_text(target)
	target.on_receive_damage(amount, direction, DamageReceiver.HitType.KNOCKDOWN, self)
	# Добивание со смертельным исходом — усиленный хитстоп
	if is_instance_valid(target) and target.current_health <= 0:
		HitstopManager.freeze(0.55, 0.55)


## Спавнит всплывающий текст («БАМ!») над жертвой добивания.
func spawn_finisher_text(target: Node2D) -> void:
	var text_instance := FLOATING_TEXT_PREFAB.instantiate()
	text_instance.text_to_display = "БАМ!"
	text_instance.position = target.global_position + Vector2(0, -250)
	get_tree().current_scene.add_child(text_instance)


## Подбирает ближайший доступный collectible-объект.
##
## В зависимости от типа предмета персонаж может:
## - подобрать нож
## - подобрать огнестрельное оружие и получить патроны
## - восстановить здоровье едой
##
## После подбора объект удаляется со сцены.
func pickup_collectible() -> void:
	if can_pickup_collectible():
		var collectible_areas := collectible_sensor.get_overlapping_areas()
		var collectible : Collectible = collectible_areas[0]
		if collectible.type == Collectible.Type.KNIFE and not has_knife:
			has_knife = true
			SoundPlayer.play(SoundManager.Sound.SWOOSH)
		if collectible.type == Collectible.Type.GUN and not has_gun:
			has_gun = true
			ammo_left = max_ammo_per_gun
			SoundPlayer.play(SoundManager.Sound.SWOOSH)
		if collectible.type == Collectible.Type.FOOD:
			set_health(max_health)
			SoundPlayer.play(SoundManager.Sound.FOOD)
		collectible.queue_free()


func is_collision_disabled() -> bool:
	match state:
		State.GROUNDED, State.DEATH, State.FLY, State.MOUNT:
			return true
		_:
			return false


func can_jumpkick() -> bool:
	return state == State.JUMP 


func on_action_complete():
	# Во время посадки завершившийся удар возвращает в седло, а не в стойку
	if is_mounting:
		state = State.MOUNT
		return
	state = State.IDLE


## Вызывается после завершения броска оружия/предмета.
##
## Логика:
## - возвращает персонажа в состояние IDLE
## - определяет, какое оружие было выброшено (нож или пушка)
## - снимает соответствующий флаг владения оружием
## - создаёт выброшенный collectible в мире
func on_throw_complete() -> void:
	state = State.IDLE
	var collectible_type := Collectible.Type.KNIFE
	if has_gun:
		collectible_type = Collectible.Type.GUN
		has_gun = false
	else:
		has_knife = false
	SoundPlayer.play(SoundManager.Sound.SWOOSH)
	
	# Точка на земле: X от оружия (чтобы летел из руки), Y от ног врага
		# Передаем точную точку руки, а высоту ставим в 0.0, чтобы движок не смещал её дважды
	var collectible_global_position := weapon_position.global_position
	var collectible_height := 0.0
	
	EntityManager.spawn_collectible.emit(collectible_type, Collectible.State.FLY, collectible_global_position, heading, collectible_height, false)

	
	
func on_takeoff_complete():
	state = State.JUMP
	height_speed = jump_intesnity
	SoundPlayer.play(SoundManager.Sound.SWOOSH)

func on_pickup_complete():
	state = State.IDLE
	pickup_collectible()
	# pickup collectible

func on_land_complete():
	state = State.IDLE


## Обрабатывает получение урона персонажем.
##
## Логика:
## - проверяет возможность получения урона
## - сбрасывает комбо атаки
## - отключает возможность респавна ножа
## - при наличии оружия выбрасывает его в мир
## - уменьшает здоровье
## - воспроизводит звук попадания
## - определяет реакцию на удар (нокаут, полёт, отбрасывание)
func on_receive_damage(amount: int, direction: Vector2, hit_type: DamageReceiver.HitType, attacker: Character = null) -> void:
	if not can_get_hurt():
		return
		
	if state == State.PREPARE_HEAVY_ATTACK:
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("set_charging_shake"):
			cam.set_charging_shake(false) # Гарантированно выключаем глитч при получении урона


	# === ПРОВЕРКА НА УДАР В СПИНУ ===
	# direction.x указывает, куда летит удар: 1 (вправо) или -1 (влево)
	# heading.x указывает, куда смотрит персонаж: 1 (вправо) или -1 (влево)
	# Если знаки совпадают (например, удар летит вправо и персонаж смотрит вправо), значит это удар в спину!
	var is_hit_from_behind : bool = sign(direction.x) == sign(heading.x)
	# ===============================
	if type == Type.PLAYER and state == State.BLOCK and not block_broken:
		# 1. Поворачиваем игрока лицом к атаке со всех сторон
		heading.x = -sign(direction.x)
	

	# === ЗАЩИТА ИГРОКА ОТ СТАНЛОКА (ВРЕМЕННОЕ ОКНО) ===
	if type == Type.PLAYER:
		var current_time := Time.get_ticks_msec()
		# Переводим секунды окна в миллисекунды (0.8 сек = 600 мс)
		var max_stunlock_interval := 800.0 
		
		# Проверяем, сколько времени прошло с прошлого удара
		if (current_time - last_hurt_time) <= max_stunlock_interval:
			# Удары сыплются слишком быстро — увеличиваем счётчик
			combo_hurt_count += 1
			
			# Если это 3-й удар в рамках временного окна — принудительно спасаем игрока
			if combo_hurt_count >= 3:
				hit_type = DamageReceiver.HitType.LAUNCH
				HitstopManager.freeze(0.2, 0.2) 
				combo_hurt_count = 0
		else:
			# Передышка была долгой — это новый чистый удар, начинаем отсчёт заново
			combo_hurt_count = 1
			
		# Запоминаем время текущего удара для следующей проверки
		last_hurt_time = current_time
	# ==================================================

		# === ЛОГИКА БЛОКИРОВАНИЯ ===
	if state == State.BLOCK:
		# Удар в спину для игрока — блок не работает, урон проходит
		if type == Type.PLAYER and is_hit_from_behind:
			pass # Пропускаем блок, урон проходит обычным путём
		else:
			# Проверяем, не прилетел ли в нас заряженный удар от нападающего
			var is_hit_by_heavy : bool = (attacker != null and attacker.state == State.HEAVY_ATTACK)
			
			# Если бьют тяжелым заряженным ударом — блок брутально пробивается!
			if is_hit_by_heavy:
				block_health = 0
				block_broken = true
				block_activated_time = 0.0
				hit_type = DamageReceiver.HitType.KNOCKDOWN
				
				if is_hit_by_heavy:
					HitstopManager.freeze(0.2, 0.2)
					SoundPlayer.play(SoundManager.Sound.HIT1, true) 
				
			else:
				# --- ПРОВЕРКА НА ИДЕАЛЬНЫЙ БЛОК (PARRY) ---
				var current_time := Time.get_ticks_msec()
				var is_parry : bool = (current_time - block_activated_time) <= (parry_window * 1000.0)
				
				if is_parry:
					HitstopManager.freeze(0.15, 0.15) 
					EntityManager.spawn_spark.emit(position) 
					SoundPlayer.play(SoundManager.Sound.HIT3, true)
					if attacker != null:
						attacker.apply_parry_stun(-direction * launch_horizontal_intensity * 0.1)
					return
				# ------------------------------------------

				# Обычный успешный блок
				block_health -= amount
				if block_health > 0:
					SoundPlayer.play(SoundManager.Sound.HIT2, true)
					velocity = direction * (knockback_intensity * 0.3)
					animation_player.play("block_damage") 
					return
				else:
					block_health = 0
					block_broken = true
					block_activated_time = 0.0
					hit_type = DamageReceiver.HitType.KNOCKDOWN
	# ==========================================


	# Обычное получение урона (выполняется, если не блокировали или block пробили)
	attack_combo_index = 0
	can_respawn_knives = false
	if has_knife:
		has_knife = false
		EntityManager.spawn_collectible.emit(Collectible.Type.KNIFE, Collectible.State.FALL, global_position, Vector2.ZERO, 0.0, autodestroy_on_drop)
		time_since_knife_dismiss = Time.get_ticks_msec()
	if has_gun:
		has_gun = false
		EntityManager.spawn_collectible.emit(Collectible.Type.GUN, Collectible.State.FALL, global_position, Vector2.ZERO, 0.0, autodestroy_on_drop)
	
	set_health(current_health - amount)
	
	if current_health == 0 or hit_type == DamageReceiver.HitType.KNOCKDOWN:
		state = State.FALL
		height_speed = knockdown_intensity
		velocity = direction * knockback_intensity
		DamageManager.heavy_blow_received.emit()
		SoundPlayer.play(SoundManager.Sound.HIT1, true)
		if type == Type.PLAYER:
			combo_hurt_count = 0
			_notify_enemies_player_down()
	elif hit_type == DamageReceiver.HitType.LAUNCH:
		state = State.FALL 
		height_speed = launch_vertical_intensity     
		velocity = direction * launch_horizontal_intensity
		# Апперкот — строго вверх, без горизонтального смещения
		if attacker != null and attacker.state == State.UPPERCUT:
			velocity.x = 0
		HitstopManager.freeze(0.1, 0.1) 
		DamageManager.heavy_blow_received.emit()
		SoundPlayer.play(SoundManager.Sound.HIT3, true)
		if type == Type.PLAYER:
			combo_hurt_count = 0
			_notify_enemies_player_down()
	
	elif hit_type == DamageReceiver.HitType.POWER:
		state = State.FLY
		HitstopManager.freeze(0.3, 0.3)
		velocity = direction * flight_speed
		DamageManager.heavy_blow_received.emit()
		SoundPlayer.play(SoundManager.Sound.HIT1, true)
	else:
		state = State.HURT
		velocity = direction * knockback_intensity
		HitstopManager.freeze(0.05, 0.05)
		SoundPlayer.play(SoundManager.Sound.HIT2, true)


func apply_parry_stun(knockback: Vector2 = Vector2.ZERO) -> void:
	state = State.RECOVER
	# Тот же таймер, которым BasicEnemy выходит из RECOVER. Без этого
	# остаток от прошлого блока часто уже <= 0, и стан сбрасывается в том же кадре.
	enemy_block_timer = parry_stun_duration
	attack_combo_index = 0
	velocity = knockback


func _notify_enemies_player_down() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("on_player_knocked_down"):
			enemy.on_player_knocked_down()


## Функция обрабатывает момент нанесения удара текущим персонажем.
## Рассчитывает направление атаки, тип повреждения (обычный, подброс, тяжелый), 
## учитывает состояние жертвы (критический урон по оглушенным) и отправляет сигнал урона.
func on_emit_damage(receiver: DamageReceiver):
	# increase score
	var hit_type := DamageReceiver.HitType.NORMAL
	var direction := Vector2.LEFT if receiver.global_position.x < global_position.x else Vector2.RIGHT
	var current_damage = damage
	if state == State.JUMPKICK:
		hit_type = DamageReceiver.HitType.LAUNCH
	if attack_combo_index == anim_attacks.size() - 1:
		hit_type = DamageReceiver.HitType.LAUNCH
		current_damage = damage_power
	if state == State.SPRINT_ATTACK:
		hit_type = DamageReceiver.HitType.POWER
	if state == State.KICK:
		hit_type = DamageReceiver.HitType.LAUNCH
	if state == State.UPPERCUT:
		hit_type = DamageReceiver.HitType.LAUNCH
	if state == State.DASH_KICK:
		hit_type = DamageReceiver.HitType.LAUNCH
		direction = -heading  # Враги летят за спину игрока
	if state == State.RUNNING_GRAB:
		hit_type = DamageReceiver.HitType.LAUNCH
		direction = heading  # Враги отлетают по ходу движения
	if state == State.HEAVY_ATTACK:
		hit_type = DamageReceiver.HitType.POWER
	# === КРИТИЧЕСКИЙ УРОН ПО ОГЛУШЕННОМУ ВРАГУ ===
	# Получаем ссылку на персонажа-жертву через его компонент получения урона
	var victim = receiver.get_parent()
	if victim and victim.state == State.RECOVER:
		current_damage = int(current_damage * 2.0)
		hit_type = DamageReceiver.HitType.LAUNCH # Удваиваем урон! Коэффициент можно настроить (например, 1.5)
		
	# =============================================	
	receiver.damage_received.emit(current_damage, direction, hit_type, self)
	is_last_hit_successful = true


func on_emit_collateral_damage(receiver: DamageReceiver) -> void:
	if receiver != damage_receiver:
		var direction := Vector2.LEFT if receiver.global_position.x < global_position.x else Vector2.RIGHT
		receiver.damage_received.emit(0, direction, DamageReceiver.HitType.KNOCKDOWN)
		
		

func on_wall_hit(_wall: AnimatableBody2D) -> void:
	state = State.FALL
	height_speed = knockdown_intensity
	velocity = -velocity / 2.0
	SoundPlayer.play(SoundManager.Sound.COLLISION_HIT)


func set_health(health: int, is_emitting_signal: bool = true) -> void:
	current_health = clamp(health, 0, max_health)
	if is_emitting_signal:
		DamageManager.health_change.emit(type, current_health, max_health)
	

func play_hit_shake() -> void:
	pass


func handle_double_tap_dash():
	pass


func start_dash(_direction: Vector2):
	pass


func cutscene_state() -> void:
	pass
