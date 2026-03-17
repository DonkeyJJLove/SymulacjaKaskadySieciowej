from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import matplotlib.pyplot as plt
import numpy as np
from scipy.stats import beta as beta_dist
from scipy.stats import truncnorm

from .model_interface import GSA_PARAM_NAMES, available_param_names, validate_gsa_param_names


@dataclass(frozen=True)
class DistSpec:
    kind: str
    lo: float
    hi: float
    args: tuple[float, ...]


def default_dist_spec() -> dict[str, DistSpec]:
    """
    Rozkłady parametrów dopasowane do aktualnej, skalibrowanej wersji modelu.
    Zakresy są celowo umiarkowane, aby Sobol / Morris badały aktualny model,
    a nie historyczny, zbyt agresywny wariant.
    """
    dist_spec: dict[str, DistSpec] = {
        "k_san_oil": DistSpec("beta", 0.25, 0.85, (5.0, 3.0)),
        "k_war_oil": DistSpec("beta", 0.35, 0.90, (4.0, 4.0)),

        "k_pi_san": DistSpec("truncnorm", 0.04, 0.25, (0.12, 0.03)),
        "k_pi_war": DistSpec("truncnorm", 0.06, 0.30, (0.18, 0.04)),
        "pi_base": DistSpec("truncnorm", 0.08, 0.40, (0.18, 0.05)),

        "r0": DistSpec("truncnorm", 0.60, 1.10, (0.90, 0.08)),

        "k_mob": DistSpec("truncnorm", 0.03, 0.12, (0.080, 0.016)),
        "k_demob": DistSpec("truncnorm", 0.05, 0.18, (0.100, 0.022)),

        "k_loss_p": DistSpec("truncnorm", 0.015, 0.080, (0.040, 0.012)),
        "k_cons": DistSpec("truncnorm", 0.06, 0.18, (0.110, 0.020)),
        "k_pay": DistSpec("truncnorm", 0.03, 0.11, (0.070, 0.015)),
        "k_loss_l": DistSpec("truncnorm", 0.01, 0.10, (0.040, 0.018)),
        "k_split": DistSpec("truncnorm", 0.005, 0.080, (0.030, 0.012)),

        "k_elite_cost": DistSpec("truncnorm", 0.005, 0.030, (0.015, 0.004)),
        "k_elite_protest": DistSpec("truncnorm", 0.003, 0.020, (0.010, 0.003)),
        "k_elite_recover": DistSpec("truncnorm", 0.08, 0.20, (0.120, 0.020)),

        "k_info_emerg": DistSpec("truncnorm", 0.01, 0.10, (0.040, 0.018)),
        "k_info": DistSpec("truncnorm", 0.010, 0.060, (0.030, 0.010)),

        "k_rev": DistSpec("truncnorm", 0.06, 0.24, (0.120, 0.030)),
        "k_war_spend": DistSpec("truncnorm", 0.03, 0.18, (0.100, 0.025)),
        "k_rally_s": DistSpec("truncnorm", 0.015, 0.12, (0.050, 0.020)),
    }
    return dist_spec


def validate_dist_spec(dist_spec: dict[str, DistSpec]) -> None:
    """
    Sprawdza spójność:
    - GSA_PARAM_NAMES vs dist_spec
    - GSA_PARAM_NAMES vs Params (przez model_interface)
    - poprawność definicji zakresów
    """
    validate_gsa_param_names(dist_spec)

    available = set(available_param_names())
    for name, spec in dist_spec.items():
        if name not in available:
            raise RuntimeError(f"dist_spec zawiera parametr nieobecny w Params: {name}")
        if spec.lo >= spec.hi:
            raise ValueError(f"Niepoprawny zakres dla {name}: lo >= hi")
        if spec.kind not in {"beta", "truncnorm"}:
            raise ValueError(f"Nieobsługiwany typ rozkładu dla {name}: {spec.kind}")


def build_problem_unit_hypercube(param_names: list[str]) -> dict[str, Any]:
    return {
        "num_vars": len(param_names),
        "names": list(param_names),
        "bounds": [[0.0, 1.0] for _ in param_names],
    }


def _scale(lo: float, hi: float, x01: np.ndarray) -> np.ndarray:
    return lo + (hi - lo) * x01


