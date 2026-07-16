extends Area3D
## The shredder's "blades": a thin detection zone at the narrow throat of
## the hopper. A ShreddableItem only reaches it after falling through the
## hopper under gravity, at which point the rotors catch it and grind it
## down over real time, modeled frame-by-frame on real dual-shaft shredder
## footage (a steel pipe being fed through): the item is fed through
## end-first — the face touching the blades stays pinned at the blade line
## while the rest of the part is pulled down into it and consumed — while
## the whole item leans a few degrees off vertical and sways in the
## rotors' grip, and the material at the bite is pinched into a crumpled
## "crush tip" stub (in the footage the pipe's leading end folds into a
## cone as the rotors bite it; a clean flat cut looks wrong). Each visual
## part takes its own `durability` seconds (a sledgehammer's wood handle
## chews through much faster than its steel head). Chip particles tinted
## with the current part's material color spill from the actual bite point
## (not the machine center) downward into the trough — downward on
## purpose: particles don't collide with the hopper geometry, so anything
## fired outward would fly straight through the funnel walls. Money is
## awarded when the grind finishes.

signal item_shredded(value: float)

@export var particles_scene: PackedScene
@export var shake_amplitude: float = 0.02
## Where the rotors grip caught items, relative to this node: the rotor
## gap line. The detection zone spans the whole throat, so items are often
## caught while still resting against the funnel's sloped wall — they get
## yanked here first so the grind visibly happens between the rotors
## instead of half-buried in the funnel.
@export var grip_local: Vector3 = Vector3(0, -0.55, 0)
@export var grip_x_half_range: float = 0.9
@export var grip_pull_time: float = 0.25
## Steady lean off vertical while gripped by the rotors, plus the extra
## sway oscillation on top, both in degrees (from the reference footage:
## the pipe never stays perfectly upright while being pulled in).
@export var grind_lean_degrees: float = 3.0
@export var grind_sway_degrees: float = 2.5
@export var grind_sway_frequency: float = 9.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not (body is ShreddableItem):
		return
	if body.being_shredded:
		return
	_shred(body)


