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


def default_params_dict() -> dict[str, float]:
    """Zwraca domyślne parametry modelu jako słownik."""
    return asdict(Params())


def available_param_names() -> list[str]:
    """Lista wszystkich nazw parametrów dostępnych w Params."""
    return sorted(default_params_dict().keys())


def validate_param_overrides(overrides: dict[str, Any] | None) -> None:
    """Waliduje nadpisania parametrów przed budową obiektu Params."""
    if overrides is None:
        return

    if not isinstance(overrides, dict):
        raise TypeError("overrides musi być słownikiem dict[str, float].")

    base = default_params_dict()
    unknown = [key for key in overrides if key not in base]
    if unknown:
        raise KeyError(
            f"Unknown parameter(s): {unknown}. "
            f"Available parameters: {available_param_names()}"
        )

    non_numeric = [key for key, value in overrides.items() if not isinstance(value, (int, float))]
    if non_numeric:
        raise TypeError(
            f"Non-numeric override(s): {non_numeric}. "
            "All parameter overrides must be int or float."
        )


def validate_gsa_param_names(dist_spec: dict[str, Any] | None = None) -> None:
    """
    Sprawdza spójność listy GSA_PARAM_NAMES z Params oraz opcjonalnie z dist_spec.
    dist_spec może być np. słownikiem rozkładów z gsa_common.py.
    """
    base = default_params_dict()

    missing_in_params = [name for name in GSA_PARAM_NAMES if name not in base]
    if missing_in_params:
        raise RuntimeError(
            f"GSA_PARAM_NAMES zawiera parametry nieobecne w Params: {missing_in_params}"
        )

    if dist_spec is not None:
        missing_in_dist = [name for name in GSA_PARAM_NAMES if name not in dist_spec]
        if missing_in_dist:
            raise RuntimeError(
                f"GSA_PARAM_NAMES zawiera parametry nieobecne w dist_spec: {missing_in_dist}"
            )


def build_params(overrides: dict[str, float] | None = None) -> Params:
    """
    Buduje obiekt Params z opcjonalnymi nadpisaniami.
    """
    validate_param_overrides(overrides)
    base = default_params_dict()

    for key, value in (overrides or {}).items():
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
    """
    Uruchamia model dla zadanych parametrów i zwraca metryki końcowe.
    """
    model_params = build_params(params)

    df = simulate(
        model_params,
        scenario=scenario,
        years=years,
        seed=seed,
    )

    return compute_metrics(
        df,
        years=years,
        stab_crit=stab_crit,
        elite_crit=elite_crit,
        elite_streak_weeks=elite_streak_weeks,
    )