def transform_unit_samples_to_params(
    X_unit: np.ndarray,
    dist_spec: dict[str, DistSpec] | None = None,
) -> tuple[np.ndarray, dict[str, DistSpec]]:
    """
    Transformuje próbki z hipersześcianu jednostkowego [0,1]^D
    do fizycznej przestrzeni parametrów modelu.
    """
    if dist_spec is None:
        dist_spec = default_dist_spec()

    validate_dist_spec(dist_spec)

    if not isinstance(X_unit, np.ndarray):
        raise TypeError("X_unit musi być numpy.ndarray")

    if X_unit.ndim != 2:
        raise ValueError("X_unit musi mieć wymiar 2: (N, D)")

    if X_unit.shape[1] != len(GSA_PARAM_NAMES):
        raise ValueError(
            f"Liczba kolumn X_unit ({X_unit.shape[1]}) musi odpowiadać "
            f"liczbie GSA_PARAM_NAMES ({len(GSA_PARAM_NAMES)})"
        )

    X_phys = np.zeros_like(X_unit, dtype=float)

    for j, name in enumerate(GSA_PARAM_NAMES):
        spec = dist_spec[name]
        u = np.clip(X_unit[:, j], 1e-12, 1.0 - 1e-12)

        if spec.kind == "beta":
            a, b = spec.args
            x01 = beta_dist.ppf(u, a, b)
            X_phys[:, j] = _scale(spec.lo, spec.hi, x01)

        elif spec.kind == "truncnorm":
            mu, sigma = spec.args
            a = (spec.lo - mu) / sigma
            b = (spec.hi - mu) / sigma
            X_phys[:, j] = truncnorm.ppf(u, a, b, loc=mu, scale=sigma)

        else:
            raise ValueError(f"Unknown dist kind: {spec.kind}")

    return X_phys, dist_spec


def aggregate_replicates(metrics_list: list[dict[str, float]]) -> dict[str, float]:
    """
    Agreguje listę metryk z replik:
    - mean
    - std
    - min
    - max
    """
    if not metrics_list:
        raise ValueError("metrics_list nie może być puste")

    out: dict[str, float] = {}
    keys = list(metrics_list[0].keys())

    for key in keys:
        vals = np.array([row[key] for row in metrics_list], dtype=float)
        out[f"{key}_mean"] = float(np.mean(vals))
        out[f"{key}_std"] = float(np.std(vals, ddof=1)) if len(vals) > 1 else 0.0
        out[f"{key}_min"] = float(np.min(vals))
        out[f"{key}_max"] = float(np.max(vals))

    return out


def plot_morris_bar(Si: dict[str, Any], names: list[str], title: str, out_png: str) -> None:
    mu_star = np.asarray(Si["mu_star"], dtype=float)
    order = np.argsort(-mu_star)

    plt.figure(figsize=(10, 6))
    plt.bar(range(len(names)), mu_star[order])
    plt.xticks(range(len(names)), [names[i] for i in order], rotation=75, ha="right")
    plt.ylabel("mu_star")
    plt.title(title)
    plt.tight_layout()
    plt.savefig(out_png, dpi=200)
    plt.close()


def plot_sobol_bars(Si: dict[str, Any], names: list[str], title: str, out_png: str) -> None:
    s1 = np.asarray(Si["S1"], dtype=float)
    s1_conf = np.asarray(Si["S1_conf"], dtype=float)
    st = np.asarray(Si["ST"], dtype=float)
    st_conf = np.asarray(Si["ST_conf"], dtype=float)

    order = np.argsort(-st)
    x = np.arange(len(names))
    width = 0.38

    plt.figure(figsize=(11, 6))
    plt.bar(x - width / 2, s1[order], width, yerr=s1_conf[order], capsize=3, label="S1")
    plt.bar(x + width / 2, st[order], width, yerr=st_conf[order], capsize=3, label="ST")
    plt.xticks(x, [names[i] for i in order], rotation=75, ha="right")
    plt.ylabel("Sobol index")
    plt.title(title)
    plt.legend()
    plt.tight_layout()
    plt.savefig(out_png, dpi=200)
    plt.close()


def plot_sobol_s2_heatmap(Si: dict[str, Any], names: list[str], title: str, out_png: str) -> None:
    if "S2" not in Si or Si["S2"] is None:
        return

    s2 = np.nan_to_num(np.asarray(Si["S2"], dtype=float), nan=0.0)

    plt.figure(figsize=(9, 7))
    im = plt.imshow(s2, cmap="viridis", aspect="auto")
    plt.colorbar(im, label="S2")
    plt.xticks(np.arange(len(names)), names, rotation=75, ha="right")
    plt.yticks(np.arange(len(names)), names)
    plt.title(title)
    plt.tight_layout()
    plt.savefig(out_png, dpi=200)
    plt.close()