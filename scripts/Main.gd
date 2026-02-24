extends Node2D

## ---------------------------------------------------------------------------
## Main scene controller – HUD, episode stats, training mode detection.
## ---------------------------------------------------------------------------

@onready var hud_speed: Label = $HUD/VBox/SpeedLabel
@onready var hud_reward: Label = $HUD/VBox/RewardLabel
@onready var hud_laps: Label = $HUD/VBox/LapsLabel
@onready var hud_episode: Label = $HUD/VBox/EpisodeLabel

@onready var car: Car = $Car
@onready var track_manager: TrackManager = $Track/TrackManager

var _episode: int = 0
var _total_reward: float = 0.0
var _episode_reward: float = 0.0

func _ready() -> void:
	if car and car.ai_controller:
		car.ai_controller.reward_updated.connect(_on_reward_updated)
	pass

func _process(_delta: float) -> void:
	if not car:
		return

	# Update HUD
	hud_speed.text = "Speed: %d px/s" % int(car.speed)
	hud_reward.text = "Ep Reward: %.1f" % _episode_reward
	hud_laps.text = "Laps: %d" % track_manager.get_laps()
	hud_episode.text = "Episode: %d" % _episode

func _on_reward_updated(reward: float) -> void:
	_episode_reward += reward
	_total_reward += reward

func start_new_episode() -> void:
	_episode += 1
	_episode_reward = 0.0
