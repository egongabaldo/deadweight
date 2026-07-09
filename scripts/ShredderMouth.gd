extends Area2D
## The shredder's "mouth" hitbox. Any ShreddableItem dragged into this area
## is immediately shredded: it awards money based on the current tier/power,
## spawns a placeholder particle burst, and is removed from the scene.

signal item_shredded(value: float)

@export var particles_scene: PackedScene


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if not (area is ShreddableItem):
		return
	var value: float = Economy.item_value() * area.value_multiplier
	Economy.add_money(value)
	_spawn_burst(area.global_position)
	item_shredded.emit(value)
	area.queue_free()


func _spawn_burst(at_position: Vector2) -> void:
	if particles_scene == null:
		return
	var burst: CPUParticles2D = particles_scene.instantiate()
	get_tree().current_scene.add_child(burst)
	burst.global_position = at_position
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
