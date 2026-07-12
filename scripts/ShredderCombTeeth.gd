extends Node3D
## Fixed row of comb teeth bolted to an inner wall of the hopper throat,
## spaced to slot into the gaps between a rotor's blade discs so material
## gets stripped off the spinning shaft instead of wrapping around it.
## Static, so unlike the rotors these get real box collision per tooth.

@export var tooth_count: int = 9
@export var spacing: float = 0.24
@export var tooth_length: float = 0.22 ## how far the tooth reaches inward
@export var tooth_width: float = 0.1
@export var tooth_height: float = 0.14
@export var facing: float = 1.0 ## +1 points the tooth toward +Z, -1 toward -Z
@export var color: Color = Color(0.2, 0.19, 0.18)


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.5
	mat.roughness = 0.6

	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(tooth_width, tooth_height, tooth_length)
	box_mesh.material = mat

	var box_shape := BoxShape3D.new()
	box_shape.size = box_mesh.size

	var half_count: float = float(tooth_count - 1) / 2.0
	for i in range(tooth_count):
		var x: float = (float(i) - half_count) * spacing
		var local_pos := Vector3(x, 0.0, facing * tooth_length / 2.0)

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = box_mesh
		mesh_instance.position = local_pos
		add_child(mesh_instance)

		var body := StaticBody3D.new()
		body.position = local_pos
		var shape := CollisionShape3D.new()
		shape.shape = box_shape
		body.add_child(shape)
		add_child(body)
