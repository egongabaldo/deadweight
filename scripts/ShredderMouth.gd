extends Area3D
## The shredder's "blades": a thin detection zone at the narrow throat of
## the hopper. A ShreddableItem only reaches it after falling through the
## hopper under gravity, at which point it's shredded: awards money based
## on the current tier/power, spawns a placeholder particle burst, and is
## removed from the scene.

signal item_shredded(value: float)

@export var particles_scene: PackedScene


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not (body is ShreddableItem):
		return
	var value: float = Economy.item_value() * body.value_multiplier
	Economy.add_money(value)
	_spawn_burst(body.global_position)
	item_shredded.emit(value)
	body.queue_free()


func _spawn_burst(at_position: Vector3) -> void:
	if particles_scene == null:
		return
	var burst: CPUParticles3D = particles_scene.instantiate()
	get_tree().current_scene.add_child(burst)
	burst.global_position = at_position
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
