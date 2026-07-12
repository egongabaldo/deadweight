class_name ShreddableItem
extends RigidBody3D
## Draggable placeholder "junk" item. Rides a conveyor belt from the spawn
## point toward the pickup zone; the player can grab it at any point along
## the ride and drag it above the shredder's hopper. The body stays frozen
## (kinematic) only while riding the belt. Once picked up it stays a full
## dynamic RigidBody: a spring-damper force chases the exact point that was
## clicked (not the body's center) toward the cursor, with gravity
## cancelled out as a separate feed-forward term so the item doesn't have
## to sag into a resting position error just to hold itself up (that was
## an earlier bug here). Because the correction is a force, not a hard
## velocity solve, heavier items genuinely lag behind fast mouse movement
## while light ones track almost instantly. It still collides for real
## while held (it can't be dragged through the hopper walls or other items,
## and bumping something pushes/rotates it).
## Gravity's torque around that grabbed point is applied every hold frame
## (lightly damped), so the item continuously swings/hangs from wherever it
## was grabbed instead of staying frozen in rotation until something bumps
## it. Release is driven by polling the mouse button state every frame
## rather than by the input_event's release signal, since once the item has
## moved away from under the cursor it would stop receiving input events
## entirely and the drag would get stuck. Releasing just stops steering and
## lets whatever linear/angular velocity it already has carry through as a
## real throw.
## While on the belt, items keep a minimum distance from whichever item is
## ahead of them (see _max_allowed_z) so they queue up instead of all
## marching to the exact same spot and overlapping.
## Visuals are placeholder shapes for the MVP; swap the Visual node for
## real art later.

@export var value_multiplier: float = 1.0
@export var belt_speed: float = 2.0
@export var belt_min_spacing: float = 0.15
@export var hold_stiffness: float = 300.0
@export var hold_damping_ratio: float = 1.0
@export var hold_max_force: float = 200.0
@export var hold_max_leash_distance: float = 1.2
@export var hold_angular_damp: float = 0.9
@export var limbo_y: float = -8.0

var dragging: bool = false
var grab_local_point: Vector3 = Vector3.ZERO
var drag_plane_y: float = 0.0
var on_belt: bool = true
var belt_target: Vector3 = Vector3.ZERO
var _footprint_radius: float = 0.5


func _ready() -> void:
	input_event.connect(_on_input_event)
	add_to_group("shreddable_items")
	belt_target = global_position
	_footprint_radius = _compute_footprint_radius()
	freeze = true
	# The fall is long and items can build up real speed; without CCD a
	# fast-moving box can tunnel straight through the hopper's thin
	# collider walls between physics steps.
	continuous_cd = true

	var mat := PhysicsMaterial.new()
	mat.friction = 0.08
	mat.bounce = 0.28
	physics_material_override = mat


