extends Node3D
## Procedurally builds one shredder rotor shaft: a row of thick round
## discs, each with a few hooked claw teeth, mounted on a smooth round
## core rod — matching the dual-shaft shredder in the reference footage
## (mostly-circular discs with 2-3 chunky hooks, not spiky star gears).
## Each claw ramps up gradually and drops off sharply, so the steep face
## leads into the spin and reads as the "bite"; the profile is mirrored
## with spin_direction so the counter-rotating pair both bite downward
## into the gap. Claws are phase-shifted disc to disc, spiraling along
## the shaft like the real machine. Spins continuously around its own
## axis (local X). The physical collision is a plain cylinder rather than
## the toothed mesh, since Godot's concave trimesh shapes aren't meant to
## move/rotate reliably — the cylinder still gives falling items a
## believable bounce off the spinning shaft.

@export var shaft_length: float = 2.2
@export var outer_radius: float = 0.3
@export var body_radius: float = 0.23
@export var claw_count: int = 3
## Fraction of each claw's angular period spent ramping from the disc
## body up to the claw tip (the rest is bare disc). Small = short steep
## hooks, large = long shark-fin ramps.
@export var claw_ramp_fraction: float = 0.24
## Angular shift between neighbouring discs, so the claws spiral along
## the shaft instead of forming straight rows.
@export var claw_phase_step: float = 0.55
@export var segments: int = 48
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
		_add_disc(st, x, x + disc_thickness, tint, float(i) * claw_phase_step)
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


## Radius of the disc profile at a given angle: a smooth circle at
## body_radius, interrupted by claw_count hooks that ramp up to
## outer_radius and then drop off sharply. Mirrored by spin_direction so
## the steep drop (the biting face) always leads into the rotation.
func _claw_radius(angle: float) -> float:
	var claw_period: float = TAU / claw_count
	var local: float = fposmod(angle * spin_direction, claw_period) / claw_period
	if local < claw_ramp_fraction:
		return body_radius + (outer_radius - body_radius) * (local / claw_ramp_fraction)
	return body_radius


func _add_disc(st: SurfaceTool, x0: float, x1: float, color: Color, phase: float) -> void:
	st.set_color(color)
	var front_center := Vector3(x0, 0, 0)
	var back_center := Vector3(x1, 0, 0)

	for i in range(segments):
		var a0: float = (float(i) / segments) * TAU
		var a1: float = (float(i + 1) / segments) * TAU
		var r0: float = _claw_radius(a0 + phase)
		var r1: float = _claw_radius(a1 + phase)

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
	var sides: int = 20
	var radius: float = body_radius * 0.5

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
