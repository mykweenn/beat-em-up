shader_type canvas_item;

// Считываем экранную текстуру
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Параметры искажения
uniform float distortion_intensity : hint_range(-0.5, 0.5) = 0.05; // Сила "бочки"
uniform float aberration_intensity : hint_range(0.0, 0.1) = 0.01;   // Сила сдвига RGB

// Функция для искажения UV координат (эффект "бочки")
vec2 dist_uv(vec2 uv, float dist) {
    vec2 c = uv - 0.5; // Сдвиг центра в (0,0)
    float r2 = dot(c, c); // Квадрат расстояния до центра
    // Чем дальше от центра, тем сильнее искажение
    c *= 1.0 + r2 * dist; 
    return c + 0.5; // Сдвиг центра обратно
}

void fragment() {
    // Получаем базовые UV координаты экрана
    vec2 uv = SCREEN_UV;
    
    // 1. Применяем искажение линзы (бочка)
    vec2 dist_uv_coord = dist_uv(uv, distortion_intensity);
    
    // 2. Добавляем хроматическую аберрацию
    // Сдвигаем UV для красного и синего каналов
    // Сдвиг зависит от удаленности от центра
    vec2 center_dir = normalize(uv - 0.5);
    float dist_from_center = length(uv - 0.5);
    
    vec2 r_uv = dist_uv(uv + center_dir * aberration_intensity * dist_from_center, distortion_intensity);
    vec2 g_uv = dist_uv_coord;
    vec2 b_uv = dist_uv(uv - center_dir * aberration_intensity * dist_from_center, distortion_intensity);

    // Сэмплируем цвета
    float r = texture(screen_texture, r_uv).r;
    float g = texture(screen_texture, g_uv).g;
    float b = texture(screen_texture, b_uv).b;
    
    // Записываем финальный цвет
    COLOR = vec4(r, g, b, 1.0);
}