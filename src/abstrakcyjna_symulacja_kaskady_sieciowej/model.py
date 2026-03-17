from __future__ import annotations

import math
from dataclasses import asdict, dataclass
from typing import Optional

import numpy as np
import pandas as pd


def clip(x: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, x))


def sigmoid(x: float) -> float:
    x = max(-60.0, min(60.0, x))
    return 1.0 / (1.0 + math.exp(-x))


@dataclass
class Params:
    oil_export_cap: float = 1.0
    k_san_oil: float = 0.6
    k_war_oil: float = 0.7
    k_rev: float = 0.12
    k_war_spend: float = 0.10
    k_subsidy: float = 0.06
    k_san_leak: float = 0.04
    pi_base: float = 0.35
    pi_target: float = 0.10
    k_pi_san: float = 0.25
    k_pi_war: float = 0.35
    k_pi_fisc: float = 0.20
    a_inf: float = 4.0
    a_fisc: float = 3.0
    a_war: float = 2.0
    r0: float = 0.9
    r_w: float = 0.3
    k_mob: float = 0.08
    k_demob: float = 0.10
    b1: float = 2.5
    b2: float = 1.2
    b3: float = 1.0
    b4: float = 0.8
    b5: float = 2.2
    c1: float = 2.0
    c2: float = 1.0
    c3: float = 0.6
    k_rally: float = 0.06
    tau_rally: float = 26.0
    k_fatigue: float = 0.05
    k_price: float = 0.015
    k_disp: float = 0.004
    k_morale_recover: float = 0.03
    k_cons: float = 0.075
    k_info: float = 0.02
    k_loss_p: float = 0.060
    k_loss_e: float = 0.040
    k_loss_w: float = 0.03
    k_rally_s: float = 0.05
    k_stab_recover: float = 0.070
    k_elite_rally: float = 0.02
    k_elite_cost: float = 0.02
    k_elite_protest: float = 0.015
    k_elite_recover: float = 0.12
    k_pay: float = 0.05
    k_loss_l: float = 0.04
    k_split: float = 0.03
    k_loyal_recover: float = 0.02
    k_info_invest: float = 0.03
    k_info_emerg: float = 0.04
    k_info_deg_w: float = 0.03
    k_info_decay_calm: float = 0.01
    k_troop_up: float = 0.05
    k_troop_down: float = 0.04
    k_troop_attr: float = 0.02
    k_disp_w: float = 0.05
    k_disp_p: float = 0.03
    k_disp_e: float = 0.01
    k_return: float = 0.03
    oil_price_base: float = 1.0
    k_price_shock: float = 0.5


def scenario_exog(t_week: int, scenario: str) -> tuple[float, float]:
    if scenario == "szybka_wojna":
        war = 1.0 if t_week < 8 else (0.5 if t_week < 12 else 0.1)
        sanctions = 0.7 if t_week < 26 else 0.5
    elif scenario == "dlugotrwala_wojna":
        war = 0.8 if t_week < 52 else 0.6
        sanctions = 0.85
    elif scenario == "impas":
        war = 0.5 + 0.15 * math.sin(2 * math.pi * t_week / 26)
        sanctions = 0.75
    elif scenario == "eskalacja_regionalna":
        war = 0.9 if t_week < 26 else 0.7
        sanctions = 0.9
    else:
        war = 0.0
        sanctions = 0.3
    return clip(war), clip(sanctions)


