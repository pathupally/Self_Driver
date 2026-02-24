# Self-Driving Car RL Mini Game (Godot 4 + PPO)

A 2D top-down racing game where a car learns to drive around an oval track using **Reinforcement Learning** (PPO via StableBaselines3). The Godot engine simulates physics; Python handles training via TCP using the [Godot RL Agents](https://github.com/edbeeching/godot_rl_agents) bridge.

```
Player ──── (manual play)
              │
     Godot 4 Game ◄────TCP────► Python PPO Training
              │                       │
        8 Raycasts              StableBaselines3
        Physics sim             checkpoints/models/
```

---

## Project Structure

```
Self_Driver/
├── project.godot          # Godot 4 project config
├── scenes/
│   ├── Main.tscn          # Root scene (Track + Car + Sync + HUD)
│   ├── Car.tscn           # Car body + 8 raycasts + AIController
│   └── Track.tscn         # Oval racetrack + 8 checkpoints
├── scripts/
│   ├── Car.gd             # Physics, raycast sensing, crash detection
│   ├── CarAIController.gd # RL bridge: observations, actions, rewards
│   ├── TrackManager.gd    # Checkpoint sequencing, lap counting
│   └── Main.gd            # HUD updates, episode tracking
├── training/
│   ├── train.py           # PPO training + inference runner
│   ├── requirements.txt
│   └── README.md
├── addons/
│   └── godot_rl_agents/   # Plugin (install via Godot editor)
└── assets/
    └── car.png
```

---

## Quick Start

### 1. Install the Godot RL Agents Plugin

```bash
# Option A – via AssetLib inside Godot editor
# Search "Godot RL Agents" → Install → Enable in Project Settings → Plugins

# Option B – manual
cd Self_Driver
git submodule add https://github.com/edbeeching/godot_rl_agents.git addons/godot_rl_agents
```

### 2. Install Python Dependencies

```bash
cd training
python -m venv venv
source venv/bin/activate    # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Run Training

**Terminal 1 – Start Godot:**
```bash
# Open project.godot in Godot 4 and press Play (F5)
# The game window will appear and wait for a TCP connection
```

**Terminal 2 – Start Training:**
```bash
cd training
source venv/bin/activate
python train.py
```

Training will run for 500,000 steps (~30–60 min depending on hardware).  
Watch live metrics: `tensorboard --logdir ./tb_logs`

### 4. Watch Your Trained Agent

```bash
python train.py --mode run --model models/self_driving_ppo_final.zip
```

---

## How It Works

### Observations (10 floats per step)
| Index | Description |
|-------|-------------|
| 0–7   | Normalized raycast distances (0 = wall, 1 = clear air) |
| 8     | Normalized speed (0–1) |
| 9     | Heading angle delta to next checkpoint (−1 to +1) |

### Actions (continuous)
| Index | Range | Description |
|-------|-------|-------------|
| 0     | −1 to +1 | Steering (left/right) |
| 1     | 0 to +1  | Throttle (gas) |

### Reward Shaping
| Event | Reward |
|-------|--------|
| Per step (speed bonus) | `+0.1 × (speed / max_speed)` |
| Checkpoint passed | `+5.0` |
| Wall crash | `−10.0` |
| Episode timeout (30 s) | Episode ends |

---

## Hyperparameters

See `training/train.py` for all PPO hyperparameters. Key values:

| Param | Value |
|-------|-------|
| Algorithm | PPO |
| Steps per update | 2,048 |
| Batch size | 64 |
| Learning rate | 3e-4 |
| Discount (γ) | 0.99 |
| Network | MLP [256, 256] actor + critic |
| Total timesteps | 500,000 |

---

## Exporting the Trained Model (ONNX → Godot Inference)

Once trained, you can load the model directly into Godot without Python:
1. Export the SB3 model to ONNX (see `godot_rl_agents` docs)
2. Place the `.onnx` file in `models/`
3. Set `control_mode = 1` on the `Sync` node in `Main.tscn`
4. Point the `Sync` node to your `.onnx` file
5. Press Play — the car drives itself with no Python!

---

## Extending the Project

- **Add tracks**: Duplicate `Track.tscn`, change wall shapes and checkpoint positions
- **Add opponents**: Instance multiple `Car.tscn` nodes with different spawn points
- **Curriculum learning**: Start with wider tracks, gradually narrow them
- **Add braking**: Extend action space to `[steering, throttle, brake]`
