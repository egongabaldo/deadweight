extends MeshInstance3D
## Thin decorative overlay on top of the conveyor belt's plain box, with a
## procedurally-generated tread texture that scrolls toward the hopper so
## the belt visibly reads as moving instead of a static grey slab. Purely
## visual — the belt's actual collision lives on the sibling ConveyorBelt
## box and is untouched.

@export var stripe_count: int = 12
@export var scroll_speed: float = 0.6
@export var base_color: Color = Color(0.58, 0.58, 0.63)
@export var cleat_color: Color = Color(0.32, 0.32, 0.36)

var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_texture = _build_tread_texture()
	_material.uv1_scale = Vector3(1.0, stripe_count, 1.0)
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material.roughness = 0.9
	material_override = _material


func _process(delta: float) -> void:
	_material.uv1_offset.y -= scroll_speed * delta


func _build_tread_texture() -> ImageTexture:
	# A handful of rows: mostly the belt's base color, with a couple of
	# darker "cleat" rows near the top to read as a raised tread bar rather
	# than plain zebra stripes.
	var height := 16
	var image := Image.create(4, height, false, Image.FORMAT_RGB8)
	for y in height:
		var color: Color = cleat_color if y < 3 else base_color
		for x in 4:
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
