shader_type canvas_item;

// ============================================================
// FOUND-FOOTAGE / ЦИФРОВАЯ КАМЕРА (стиль Kane & Lynch 2)
// ============================================================
// Шейдер пост-обработки. Накладывается на ColorRect,
// растянутый на весь экран поверх CanvasLayer.
// Использует SCREEN_TEXTURE для чтения кадра целиком.
// ============================================================

// Сэмплер экрана (обязательно для screen-шейдеров)
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

// --- 1. ПИКСЕЛИЗАЦИЯ ---
// Размер «виртуального пикселя». Чем больше значение — тем грубее картинка.
// 1.0 = без пикселизации, 4.0 = крупные блоки, 8.0 = Very Good Bytes
uniform float pixel_size : hint_range(1.0, 16.0, 0.5) = 3.0;

// --- 2. ПЕРЕСВЕТ / ПРОСВЕТ ЯРКИХ ЗОН ---
// Множитель яркости. Высокие значения «выжигают» светлые участки.
uniform float exposure : hint_range(0.5, 4.0, 0.05) = 1.6;
// Порог, выше которого цвета начинают клиппиться в белый (bloom/clipping).
uniform float clip_threshold : hint_range(0.5, 1.2, 0.05) = 0.85;
// Сила «кровотечения» — растушевка клиппинга (0 = резкий обрез, 1 = мягкий bloom).
uniform float bloom_softness : hint_range(0.0, 0.3, 0.01) = 0.08;

// --- 3. ЦИФРОВОЙ ШУМ / ЗЕРНО ---
// Интенсивность шума (0 = выкл, 1 = максимум грязи).
uniform float noise_strength : hint_range(0.0, 0.5, 0.01) = 0.12;
// Скорость мерцания шума (кадры в секунду имитации ISO).
uniform float noise_speed : hint_range(1.0, 30.0, 1.0) = 12.0;

// --- 4. ЦВЕТОКОРРЕКЦИЯ ---
// Общий тон заливки: грязный зеленовато-желтый или синюшный.
// Значения по умолчанию — удушающий зеленовато-желтый (Kane & Lynch).
uniform vec3 tint_color = vec3(0.78, 0.82, 0.62);
// Сила наложения цветового оттенка (0 = оригинальные цвета, 1 = полный тон).
uniform float tint_strength : hint_range(0.0, 1.0, 0.05) = 0.35;
// Насыщенность (0 = ч/б, 1 = оригинал, >1 = перенасыщение).
uniform float saturation : hint_range(0.0, 2.0, 0.05) = 0.7;
// Контраст.
uniform float contrast : hint_range(0.5, 2.0, 0.05) = 1.15;

// --- 5. ГЛИТЧИ СЖАТИЯ / МАКРОБЛОКИНГ ---
// Интенсивность горизонтальных полос сбоя (pixel-tear).
uniform float glitch_strength : hint_range(0.0, 1.0, 0.05) = 0.15;
// Хроматическая аберрация (RGB split) по горизонтали.
uniform float chroma_aberration : hint_range(0.0, 8.0, 0.5) = 2.0;
// Виньетирование по краям (имитация дешёвой линзы).
uniform float vignette : hint_range(0.0, 1.0, 0.05) = 0.3;

// ============================================================
// ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ============================================================

// Быстрый хеш для генерации псевдослучайного числа из UV + времени.
// Используется для шума и глитчей.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Виньетирование: затемнение по краям кадра (имитация barrel distortion дешёвой линзы).
float vignette_mask(vec2 uv) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	return smoothstep(0.7, 0.3, dist * (1.0 + vignette));
}

