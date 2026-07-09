class_name ShreddableItem
extends Area2D
## Draggable placeholder "junk" item. The player drags it into the
## ShredderMouth area to shred it for money. Visuals are placeholder shapes
## for the MVP; swap the Visual node for real art later.

@export var value_multiplier: float = 1.0

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			z_index = 10
			drag_offset = global_position - get_global_mouse_position()
		else:
			dragging = false


func _process(_delta: float) -> void:
	if dragging:
		global_position = get_global_mouse_position() + drag_offset
