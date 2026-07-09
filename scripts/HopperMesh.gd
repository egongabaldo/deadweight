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


func _ready() -> void:
	mesh = _build_mesh()
	# Walls-only trimesh collider generated from the same geometry, so
	# falling items are blocked by the funnel flaps instead of clipping
	# through them.
	create_trimesh_collision()


func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var tw: float = top_size.x / 2.0
	var td: float = top_size.y / 2.0
	var bw: float = bottom_size.x / 2.0
	var bd: float = bottom_size.y / 2.0
	var rim_top: float = height + rim_depth

	var t_fl := Vector3(-tw, height, td)
	var t_fr := Vector3(tw, height, td)
	var t_bl := Vector3(-tw, height, -td)
	var t_br := Vector3(tw, height, -td)
	var b_fl := Vector3(-bw, 0.0, bd)
	var b_fr := Vector3(bw, 0.0, bd)
	var b_bl := Vector3(-bw, 0.0, -bd)
	var b_br := Vector3(bw, 0.0, -bd)
	var r_fl := Vector3(-tw, rim_top, td)
	var r_fr := Vector3(tw, rim_top, td)
	var r_bl := Vector3(-tw, rim_top, -td)
	var r_br := Vector3(tw, rim_top, -td)

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
