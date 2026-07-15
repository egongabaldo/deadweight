extends Camera3D
## Right-click-drag orbit camera. Always looks at `target` (the shredder,
## by default) and lets the player drag around it to look from any angle.
## Ctrl+left-drag pans that look-at target instead — plain left-click
## dragging (no Ctrl) is reserved for picking up ShreddableItems.

@export var target: Vector3 = Vector3(0.0, 1.8, -0.5)
@export var distance: float = 22.5
@export var yaw: float = -45.0
@export var pitch: float = 45.0
@export var min_pitch: float = 10.0
@export var max_pitch: float = 85.0
@export var sensitivity: float = 0.25
@export var min_distance: float = 2.0
@export var max_distance: float = 40.0
@export var zoom_step: float = 2.0
@export var pan_speed: float = 0.0025

var _dragging: bool = false
var _panning: bool = false


func _ready() -> void:
	_update_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.ctrl_pressed:
			_panning = true
		elif not event.pressed:
			_panning = false
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x * sensitivity
		pitch = clamp(pitch - event.relative.y * sensitivity, min_pitch, max_pitch)
		_update_transform()
	elif event is InputEventMouseMotion and _panning:
		# Scaled by distance so a screen-pixel of drag pans by the same
		# apparent amount whether zoomed in close or far out.
		var pan_scale: float = distance * pan_speed
		target -= global_transform.basis.x * event.relative.x * pan_scale
		target += global_transform.basis.y * event.relative.y * pan_scale
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
