class_name Character
extends CharacterBody2D

const GRAVITY := 3800.0

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
@export var max_block_health : float = 100.0
@export var block_regen_rate : float = 20.0
## Шанс (от 0.0 до 1.0), что враг решит заблокировать удар вместо получения урона
@export var block_chance : float = 0.4 
## Как долго враг будет удерживать блок (в секундах) после активации
@export var block_duration : float = 0.8 
## Окно времени (в секундах), в течение которого блок считается идеальным парированием.
@export var parry_window : float = 0.15

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
THROW, PICKUP, SHOOT, PREP_SHOOT, RECOVER, DROP, WAIT, APPEARING, SPRINT, DASH, SPRINT_ATTACK, CUTSCENE, BLOCK, KICK, HEAVY_ATTACK}
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
	State.HEAVY_ATTACK: "heavy_attack",
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


func _ready():
	damage_emitter.area_entered.connect(on_emit_damage.bind())
	damage_receiver.damage_received.connect(on_receive_damage.bind())
	collateral_damage_emitter.area_entered.connect(on_emit_collateral_damage.bind())
	collateral_damage_emitter.body_entered.connect(on_wall_hit.bind())
	set_health(max_health, type == Character.Type.PLAYER)
	set_sprite_height_position()
	block_health = max_block_health
	

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
	collision_shape.disabled = is_collision_disabled() 
	damage_emitter.monitoring = is_attacking()
	damage_receiver.monitorable = can_get_hurt()
	collateral_damage_emitter.monitoring = state == State.FLY


func handle_movement(delta: float): # Добавили delta в аргументы
# Если персонаж заблокирован физикой — не даем коду ниже занулять скорость
	if [State.HURT, State.FALL, State.FLY, State.BLOCK, State.RECOVER].has(state):
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
	if [State.JUMP, State.JUMPKICK, State.FALL, State.DROP].has(state):
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
## - постепенно уменьшает прозрачность объекта
## - удаляет персонажа со сцены после полного исчезновения
func handle_death(delta) -> void:
	if state == State.DEATH and not can_respawn:
		modulate.a -= delta / 2.0
		if modulate.a <= 0:
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
	if state == State.BLOCK:
		print("Текущая анимация: ", animation_player.current_animation, " | Играет: ", animation_player.is_playing())

		# 1. Специфичная логика для блока
	if state == State.BLOCK:
		# Если персонаж только что получил удар и играет анимация дёргания
		if animation_player.current_animation == "block_damage":
			return # Просто выходим и даем анимации block_damage доиграть до конца
			
		# Если анимация block_damage ЗАВЕРШИЛАСЬ, плавно возвращаем персонажа в обычную стойку
		if animation_player.assigned_animation == "block_damage" and not animation_player.is_playing():
			animation_player.play("block")
			animation_player.seek(0.3, true) # Сразу перематываем на финальный статичный кадр блока
			return
			
		# Если обычная анимация блока завершилась и замерла, удерживаем её на финальной позиции
		if animation_player.assigned_animation == "block" and not animation_player.is_playing():
			animation_player.seek(0.3, true)
		# Иначе, если играет что-то другое (например, вошли из IDLE), запускаем блок
		elif animation_player.current_animation != "block":
			animation_player.play("block")
		return


	# 2. Логика обычных атак
	if state == State.ATTACK:
		animation_player.play(anim_attacks[attack_combo_index])
	# 3. Все остальные стандартные анимации из словаря
	elif animation_player.has_animation(anim_map[state]):
		animation_player.play(anim_map[state])


	 


func set_heading() -> void:
	pass


func flip_sprites():
	if heading == Vector2.RIGHT:
		character_sprite.flip_h = false
		knife_sprite.scale.x = 1
		gun_sprite.scale.x = 1
		projectile_aim.scale.x = 1
		damage_emitter.scale.x = 1
	else:
		character_sprite.flip_h = true
		knife_sprite.scale.x = -1
		gun_sprite.scale.x = -1
		projectile_aim.scale.x = -1
		damage_emitter.scale.x = -1


func can_move() -> bool:
	return state == State.IDLE or state == State.WALK or state == State.SPRINT


func can_attack() -> bool:
	return state == State.IDLE or state == State.WALK


func can_jump() -> bool:
	return state == State.IDLE or state == State.WALK or state == State.SPRINT
	

func can_block() -> bool:
	# Блокировать можно из спокойных состояний, если щит не сломан
	var valid_states = [State.IDLE, State.WALK, State.SPRINT, State.PREP_ATTACK]
	return valid_states.has(state) and not block_broken



func can_get_hurt() -> bool:
	return [State.IDLE, State.WALK, State.TAKEOFF, State.LAND, State.PREP_ATTACK, State.BLOCK, State.RECOVER].has(state)


