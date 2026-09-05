shader_type canvas_item;

// Ссылка на текущую текстуру экрана
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Настройки эффекта
uniform float brightness_threshold : hint_range(0.0, 2.0) = 0.8; // Порог яркости (что будет светиться)
uniform float flare_intensity : hint_range(0.0, 5.0) = 2.0;      // Общая сила блика
uniform float flare_stretch : hint_range(0.0, 0.1) = 0.04;       // Длина растяжения лучей
uniform vec4 flare_color : source_color = vec4(0.1, 0.4, 1.0, 1.0); // Кинематографический синий цвет

// Функция генерации псевдорандомного числа на основе времени
float hash(float p) {
    p = fract(p * 0.011);
    p *= p + 7.5;
    p *= p + p;
    return fract(p);
}

// Плавный случайный шум (использует интерполяцию между рандомными точками во времени)
float noise_time(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f); // Сглаживание переходов
    return mix(hash(i), hash(i + 1.0), u);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // --- ГЕНЕРАЦИЯ ЖИВОГО СЛУЧАЙНОГО ШУМА ---
    // Умножаем TIME на скорость изменений (чем больше число, тем резче дрожание)
    float speed = 12.0; 
    
    // Получаем случайные значения в диапазоне [0.0, 1.0] с разными сдвигами
	// Чтобы графики параметров не колебались синхронно
    float n_intensity = noise_time(TIME * speed);
    float n_stretch = noise_time((TIME + 45.0) * (speed * 0.8));
    float n_threshold = noise_time((TIME + 90.0) * 25.0); // Высокая скорость для мерцания матрицы

    // Применяем хаотичные колебания к параметрам из инспектора
    // mix() переводит шум из диапазона [0,1] в диапазон отклонений, например +-15%
    float dynamic_intensity = flare_intensity * mix(0.8, 1.2, n_intensity);
    float dynamic_stretch   = flare_stretch   * mix(0.85, 1.15, n_stretch);
    float dynamic_threshold = brightness_threshold + mix(-0.015, 0.015, n_threshold);
    // ----------------------------------------

    // ДАЛЬШЕ ИДЕТ ВАШ СТАНДАРТНЫЙ ЦИКЛ BLUR...
    vec3 out_flare = vec3(0.0);
    const int samples = 16; 

    for (int i = -samples; i <= samples; i++) {
        float offset = float(i) * dynamic_stretch / float(samples);
        vec2 sample_uv = vec2(uv.x + offset, uv.y);
        
        sample_uv = clamp(sample_uv, vec2(0.0), vec2(1.0));
        vec3 scene_color = texture(screen_texture, sample_uv).rgb;
        float luma = dot(scene_color, vec3(0.299, 0.587, 0.114));
        
        if (luma > dynamic_threshold) {
            float weight = 1.0 - (abs(float(i)) / float(samples));
            out_flare += (scene_color - dynamic_threshold) * weight;
        }
    }

    out_flare = (out_flare / float(samples * 2)) * dynamic_intensity * flare_color.rgb;
    vec4 original_color = texture(screen_texture, uv);
    COLOR = vec4(original_color.rgb + out_flare, original_color.a);
}
