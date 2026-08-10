shader_type canvas_item;

// Сюда мы пишем точный цвет зуба (#040404)
const vec3 TARGET_COLOR = vec3(0.015686, 0.015686, 0.015686);

uniform float gold_chance : hint_range(0.0, 1.0) = 0.3;
uniform vec4 gold_color : source_color = vec4(0.85, 0.65, 0.13, 1.0);
uniform float enemy_seed = 1.0;

float rand(vec2 co) {
    return fract(sin(dot(co * enemy_seed, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Считаем разницу между цветом пикселя и цветом #040404
    vec3 diff = abs(tex_color.rgb - TARGET_COLOR);
    
    // Если цвет ОЧЕНЬ близко к #040404 (допуск 0.01) и пиксель не прозрачный
    if (diff.r < 0.01 && diff.g < 0.01 && diff.b < 0.01 && tex_color.a > 0.0) {
        
        float random_value = rand(UV);
        if (random_value < gold_chance) {
            tex_color.rgb = gold_color.rgb;
        }
    }
    
    COLOR = tex_color;
}
