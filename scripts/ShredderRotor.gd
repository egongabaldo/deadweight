extends Node3D
## Procedurally builds one shredder rotor shaft: a row of thick toothed
## gear discs (chunky angular claws, not thin blades) mounted on a slim
## center rod, matching a real industrial two-shaft shredder rotor. Spins
## continuously around its own axis (local X). The physical collision is a
## plain cylinder rather than the toothed mesh, since Godot's concave
## trimesh shapes aren't meant to move/rotate reliably — the cylinder still
## gives falling items a believable bounce off the spinning shaft.

@export var shaft_length: float = 2.2
@export var outer_radius: float = 0.3
@export var inner_radius: float = 0.17
@export var teeth_count: int = 8
@export var disc_thickness: float = 0.12
@export var disc_gap: float = 0.12
@export var disc_offset: float = 0.0 ## shifts this rotor's discs so they interleave with the other rotor's
@export var spin_speed: float = 3.2 ## radians/sec
@export var spin_direction: float = 1.0
@export var collision_radius: float = 0.2
@export var base_color: Color = Color(0.24, 0.24, 0.26)
@export var grime_color: Color = Color(0.15, 0.12, 0.1)


func _ready() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _build_mesh()
	add_child(mesh_instance)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = collision_radius
	cyl.height = shaft_length
	shape.shape = cyl
	shape.rotation_degrees = Vector3(0, 0, 90) # cylinder's default axis is Y; align it with the shaft's X axis
	body.add_child(shape)
	add_child(body)


func _process(delta: float) -> void:
	rotate_x(spin_direction * spin_speed * delta)


func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_len: float = shaft_length / 2.0
	var period: float = disc_thickness + disc_gap
	var x: float = -half_len + disc_offset
	var i: int = 0
	while x + disc_thickness <= half_len + 0.001:
		var tint: Color = grime_color if i % 3 == 0 else base_color
		_add_disc(st, x, x + disc_thickness, tint)
		x += period
		i += 1

	_add_core(st, -half_len, half_len, base_color)

	st.generate_normals()
	var array_mesh: ArrayMesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.6
	mat.roughness = 0.55
	array_mesh.surface_set_material(0, mat)
	return array_mesh


func _add_disc(st: SurfaceTool, x0: float, x1: float, color: Color) -> void:
	st.set_color(color)
	var sides: int = teeth_count * 2
	var front_center := Vector3(x0, 0, 0)
	var back_center := Vector3(x1, 0, 0)

	for i in range(sides):
		var a0: float = (float(i) / sides) * TAU
		var a1: float = (float(i + 1) / sides) * TAU
		var r0: float = outer_radius if i % 2 == 0 else inner_radius
		var r1: float = outer_radius if (i + 1) % 2 == 0 else inner_radius

		var p0f := Vector3(x0, cos(a0) * r0, sin(a0) * r0)
		var p1f := Vector3(x0, cos(a1) * r1, sin(a1) * r1)
		var p0b := Vector3(x1, cos(a0) * r0, sin(a0) * r0)
		var p1b := Vector3(x1, cos(a1) * r1, sin(a1) * r1)

		st.add_vertex(p0f)
		st.add_vertex(p1b)
		st.add_vertex(p1f)
		st.add_vertex(p0f)
		st.add_vertex(p0b)
		st.add_vertex(p1b)

		st.add_vertex(front_center)
		st.add_vertex(p1f)
		st.add_vertex(p0f)

		st.add_vertex(back_center)
		st.add_vertex(p0b)
		st.add_vertex(p1b)


func _add_core(st: SurfaceTool, x0: float, x1: float, color: Color) -> void:
	st.set_color(color)
	var sides: int = 8
	var radius: float = inner_radius * 0.55

	for i in range(sides):
		var a0: float = (float(i) / sides) * TAU
		var a1: float = (float(i + 1) / sides) * TAU
		var p0f := Vector3(x0, cos(a0) * radius, sin(a0) * radius)
		var p1f := Vector3(x0, cos(a1) * radius, sin(a1) * radius)
		var p0b := Vector3(x1, cos(a0) * radius, sin(a0) * radius)
		var p1b := Vector3(x1, cos(a1) * radius, sin(a1) * radius)

		st.add_vertex(p0f)
		st.add_vertex(p1b)
		st.add_vertex(p1f)
		st.add_vertex(p0f)
		st.add_vertex(p0b)
		st.add_vertex(p1b)
