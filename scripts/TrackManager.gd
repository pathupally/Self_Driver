extends Node2D
class_name TrackManager

## ---------------------------------------------------------------------------
## TrackManager – Manages checkpoints and lap tracking for the oval track.
##
## Checkpoints are Area2D nodes that are children of this node.
## The car must pass through them in order. Rewards are issued via signal.
## ---------------------------------------------------------------------------

signal checkpoint_reached(car_node: Node)

var _checkpoints: Array[Area2D] = []
var _next_checkpoint_index: int = 0
var _laps_completed: int = 0

func _ready() -> void:
	# Collect all Area2D children as checkpoints (in scene order)
	for child in get_children():
		if child is Area2D:
			_checkpoints.append(child)
			child.body_entered.connect(_on_checkpoint_body_entered.bind(child))

## Returns the signed angle (radians) from car's current heading to the
## next checkpoint. Positive = turn right, negative = turn left.
func get_next_checkpoint_angle(car_pos: Vector2, car_rotation: float) -> float:
	if _checkpoints.is_empty():
		return 0.0

	var cp: Area2D = _checkpoints[_next_checkpoint_index]
	var to_cp: Vector2 = (cp.global_position - car_pos).normalized()
	var forward: Vector2 = Vector2(sin(car_rotation), -cos(car_rotation))
	return forward.angle_to(to_cp)

func get_laps() -> int:
	return _laps_completed

func reset() -> void:
	_next_checkpoint_index = 0
	_laps_completed = 0

# ── Checkpoint collision ──────────────────────────────────────────────────────
func _on_checkpoint_body_entered(body: Node, checkpoint: Area2D) -> void:
	if not body.is_in_group("car"):
		return

	# Only accept if this is the *next* expected checkpoint
	var idx: int = _checkpoints.find(checkpoint)
	if idx == _next_checkpoint_index:
		_next_checkpoint_index = (_next_checkpoint_index + 1) % _checkpoints.size()
		if _next_checkpoint_index == 0:
			_laps_completed += 1
		emit_signal("checkpoint_reached", body)