func _shred(item: ShreddableItem) -> void:
	item.being_shredded = true
	if item.dragging:
		# Ripped right out of the player's grip — the rotors win.
		item._end_hold()
	item.on_belt = false
	item.freeze = true
	item.set_collision_enabled(false)
	item.input_ray_pickable = false

	# Yank the item to the rotor gap before grinding starts. Without this
	# it grinds wherever the overlap happened to fire — often still
	# against the funnel's sloped wall, where it appears to vanish into
	# the funnel instead of feeding down between the rotors.
	var grip: Vector3 = to_global(grip_local)
	grip.x = clampf(item.global_position.x,
		global_position.x - grip_x_half_range, global_position.x + grip_x_half_range)
	var pull: Tween = create_tween()
	pull.tween_property(item, "global_position", grip, grip_pull_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await pull.finished
	if not is_instance_valid(item):
		return

	# Grind parts closest to the blades first (lowest along global Y), so
	# whatever end fell in first is what gets eaten first.
	var parts: Array[Dictionary] = item.get_grind_parts()
	parts.sort_custom(func(a, b) -> bool:
		return (a.node as Node3D).global_position.y < (b.node as Node3D).global_position.y)

	var chips: CPUParticles3D = _make_chip_emitter()
	get_tree().current_scene.add_child(chips)
	chips.global_position = item.global_position

	# The whole item is pulled down through the blades as material is
	# consumed, so each successive part arrives at the blade line when its
	# turn comes instead of grinding in mid-air at its original height.
	var feed_base: Vector3 = item.global_position
	for part in parts:
		if not is_instance_valid(item):
			break
		chips.color = part.color if part.color.a > 0.0 else Color(0.5, 0.5, 0.55)
		chips.emitting = true
		var consumed: float = await _grind_part(item, part, chips, feed_base)
		feed_base.y -= consumed

	var last_bite: Vector3 = chips.global_position if is_instance_valid(chips) else global_position
	if is_instance_valid(chips):
		chips.emitting = false
		get_tree().create_timer(1.0).timeout.connect(chips.queue_free)

	if is_instance_valid(item):
		var value: float = Economy.item_value() * item.value_multiplier
		Economy.add_money(value)
		item_shredded.emit(value)
		_spawn_burst(last_bite)
		item.queue_free()


## Feeds one visual part through the blades over its durability. The whole
## item sinks by the consumed length (the rotors pulling it in) while the
## part shrinks along whichever of its local axes points most steeply into
## the blades AND slides backward within the item by half that length —
## the net effect in world space is the part's leading face staying pinned
## at the blade line while everything behind it is dragged down through,
## which is what "being fed into the rotors" looks like (rather than
## deflating in place). The item judders in the rotors' grip meanwhile,
## and the chip emitter tracks the live bite point. Returns the world
## length consumed so the caller can carry the feed into the next part.
func _grind_part(item: ShreddableItem, part: Dictionary, chips: CPUParticles3D, feed_base: Vector3) -> float:
	var node: Node3D = part.node
	var duration: float = maxf(0.2, float(part.durability))

	# Pick the part's local axis most aligned with world down = the feed
	# direction the blades pull it along.
	var world_basis: Basis = node.global_transform.basis
	var axis: int = 0
	var best_alignment: float = -1.0
	for i in 3:
		var alignment: float = absf(world_basis[i].normalized().dot(Vector3.DOWN))
		if alignment > best_alignment:
			best_alignment = alignment
			axis = i
	var feed_sign: float = 1.0 if world_basis[axis].dot(Vector3.DOWN) >= 0.0 else -1.0
	var feed_dir_world: Vector3 = world_basis[axis].normalized() * feed_sign
	var feed_dir_local: Vector3 = Vector3.ZERO
	feed_dir_local[axis] = feed_sign

	var aabb: AABB = AABB(Vector3.ZERO, Vector3(0.6, 0.6, 0.6))
	if node is GeometryInstance3D:
		var node_aabb: AABB = (node as GeometryInstance3D).get_aabb()
		if node_aabb.size[axis] > 0.01:
			aabb = node_aabb
	var extent: float = aabb.size[axis]
	var start_scale: Vector3 = node.scale
	var start_local_pos: Vector3 = node.position
	var start_item_basis: Basis = item.global_transform.basis
	var world_length: float = extent * start_scale[axis]

	# The crumpled stub of material being pinched into the rotor gap,
	# sized from the part's cross-section (the two non-feed axes).
	var tip: MeshInstance3D = _make_crush_tip(aabb, axis, start_scale, part.color)
	get_tree().current_scene.add_child(tip)

	# Lean direction is arbitrary but stays fixed for this part, so the
	# item settles into a tilt instead of flopping around randomly.
	var lean_axis: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	var sway_axis: Vector3 = lean_axis.cross(Vector3.UP).normalized()

	var elapsed: float = 0.0
	while elapsed < duration:
		await get_tree().physics_frame
		if not is_instance_valid(item) or not is_instance_valid(node):
			break
		elapsed += get_physics_process_delta_time()
		var progress: float = clampf(elapsed / duration, 0.0, 1.0)
		var consumed: float = world_length * progress

		var new_scale: Vector3 = start_scale
		new_scale[axis] = start_scale[axis] * maxf(0.02, 1.0 - progress)
		node.scale = new_scale
		# Backward within the item by half the consumed length: combined
		# with the item itself sinking by the full consumed length below,
		# the part's leading face stays pinned at the blade line.
		node.position = start_local_pos - feed_dir_local * (extent * start_scale[axis] * progress * 0.5)

		item.global_position = feed_base + Vector3(
			randf_range(-shake_amplitude, shake_amplitude),
			-consumed,
			randf_range(-shake_amplitude, shake_amplitude),
		)
		# Steady lean plus sway, straight from the reference footage: the
		# item tips a few degrees toward the rotor gap and rocks around
		# that lean while being pulled in.
		var lean: float = deg_to_rad(grind_lean_degrees)
		var sway: float = deg_to_rad(grind_sway_degrees) * sin(elapsed * grind_sway_frequency)
		item.global_transform.basis = Basis(lean_axis, lean) * Basis(sway_axis, sway) * start_item_basis

		var bite_point: Vector3 = node.global_position + feed_dir_world * (world_length * (1.0 - progress) * 0.5)
		if is_instance_valid(chips):
			chips.global_position = bite_point
		if is_instance_valid(tip):
			# Crumpled stub jitters and pulses right under the bite.
			tip.global_position = bite_point + Vector3(0, -0.03, 0)
			tip.rotation = Vector3(
				randf_range(-0.2, 0.2), randf_range(-0.4, 0.4), randf_range(-0.2, 0.2))
			var pulse: float = randf_range(0.75, 1.05)
			tip.scale = Vector3(pulse, randf_range(0.5, 0.8), pulse)

	if is_instance_valid(node):
		node.visible = false
	if is_instance_valid(tip):
		tip.queue_free()
	if is_instance_valid(item):
		item.global_transform.basis = start_item_basis
	return world_length


## A small squashed box the color of the part being ground, standing in
## for the crumpled material pinched between the rotors (in the reference
## footage the pipe's leading end folds into a cone rather than ending in
## a clean cut). Repositioned and re-jittered every grind frame.
func _make_crush_tip(aabb: AABB, feed_axis: int, part_scale: Vector3, color: Color) -> MeshInstance3D:
	var cross: Array[float] = []
	for i in 3:
		if i != feed_axis:
			cross.append(aabb.size[i] * part_scale[i])
	var width: float = maxf(0.05, minf(cross[0], cross[1]) * 0.7)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.1, width)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color if color.a > 0.0 else Color(0.5, 0.5, 0.55)
	mat.roughness = 0.8
	mesh.material = mat

	var tip := MeshInstance3D.new()
	tip.mesh = mesh
	return tip


## Continuous stream of small chips falling into the trough below the
## blades, retinted per part while the grind runs. The mesh needs a
## material with vertex_color_use_as_albedo — without it the per-particle
## `color` is ignored and every chip renders plain white.
func _make_chip_emitter() -> CPUParticles3D:
	var chips := CPUParticles3D.new()
	chips.amount = 48
	chips.lifetime = 0.6
	chips.one_shot = false
	chips.emitting = false
	chips.direction = Vector3(0, -1, 0)
	chips.spread = 25.0
	chips.gravity = Vector3(0, -9.8, 0)
	chips.initial_velocity_min = 1.0
	chips.initial_velocity_max = 2.5
	chips.scale_amount_min = 0.5
	chips.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.7
	mesh.material = mat
	chips.mesh = mesh
	return chips


func _spawn_burst(at_position: Vector3) -> void:
	if particles_scene == null:
		return
	var burst: CPUParticles3D = particles_scene.instantiate()
	get_tree().current_scene.add_child(burst)
	burst.global_position = at_position
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
