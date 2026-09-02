shader_type canvas_item;

// Ссылка на текущую текстуру экрана
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Настройки эффекта
uniform float brightness_threshold : hint_range(0.0, 2.0) = 0.8; // Порог яркости (что будет светиться)
uniform float flare_intensity : hint_range(0.0, 5.0) = 2.0;      // Общая сила блика
uniform float flare_stretch : hint_range(0.0, 0.1) = 0.04;       // Длина растяжения лучей
uniform vec4 flare_color : source_color = vec4(0.1, 0.4, 1.0, 1.0); // Кинематографический синий цвет

void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 out_flare = vec3(0.0);
    
    // Количество выборок для размытия по горизонтали (чем больше, тем плавнее)
    const int samples = 16; 

    // Цикл размытия влево и вправо от яркой точки
    for (int i = -samples; i <= samples; i++) {
        // Смещаем UV-координаты только по оси X
        float offset = float(i) * flare_stretch / float(samples);
        vec2 sample_uv = vec2(uv.x + offset, uv.y);
        
        // Ограничиваем выборку рамками экрана
        sample_uv = clamp(sample_uv, vec2(0.0), vec2(1.0));
        
        // Получаем цвет пикселя сцены
        vec3 scene_color = texture(screen_texture, sample_uv).rgb;
        
        // Считаем его относительную яркость (Luminance)
        float luma = dot(scene_color, vec3(0.299, 0.587, 0.114));
        
        // Если пиксель ярче порога, добавляем его в накопление блика
        if (luma > brightness_threshold) {
            // Ослабляем эффект к краям растяжения
            float weight = 1.0 - (abs(float(i)) / float(samples));
            out_flare += (scene_color - brightness_threshold) * weight;
        }
    }

    // Нормализуем результат и накладываем цвет анаморфотной линзы
    out_flare = (out_flare / float(samples * 2)) * flare_intensity * flare_color.rgb;

    // Считываем оригинальный цвет этого пикселя сцены
    vec4 original_color = texture(screen_texture, uv);

    // Смешиваем оригинальную картинку с полученным горизонтальным треком
    COLOR = vec4(original_color.rgb + out_flare, original_color.a);
}
