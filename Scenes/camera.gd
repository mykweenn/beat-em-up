class_name Camera
extends Camera2D

@export var duration_shake : int
@export var shake_intensity : int

var is_shaking := false
var time_start_shacking := Time.get_ticks_msec()

# === НОВАЯ ПЕРЕМЕННАЯ ДЛЯ ЗАРЯДКИ ===
var is_charging_shake := false
# ====================================

func _init() -> void:
	DamageManager.heavy_blow_received.connect(on_heavy_blow_received.bind())

func on_heavy_blow_received() -> void:
	if OptionsManager.is_screenshake_enabled:
		is_shaking = true
		time_start_shacking = Time.get_ticks_msec()

# === НОВЫЙ МЕТОД ДЛЯ УПРАВЛЕНИЯ ТРЯСКОЙ ЗАРЯДКИ ===
func set_charging_shake(active: bool) -> void:
	if OptionsManager.is_screenshake_enabled:
		is_charging_shake = active
		if not active:
			offset = Vector2.ZERO
# ==================================================

func _process(_delta: float) -> void:
	# 1. Если идет зарядка удара, генерируем мелкую глитч-тряску
	if is_charging_shake:
		offset = Vector2(randi_range(-3, 3), randi_range(-3, 3)) # Интенсивность можно настроить
	# 2. Иначе проверяем обычную тряску от тяжелых ударов
	elif is_shaking and (Time.get_ticks_msec() - time_start_shacking < duration_shake):
		offset = Vector2(randi_range(-shake_intensity, shake_intensity), randi_range(-shake_intensity, shake_intensity))
	# 3. Если ничего не происходит — сбрасываем в ноль
	else:
		offset = Vector2.ZERO
		is_shaking = false
