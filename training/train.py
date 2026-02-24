#!/usr/bin/env python3
"""
train.py – Self-Driving Car RL Training via Godot RL Agents + StableBaselines3

SETUP:
  1. pip install -r requirements.txt
  2. Open the Godot project (Self_Driver/) in Godot 4
  3. Run the Main scene in Godot (it will wait for a TCP connection)
  4. In a separate terminal: python train.py

The script will train a PPO agent for 500,000 timesteps and save:
  - Periodic checkpoints → ./checkpoints/
  - Final model         → ./models/self_driving_ppo_final
  - TensorBoard logs    → ./tb_logs/

To watch training progress:
  tensorboard --logdir ./tb_logs
"""

import os
import time
from pathlib import Path

from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import (
    CheckpointCallback,
    EvalCallback,
)
from stable_baselines3.common.monitor import Monitor

# ── Paths ──────────────────────────────────────────────────────────────────
BASE_DIR = Path(__file__).parent
CHECKPOINT_DIR = BASE_DIR / "checkpoints"
MODEL_DIR = BASE_DIR / "models"
LOG_DIR = BASE_DIR / "tb_logs"

CHECKPOINT_DIR.mkdir(exist_ok=True)
MODEL_DIR.mkdir(exist_ok=True)
LOG_DIR.mkdir(exist_ok=True)

# ── Hyperparameters ────────────────────────────────────────────────────────
TOTAL_TIMESTEPS = 500_000

PPO_HPARAMS = {
    "n_steps": 2048,          # steps collected per env before update
    "batch_size": 64,          # minibatch size for gradient updates
    "n_epochs": 10,            # passes over collected data per update
    "learning_rate": 3e-4,     # Adam learning rate
    "gamma": 0.99,             # discount factor
    "gae_lambda": 0.95,        # GAE lambda for advantage estimation
    "clip_range": 0.2,         # PPO clipping parameter
    "ent_coef": 0.01,          # entropy bonus (encourages exploration)
    "vf_coef": 0.5,            # value function loss coefficient
    "max_grad_norm": 0.5,      # gradient clipping norm
    "verbose": 1,
}

POLICY_HPARAMS = {
    "net_arch": [dict(pi=[256, 256], vf=[256, 256])],  # actor-critic network
    "activation_fn": "tanh",   # activation (tanh works well for continuous)
}


def make_env(show_window: bool = True) -> StableBaselinesGodotEnv:
    """Create and wrap the Godot environment."""
    env = StableBaselinesGodotEnv(
        env_path=None,          # None = connect to already-running Godot instance
        show_window=show_window,
        speedup=1,              # set >1 for headless speedup
    )
    return Monitor(env)


def train() -> None:
    print("=" * 60)
    print("  Self-Driving Car RL Training")
    print("  Algorithm : PPO (StableBaselines3)")
    print("  Timesteps : {:,}".format(TOTAL_TIMESTEPS))
    print("=" * 60)
    print("\n[INFO] Waiting for Godot to connect on TCP port 11008...")

    env = make_env(show_window=True)

    model = PPO(
        policy="MlpPolicy",
        env=env,
        policy_kwargs=POLICY_HPARAMS,
        tensorboard_log=str(LOG_DIR),
        **PPO_HPARAMS,
    )

    # Save a checkpoint every 50k steps
    checkpoint_cb = CheckpointCallback(
        save_freq=50_000,
        save_path=str(CHECKPOINT_DIR),
        name_prefix="self_driving_ppo",
        verbose=1,
    )

    print("[INFO] Training started. Open TensorBoard to monitor:\n"
          "       tensorboard --logdir ./tb_logs\n")

    start = time.time()
    model.learn(
        total_timesteps=TOTAL_TIMESTEPS,
        callback=checkpoint_cb,
        tb_log_name="ppo_selfdriving",
        progress_bar=True,
        reset_num_timesteps=True,
    )

    elapsed = time.time() - start
    final_path = str(MODEL_DIR / "self_driving_ppo_final")
    model.save(final_path)

    print("\n" + "=" * 60)
    print(f"  Training complete in {elapsed / 60:.1f} min")
    print(f"  Final model saved → {final_path}.zip")
    print("=" * 60)

    env.close()


def load_and_run(model_path: str, steps: int = 10_000) -> None:
    """Load a saved model and run inference in Godot."""
    env = make_env(show_window=True)
    model = PPO.load(model_path, env=env)

    obs, _ = env.reset()
    for _ in range(steps):
        action, _ = model.predict(obs, deterministic=True)
        obs, reward, terminated, truncated, info = env.step(action)
        if terminated or truncated:
            obs, _ = env.reset()

    env.close()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Self-Driving Car RL")
    parser.add_argument("--mode", choices=["train", "run"], default="train",
                        help="'train' to train a new model, 'run' to watch a saved one")
    parser.add_argument("--model", type=str, default="",
                        help="Path to saved model zip (for --mode run)")
    args = parser.parse_args()

    if args.mode == "train":
        train()
    else:
        if not args.model:
            print("[ERROR] --model path required for --mode run")
        else:
            load_and_run(args.model)
