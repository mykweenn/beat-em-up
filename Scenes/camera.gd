class_name Camera
extends Camera2D

@export var duration_shake : int
@export var shake_intensity : int

@export_group("Handheld Shake (Спринт)")
## Мастер-множитель силы тряски при спринте (съёмка с рук / бегущий оператор).
@export var handheld_intensity := 1.0
## Амплитуда случайной дрожи по X (пиксели при intensity=1).
@export var handheld_jitter_x := 0.8
## Амплитуда случайной дрожи по Y (пиксели при intensity=1).
@export var handheld_jitter_y := 1.2
## Амплитуда покачивания (sin) по X при беге (пиксели).
@export var handheld_bob_amp_x := 1.3
## Амплитуда покачивания (sin) по Y при беге (пиксели).
@export var handheld_bob_amp_y := 1.8
## Частота покачивания по X (рад/сек).
@export var handheld_bob_freq_x := 24.0
## Частота покачивания по Y (рад/сек).
@export var handheld_bob_freq_y := 11.0
## Амплитуда лёгкого наклона камеры при беге (радианы).
@export var handheld_rotation_amp := 0.008
## Частота наклона камеры при беге (рад/сек).
@export var handheld_rotation_freq := 13.0

@export_group("Finisher Burst (Замах)")
## Интенсивность тряски-вспышки в начале добивания (замах).
@export var burst_windup_intensity := 3.0
## Длительность тряски-вспышки в начале добивания (сек).
@export var burst_windup_duration := 0.12
@export_group("Finisher Burst (Удар)")
## Интенсивность тряски-вспышки в момент удара добивания.
@export var burst_impact_intensity := 6.0
## Длительность тряски-вспышки в момент удара добивания (сек).
@export var burst_impact_duration := 0.2
## Амплитуда наклона камеры во время тряски-вспышки (радианы).
@export var burst_rotation_amp := 0.008

@export_group("Player Hurt (Урон игроку)")
## Интенсивность тряски при получении урона игроком.
@export var hurt_shake_intensity := 4.0
## Длительность тряски при получении урона игроком (сек).
@export var hurt_shake_duration := 0.15

@export_group("Finisher Zoom (Добивание)")
## Во сколько раз камера приближается к игроку во время добивания/посадки.
@export var finisher_zoom_scale := 1.22
## Время наезда (и отъезда) камеры при добивании (сек).
@export var finisher_zoom_time := 0.25

@export_group("Finisher Focus (Фокус)")
## Вертикальное кадрирование при добивании: расстояние от линии земли
## персонажей (player.position.y) до центра камеры.
## Больше значение — персонажи выше в кадре, меньше — ниже.
@export var finisher_focus_y_offset := 220.0

var is_shaking := false
var time_start_shacking := Time.get_ticks_msec()

# === ЗАРЯДКА УДАРА ===
var is_charging_shake := false

# === РУЧНАЯ ТРЯСКА КАМЕРЫ (handheld / съёмка с рук) ===
var is_handheld_shake := false

# === ТРЯСКА-ВСПЫШКА (добивание и т.п.) ===
var burst_shake_intensity := 0.0
var burst_shake_duration := 0.0
var burst_shake_start := 0

# === ЗУМ ПРИ ДОБИВАНИИ ===
var _finisher_zoom_active := false
var _finisher_zoom_tween : Tween = null

func _init() -> void:
	DamageManager.heavy_blow_received.connect(on_heavy_blow_received.bind())

func on_heavy_blow_received() -> void:
	if OptionsManager.is_screenshake_enabled:
		is_shaking = true
		time_start_shacking = Time.get_ticks_msec()

## Управление тряской при зарядке удара (глитч-тряска).
func set_charging_shake(active: bool) -> void:
	if OptionsManager.is_screenshake_enabled:
		is_charging_shake = active
		if not active:
			offset = Vector2.ZERO

