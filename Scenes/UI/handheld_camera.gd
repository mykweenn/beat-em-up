extends Camera2D
## Имитация «съёмки с рук» (handheld camera) в стиле Kane & Lynch 2: Dog Days.
## Вешается на Camera2D в главном меню.
## Создаёт ощущение тяжёлой камеры: плавное покачивание + резкий тремор рук.

# === ШУМ ПЕРЛИНА ===
var _noise_sway: FastNoiseLite = FastNoiseLite.new()
var _noise_tremor: FastNoiseLite = FastNoiseLite.new()
var _noise_zoom: FastNoiseLite = FastNoiseLite.new()

var _time_sway := 0.0
var _time_tremor := 0.0
var _time_zoom := 0.0

var _current_offset := Vector2.ZERO
var _current_rotation := 0.0
var _current_zoom := Vector2.ONE

# Базовая позиция камеры из инспектора (чтобы не затирать её).
var _base_position := Vector2.ZERO

# === НАСТРОЙКИ (Inspector) ===

@export_group("Sway (Плавное покачивание)")
## Скорость покачивания камеры. Чем выше — тем быстрее «дышит» камера.
@export var shake_speed: float = 1.5
## Максимальное смещение по осям X и Y в пикселях.
## Например, Vector2(20, 12) — камера сильнее качается по горизонтали.
@export var shake_amplitude: Vector2 = Vector2(20.0, 12.0)
## Максимальный угол наклона камеры в градусах (завал горизонта).
@export var rotation_amplitude: float = 1.5

@export_group("Micro Tremor (Мелкое дрожание рук)")
## Интенсивность мелкого, резкого дрожания.
## Имитирует усталость рук оператора. 0 = выключено.
@export var micro_tremor_strength: float = 3.0
## Скорость дрожания (должна быть выше shake_speed для резкости).
@export var micro_tremor_speed: float = 8.0

@export_group("Direction (Направление)")
## Вектор-множитель направления тряски.
## Позволяет ограничить или направить покачивание.
## Например, Vector2(1.0, 0.3) — сильнее по горизонтали, слабее по вертикали.
## Vector2(0.0, 1.0) — только вертикальное покачивание.
@export var direction_mask: Vector2 = Vector2(1.0, 0.6)

@export_group("Impulse (Внешний импульс)")
## Сила резкого толчка камеры при вызове trigger_shake().
## Имитирует испуг оператора, удар, или резкое движение.
@export var impulse_strength: float = 8.0
## Длительность затухания импульса в секундах.
@export var impulse_decay: float = 0.8

@export_group("Zoom (Плавное дыхание камеры)")
## Минимальный зум (приближение). 1.0 = оригинальный размер.
## Значение < 1.0 = камера ближе, > 1.0 = камера дальше.
@export var zoom_min: float = 0.95
## Максимальный зум (отдаление).
@export var zoom_max: float = 1.05
## Скорость «дыхания» — как быстро зум меняется.
@export var zoom_speed: float = 0.8
## Сила рывков зума (микро-тремор зума, параллельно с дрожанием позиции).
@export var zoom_tremor: float = 0.02

@export_group("Defocus (Случайный расфокус)")
## Шанс расфокуса каждый кадр (0.0–1.0). Например, 0.002 = ~0.2% шанс в кадр.
@export var defocus_chance: float = 0.003
## Минимальная длительность расфокуса в секундах.
@export var defocus_duration_min: float = 0.3
## Максимальная длительность расфокуса в секундах.
@export var defocus_duration_max: float = 1.2
## Сила расфокуса (передаётся в шейдер как defocus: 0.0–1.0).
@export var defocus_strength: float = 0.7
## Ссылка на материал шейдера found_footage_rect (чтобы менять параметр defocus).
@export var shader_material: ShaderMaterial

# Внутренний вектор импульса (накапливается при trigger_shake(), затухает со временем).
var _impulse := Vector2.ZERO
var _impulse_timer := 0.0

# Состояние расфокуса.
var _defocus_timer := 0.0
var _defocus_duration := 0.0
var _defocus_current := 0.0


func _ready() -> void:
	# Сохраняем позицию камеры из инспектора.
	# Всё смещение будет прибавляться к ней, а не затирать её.
	_base_position = position

	# Инициализация шумовых генераторов.
	_noise_sway.seed = randi()
	_noise_sway.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_sway.frequency = 0.05

	_noise_tremor.seed = randi()
	_noise_tremor.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_tremor.frequency = 0.15

	_noise_zoom.seed = randi()
	_noise_zoom.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_zoom.frequency = 0.03  # Очень низкая — зум «дышит» медленно

	# Запоминаем стартовый зум из инспектора.
	_current_zoom = zoom


