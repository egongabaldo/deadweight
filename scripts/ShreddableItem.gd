class_name ShreddableItem
extends RigidBody3D
## Draggable placeholder "junk" item. Rides a conveyor belt from the spawn
## point toward the pickup zone; the player can grab it at any point along
## the ride and drag it above the shredder's hopper. The body stays frozen
## (kinematic) only while riding the belt. Once picked up it stays a full
## dynamic RigidBody, pinned to a small invisible "hand" body (an
## AnimatableBody3D that follows the cursor) via a PinJoint3D anchored at
## the exact point that was clicked. The joint keeps that point locked to
## the hand while leaving rotation free, so gravity and momentum swing the
## item naturally around wherever it was grabbed — Godot's own constraint
## solver handles the linear+angular coupling, which measured (via a
## headless physics test) as stable even on long grab arms. An earlier
## version computed hold forces/torques by hand instead, which fought
## itself into a sustained trembling spin under the same conditions; a
## real joint also means the item can never separate from the cursor, so
## no leash-distance hack is needed either. angular_damp/linear_damp are
## raised while held so the swing settles instead of continuing forever,
## and dropped back to zero on release so the resulting throw/fall isn't
## artificially draggy.
## It still collides for real while held (it can't be dragged through the
## hopper walls or other items, and bumping something pushes/rotates it).
## Release is driven by polling the mouse button state every frame rather
## than by the input_event's release signal, since once the item has moved
## away from under the cursor it would stop receiving input events
## entirely and the drag would get stuck.
## While on the belt, items keep a minimum distance from whichever item is
## ahead of them (see _max_allowed_z) so they queue up instead of all
## marching to the exact same spot and overlapping.
## Visuals are placeholder shapes for the MVP; swap the Visual node for
## real art later.

@export var value_multiplier: float = 1.0
@export var belt_speed: float = 2.0
@export var belt_min_spacing: float = 0.15
@export var hold_angular_damp: float = 1.5
@export var hold_linear_damp: float = 0.5
@export var limbo_y: float = -8.0
## Seconds the shredder takes to grind this item when its visual doesn't
## define per-part `durability` metadata (see get_grind_parts()).
@export var default_durability: float = 1.5

## Set by the shredder when the grind starts, so the player can't pick the
## item back up (or the belt/hold logic re-engage) mid-grind.
var being_shredded: bool = false

var dragging: bool = false
var drag_plane_y: float = 0.0
var on_belt: bool = true
var belt_target: Vector3 = Vector3.ZERO
var _footprint_radius: float = 0.5
var _hold_hand: AnimatableBody3D
var _hold_joint: PinJoint3D
var _hold_generation: int = 0


func _ready() -> void:
	input_event.connect(_on_input_event)
	tree_exiting.connect(_cleanup_hold_nodes)
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
			if being_shredded:
				# Once the rotors have it, it can't be pulled back out.
				return
			_start_hold(click_position)
		else:
			_end_hold()


func _start_hold(click_position: Vector3) -> void:
	dragging = true
	on_belt = false
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	angular_damp = hold_angular_damp
	linear_damp = hold_linear_damp
	drag_plane_y = click_position.y
	_hold_generation += 1
	_setup_hold_joint(click_position, _hold_generation)


## Building the hand + joint and wiring node_a/node_b all in the same
## frame both bodies enter the tree captures each body's local anchor
## frame before the physics server has settled them — measured (headless
## test) as a violent one-frame pop. Spacing each step a physics frame
## apart (matching how a hand-built test rig that worked used real frame
## boundaries, not just call_deferred) avoids it. `generation` guards
## against a release (or a new grab) landing mid-setup, which would
## otherwise finish wiring a joint for a hold that's already over.
func _setup_hold_joint(click_position: Vector3, generation: int) -> void:
	var hand := AnimatableBody3D.new()
	get_tree().current_scene.add_child(hand)
	hand.global_position = click_position
	await get_tree().physics_frame

	var joint := PinJoint3D.new()
	get_tree().current_scene.add_child(joint)
	joint.global_position = click_position
	await get_tree().physics_frame

	if generation != _hold_generation:
		hand.queue_free()
		joint.queue_free()
		return

	joint.node_a = hand.get_path()
	joint.node_b = get_path()
	_hold_hand = hand
	_hold_joint = joint


func _end_hold() -> void:
	dragging = false
	angular_damp = 0.0
	linear_damp = 0.0
	_hold_generation += 1
	_cleanup_hold_nodes()


func _cleanup_hold_nodes() -> void:
	if _hold_joint:
		_hold_joint.queue_free()
		_hold_joint = null
	if _hold_hand:
		_hold_hand.queue_free()
		_hold_hand = null


func _physics_process(delta: float) -> void:
	# Items that fall on the ground are removed by GroundKillZone in
	# Main.gd, but a flung/dragged item can end up outside the ground's
	# finite footprint entirely and just fall forever with nothing to
	# catch it. This is the safety net for that "limbo" case.
	if global_position.y < limbo_y:
		_end_hold()
		queue_free()
		return
	if dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			# The item can drift out from under the cursor while held, so it
			# may stop receiving input_event callbacks entirely; polling the
			# raw button state here is what actually guarantees release works.
			_end_hold()
			return
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam == null:
			return
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var ray_origin: Vector3 = cam.project_ray_origin(mouse_pos)
		var ray_dir: Vector3 = cam.project_ray_normal(mouse_pos)
		var plane := Plane(Vector3.UP, drag_plane_y)
		var target = plane.intersects_ray(ray_origin, ray_dir)
		if target != null and _hold_hand:
			_hold_hand.global_position = target
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


## Disables (or re-enables) this item's own collision. Used when the
## grind starts so the still-spinning rotors don't keep shoving a body
## that's being held in the blades and consumed.
func set_collision_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			# Deferred: this gets called from inside the ShredderMouth's
			# body_entered callback, i.e. mid physics flush, where changing
			# shape state directly is an error.
			child.set_deferred("disabled", not enabled)


## The visual pieces the shredder grinds through, in the durability sense:
## each part is consumed one at a time, taking `durability` seconds, and
## tints the chip particles with its own material color. Parts are the
## children of Visual that carry a `durability` metadata entry (e.g. the
## sledgehammer's wood handle vs. steel head); items whose visual is one
## homogeneous material (like the all-chrome wrench) define no per-part
## metadata and fall back to the whole Visual as a single part using
## `default_durability`.
func get_grind_parts() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var visual: Node3D = get_node_or_null("Visual")
	if visual == null:
		return parts
	for child in visual.get_children():
		if child is Node3D and child.has_meta("durability"):
			parts.append({
				"node": child,
				"durability": float(child.get_meta("durability")),
				"color": _part_color(child),
			})
	if parts.is_empty():
		parts.append({
			"node": visual,
			"durability": default_durability,
			"color": _part_color(visual),
		})
	return parts


func _part_color(node: Node) -> Color:
	if node is CSGPrimitive3D and node.get("material") is StandardMaterial3D:
		return (node.get("material") as StandardMaterial3D).albedo_color
	if node is MeshInstance3D and node.mesh != null and node.mesh.get("material") is StandardMaterial3D:
		return (node.mesh.get("material") as StandardMaterial3D).albedo_color
	for child in node.get_children():
		var found: Color = _part_color(child)
		if found.a > 0.0:
			return found
	return Color(0, 0, 0, 0)
