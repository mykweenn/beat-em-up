shader_type canvas_item;

// Лёгкая «тряска»/дрожание надписей в духе VHS-кассет.
// Применяется на Label в главном меню; смещает пиксели текста через UV,
// не трогая саму раскладку (иначе VBoxContainer перезаписал бы position).

// Сила общей тряски (умножается на размер пикселя).
uniform float jitter_strength : hint_range(0.0, 3.0) = 0.3;
// Скорость общей тряски.
uniform float jitter_speed : hint_range(0.0, 60.0) = 24.0;
// Сила горизонтальной «ряби» tracking (смещение строк).
uniform float tracking_strength : hint_range(0.0, 6.0) = 1.4;
// Скорость смены «полос» tracking.
uniform float tracking_speed : hint_range(0.0, 30.0) = 5.0;
// Толщина полос tracking (сколько полос по высоте текста).
uniform float tracking_bands : hint_range(2.0, 30.0) = 10.0;
// Общий множитель времени (замедление/ускорение эффекта).
uniform float time_scale : hint_range(0.0, 4.0) = 1.0;

float hash21(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	float t = TIME * time_scale;
	vec2 uv = UV;

	// Общее дрожание текста (мелкая, быстрая тряска).
	vec2 jitter = vec2(
		hash21(floor(t * jitter_speed)) - 0.5,
		hash21(floor(t * jitter_speed * 1.37) + 7.0) - 0.5
	) * jitter_strength * vec2(TEXTURE_PIXEL_SIZE.x, TEXTURE_PIXEL_SIZE.y);

	// Рябь tracking: целые горизонтальные полосы периодически смещаются
	// (классические «полосы» на кассетной записи).
	float band = floor(uv.y * tracking_bands);
	// Активность полосы плавно мерцает со временем.
	float active = step(0.45, 0.5 + 0.5 * sin(band * 2.1 + t * tracking_speed));
	// Смещение активных полос прыгает при каждом шаге времени.
	float shift = (hash21(band + floor(t * tracking_speed) * 1.7) - 0.5)
		* tracking_strength * TEXTURE_PIXEL_SIZE.y * active;

	uv.x += jitter.x;
	uv.y += jitter.y + shift;

	// Сохраняем modulate (мерцание активной кнопки и font_color).
	COLOR = texture(TEXTURE, uv) * COLOR;
}
