# Training README

## Setup

```bash
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## Running Training

1. Open `Self_Driver/` in Godot 4 and press **Play (F5)**
2. The game will display and wait silently for a TCP connection on port **11008**
3. In a new terminal with the venv activated:

```bash
python train.py
```

Training runs for **500,000 steps** and saves:

| Output | Location |
|--------|----------|
| Periodic checkpoints | `checkpoints/` |
| Final model | `models/self_driving_ppo_final.zip` |
| TensorBoard logs | `tb_logs/` |

Monitor live with:
```bash
tensorboard --logdir ./tb_logs
```

## Watch a Trained Agent

```bash
python train.py --mode run --model models/self_driving_ppo_final.zip
```

## Training Tips

- **Slow convergence?** Increase `n_steps` to 4096 or more
- **Too much crashing?** Increase the wall crash penalty (`−10 → −20`) in `CarAIController.gd`
- **Faster training?** Pass `speedup=4` in `StableBaselinesGodotEnv` and run Godot headless
- **Resume training?** Load a checkpoint and call `model.learn()` again with `reset_num_timesteps=False`
