from __future__ import annotations

from copy import deepcopy
from pathlib import Path
from typing import Any

import yaml


DEFAULT_RUNTIME_CONFIG: dict[str, Any] = {
    "scenario": "impas",
    "years": 3,
    "seed_base": 12345,
    "rep_seed_stride": 100000,
    "n_reps": 5,
    "stab_crit": 0.30,
    "elite_crit": 0.35,
    "elite_streak_weeks": 4,
    "mc_enabled": True,
    "mc_n": 500,
    "mc_spread": 0.20,
    "morris_num_levels": 8,
    "morris_trajectories": 30,
    "morris_optimal_trajectories": 10,
    "morris_local_optimization": True,
    "sobol_N": 1024,
    "sobol_calc_second_order": False,
    "sobol_num_resamples": 1000,
    "sobol_conf_level": 0.95,
    "n_jobs": -1,
    "outputs_dir": "outputs",
}


def _deep_update(base: dict[str, Any], patch: dict[str, Any]) -> dict[str, Any]:
    result = deepcopy(base)
    for key, value in patch.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = _deep_update(result[key], value)
        else:
            result[key] = value
    return result


def _load_yaml(path: str | Path) -> dict[str, Any]:
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Nie znaleziono pliku config: {p}")
    with p.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    if not isinstance(data, dict):
        raise ValueError(f"Config musi być mapą YAML, otrzymano: {type(data).__name__}")
    return data


def _flatten_config(data: dict[str, Any]) -> dict[str, Any]:
    """
    Obsługuje dwa formaty:
    1. płaski runtime config:
       scenario, years, seed_base, ...
    2. config hierarchiczny:
       mc.enabled, random.seed_base, thresholds.stab_crit, ...
    """
    flat: dict[str, Any] = {}

    # jeśli wygląda jak płaski runtime config, bierzemy pola bezpośrednio
    runtime_keys = set(DEFAULT_RUNTIME_CONFIG.keys())
    direct_hits = runtime_keys.intersection(data.keys())
    for key in direct_hits:
        flat[key] = data[key]

    # mapowanie z formatu hierarchicznego
    if "scenario" in data:
        flat["scenario"] = data["scenario"]
    if "years" in data:
        flat["years"] = data["years"]

    random_cfg = data.get("random", {})
    if isinstance(random_cfg, dict):
        if "seed_base" in random_cfg:
            flat["seed_base"] = random_cfg["seed_base"]
        if "rep_seed_stride" in random_cfg:
            flat["rep_seed_stride"] = random_cfg["rep_seed_stride"]

    thresholds = data.get("thresholds", {})
    if isinstance(thresholds, dict):
        if "stab_crit" in thresholds:
            flat["stab_crit"] = thresholds["stab_crit"]
        if "elite_crit" in thresholds:
            flat["elite_crit"] = thresholds["elite_crit"]
        if "elite_streak_weeks" in thresholds:
            flat["elite_streak_weeks"] = thresholds["elite_streak_weeks"]

    mc = data.get("mc", {})
    if isinstance(mc, dict):
        if "enabled" in mc:
            flat["mc_enabled"] = mc["enabled"]
        if "n" in mc:
            flat["mc_n"] = mc["n"]
        if "spread" in mc:
            flat["mc_spread"] = mc["spread"]

    gsa = data.get("gsa", {})
    if isinstance(gsa, dict):
        if "n_reps" in gsa:
            flat["n_reps"] = gsa["n_reps"]

        morris = gsa.get("morris", {})
        if isinstance(morris, dict):
            if "num_levels" in morris:
                flat["morris_num_levels"] = morris["num_levels"]
            if "trajectories" in morris:
                flat["morris_trajectories"] = morris["trajectories"]
            if "optimal_trajectories" in morris:
                flat["morris_optimal_trajectories"] = morris["optimal_trajectories"]
            if "local_optimization" in morris:
                flat["morris_local_optimization"] = morris["local_optimization"]

        sobol = gsa.get("sobol", {})
        if isinstance(sobol, dict):
            if "N" in sobol:
                flat["sobol_N"] = sobol["N"]
            if "calc_second_order" in sobol:
                flat["sobol_calc_second_order"] = sobol["calc_second_order"]
            if "num_resamples" in sobol:
                flat["sobol_num_resamples"] = sobol["num_resamples"]
            if "conf_level" in sobol:
                flat["sobol_conf_level"] = sobol["conf_level"]

    runtime = data.get("runtime", {})
    if isinstance(runtime, dict):
        if "n_jobs" in runtime:
            flat["n_jobs"] = runtime["n_jobs"]

    paths = data.get("paths", {})
    if isinstance(paths, dict):
        if "outputs_dir" in paths:
            flat["outputs_dir"] = paths["outputs_dir"]

    return flat


def _drop_none_values(data: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in data.items() if v is not None}


def _coerce_types(cfg: dict[str, Any]) -> dict[str, Any]:
    bool_keys = {
        "mc_enabled",
        "morris_local_optimization",
        "sobol_calc_second_order",
    }
    int_keys = {
        "years",
        "seed_base",
        "rep_seed_stride",
        "n_reps",
        "elite_streak_weeks",
        "mc_n",
        "morris_num_levels",
        "morris_trajectories",
        "morris_optimal_trajectories",
        "sobol_N",
        "sobol_num_resamples",
        "n_jobs",
    }
    float_keys = {
        "stab_crit",
        "elite_crit",
        "mc_spread",
        "sobol_conf_level",
    }
    str_keys = {
        "scenario",
        "outputs_dir",
    }

    out = dict(cfg)

    for key in bool_keys:
        if key in out:
            out[key] = bool(out[key])

    for key in int_keys:
        if key in out:
            out[key] = int(out[key])

    for key in float_keys:
        if key in out:
            out[key] = float(out[key])

    for key in str_keys:
        if key in out:
            out[key] = str(out[key])

    return out


def validate_runtime_config(cfg: dict[str, Any]) -> dict[str, Any]:
    scenario = cfg["scenario"]
    if scenario not in {"impas", "szybka_wojna", "eskalacja_regionalna"}:
        raise ValueError(f"Nieobsługiwany scenariusz: {scenario}")

    if cfg["years"] <= 0:
        raise ValueError("years musi być > 0")

    if cfg["n_reps"] <= 0:
        raise ValueError("n_reps musi być > 0")

    if cfg["mc_n"] <= 0:
        raise ValueError("mc_n musi być > 0")

    if cfg["morris_num_levels"] < 2:
        raise ValueError("morris_num_levels musi być >= 2")

    if cfg["morris_trajectories"] <= 0:
        raise ValueError("morris_trajectories musi być > 0")

    if cfg["sobol_N"] <= 0:
        raise ValueError("sobol_N musi być > 0")

    if not (0.0 < cfg["sobol_conf_level"] < 1.0):
        raise ValueError("sobol_conf_level musi być w (0,1)")

    if cfg["mc_spread"] < 0:
        raise ValueError("mc_spread nie może być ujemny")

    return cfg


def load_runtime_config(config_path: str | Path, cli_overrides: dict[str, Any] | None = None) -> dict[str, Any]:
    cfg = deepcopy(DEFAULT_RUNTIME_CONFIG)

    if config_path:
        raw = _load_yaml(config_path)
        flat = _flatten_config(raw)
        cfg.update(flat)

    if cli_overrides:
        cfg.update(_drop_none_values(cli_overrides))

    cfg = _coerce_types(cfg)
    cfg = validate_runtime_config(cfg)
    return cfg


# kompatybilność wsteczna
DEFAULT_CONFIG = DEFAULT_RUNTIME_CONFIG