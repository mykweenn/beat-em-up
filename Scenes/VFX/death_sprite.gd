extends Sprite2D

const DESATURATE_SHADER := preload("res://Resources/desaturate_death.gdshader")

var desaturation := 0.0:
	set(value):
		desaturation = value
		if material:
			material.set_shader_parameter("desaturation", desaturation)

func setup_from_character(character: Character) -> void:
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = DESATURATE_SHADER
	material = shader_mat

	global_position = character.global_position

	var animated : AnimatedSprite2D = character.get_node_or_null("AnimatedSprite2D")
	var char_sprite : Sprite2D = character.character_sprite

	if animated and animated.visible:
		texture = animated.sprite_frames.get_frame_texture(
			animated.animation, animated.frame)
		global_position = animated.global_position
		scale = animated.global_scale
		flip_h = animated.flip_h
		z_index = animated.z_index
	elif char_sprite and char_sprite.texture:
		var tex : Texture2D = char_sprite.texture
		var tw := tex.get_width()
		var th := tex.get_height()
		var hf : int = char_sprite.hframes
		var vf : int = char_sprite.vframes
		var fw : float = tw / float(hf)
		var fh : float = th / float(vf)
		var col : int = char_sprite.frame % hf
		var row : int = char_sprite.frame / hf
		texture = AtlasTexture.new()
		texture.atlas = tex
		texture.region = Rect2(col * fw, row * fh, fw, fh)
		global_position = char_sprite.global_position
		if char_sprite.centered:
			global_position -= char_sprite.offset
		else:
			global_position += char_sprite.offset
		scale = char_sprite.scale
		flip_h = char_sprite.flip_h
		z_index = char_sprite.z_index

func _ready() -> void:
	desaturation = 0.0
	var tween = create_tween()
	tween.tween_property(self, "desaturation", 1.0, 2.0)
