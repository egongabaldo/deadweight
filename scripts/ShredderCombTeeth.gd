extends Node3D
## Fixed row of comb teeth bolted to an inner wall of the hopper throat,
## spaced to slot into the gaps between a rotor's blade discs so material
## gets stripped off the spinning shaft instead of wrapping around it.
## Each tooth is a tapered wedge (full-height at the wall, thinning
## toward the tip) rather than a plain box, matching the stripper
## fingers on real dual-shaft shredders.
## Static, so unlike the rotors these get real box collision per tooth.

@export var tooth_count: int = 9
@export var spacing: float = 0.24
@export var tooth_length: float = 0.22 ## how far the tooth reaches inward
@export var tooth_width: float = 0.1
@export var tooth_height: float = 0.14
## Tip cross-section as a fraction of the base, giving the taper.
@export var tip_height_fraction: float = 0.35
@export var tip_width_fraction: float = 0.7
@export var facing: float = 1.0 ## +1 points the tooth toward +Z, -1 toward -Z
@export var color: Color = Color(0.2, 0.19, 0.18)


func _ready() -> void:
	var wedge_mesh: ArrayMesh = _build_wedge_mesh()

	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(tooth_width, tooth_height, tooth_length)

	var half_count: float = float(tooth_count - 1) / 2.0
	for i in range(tooth_count):
		var x: float = (float(i) - half_count) * spacing
		var local_pos := Vector3(x, 0.0, facing * tooth_length / 2.0)

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = wedge_mesh
		mesh_instance.position = local_pos
		if facing < 0.0:
			# The wedge is built tapering toward +Z; flip it around to
			# point the tip the other way instead of mirror-scaling
			# (negative scale inverts the winding/normals).
			mesh_instance.rotation.y = PI
		add_child(mesh_instance)

		var body := StaticBody3D.new()
		body.position = local_pos
		var shape := CollisionShape3D.new()
		shape.shape = box_shape
		body.add_child(shape)
		add_child(body)


## A frustum wedge centered on the origin: base rectangle (full width and
## height) at -Z where it meets the wall, tapering to a smaller tip
## rectangle at +Z reaching toward the rotor.
func _build_wedge_mesh() -> ArrayMesh:
	var hw: float = tooth_width / 2.0
	var hh: float = tooth_height / 2.0
	var tw: float = hw * tip_width_fraction
	var th: float = hh * tip_height_fraction
	var hl: float = tooth_length / 2.0

	var base := [
		Vector3(-hw, -hh, -hl), Vector3(hw, -hh, -hl),
		Vector3(hw, hh, -hl), Vector3(-hw, hh, -hl),
	]
	var tip := [
		Vector3(-tw, -th, hl), Vector3(tw, -th, hl),
		Vector3(tw, th, hl), Vector3(-tw, th, hl),
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Four side faces connecting base ring to tip ring.
	for i in 4:
		var j: int = (i + 1) % 4
		_add_quad(st, base[i], base[j], tip[j], tip[i])
	# Base cap (facing the wall) and tip cap.
	_add_quad(st, base[3], base[2], base[1], base[0])
	_add_quad(st, tip[0], tip[1], tip[2], tip[3])

	st.generate_normals()
	var array_mesh: ArrayMesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.5
	mat.roughness = 0.6
	array_mesh.surface_set_material(0, mat)
	return array_mesh


func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)
