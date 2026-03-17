# ---------------- variant spec -------------
scenario: "impas"
years: 2
seed_base: 12345          # pierwszy seed deterministyczny

# ------------- Monte-Carlo -----------------
n_reps: 5                 # liczba replik MC
rep_seed_stride: 100000   # kolejne seedy: 12345, 101 345, …

stab_crit: 0.30
elite_crit: 0.35
elite_streak_weeks: 4

# ------------- Morris screening ------------
morris_num_levels: 8
morris_trajectories: 30
morris_optimal_trajectories: 10
morris_local_optimization: true

# ------------- Sobol indices ---------------
sobol_N: 1024
sobol_calc_second_order: false
sobol_num_resamples: 1000
sobol_conf_level: 0.95

# ------------- CPU / wątki -----------------
n_jobs: -1                # -1 = pełne wykorzystanie wszystkich rdzeni