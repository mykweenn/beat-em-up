class_name LeaperEnemy
extends BasicEnemy

@export_category("Leap attack")
## Дистанция (по X), на которой враг останавливается и начинает готовиться к прыжку.
@export var leap_attack_range := 400.0
## Если игрок подошёл ближе этого расстояния — враг отходит назад,
## чтобы прыжок получался осмысленным (игрок не в упор).
@export var leap_min_range := 170.0
## Задержка (сек) «прицеливания»/стойки перед прыжком после выхода на дистанцию.
@export var leap_prep_delay := 0.6
## Максимальная горизонтальная скорость прыжка на игрока (наводится на игрока,
## но не быстрее этого значения).
@export var leap_velocity := 650.0
## Кулдаун между прыжками после приземления (сек).
@export var leap_cooldown := 1.3

var _leap_prep_elapsed := -1.0
var _next_leap_time_ms := 0
var _leap_direction := 1.0
var _leap_hspeed := 0.0
## Резервный таймер взлёта: подстраховка, если кастомная анимация takeoff
## не вызывает on_takeoff_complete (тогда взлетаем сами по таймеру).
var _takeoff_timer := 0.0
const TAKEOFF_BUFFER := 0.12


func _ready() -> void:
	super._ready()
	_ensure_air_animations()
	# Стандартный anim_map уже ведёт TAKEOFF/JUMP/JUMPKICK на эти анимации.


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Фолбэк взлёта на случай, если у takeoff нет method-трека on_takeoff_complete
	if state == State.TAKEOFF:
		_takeoff_timer -= delta
		if _takeoff_timer <= 0.0:
			_launch_after_takeoff()


## Прыгает на игрока при достижении дистанции: сначала пауза (задержка),
## затем взлёт по дуге (State.TAKEOFF -> State.JUMPKICK с горизонтальной скоростью).
func handle_input() -> void:
	if player == null or not can_move():
		return

	# Пока игрок лежит — ведём себя как обычный враг (обходим, не прыгаем)
	if _should_give_player_space():
		_leap_prep_elapsed = -1.0
		_hold_back_from_player()
		return

	var dx := player.global_position.x - global_position.x
	var adx := absf(dx)

	# Игрок слишком близко — отходим назад (и во время кулдауна тоже),
	# чтобы прыжок не был «в лоб» и нас не прижимали к стене в упор.
	if adx < leap_min_range:
		_leap_prep_elapsed = -1.0
		_release_player_slot()
		velocity = Vector2(-signf(dx) * speed, 0.0)
		return

	# Вне зоны прыжка — спокойно подходим
	if adx > leap_attack_range and _leap_prep_elapsed < 0.0:
		velocity = Vector2(signf(dx) * speed, 0.0)
		return

	# Кулдаун после прошлого прыжка — стоим на месте
	if Time.get_ticks_msec() < _next_leap_time_ms:
		velocity = Vector2.ZERO
		if _leap_prep_elapsed >= 0.0:
			_leap_prep_elapsed = -1.0
		return

	# Задержка перед прыжком
	if _leap_prep_elapsed < 0.0:
		_leap_prep_elapsed = 0.0
		_leap_direction = 1.0 if dx > 0.0 else -1.0
	if _leap_prep_elapsed < leap_prep_delay:
		_leap_prep_elapsed += get_physics_process_delta_time()
		velocity = Vector2.ZERO # стоим «на прицеле»
		return

	# Задержка прошла — выпрыгиваем
	_leap_prep_elapsed = -1.0
	_start_leap()


## Запускает прыжок: взводит анимацию взлёта (takeoff) и задаёт горизонтальную скорость.
func _start_leap() -> void:
	_next_leap_time_ms = Time.get_ticks_msec() + int(leap_cooldown * 1000.0)
	var dx := player.global_position.x - global_position.x
	_leap_direction = 1.0 if dx > 0.0 else -1.0
	# Время полёта вверх+вниз при jump_intesnity и GRAVITY
	var flight_time := 2.0 * jump_intesnity / GRAVITY
	if flight_time <= 0.0:
		flight_time = 0.7
	# Наводимся на игрока: vx = расстояние / время полёта (не быстрее leap_velocity)
	_leap_hspeed = clampf(absf(dx) / flight_time, 0.0, leap_velocity)
	state = State.TAKEOFF
	_takeoff_timer = TAKEOFF_BUFFER


## Вызывается анимацией takeoff (если в ней есть method-трек) — взлетаем и
## включаем урон в воздухе (JUMPKICK).
func on_takeoff_complete() -> void:
	_launch_after_takeoff()


## Сам взлёт: защита от двойного вызова (method-трек + резервный таймер).
func _launch_after_takeoff() -> void:
	if state != State.TAKEOFF:
		return
	super.on_takeoff_complete() # state = JUMP, height_speed = jump_intesnity
	if _leap_hspeed > 0.0:
		velocity.x = _leap_direction * _leap_hspeed
	state = State.JUMPKICK


## Добавляет в библиотеку анимаций enemy недостающие takeoff/jump/jumpkick.
## Кадры берём из общей плитки "Player 96X96 test.png" (как у игрока):
## takeoff = 90, jump = 71, jumpkick = 46.
func _ensure_air_animations() -> void:
	var library: AnimationLibrary = animation_player.get_animation_library("")
	if library == null:
		return

	if not animation_player.has_animation("jump"):
		library.add_animation("jump", _make_frame_animation(71, true))
	if not animation_player.has_animation("jumpkick"):
		library.add_animation("jumpkick", _make_frame_animation(46, true))

	# takeoff дополнительно вызывает on_takeoff_complete в конце, чтобы враг взлетел
	if not animation_player.has_animation("takeoff"):
		var takeoff_anim := _make_frame_animation(90, false)
		var method_track := takeoff_anim.add_track(Animation.TYPE_METHOD)
		takeoff_anim.track_set_path(method_track, NodePath("."))
		takeoff_anim.track_insert_key(method_track, takeoff_anim.length, {"args": [], "method": &"on_takeoff_complete"})
		library.add_animation("takeoff", takeoff_anim)


func _make_frame_animation(frame: int, loop: bool) -> Animation:
	var anim := Animation.new()
	anim.length = 0.1
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var frame_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frame_track, NodePath("CharacterSprite:frame"))
	anim.track_insert_key(frame_track, 0.0, frame)
	return anim
