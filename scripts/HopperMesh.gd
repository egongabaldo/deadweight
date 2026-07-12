extends MeshInstance3D
## Procedurally builds the shredder's funnel/hopper mesh: an open-top
## frustum (big rectangle at the top narrowing to a small rectangle at the
## bottom), capped with a straight vertical collar band at the very top for
## a heavier, reinforced-edge look. Hand-authoring this geometry directly
## in scene text isn't practical without the editor, so it's generated at
## runtime instead. Tune the exported sizes to reshape the hopper.

@export var top_size: Vector2 = Vector2(6.0, 5.0)
@export var bottom_size: Vector2 = Vector2(2.6, 1.2)
@export var height: float = 1.8
@export var wall_color: Color = Color(0.16, 0.15, 0.14)
@export var rim_color: Color = Color(0.1, 0.09, 0.08)
@export var rim_depth: float = 0.2
@export var wall_thickness: float = 0.12


func _ready() -> void:
	mesh = _build_mesh()
	_build_wall_collision()


func _corners() -> Dictionary:
	var tw: float = top_size.x / 2.0
	var td: float = top_size.y / 2.0
	var bw: float = bottom_size.x / 2.0
	var bd: float = bottom_size.y / 2.0
	var rim_top: float = height + rim_depth

	return {
		"t_fl": Vector3(-tw, height, td),
		"t_fr": Vector3(tw, height, td),
		"t_bl": Vector3(-tw, height, -td),
		"t_br": Vector3(tw, height, -td),
		"b_fl": Vector3(-bw, 0.0, bd),
		"b_fr": Vector3(bw, 0.0, bd),
		"b_bl": Vector3(-bw, 0.0, -bd),
		"b_br": Vector3(bw, 0.0, -bd),
		"r_fl": Vector3(-tw, rim_top, td),
		"r_fr": Vector3(tw, rim_top, td),
		"r_bl": Vector3(-tw, rim_top, -td),
		"r_br": Vector3(tw, rim_top, -td),
	}


func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c: Dictionary = _corners()
	var t_fl: Vector3 = c.t_fl
	var t_fr: Vector3 = c.t_fr
	var t_bl: Vector3 = c.t_bl
	var t_br: Vector3 = c.t_br
	var b_fl: Vector3 = c.b_fl
	var b_fr: Vector3 = c.b_fr
	var b_bl: Vector3 = c.b_bl
	var b_br: Vector3 = c.b_br
	var r_fl: Vector3 = c.r_fl
	var r_fr: Vector3 = c.r_fr
	var r_bl: Vector3 = c.r_bl
	var r_br: Vector3 = c.r_br

	_add_wall(st, t_fl, t_fr, b_fr, b_fl, wall_color)
	_add_wall(st, t_br, t_bl, b_bl, b_br, wall_color.lightened(0.05))
	_add_wall(st, t_bl, t_fl, b_fl, b_bl, wall_color.darkened(0.05))
	_add_wall(st, t_fr, t_br, b_br, b_fr, wall_color.darkened(0.08))

	_add_wall(st, r_fl, r_fr, t_fr, t_fl, rim_color)
	_add_wall(st, r_br, r_bl, t_bl, t_br, rim_color)
	_add_wall(st, r_bl, r_fl, t_fl, t_bl, rim_color)
	_add_wall(st, r_fr, r_br, t_br, t_fr, rim_color)

	st.generate_normals()
	var array_mesh: ArrayMesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.55
	mat.roughness = 0.6
	array_mesh.surface_set_material(0, mat)
	return array_mesh


func _add_wall(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


func _build_wall_collision() -> void:
	# One convex BoxShape3D per wall face instead of a single concave
	# trimesh. Concave (trimesh) colliders only resolve contact reliably
	# near triangle edges/vertices, so a falling item resting mid-face
	# barely touches anything and doesn't slide — it only catches near the
	# borders. Convex boxes give continuous, stable contact across the
	# whole slanted face.
	var body := StaticBody3D.new()
	add_child(body)

	var c: Dictionary = _corners()

	_add_wall_collision(body, c.t_fl, c.t_fr, c.b_fr, c.b_fl)
	_add_wall_collision(body, c.t_br, c.t_bl, c.b_bl, c.b_br)
	_add_wall_collision(body, c.t_bl, c.t_fl, c.b_fl, c.b_bl)
	_add_wall_collision(body, c.t_fr, c.t_br, c.b_br, c.b_fr)

	_add_wall_collision(body, c.r_fl, c.r_fr, c.t_fr, c.t_fl)
	_add_wall_collision(body, c.r_br, c.r_bl, c.t_bl, c.t_br)
	_add_wall_collision(body, c.r_bl, c.r_fl, c.t_fl, c.t_bl)
	_add_wall_collision(body, c.r_fr, c.r_br, c.t_br, c.t_fr)


func _add_wall_collision(body: StaticBody3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# a/b = top edge corners, c/d = bottom edge corners (same winding as
	# _add_wall). Builds a thin oriented box that follows the face's own
	# slope, so its flat side is what the item actually rests and slides on.
	var top_mid: Vector3 = (a + b) / 2.0
	var bottom_mid: Vector3 = (c + d) / 2.0
	var normal: Vector3 = (b - a).cross(d - a).normalized()
	var up_dir: Vector3 = (top_mid - bottom_mid).normalized()
	var right_dir: Vector3 = normal.cross(up_dir).normalized()

	var width: float = max((b - a).length(), (c - d).length())
	var slant_length: float = (top_mid - bottom_mid).length()

	var shape := BoxShape3D.new()
	shape.size = Vector3(width, slant_length, wall_thickness)

	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(Basis(right_dir, up_dir, normal), (top_mid + bottom_mid) / 2.0)
	body.add_child(collision)