def step(state: dict[str, float], t_week: int, p: Params, scenario: str) -> dict[str, float]:
    war, sanctions = scenario_exog(t_week, scenario)

    oil_price = p.oil_price_base * (1.0 + p.k_price_shock * war)
    revenue = p.oil_export_cap * (1.0 - p.k_san_oil * sanctions) * (1.0 - p.k_war_oil * war) * oil_price
    revenue = max(0.0, revenue)

    fiscal = state["Fiscal"]
    inflation = p.pi_base + p.k_pi_san * sanctions + p.k_pi_war * war + p.k_pi_fisc * max(0.0, 0.5 - fiscal)
    inflation = max(0.0, inflation)
    cpi = state["CPI"] * (1.0 + inflation / 52.0)

    estress = sigmoid(p.a_inf * (inflation - p.pi_target) + p.a_fisc * (0.5 - fiscal) + p.a_war * war)
    calm = (1.0 - war) * (1.0 - state["Protest"])

    elite = state["Elite"]
    loyal = state["Loyal"]
    info = state["Info"]
    repr_cap = clip((p.r0 * loyal * elite + p.r_w * war) * info)

    morale = state["Morale"]
    displaced = state["Displaced"]
    rally_term = p.k_rally * war * math.exp(-t_week / p.tau_rally)
    morale_next = clip(
        morale + rally_term - p.k_fatigue * (war + estress) - p.k_price * inflation - p.k_disp * displaced + p.k_morale_recover * calm * (1.0 - morale)
    )

    inflow = p.k_rev * revenue
    outflow = p.k_war_spend * war + p.k_subsidy * (1.0 - morale_next) + p.k_san_leak * sanctions
    fiscal_next = clip(fiscal + inflow - outflow + 0.01 * calm * (1.0 - fiscal))

    info_next = clip(
        info + p.k_info_invest * fiscal_next + p.k_info_emerg * (war + state["Protest"]) - p.k_info_deg_w * war - p.k_info_decay_calm * calm * info
    )

    protest = state["Protest"]
    mobilize = p.k_mob * sigmoid(
        p.b1 * estress + p.b2 * (1.0 - morale_next) + p.b3 * (1.0 - state["Stab"]) + p.b4 * (1.0 - info_next) - p.b5 * repr_cap
    )
    demobilize = p.k_demob * sigmoid(p.c1 * repr_cap + p.c2 * war + p.c3 * protest) + 0.02 * calm * protest
    protest_next = clip(protest + mobilize - demobilize)

    stab = state["Stab"]
    elite_eq = clip(0.38 + 0.28 * stab, 0.22, 0.82)
    elite_damage = p.k_elite_cost * (0.75 * estress + 0.45 * war) + 1.20 * p.k_elite_protest * protest_next
    elite_next = clip(elite + p.k_elite_rally * war * (1.0 - elite) - elite_damage * elite + 0.75 * p.k_elite_recover * (elite_eq - elite))

    loyal_next = clip(
        loyal + p.k_pay * fiscal_next - p.k_loss_l * (war + estress) - p.k_split * (1.0 - elite_next) + p.k_loyal_recover * calm * (1.0 - loyal)
    )

    stab_next = clip(
        stab
        + p.k_cons * (elite_next * loyal_next * fiscal_next)
        + p.k_info * info_next
        + 0.015 * morale_next
        + p.k_rally_s * war * math.exp(-t_week / p.tau_rally)
        - p.k_loss_p * protest_next
        - p.k_loss_e * estress
        - p.k_loss_w * war
        + p.k_stab_recover * calm * (1.0 - stab)
    )

    troops = state["Troops"]
    troops_next = clip(troops + p.k_troop_up * war * (1.0 - troops) - p.k_troop_down * (1.0 - war) * troops - p.k_troop_attr * war * troops)

    new_disp = p.k_disp_w * war + p.k_disp_p * protest_next * repr_cap + p.k_disp_e * estress
    returns = p.k_return * (1.0 - war) * (1.0 - protest_next) * state["Displaced"]
    displaced_next = max(0.0, state["Displaced"] + new_disp - returns)

    return {
        "Stab": stab_next,
        "Elite": elite_next,
        "Loyal": loyal_next,
        "Info": info_next,
        "Morale": morale_next,
        "Protest": protest_next,
        "Fiscal": fiscal_next,
        "CPI": cpi,
        "Infl": inflation,
        "EStress": estress,
        "Repr": repr_cap,
        "Troops": troops_next,
        "Displaced": displaced_next,
        "War": war,
        "Sanctions": sanctions,
        "OilPrice": oil_price,
        "OilRevIndex": revenue,
    }


def simulate(p: Params, scenario: str, years: int = 3, seed: int = 1, init: Optional[dict[str, float]] = None) -> pd.DataFrame:
    _ = np.random.default_rng(seed)
    steps = int(years * 52)
    state = init.copy() if init is not None else {
        "Stab": 0.60,
        "Elite": 0.65,
        "Loyal": 0.75,
        "Info": 0.70,
        "Morale": 0.55,
        "Protest": 0.20,
        "Fiscal": 0.45,
        "CPI": 100.0,
        "Troops": 0.20,
        "Displaced": 0.0,
    }
    rows: list[dict[str, float]] = []
    for t in range(steps):
        state = step(state, t, p, scenario)
        rows.append({"week": t, "year": t / 52.0, **state})
    return pd.DataFrame(rows)


def compute_metrics(df: pd.DataFrame, years: int, stab_crit: float = 0.30, elite_crit: float = 0.35, elite_streak_weeks: int = 4) -> dict[str, float]:
    max_weeks = int(years * 52)
    stab_idx = df.index[df["Stab"] < stab_crit]
    t_crit = int(stab_idx[0]) if len(stab_idx) > 0 else (max_weeks + 1)

    streak = 0
    fracture = 0.0
    t_frac = max_weeks + 1
    for i, value in enumerate(df["Elite"].values):
        if value < elite_crit:
            streak += 1
            if streak >= elite_streak_weeks:
                fracture = 1.0
                t_frac = i - elite_streak_weeks + 1
                break
        else:
            streak = 0

    return {
        "Tcrit": float(t_crit),
        "elite_fracture_prob": float(fracture),
        "time_to_elite_fracture": float(t_frac),
        "weeks_below_elite_crit": float((df["Elite"] < elite_crit).sum()),
        "avg_loyal": float(df["Loyal"].mean()),
        "peak_protest": float(df["Protest"].max()),
        "end_displaced_m": float(df["Displaced"].iloc[-1]),
        "mean_elite": float(df["Elite"].mean()),
        "min_elite": float(df["Elite"].min()),
        "mean_stab": float(df["Stab"].mean()),
        "min_stab": float(df["Stab"].min()),
    }


def monte_carlo(base_params: Params, scenario: str, years: int = 3, n: int = 500, seed: int = 1, spread: float = 0.20, metric_kwargs: Optional[dict[str, float]] = None) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    base = asdict(base_params)
    metric_kwargs = metric_kwargs or {}
    rows: list[dict[str, float]] = []
    for i in range(n):
        sampled: dict[str, float] = {}
        for key, value in base.items():
            lo = value * (1.0 - spread)
            hi = value * (1.0 + spread)
            if key.endswith("_target"):
                lo = max(0.0, lo)
            sampled[key] = float(rng.uniform(lo, hi))
        params_i = Params(**sampled)
        df_i = simulate(params_i, scenario=scenario, years=years, seed=seed + i + 1)
        rows.append(compute_metrics(df_i, years=years, **metric_kwargs))
    return pd.DataFrame(rows)
