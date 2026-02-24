# Hyperparameter Notes – Self-Driving Car RL

## Algorithm: PPO (Proximal Policy Optimization)

PPO is an on-policy actor-critic algorithm. It collects `n_steps` of experience,
then performs multiple gradient updates (`n_epochs`) over that batch using clipped
surrogate objectives to keep updates conservative.

---

## Key Hyperparameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| `n_steps` | 2048 | Steps per env before update. Increase for more stable gradient estimates. |
| `batch_size` | 64 | Minibatch size. Power of 2, should divide `n_steps`. |
| `n_epochs` | 10 | Passes over data. Too high → overfitting on stale data. |
| `learning_rate` | 3e-4 | Adam LR. Decay scheduling can help later in training. |
| `gamma` | 0.99 | Discount factor. High → values future rewards heavily. |
| `gae_lambda` | 0.95 | GAE smoothing. Higher = more bias, lower = more variance. |
| `clip_range` | 0.2 | PPO clip ε. Constrains policy update size. |
| `ent_coef` | 0.01 | Entropy bonus. Encourages exploration early on. Decay to 0 later. |
| `vf_coef` | 0.5 | Value function loss weight. |
| `max_grad_norm` | 0.5 | Gradient clipping — prevents exploding gradients. |

---

## Network Architecture

```
Observations (10) → FC(256) → FC(256) → Actor head → Action (2)
                                       → Critic head → Value (1)
```

Activation: `tanh` (good for bounded action spaces like steering).

---

## Reward Function Tuning

| Signal | Magnitude | Rationale |
|--------|-----------|-----------|
| Speed bonus | +0.1 × v/vmax | Dense reward — keeps car moving |
| Checkpoint | +5.0 | Sparse — landmark for correct path |
| Wall crash | −10.0 | Strong negative — crash is fatal |

**Tuning guide:**
- If the car drives in circles without passing checkpoints → increase checkpoint reward
- If the car drives too slowly → increase the speed bonus scale
- If the car drives recklessly fast into walls → decrease speed bonus, increase crash penalty

---

## Episode Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| Max steps | 3000 | ~50 s at 60 Hz. Short enough for fast resets. |
| Action repeat | 8 | Each RL action lasts 8 physics frames |
| Effective FPS for RL | 7.5 Hz | 60 / 8 |

---

## Suggested Experiment Schedule

1. **Phase 1** (0–100k steps): Wide track, high entropy — explore freely
2. **Phase 2** (100k–300k): Standard track, reduce `ent_coef` to 0.005
3. **Phase 3** (300k–500k): Fine-tune on tighter corners, `learning_rate` decay

---

## References

- [PPO Paper (Schulman et al., 2017)](https://arxiv.org/abs/1707.06347)
- [Godot RL Agents Docs](https://github.com/edbeeching/godot_rl_agents)
- [StableBaselines3 PPO API](https://stable-baselines3.readthedocs.io/en/master/modules/ppo.html)