func can_dash() -> bool:
	return [State.IDLE, State.WALK, State.BLOCK].has(state)


func can_sprint_attack() -> bool:
	return state == State.DASH or state == State.SPRINT

func can_kick() -> bool:
	return state == State.IDLE or state == State.WALK

#func can_sprint_attack() -> bool:
	#return state == State.IDLE or state == State.WALK

### Если атакует, возвращаем список состояний боевых
func is_attacking() -> bool:
	return [State.ATTACK, State.JUMPKICK, State.SPRINT_ATTACK, State.KICK].has(state)


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
	return [State.GROUNDED, State.DEATH, State.FLY].has(state)


func can_jumpkick() -> bool:
	return state == State.JUMP 


func on_action_complete():
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

	print("knife spawned")

	
	
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
	
	# === ПРОВЕРКА НА УДАР В СПИНУ ===
	# direction.x указывает, куда летит удар: 1 (вправо) или -1 (влево)
	# heading.x указывает, куда смотрит персонаж: 1 (вправо) или -1 (влево)
	# Если знаки совпадают (например, удар летит вправо и персонаж смотрит вправо), значит это удар в спину!
	var is_hit_from_behind : bool = sign(direction.x) == sign(heading.x)
	# ===============================

	# === РЕАКЦИЯ ИИ ВРАГА ===
	# Добавляем условие "not is_hit_from_behind", чтобы враг не мог среагировать на удар со спины
	if type != Type.PLAYER and state != State.BLOCK and can_block() and not is_hit_from_behind:
		if randf() < block_chance:
			state = State.BLOCK
			enemy_block_timer = block_duration
			velocity = Vector2.ZERO

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
		if is_hit_from_behind:
			block_health = 0
			block_broken = true
			hit_type = DamageReceiver.HitType.KNOCKDOWN 
		else:
			# --- ПРОВЕРКА НА ИДЕАЛЬНЫЙ БЛОК (PARRY) ---
			# Переводим parry_window из секунд в миллисекунды (0.15 сек = 150 мс)
			var current_time := Time.get_ticks_msec()
			var is_parry : bool = (current_time - block_activated_time) <= (parry_window * 1000.0)
			
			if is_parry:
				# Успешное парирование!
				HitstopManager.freeze(0.25, 0.25) 
				EntityManager.spawn_spark.emit(position) 
				SoundPlayer.play(SoundManager.Sound.HIT3, true)
				
				# === ОТЛАДКА ПАРИРОВАНИЯ ===
				print("=== СРАБОТАЛО ПАРИРОВАНИЕ ===")
				print("Защищающийся: ", name, " | Состояние ДО: ", State.keys()[state])
				if attacker != null:
					print("Нападающий обнаружен: ", attacker.name, " | Его состояние ДО: ", State.keys()[attacker.state])
					
					# Принудительно меняем состояние нападающего
					attacker.state = State.RECOVER 
					attacker.enemy_block_timer = 1.5 
					attacker.velocity = -direction * (launch_horizontal_intensity * 0.3)
					attacker.attack_combo_index = 0
					
					print("Нападающему ЗАДАНО состояние: ", State.keys()[attacker.state])
					print("Нападающему задана скорость: ", attacker.velocity)
				else:
					print("ВНИМАНИЕ: Ссылка на attacker равна NULL!")
				print("=============================")
				# ===========================
				
				return 
			# ------------------------------------------

			# Обычный блок (если окно парирования уже закрылось)
			block_health -= amount
			if block_health > 0:
				SoundPlayer.play(SoundManager.Sound.HIT2, true)
				velocity = direction * (knockback_intensity * 0.3)
				animation_player.play("block_damage") 
				return
			else:
				block_health = 0
				block_broken = true
				hit_type = DamageReceiver.HitType.KNOCKDOWN
	# ===========================

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
		if type == Type.PLAYER: combo_hurt_count = 0
	elif hit_type == DamageReceiver.HitType.LAUNCH:
		state = State.FALL 
		height_speed = launch_vertical_intensity     
		velocity = direction * launch_horizontal_intensity 
		HitstopManager.freeze(0.1, 0.1) 
		DamageManager.heavy_blow_received.emit()
		SoundPlayer.play(SoundManager.Sound.HIT3, true)
		# if type == Type.PLAYER: combo_hurt_count = 0
		if type == Type.PLAYER:
			combo_hurt_count = 0
			
			# === РАЗГОНЯЕМ ТОЛПУ: ОСТАНОВКА ВСЕХ ВРАГОВ ===
			# Находим всех врагов на сцене (предполагается, что у них есть группа "enemies")
			var enemies = get_tree().get_nodes_in_group("enemy")
			for enemy in enemies:
				# Переводим каждого врага в режим ожидания на 3.8 секунды
				enemy.player_down_delay = 3.8
	
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
