shader_type canvas_item;

uniform float desaturation : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float grey = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(tex_color.rgb, vec3(grey), desaturation);
	COLOR = vec4(desaturated, tex_color.a);
}
