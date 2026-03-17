from __future__ import annotations

from dataclasses import asdict
from typing import Any

from .model import Params, compute_metrics, simulate

GSA_PARAM_NAMES: list[str] = [
    "k_san_oil",
    "k_war_oil",
    "k_pi_san",
    "k_pi_war",
    "pi_base",
    "r0",
    "k_mob",
    "k_demob",
    "k_loss_p",
    "k_cons",
    "k_pay",
    "k_loss_l",
    "k_split",
    "k_elite_cost",
    "k_elite_protest",
    "k_info_emerg",
    "k_info",
    "k_rev",
    "k_war_spend",
    "k_rally_s",
    "k_elite_recover",
]


def build_params(overrides: dict[str, float] | None = None) -> Params:
    base = asdict(Params())
    for key, value in (overrides or {}).items():
        if key not in base:
            raise KeyError(f"Unknown parameter '{key}'.")
        base[key] = float(value)
    return Params(**base)


def run_model(
    params: dict[str, float] | None,
    seed: int,
    scenario: str,
    years: int,
    stab_crit: float,
    elite_crit: float,
    elite_streak_weeks: int,
) -> dict[str, float]:
    model_params = build_params(params)
    df = simulate(model_params, scenario=scenario, years=years, seed=seed)
    return compute_metrics(
        df,
        years=years,
        stab_crit=stab_crit,
        elite_crit=elite_crit,
        elite_streak_weeks=elite_streak_weeks,
    )
