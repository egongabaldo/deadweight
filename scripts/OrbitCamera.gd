extends Camera3D
## Right-click-drag orbit camera. Always looks at `target` (the shredder,
## by default) and lets the player drag around it to look from any angle.
## Only reacts to the right mouse button — left-click dragging is reserved
## for picking up ShreddableItems.

@export var target: Vector3 = Vector3(0.0, 1.8, 1.0)
@export var distance: float = 7.0
@export var yaw: float = 180.0
@export var pitch: float = 27.0
@export var min_pitch: float = 10.0
@export var max_pitch: float = 85.0
@export var sensitivity: float = 0.25
@export var min_distance: float = 2.0
@export var max_distance: float = 40.0
@export var zoom_step: float = 2.0

var _dragging: bool = false


func _ready() -> void:
	_update_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x * sensitivity
		pitch = clamp(pitch - event.relative.y * sensitivity, min_pitch, max_pitch)
		_update_transform()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		distance = clamp(distance - zoom_step, min_distance, max_distance)
		_update_transform()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		distance = clamp(distance + zoom_step, min_distance, max_distance)
		_update_transform()


func _update_transform() -> void:
	var yaw_rad: float = deg_to_rad(yaw)
	var pitch_rad: float = deg_to_rad(pitch)
	var offset := Vector3(
		distance * cos(pitch_rad) * sin(yaw_rad),
		distance * sin(pitch_rad),
		distance * cos(pitch_rad) * cos(yaw_rad)
	)
	global_position = target + offset
	look_at(target, Vector3.UP)
