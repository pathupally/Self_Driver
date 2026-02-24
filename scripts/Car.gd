extends RigidBody2D
class_name Car

## ---------------------------------------------------------------------------
## Car Physics & Sensor Controller
## Handles movement, raycasts, resets, and collision detection.
## ---------------------------------------------------------------------------

# ── Inspector-tweakable constants ──────────────────────────────────────────
@export var max_speed: float = 400.0          # pixels/sec
@export var acceleration_force: float = 800.0  # applied linear force
@export var steering_torque: float = 2.5       # radians/sec² equivalent
@export var drag: float = 0.95                 # linear damping multiplier
@export var angular_drag: float = 0.85         # angular damping multiplier

@export var raycast_length: float = 200.0      # max sensor range (px)

# ── Node references (assigned after scene is ready) ───────────────────────
@onready var ai_controller: CarAIController = $CarAIController
@onready var raycasts: Array[RayCast2D] = []

# ── Spawn state ────────────────────────────────────────────────────────────
var _spawn_position: Vector2
var _spawn_rotation: float

# ── Runtime state ──────────────────────────────────────────────────────────
var crashed: bool = false
var speed: float = 0.0

# Raycast angles relative to car's forward direction (degrees)
const RAYCAST_ANGLES: Array[float] = [-135.0, -90.0, -45.0, -22.5,
                                        22.5,  45.0,  90.0, 135.0]

# ── Signals ────────────────────────────────────────────────────────────────
signal car_crashed

func _ready() -> void:
	_spawn_position = global_position
	_spawn_rotation = global_rotation

	# Collect all RayCast2D children
	for child in get_children():
		if child is RayCast2D:
			raycasts.append(child)

	# Physics: no gravity in top-down, manual damping
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0

# ── AI interface ────────────────────────────────────────────────────────────

## Apply a normalized action [{-1,1} steering, {0,1} throttle]
func apply_action(steering: float, throttle: float) -> void:
	if crashed:
		return

	# Clamp inputs
	steering = clamp(steering, -1.0, 1.0)
	throttle = clamp(throttle, 0.0, 1.0)

	# Steering: rotate around z axis
	angular_velocity = steering * steering_torque * 60.0

	# Throttle: apply force in the car's forward direction
	var forward: Vector2 = Vector2(sin(global_rotation), -cos(global_rotation))
	apply_central_force(forward * throttle * acceleration_force)

## Returns 8 normalized [0,1] raycast hit distances
func get_raycast_distances() -> Array[float]:
	var distances: Array[float] = []
	for rc in raycasts:
		if rc.is_colliding():
			var dist: float = rc.get_collision_point().distance_to(global_position)
			distances.append(clamp(dist / raycast_length, 0.0, 1.0))
		else:
			distances.append(1.0)   # no hit → max distance
	# Pad if somehow fewer than 8
	while distances.size() < 8:
		distances.append(1.0)
	return distances

# ── Physics process ─────────────────────────────────────────────────────────
func _physics_process(_delta: float) -> void:
	# Manual damping (Godot's built-in damps are applied before forces resolve)
	linear_velocity *= drag
	angular_velocity *= angular_drag

	# Clamp speed
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

	speed = linear_velocity.length()

# ── Reset ────────────────────────────────────────────────────────────────────
func reset() -> void:
	crashed = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = _spawn_position
	global_rotation = _spawn_rotation
	speed = 0.0

# ── Collision ────────────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("wall"):
		crashed = true
		emit_signal("car_crashed")
		if ai_controller:
			ai_controller.needs_reset = true
