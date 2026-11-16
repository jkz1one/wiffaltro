class_name StadiumSurfaceTexture
extends RefCounted
## Original deterministic packed grain/gradient texture, with mipmaps for distant readability.

static var _texture: ImageTexture
# Original factory issuance, retained before exposing any mutable backing image.
# This is data provenance, not a cached validation result. The new candidate3
# adapter alone consumes it; historical callers and generated pixels are unchanged.
static var _issued_texture: ImageTexture
static var _issued_source: Image
static var _issued_image: Dictionary = {}


static func texture() -> ImageTexture:
	if _texture != null:
		return _texture
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 6100520
	noise.frequency = 0.07
	var fine: Image = noise.get_seamless_image(128, 128)
	noise.frequency = 0.02
	noise.seed = 6100521
	var macro: Image = noise.get_seamless_image(128, 128)
	var image: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var value: float = fine.get_pixel(x, y).r
			var dx: float = fine.get_pixel((x + 1) % 128, y).r \
				- fine.get_pixel((x + 127) % 128, y).r
			var dz: float = fine.get_pixel(x, (y + 1) % 128).r \
				- fine.get_pixel(x, (y + 127) % 128).r
			image.set_pixel(x, y, Color(value, clampf(dx * 2 + 0.5, 0, 1),
				clampf(dz * 2 + 0.5, 0, 1), macro.get_pixel(x, y).r))
	image.generate_mipmaps()
	_texture = ImageTexture.create_from_image(image)
	_texture.set_meta("source_image", image)
	if _issued_texture == null:
		_issued_texture = _texture
		_issued_source = image
		_issued_image = image_content(image)
		_issued_image.make_read_only()
	return _texture


static func material(dirt: bool, rough: bool, height: float, pattern: int) -> ShaderMaterial:
	var result: ShaderMaterial = ShaderMaterial.new()
	result.shader = load("res://src/presentation/stadium/surfaces/surface_finish.gdshader")
	result.set_shader_parameter("surface_noise", texture())
	result.set_shader_parameter("dirt_surface", dirt)
	result.set_shader_parameter("condition", 1.0 if rough else 0.0)
	result.set_shader_parameter("grass_height", height)
	result.set_shader_parameter("mowing_pattern", pattern)
	result.set_shader_parameter("mowing_width", 1.2)
	result.set_shader_parameter("base_color", Color("866c4d") if dirt else Color("416334"))
	return result


static func issued_texture_state(value: ImageTexture) -> Dictionary:
	# Never create, repair or adopt a texture through this accessor. Returning a
	# detached container cannot rewrite the original byte/descriptor baseline.
	if value == null or not is_same(value, _texture) or not is_same(value, _issued_texture) \
		or _issued_source == null or _issued_image.is_empty():
		return {}
	return {"texture": _issued_texture, "source": _issued_source,
		"image": _issued_image.duplicate(true)}


static func image_content(image: Image) -> Dictionary:
	if not is_instance_valid(image):
		return {}
	return {"width": image.get_width(), "height": image.get_height(),
		"format": image.get_format(), "mipmaps": image.has_mipmaps(),
		"mipmap_count": image.get_mipmap_count(), "data": image.get_data()}
