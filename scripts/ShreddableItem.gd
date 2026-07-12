class_name ShreddableItem
extends RigidBody3D
## Draggable placeholder "junk" item. Rides a conveyor belt from the spawn
## point toward the pickup zone; the player can grab it at any point along
## the ride and drag it above the shredder's hopper. The body stays frozen
## (kinematic) while riding the belt or being dragged so it follows the
## mouse exactly; releasing it unfreezes physics, so gravity pulls it down
## through the hopper until it reaches the ShredderMouth's blade zone and
## is destroyed.
## Visuals are placeholder shapes for the MVP; swap the Visual node for
## real art later.

@export var value_multiplier: float = 1.0
@export var belt_speed: float = 2.0

var dragging: bool = false
var drag_offset: Vector3 = Vector3.ZERO
var drag_plane_y: float = 0.0
var on_belt: bool = true
var belt_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	input_event.connect(_on_input_event)
	belt_target = global_position
	freeze = true
	# Locked so items don't tip onto their side and snag on the hopper's
	# concave trimesh collider while sliding down to the blades.
	lock_rotation = true
	# The fall is long and items can build up real speed; without CCD a
	# fast-moving box can tunnel straight through the hopper's thin
	# trimesh walls between physics steps.
	continuous_cd = true

	var mat := PhysicsMaterial.new()
	mat.friction = 0.08
	mat.bounce = 0.28
	physics_material_override = mat


func _on_input_event(_camera: Node, event: InputEvent, click_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			on_belt = false
			freeze = true
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			drag_plane_y = global_position.y
			drag_offset = global_position - click_position
			drag_offset.y = 0.0
		else:
			dragging = false
			freeze = false


func _process(delta: float) -> void:
	if dragging:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam == null:
			return
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var ray_origin: Vector3 = cam.project_ray_origin(mouse_pos)
		var ray_dir: Vector3 = cam.project_ray_normal(mouse_pos)
		var plane := Plane(Vector3.UP, drag_plane_y)
		var hit = plane.intersects_ray(ray_origin, ray_dir)
		if hit != null:
			global_position = hit + drag_offset
	elif on_belt:
		global_position = global_position.move_toward(belt_target, belt_speed * delta)
		if global_position.is_equal_approx(belt_target):
			on_belt = false