// ============================================================
// ОСНОВНОЙ FRAGMENT
// ============================================================
void fragment() {

	// --- А. ПИКСЕЛИЗАЦИЯ ---
	// Разбиваем UV на сетку размером pixel_size и берём значение
	// из центра каждого «блока» — классический low-res эффект.
	vec2 pix_uv = floor(SCREEN_UV * SCREEN_PIXEL_SIZE / pixel_size) * pixel_size / SCREEN_PIXEL_SIZE;

	// --- Б. ХРОМАТИЧЕСКАЯ АБЕРРАЦИЯ (до пикселизации для точности) ---
	// Сдвигаем R и B каналы в разные стороны по горизонтали.
	// Это имитирует дефект дешёвого объектива / цифровой сенсор.
	float ca = chroma_aberration / SCREEN_PIXEL_SIZE.x;
	vec2 uv_r = pix_uv + vec2(ca, 0.0);
	vec2 uv_b = pix_uv - vec2(ca, 0.0);

	// Читаем три канала независимо
	float r = texture(SCREEN_TEXTURE, uv_r).r;
	float g = texture(SCREEN_TEXTURE, pix_uv).g;
	float b = texture(SCREEN_TEXTURE, uv_b).b;
	vec3 col = vec3(r, g, b);

	// --- В. ПЕРЕСВЕТ / ПРОСВЕТ ЯРКИХ ЗОН ---
	// Умножаем на exposure, затем жёстко клиппим яркие зоны.
	// Яркие участки (лампы, окна) «выгорают» в белый,
	// имитируя перегруженный цифровой сенсор.
	col *= exposure;

	// Плавный клиппинг: всё что выше clip_threshold — приближается к белому.
	// bloom_softness регулирует растушевку (буквально «кровоточит» в белое).
	float luminance = dot(col, vec3(0.299, 0.587, 0.114));
	float clip_factor = smoothstep(clip_threshold, clip_threshold + bloom_softness, luminance);
	col = mix(col, vec3(1.0), clip_factor * 0.85);

	// --- Г. ЦИФРОВОЙ ШУМ / ЗЕРНО ---
	// Имитация артефактов высокой светочувствительности ISO.
	// Шум «гуляет» по экрану thanks TIME и噪声.
	if (noise_strength > 0.0) {
		// Генерируем шум для текущего пикселя с учётом времени
		vec2 noise_uv = pix_uv * SCREEN_PIXEL_SIZE * 0.5;
		float grain = hash(noise_uv + fract(TIME * noise_speed)) * 2.0 - 1.0;
		// Добавляем шум (отрицательный + положительный = середина = 0)
		col += grain * noise_strength;
	}

	// --- Д. ГЛИТЧИ СЖАТИЯ / МАКРОБЛОКИНГ ---
	// Горизонтальные полосы пиксельного сбоя (pixel-tear).
	// Имитирует артефакты MPEG-сжатия при плохом сигнале.
	if (glitch_strength > 0.0) {
		// Генерируем «полосу» — случайная Y-координита, которая дёргается
		float glitch_y = hash(vec2(floor(TIME * 7.0), 0.0));
		float glitch_band = smoothstep(0.0, 0.02, abs(SCREEN_UV.y - glitch_y));
		// Смещаем UV горизонтально внутри полосы
		float glitch_offset = (hash(vec2(floor(TIME * 11.0), glitch_y)) - 0.5) * glitch_strength * 0.05;
		if (glitch_band < 1.0) {
			vec2 glitch_uv = SCREEN_UV + vec2(glitch_offset, 0.0);
			col = texture(SCREEN_TEXTURE, glitch_uv).rgb * exposure;
			// Повторяем клиппинг для глитч-зоны
			float gl = dot(col, vec3(0.299, 0.587, 0.114));
			col = mix(col, vec3(1.0), smoothstep(clip_threshold, clip_threshold + bloom_softness, gl) * 0.85);
		}

		// Второй слой: тонкие горизонтальные линии (micro-blocking)
		float micro_block = hash(vec2(floor(SCREEN_UV.y * 200.0), floor(TIME * 15.0)));
		if (micro_block > (1.0 - glitch_strength * 0.15)) {
			col *= 0.7;
		}
	}

	// --- Е. ЦВЕТОКОРРЕКЦИЯ ---
	// 1. Снижение насыщенности (грязные, невзрачные цвета).
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(grey), col, saturation);

	// 2. Контраст.
	float midpoint = 0.5;
	col = (col - midpoint) * contrast + midpoint;

	// 3. Цветовой тон (tint).
	// Смешиваем с tintColor — получается удушающий зеленовато-желтый оттенок.
	col = mix(col, col * tint_color, tint_strength);

	// --- Ж. ВИНЬЕТИРОВАНИЕ ---
	// Затемнение по краям кадра (дешёвая линза + дешёвый сенсор).
	col *= vignette_mask(SCREEN_UV);

	// --- И. ФИНАЛЬНЫЙ КЛИП ---
	// Гарантируем, что цвета не выйдут за пределы [0, 1].
	col = clamp(col, vec3(0.0), vec3(1.0));

	COLOR = vec4(col, 1.0);
}
