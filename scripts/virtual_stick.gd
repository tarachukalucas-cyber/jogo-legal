extends Control

signal direction_changed(value: Vector2)

var touch_id := -1
var direction := Vector2.ZERO
var knob := Vector2.ZERO
const CENTER := Vector2(100, 100)
const RADIUS := 78.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			_update_direction(event.position)
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
			direction = Vector2.ZERO
			knob = CENTER
			direction_changed.emit(direction)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_update_direction(event.position)

func _update_direction(point: Vector2) -> void:
	var local_point := point
	var offset := local_point - CENTER
	knob = CENTER + offset.limit_length(RADIUS)
	direction = Vector2(offset.x, offset.y).limit_length(RADIUS) / RADIUS
	direction_changed.emit(direction)
	queue_redraw()

func _draw() -> void:
	draw_circle(CENTER, RADIUS, Color(0.05, 0.08, 0.1, 0.35))
	draw_arc(CENTER, RADIUS, 0.0, TAU, 48, Color(0.85, 0.9, 0.95, 0.65), 3.0)
	draw_circle(knob, 30.0, Color(0.75, 0.85, 0.95, 0.7))
