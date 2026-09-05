shader_type canvas_item;

// Считываем экранную текстуру с ПРИНУДИТЕЛЬНЫМ линейным сглаживанием
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

group_uniforms Vertical_Streaks;
uniform float streak_threshold : hint_range(0.5, 0.99) = 0.82;     // Порог яркости (все что ниже — не светится)
uniform float streak_length : hint_range(0.01, 0.3) = 0.12;       // Длина полос по Y
uniform float streak_intensity : hint_range(0.0, 10.0) = 3.5;     // Яркость полос
uniform vec4 streak_color : source_color = vec4(0.85, 0.92, 1.0, 1.0); // Оттенок луча

group_uniforms Camera_Artifacts;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.003; // Сдвиг RGB по краям
uniform float noise_amount : hint_range(0.0, 0.2) = 0.03;          // Цифровой шум (ISO)
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;     // Затемнение по углам

// Функция генерации шума
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // ------------------------------------------------------------------
    // 1. ХРОМАТИЧЕСКАЯ АБЕРРАЦИЯ
    // ------------------------------------------------------------------
    vec2 center_offset = uv - vec2(0.5);
    float dist = length(center_offset);
    vec2 dir = normalize(center_offset);
    
    float r = texture(screen_texture, uv + dir * dist * chromatic_aberration).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv - dir * dist * chromatic_aberration).b;
    vec3 base_color = vec3(r, g, b);
    
    // ------------------------------------------------------------------
    // 2. ГЛАДКИЕ ВЕРТИКАЛЬНЫЕ АНАМОРФНЫЕ ЛУЧИ
    // ------------------------------------------------------------------
    vec3 streak = vec3(0.0);
    float total_weight = 0.0;
    
    // 32 сэмпла в каждую сторону дадут плотную цельную полосу без дублирования
    const int samples = 32;
    
    for (int i = -samples; i <= samples; i++) {
        // Относительная позиция от -1.0 до 1.0
        float percent = float(i) / float(samples);
        
        // Смещение по Y
        vec2 sample_uv = uv + vec2(0.0, percent * streak_length);
        vec3 sample_col = texture(screen_texture, sample_uv).rgb;
        
        // Яркость сэмпла
        float brightness = max(sample_col.r, max(sample_col.g, sample_col.b));
        
        // Плавный порог свечения (убирает резкие пиксельные шаги)
        float light_intensity = clamp((brightness - streak_threshold) / (1.0 - streak_threshold + 0.0001), 0.0, 1.0);
        
        // Функция затухания Гаусса для гладкого края луча
        float weight = cos(percent * 1.5707963); // Мягкая косинусоида от 1.0 в центре до 0.0 на краях
        weight *= weight;
        
        streak += sample_col * light_intensity * weight;
        total_weight += weight;
    }
    
    // Нормализуем и подмешиваем цвет
    if (total_weight > 0.0) {
        streak = (streak / total_weight) * streak_intensity * streak_color.rgb;
    }
    
    vec3 final_color = base_color + streak;
    
    // ------------------------------------------------------------------
    // 3. ЦИФРОВОЙ ШУМ
    // ------------------------------------------------------------------
    float grain = random(uv * vec2(TIME * 12.0, TIME * 18.0)) - 0.5;
    final_color += grain * noise_amount;
    
    // ------------------------------------------------------------------
    // 4. ВИНЬЕТИРОВАНИЕ
    // ------------------------------------------------------------------
    float vignette = smoothstep(0.8, 0.2, dist * vignette_intensity);
    final_color *= vignette;
    
    COLOR = vec4(final_color, 1.0);
}