func _on_input_event(_camera: Node, event: InputEvent, click_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.ctrl_pressed:
				# Ctrl+left-drag is reserved for panning the camera (see
				# OrbitCamera.gd) — don't also start picking the item up.
				return
			dragging = true
			on_belt = false
			freeze = false
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			grab_local_point = to_local(click_position)
			drag_plane_y = click_position.y
		else:
			dragging = false


func _physics_process(delta: float) -> void:
	# Items that fall on the ground are removed by GroundKillZone in
	# Main.gd, but a flung/dragged item can end up outside the ground's
	# finite footprint entirely and just fall forever with nothing to
	# catch it. This is the safety net for that "limbo" case.
	if global_position.y < limbo_y:
		queue_free()
		return
	if dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			# The item can drift out from under the cursor while held, so it
			# may stop receiving input_event callbacks entirely; polling the
			# raw button state here is what actually guarantees release works.
			dragging = false
			return
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam == null:
			return
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var ray_origin: Vector3 = cam.project_ray_origin(mouse_pos)
		var ray_dir: Vector3 = cam.project_ray_normal(mouse_pos)
		var plane := Plane(Vector3.UP, drag_plane_y)
		var target = plane.intersects_ray(ray_origin, ray_dir)
		if target != null and delta > 0.0:
			var anchor_world: Vector3 = to_global(grab_local_point)

			# The spring below can be overpowered (blocked by a wall,
			# outrun by a fast mouse flick, capped by hold_max_force), which
			# would let the item drift away from the cursor indefinitely.
			# Hard-clamp the excess so it can never separate past this
			# leash distance, regardless of what the force is doing.
			var separation: Vector3 = target - anchor_world
			if separation.length() > hold_max_leash_distance:
				var correction: Vector3 = separation.normalized() * (separation.length() - hold_max_leash_distance)
				global_position += correction
				anchor_world = to_global(grab_local_point)

			var offset: Vector3 = anchor_world - global_position
			var point_velocity: Vector3 = linear_velocity + angular_velocity.cross(offset)

			var gravity_dir: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector", Vector3.DOWN)
			var gravity_strength: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
			var gravity_force: Vector3 = gravity_dir * gravity_strength * gravity_scale * mass

			# PD (spring-damper) force chasing the grabbed point toward the
			# cursor, plus gravity cancelled out explicitly as a
			# feed-forward term. The feed-forward is what prevents the old
			# bug where the spring had to "solve" for gravity through a
			# permanent resting error (the item sagging/gravitating away
			# from the cursor) — gravity is removed from the equation
			# entirely instead of being fought via position error. Critical
			# damping (kd from kp and mass) keeps it snappy without
			# oscillating, and because this is a force (not a hard velocity
			# solve), heavier items genuinely lag more than light ones.
			var kd: float = 2.0 * hold_damping_ratio * sqrt(hold_stiffness * mass)
			var hold_force: Vector3 = hold_stiffness * (target - anchor_world) - kd * point_velocity - gravity_force
			if hold_force.length() > hold_max_force:
				hold_force = hold_force.normalized() * hold_max_force
			# Applied at the grab offset (not apply_central_force) so the
			# correction itself generates torque whenever the center of
			# mass lags behind the point you're actually holding — that
			# lag-induced torque is what makes the item swing/whip when you
			# move the mouse, instead of only reacting to gravity's steady
			# hang torque below.
			apply_force(hold_force, offset)

			# Gravity acting through the center of mass produces zero torque
			# around the center of mass itself, so without this the item's
			# rotation would just sit frozen in hold until something bumped
			# it. Applying gravity's torque around the grabbed point instead
			# (lever from center of mass to the anchor, crossed with the
			# weight) makes it swing/hang continuously while held, like a
			# real object pinned at that one point.
			var lever: Vector3 = global_position - anchor_world
			apply_torque(lever.cross(gravity_force))
			angular_velocity *= hold_angular_damp
	elif on_belt:
		var desired_position: Vector3 = global_position.move_toward(belt_target, belt_speed * delta)
		var max_z: float = _max_allowed_z()
		if desired_position.z > max_z:
			desired_position.z = max_z
		global_position = desired_position
		if global_position.is_equal_approx(belt_target):
			on_belt = false


func _max_allowed_z() -> float:
	# Belt travel is a straight line toward +Z (see ItemSpawner/ConveyorEnd
	# markers). Clamp how far this item can advance based on whichever
	# other item ahead of it (larger Z, not currently being dragged) is
	# closest, so items queue up behind each other instead of overlapping
	# at the shared belt_target.
	var limit: float = belt_target.z
	for other in get_tree().get_nodes_in_group("shreddable_items"):
		if other == self or not (other is ShreddableItem) or other.dragging:
			continue
		var other_z: float = other.global_position.z
		if other_z > global_position.z:
			# Items spawn with a random Y rotation, so their footprint along
			# the queue axis isn't just their raw length — using each
			# item's own diagonal (worst case regardless of rotation) plus
			# a small margin keeps two frozen/kinematic items from ending
			# up physically overlapped. That overlap used to go unnoticed
			# until one of them got picked up and turned dynamic, at which
			# point the physics engine would suddenly resolve the
			# penetration with a violent separating impulse.
			var required_gap: float = _footprint_radius + other._footprint_radius + belt_min_spacing
			limit = min(limit, other_z - required_gap)
	return limit


func _compute_footprint_radius() -> float:
	for child in get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var size: Vector3 = (child.shape as BoxShape3D).size
			return Vector2(size.x, size.z).length() / 2.0
	return 0.5


## Half the item's own collision height, so a spawner can rest it exactly on
## top of a surface instead of guessing an offset per item type.
func get_rest_height_offset() -> float:
	for child in get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return (child.shape as BoxShape3D).size.y / 2.0
	return 0.1