func _process(delta: float) -> void:
	# Увеличиваем временные счётчики (скорость зависит от настроек).
	_time_sway += delta * shake_speed
	_time_tremor += delta * micro_tremor_speed
	_time_zoom += delta * zoom_speed

	# === 1. ПЛАВНОЕ ПОКАЧИВАНИЕ (Sway) ===
	# Два шумовых значения (X и Y) с разным смещением = несогласованное движение.
	# Значения шума от -1 до 1, умножаем на amplitude и direction_mask.
	var sway_x := _noise_sway.get_noise_1d(_time_sway) * shake_amplitude.x * direction_mask.x
	var sway_y := _noise_sway.get_noise_1d(_time_sway + 100.0) * shake_amplitude.y * direction_mask.y
	var sway_target := Vector2(sway_x, sway_y)

	# Угол наклона — третья ось шума (тоже плавная).
	var rot_target := _noise_sway.get_noise_1d(_time_sway + 200.0) * rotation_amplitude

	# === 1b. ЗУМ (Дыхание камеры) ===
	# Плавное изменение зума через отдельный шум.
	# Интерполируем между zoom_min и zoom_max на основе шума [-1..1].
	var zoom_noise := _noise_zoom.get_noise_1d(_time_zoom)
	var zoom_base := lerpf(zoom_min, zoom_max, (zoom_noise + 1.0) * 0.5)
	# Микро-тремор зума — добавляем лёгкое дрожание масштаба.
	var zoom_tremor_val := _noise_tremor.get_noise_1d(_time_tremor * 0.5) * zoom_tremor if zoom_tremor > 0.0 else 0.0
	var zoom_target := Vector2.ONE * clampf(zoom_base + zoom_tremor_val, zoom_min, zoom_max)

	# === 1c. ДЕФОКУС (Случайный расфокус камеры) ===
	# Случайное событие: с малой вероятностью камера «теряет фокус».
	if _defocus_timer > 0.0:
		_defocus_timer -= delta
		var progress := 1.0 - (_defocus_timer / _defocus_duration)
		# Нарастание быстрее затухания (30% нарастание, 70% затухание).
		if progress < 0.3:
			_defocus_current = lerpf(0.0, defocus_strength, progress / 0.3)
		else:
			_defocus_current = lerpf(defocus_strength, 0.0, (progress - 0.3) / 0.7)
	else:
		_defocus_current = 0.0
		if defocus_chance > 0.0 and randf() < defocus_chance:
			_defocus_duration = randf_range(defocus_duration_min, defocus_duration_max)
			_defocus_timer = _defocus_duration

	# Передаём значение в шейдер.
	if shader_material:
		shader_material.set_shader_parameter("defocus", _defocus_current)

	# === 2. МИКРОТРЕМОР (Micro Tremor) ===
	# Мелкое, быстрое дрожание поверх основного покачивания.
	# Использует тот же шейдер, но с другой скоростью и частотой.
	if micro_tremor_strength > 0.0:
		var tremor_x := _noise_tremor.get_noise_1d(_time_tremor) * micro_tremor_strength * direction_mask.x
		var tremor_y := _noise_tremor.get_noise_1d(_time_tremor + 50.0) * micro_tremor_strength * direction_mask.y
		sway_target += Vector2(tremor_x, tremor_y)

	# === 3. ИМПУЛЬС (Внешний толчок) ===
	# Затухающий вектор: добавляется при trigger_shake(), уменьшается со временем.
	if _impulse_timer > 0.0:
		_impulse_timer -= delta
		# Линейное затухание от 1.0 до 0.0
		var t := clampf(_impulse_timer / impulse_decay, 0.0, 1.0)
		sway_target += _impulse * t

	# === 4. СГЛАЖИВАНИЕ (Lerp) ===
	# Переход от текущего положения к целевому — создаёт эффект инерции камеры.
	# Чем меньше коэффициент — тем массивнее и «тяжелее» камера.
	var smooth_factor := 5.0 * delta
	_current_offset = _current_offset.lerp(sway_target, smooth_factor)
	_current_rotation = lerp(_current_rotation, rot_target, smooth_factor)
	_current_zoom = _current_zoom.lerp(zoom_target, smooth_factor)

	# === 5. ПРИМЕНЕНИЕ ===
	# Смещение прибавляется к базовой позиции из инспектора.
	position = _base_position + _current_offset
	rotation = deg_to_rad(_current_rotation)
	zoom = _current_zoom


## Вызвать извне для резкого толчка камеры.
## Например, при нажатии кнопки меню или при событии в кат-сцене.
## Пример: $Camera2D.trigger_shake()
func trigger_shake() -> void:
	# Случайное направление толчка (полный круг 360°).
	var angle := randf() * TAU
	_impulse = Vector2(cos(angle), sin(angle)) * impulse_strength
	_impulse_timer = impulse_decay


## Сбросить смещение камеры в базовую позицию из инспектора.
## Вызывать при смене состояний, например при открытии подменю.
func reset_to_center() -> void:
	_current_offset = Vector2.ZERO
	_current_rotation = 0.0
	_current_zoom = zoom
	_defocus_timer = 0.0
	_defocus_duration = 0.0
	_defocus_current = 0.0
	if shader_material:
		shader_material.set_shader_parameter("defocus", 0.0)