## Включает/выключает непрерывную «ручную» тряску камеры (имитация съёмки с рук).
## Параметры силы/частот настраиваются в инспекторе (группа Handheld Shake).
func set_handheld_shake(active: bool) -> void:
	if not OptionsManager.is_screenshake_enabled:
		active = false
	is_handheld_shake = active
	# Сбрасываем камеру, если не идёт более сильная тряска
	if not active and burst_shake_intensity <= 0.0 and not is_shaking and not is_charging_shake:
		offset = Vector2.ZERO
		rotation = 0.0

## Тряска-вспышка в начале добивания (замах). Параметры из инспектора.
func trigger_finisher_windup_shake() -> void:
	trigger_burst_shake(burst_windup_intensity, burst_windup_duration)

## Тряска-вспышка в момент удара добивания. Параметры из инспектора.
func trigger_finisher_impact_shake() -> void:
	trigger_burst_shake(burst_impact_intensity, burst_impact_duration)

## Тряска при получении урона игроком. Параметры из инспектора.
func trigger_damage_shake() -> void:
	trigger_burst_shake(hurt_shake_intensity, hurt_shake_duration)

## Одноразовая тряска-вспышка с затуханием (приоритет выше остальных трясок).
func trigger_burst_shake(intensity: float, duration: float) -> void:
	if not OptionsManager.is_screenshake_enabled:
		return
	burst_shake_intensity = intensity
	burst_shake_duration = duration
	burst_shake_start = Time.get_ticks_msec()

## Зум-наезд на игрока во время добивания/посадки и отъезд обратно.
func set_finisher_zoom(active: bool) -> void:
	if _finisher_zoom_active == active:
		return
	_finisher_zoom_active = active
	if _finisher_zoom_tween != null and _finisher_zoom_tween.is_valid():
		_finisher_zoom_tween.kill()
	var target := Vector2(finisher_zoom_scale, finisher_zoom_scale) if active else Vector2.ONE
	_finisher_zoom_tween = create_tween()
	_finisher_zoom_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_finisher_zoom_tween.tween_property(self, "zoom", target, finisher_zoom_time)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()

	# 1. Тряска-вспышка (добивание и т.п.) — самый высокий приоритет, затухает
	if burst_shake_intensity > 0.0:
		var elapsed_ms := float(now - burst_shake_start)
		var t := elapsed_ms / (burst_shake_duration * 1000.0)
		if t >= 1.0:
			burst_shake_intensity = 0.0
		else:
			var strength := lerpf(burst_shake_intensity, 0.0, t)
			offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
			rotation = randf_range(-burst_rotation_amp, burst_rotation_amp) * (1.0 - t)
			return

	# 2. Зарядка удара — мелкая глитч-тряска
	if is_charging_shake:
		offset = Vector2(randi_range(-3, 3), randi_range(-3, 3))
		return
	# 3. Обычная тряска от тяжелых ударов
	if is_shaking and (now - time_start_shacking < duration_shake):
		offset = Vector2(randi_range(-shake_intensity, shake_intensity), randi_range(-shake_intensity, shake_intensity))
		return
	# 4. Ручная тряска (спринт / съёмка с рук)
	if is_handheld_shake:
		var time_s := now * 0.001
		var jitter := Vector2(
			randf_range(-handheld_jitter_x, handheld_jitter_x),
			randf_range(-handheld_jitter_y, handheld_jitter_y)
		)
		var bob := Vector2(
			sin(time_s * handheld_bob_freq_x) * handheld_bob_amp_x,
			abs(sin(time_s * handheld_bob_freq_y)) * handheld_bob_amp_y
		)
		offset = (jitter + bob) * handheld_intensity
		rotation = sin(time_s * handheld_rotation_freq) * handheld_rotation_amp * handheld_intensity
		return
	# 5. Ничего не происходит — сбрасываем
	offset = Vector2.ZERO
	rotation = 0.0
	is_shaking = false