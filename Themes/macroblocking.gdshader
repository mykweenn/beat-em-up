shader_type canvas_item;

// Настройки screen_texture обязательны для полноэкранных эффектов в Godot 4
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Параметры эффекта
uniform float block_size : hint_range(4.0, 64.0) = 16.0;       // Размер пиксельных блоков глитча
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.4;  // Насколько часто и агрессивно сыплется картинка
uniform float glitch_speed : hint_range(1.0, 60.0) = 12.0;    // Скорость смены кадров артефактов

// Функция генерации псевдослучайного шума
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    // Получаем текущее разрешение экрана
    vec2 screen_size = vec2(textureSize(screen_texture, 0));
    vec2 uv = SCREEN_UV;
    
    // Дискретизируем время, чтобы глитч не мерцал каждый кадр (эффект низкого fps у помехи)
    float time_step = floor(TIME * glitch_speed);
    
    // Делим экран на крупные блоки макросетки сжатия
    vec2 block_count = screen_size / block_size;
    vec2 block_uv = floor(uv * block_count) / block_count;
    
    // Генерируем случайное значение для конкретного блока в этот момент времени
    float block_noise = random(block_uv + time_step);
    
    // Если шум блока выше порога интенсивности, ломаем этот блок
    if (block_noise < glitch_intensity) {
        // Выбираем случайный вектор сдвига текстурных координат для этого блока
        // Это заставляет блок показывать кусок картинки из другого места экрана
        vec2 offset = vec2(
            random(vec2(time_step, block_uv.y)) * 2.0 - 1.0,
            random(vec2(block_uv.x, time_step)) * 2.0 - 1.0
        ) * 0.05; // 0.05 — максимальная дальность сдвига артефакта
        
        // Смещаем координаты внутри сбойного макроблока
        uv = block_uv + offset;
    }
    
    // Считываем итоговый пиксель экрана
    vec4 final_color = texture(screen_texture, uv);
    
    COLOR = final_color;
}
