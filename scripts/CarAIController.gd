extends AIController2D
class_name CarAIController

## ---------------------------------------------------------------------------
## CarAIController – Godot RL Agents bridge for the self-driving car.
##
## Observations (10 floats):
##   [0..7]  8 normalized raycast distances  (0 = wall touching, 1 = clear)
##   [8]     normalized speed                (0 = stopped, 1 = max_speed)
##   [9]     heading delta to next checkpoint (-1 = hard left, +1 = hard right)
##
## Actions (2 continuous):
##   [0]  steering  in [-1, 1]
##   [1]  throttle  in [ 0, 1]  (clamped to ≥ 0 in Car.gd)
##
## Reward shaping:
##   +0.1 × (speed / max_speed) per step   → encourages fast driving
##   +5.0 per checkpoint reached            → encourages track completion
##   −10.0 on wall crash                    → discourages crashing
## ---------------------------------------------------------------------------

@onready var car: Car = get_parent() as Car
@onready var track_manager: TrackManager = get_node("/root/Main/Track/TrackManager")

const MAX_EPISODE_STEPS: int = 3000   # ~50 s at 60 fps before forced reset

var _checkpoint_reward: float = 0.0
var _crash_reward: float = 0.0
var _steps: int = 0

func _ready() -> void:
	super._ready()
	# Connect to track manager's checkpoint signal
	if track_manager:
		track_manager.checkpoint_reached.connect(_on_checkpoint_reached)
	# Connect to car's crash signal
	if car:
		car.car_crashed.connect(_on_car_crashed)

# ── Godot RL Agents interface ───────────────────────────────────────────────

func get_obs() -> Array:
	if not car:
		return Array()

	var obs: Array = []

	# 8 raycast distances
	var dists: Array[float] = car.get_raycast_distances()
	for d in dists:
		obs.append(d)

	# Normalized speed
	obs.append(car.speed / car.max_speed)

	# Heading delta to next checkpoint
	var heading_delta: float = 0.0
	if track_manager:
		heading_delta = track_manager.get_next_checkpoint_angle(car.global_position, car.global_rotation)
	obs.append(clamp(heading_delta / PI, -1.0, 1.0))

	return obs

func get_obs_space() -> Dictionary:
	return {
		"obs": {
			"size": [10],
			"type": "float"
		}
	}

func get_action_space() -> Dictionary:
	return {
		"action": {
			"action_type": "continuous",
			"size": 2      # [steering, throttle]
		}
	}

func set_action(action) -> void:
	if not car:
		return

	var steering: float = 0.0
	var throttle: float = 0.0

	if action is Array and action.size() >= 2:
		steering = float(action[0])
		throttle = float(action[1])
	elif action is Dictionary:
		steering = float(action.get("action", [0.0, 0.0])[0])
		throttle = float(action.get("action", [0.0, 0.0])[1])

	car.apply_action(steering, throttle)

func get_reward() -> float:
	var r: float = 0.0

	# Continuous speed reward
	if car:
		r += 0.1 * (car.speed / car.max_speed)

	# One-shot rewards accumulated via signals
	r += _checkpoint_reward
	r += _crash_reward

	_checkpoint_reward = 0.0
	_crash_reward = 0.0

	return r

func get_done() -> bool:
	_steps += 1
	if needs_reset:
		return true
	if _steps >= MAX_EPISODE_STEPS:
		needs_reset = true
		return true
	return false

func reset() -> void:
	super.reset()
	_steps = 0
	_checkpoint_reward = 0.0
	_crash_reward = 0.0
	if car:
		car.reset()
	if track_manager:
		track_manager.reset()

# ── Signal callbacks ─────────────────────────────────────────────────────────

func _on_checkpoint_reached(car_node: Node) -> void:
	if car_node == car:
		_checkpoint_reward += 5.0

func _on_car_crashed() -> void:
	_crash_reward -= 10.0
