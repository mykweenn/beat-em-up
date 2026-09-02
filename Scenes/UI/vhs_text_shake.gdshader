shader_type canvas_item;

// Настройки дрожания (Jitter)
uniform float shake_speed : hint_range(0.0, 100.0) = 30.0;
uniform float shake_intensity : hint_range(0.0, 0.1) = 0.003;
uniform float shake_block_size : hint_range(1.0, 100.0) = 20.0;

// Настройки расслоения цвета (Chromatic Aberration)
uniform float color_split : hint_range(0.0, 0.05) = 0.005;

// Функция для генерации псевдослучайного шума
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    
    // Создаем ступенчатый огрубленный шаг по вертикали для эффекта полос (блоков)
    float block_uv_y = floor(uv.y * shake_block_size) / shake_block_size;
    
    // Вычисляем случайный сдвиг на основе времени и вертикального блока
    float time_step = floor(TIME * shake_speed);
    float shake = random(vec2(time_step, block_uv_y)) * 2.0 - 1.0;
    
    // Применяем дрожание только если случайное число превышает порог (чтобы дрожало не постоянно, а импульсно)
    float shake_threshold = 0.7;
    if (random(vec2(time_step * 0.1, block_uv_y)) > shake_threshold) {
        uv.x += shake * shake_intensity;
    }

    // Расслоение каналов (Красный уходит влево, Синий вправо)
    float r = texture(TEXTURE, vec2(uv.x - color_split, uv.y)).r;
    float g = texture(TEXTURE, uv).g;
    float b = texture(TEXTURE, vec2(uv.x + color_split, uv.y)).b;
    float a = texture(TEXTURE, uv).a; // Сохраняем оригинальную прозрачность текста

    // Если пиксель текста прозрачный в деформированной зоне, подтягиваем альфа-канал с краев
    float alpha = max(a, max(texture(TEXTURE, vec2(uv.x - color_split, uv.y)).a, texture(TEXTURE, vec2(uv.x + color_split, uv.y)).a));

    COLOR = vec4(r, g, b, alpha);
}
