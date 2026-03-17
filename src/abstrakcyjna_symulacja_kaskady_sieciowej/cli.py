from __future__ import annotations

import argparse
from pathlib import Path
from typing import Sequence

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from joblib import Parallel, delayed
from SALib.analyze.morris import analyze as morris_analyze
from SALib.analyze.sobol import analyze as sobol_analyze
from SALib.sample.morris import sample as morris_sample
from SALib.sample.sobol import sample as sobol_sample
from sklearn.linear_model import LogisticRegression
from tqdm import tqdm

from .config import SUPPORTED_SCENARIOS, load_runtime_config
from .gsa_common import (
    aggregate_replicates,
    build_problem_unit_hypercube,
    plot_morris_bar,
    plot_sobol_bars,
    plot_sobol_s2_heatmap,
    transform_unit_samples_to_params,
)
from .io_utils import ensure_dir, save_json
from .model import Params, compute_metrics, monte_carlo, simulate
from .model_interface import GSA_PARAM_NAMES, run_model


def _plot_timeseries(df: pd.DataFrame, scenario: str, out_dir: Path) -> Path:
    fig, axes = plt.subplots(3, 2, figsize=(14, 11), sharex=True)

    axes[0, 0].plot(df["year"], df["Stab"], label="Stab")
    axes[0, 0].plot(df["year"], df["Elite"], label="Elite")
    axes[0, 0].plot(df["year"], df["Loyal"], label="Loyal")
    axes[0, 0].plot(df["year"], df["Info"], label="Info")
    axes[0, 0].legend()
    axes[0, 0].set_title("System polityczny")

    axes[0, 1].plot(df["year"], df["Morale"], label="Morale")
    axes[0, 1].plot(df["year"], df["Protest"], label="Protest")
    axes[0, 1].plot(df["year"], df["EStress"], label="EStress")
    axes[0, 1].legend()
    axes[0, 1].set_title("Społeczeństwo")

    axes[1, 0].plot(df["year"], df["Fiscal"], label="Fiscal")
    axes[1, 0].plot(df["year"], df["OilRevIndex"], label="OilRevIndex")
    axes[1, 0].plot(df["year"], df["War"], label="War")
    axes[1, 0].plot(df["year"], df["Sanctions"], label="Sanctions")
    axes[1, 0].legend()
    axes[1, 0].set_title("Gospodarka")

    axes[1, 1].plot(df["year"], df["Infl"], label="Infl")
    axes[1, 1].plot(df["year"], df["CPI"] / df["CPI"].iloc[0], label="CPI/CPI0")
    axes[1, 1].legend()
    axes[1, 1].set_title("Ceny")

    axes[2, 0].plot(df["year"], df["Troops"], label="Troops")
    axes[2, 0].plot(df["year"], df["Repr"], label="Repr")
    axes[2, 0].legend()
    axes[2, 0].set_title("Bezpieczeństwo")

    axes[2, 1].plot(df["year"], df["Displaced"], label="Displaced")
    axes[2, 1].legend()
    axes[2, 1].set_title("Przesiedlenia")

    out = out_dir / f"plot_{scenario}.png"
    plt.tight_layout()
    plt.savefig(out, dpi=180)
    plt.close()
    return out


def _plot_mc_hist(mc: pd.DataFrame, scenario: str, out_dir: Path) -> Path:
    fig, axes = plt.subplots(2, 3, figsize=(15, 9))
    cols = ["Tcrit", "elite_fracture_prob", "avg_loyal", "peak_protest", "end_displaced_m"]

    for ax, col in zip(axes.flat, cols):
        ax.hist(mc[col], bins=30, alpha=0.85)
        ax.set_title(col)

    axes.flat[-1].axis("off")
    out = out_dir / f"mc_hist_{scenario}.png"
    plt.tight_layout()
    plt.savefig(out, dpi=180)
    plt.close()
    return out


def _summarize_mc(mc: pd.DataFrame) -> dict[str, float]:
    out: dict[str, float] = {"n": int(len(mc))}
    for col in mc.columns:
        out[f"{col}_mean"] = float(mc[col].mean())
        out[f"{col}_median"] = float(mc[col].median())
    return out


def _rep_seeds(cfg: dict[str, object]) -> list[int]:
    return [int(cfg["seed_base"]) + int(cfg["rep_seed_stride"]) * i for i in range(int(cfg["n_reps"]))]


def _eval_gsa_point(param_dict: dict[str, float], cfg: dict[str, object], rep_seeds: list[int]) -> dict[str, float]:
    metrics = [
        run_model(
            params=param_dict,
            seed=seed,
            scenario=str(cfg["scenario"]),
            years=int(cfg["years"]),
            stab_crit=float(cfg["stab_crit"]),
            elite_crit=float(cfg["elite_crit"]),
            elite_streak_weeks=int(cfg["elite_streak_weeks"]),
        )
        for seed in rep_seeds
    ]
    return aggregate_replicates(metrics)


def _save_runtime_config(cfg: dict[str, object], out_dir: Path) -> None:
    save_json(cfg, out_dir / "runtime_config.json")


def run_simulate(cfg: dict[str, object]) -> int:
    out_dir = ensure_dir(cfg["outputs_dir"])
    scenario = str(cfg["scenario"])
    years = int(cfg["years"])
    seed_base = int(cfg["seed_base"])

    _save_runtime_config(cfg, Path(out_dir))

    thresholds = {
        "stab_crit": float(cfg["stab_crit"]),
        "elite_crit": float(cfg["elite_crit"]),
        "elite_streak_weeks": int(cfg["elite_streak_weeks"]),
    }

    params = Params()
    df = simulate(params, scenario=scenario, years=years, seed=seed_base)
    metrics = compute_metrics(df, years=years, **thresholds)

    df.to_csv(Path(out_dir) / f"run_{scenario}.csv", index=False)
    save_json(metrics, Path(out_dir) / f"metrics_{scenario}.json")
    _plot_timeseries(df, scenario, Path(out_dir))

    if bool(cfg["mc_enabled"]):
        mc = monte_carlo(
            base_params=params,
            scenario=scenario,
            years=years,
            n=int(cfg["mc_n"]),
            seed=seed_base,
            spread=float(cfg["mc_spread"]),
            metric_kwargs=thresholds,
        )
        mc.to_csv(Path(out_dir) / "matlab_monte_carlo.csv", index=False)
        save_json(_summarize_mc(mc), Path(out_dir) / f"mc_summary_{scenario}.json")
        _plot_mc_hist(mc, scenario, Path(out_dir))

    print(f"[OK] scenario={scenario} outputs={out_dir}")
    return 0


def run_morris(cfg: dict[str, object]) -> int:
    out_dir = ensure_dir(Path(str(cfg["outputs_dir"])) / "morris")
    _save_runtime_config(cfg, Path(out_dir))

    problem = build_problem_unit_hypercube(GSA_PARAM_NAMES)

    X_unit = morris_sample(
        problem,
        N=int(cfg["morris_trajectories"]),
        num_levels=int(cfg["morris_num_levels"]),
        optimal_trajectories=int(cfg["morris_optimal_trajectories"]),
        local_optimization=bool(cfg["morris_local_optimization"]),
        seed=int(cfg["seed_base"]),
    )
    X_phys, _ = transform_unit_samples_to_params(X_unit)
    rep_seeds = _rep_seeds(cfg)

    def _task(i: int) -> dict[str, float]:
        param_dict = {name: float(X_phys[i, j]) for j, name in enumerate(GSA_PARAM_NAMES)}
        return _eval_gsa_point(param_dict, cfg, rep_seeds)

    Y = pd.DataFrame(
        Parallel(n_jobs=int(cfg["n_jobs"]))(
            delayed(_task)(i) for i in tqdm(range(X_phys.shape[0]))
        )
    )
    Y.to_csv(Path(out_dir) / "morris_model_outputs.csv", index=False)

    analyses: dict[str, object] = {}
    for metric in [c for c in Y.columns if c.endswith("_mean")]:
        y = Y[metric].to_numpy(float)
        if not np.isfinite(y).all() or y.std() < 1e-12:
            analyses[metric] = {"status": "skipped", "std": float(y.std())}
            continue

        Si = morris_analyze(
            problem=problem,
            X=X_unit,
            Y=y,
            num_levels=int(cfg["morris_num_levels"]),
            num_resamples=1000,
            conf_level=0.95,
            seed=int(cfg["seed_base"]),
            print_to_console=False,
        )
        analyses[metric] = {k: (v.tolist() if hasattr(v, "tolist") else v) for k, v in Si.items()}
        plot_morris_bar(
            Si,
            GSA_PARAM_NAMES,
            f"Morris μ* dla {metric}",
            str(Path(out_dir) / f"morris_mu_star_{metric}.png"),
        )

    save_json(analyses, Path(out_dir) / "morris_indices.json")
    print(f"[OK] morris outputs={out_dir}")
    return 0


def run_sobol(cfg: dict[str, object]) -> int:
    out_dir = ensure_dir(Path(str(cfg["outputs_dir"])) / "sobol")
    _save_runtime_config(cfg, Path(out_dir))

    problem = build_problem_unit_hypercube(GSA_PARAM_NAMES)

    X_unit = sobol_sample(
        problem,
        N=int(cfg["sobol_N"]),
        calc_second_order=bool(cfg["sobol_calc_second_order"]),
        scramble=True,
        seed=int(cfg["seed_base"]),
    )
    X_phys, _ = transform_unit_samples_to_params(X_unit)
    rep_seeds = _rep_seeds(cfg)

    def _task(i: int) -> dict[str, float]:
        param_dict = {name: float(X_phys[i, j]) for j, name in enumerate(GSA_PARAM_NAMES)}
        return _eval_gsa_point(param_dict, cfg, rep_seeds)

    Y = pd.DataFrame(
        Parallel(n_jobs=int(cfg["n_jobs"]))(
            delayed(_task)(i) for i in tqdm(range(X_phys.shape[0]))
        )
    )
    Y.to_csv(Path(out_dir) / "sobol_model_outputs.csv", index=False)

    summary: dict[str, object] = {}
    for metric in [c for c in Y.columns if c.endswith("_mean")]:
        y = Y[metric].to_numpy(float)
        if not np.isfinite(y).all() or y.std() < 1e-12:
            summary[metric] = {"status": "skipped", "mean": float(y.mean()), "std": float(y.std())}
            continue

        Si = sobol_analyze(
            problem,
            y,
            calc_second_order=bool(cfg["sobol_calc_second_order"]),
            num_resamples=int(cfg["sobol_num_resamples"]),
            conf_level=float(cfg["sobol_conf_level"]),
            print_to_console=False,
        )

        frame = pd.DataFrame(
            {
                "parameter": GSA_PARAM_NAMES,
                "S1": Si["S1"],
                "S1_conf": Si["S1_conf"],
                "ST": Si["ST"],
                "ST_conf": Si["ST_conf"],
            }
        ).sort_values("ST", ascending=False)

        frame.to_csv(Path(out_dir) / f"sobol_{metric}_main.csv", index=False)
        plot_sobol_bars(
            Si,
            GSA_PARAM_NAMES,
            f"Sobol dla {metric}",
            str(Path(out_dir) / f"sobol_{metric}_bars.png"),
        )
        plot_sobol_s2_heatmap(
            Si,
            GSA_PARAM_NAMES,
            f"Sobol S2 dla {metric}",
            str(Path(out_dir) / f"sobol_{metric}_s2.png"),
        )

        summary[metric] = {
            "status": "ok",
            "mean": float(y.mean()),
            "std": float(y.std()),
            "results": frame.to_dict("records"),
        }

    save_json(summary, Path(out_dir) / "sobol_summary.json")
    print(f"[OK] sobol outputs={out_dir}")
    return 0


def run_bifurcation(data_path: str | Path) -> int:
    path = Path(data_path)
    df = pd.read_csv(path)

    features = ["peak_protest_mean", "mean_stab_mean", "mean_elite_mean", "avg_loyal_mean"]
    target = "elite_fracture_prob_mean"

    missing = [c for c in [*features, target] if c not in df.columns]
    if missing:
        raise RuntimeError(f"Brak kolumn: {', '.join(missing)}")

    y = (df[target] > 0).astype(int)
    X = df[features]

    model = LogisticRegression(max_iter=2000)
    model.fit(X, y)

    coef_peak = float(model.coef_[0][0])
    intercept = float(model.intercept_[0])
    threshold = float("nan") if abs(coef_peak) < 1e-12 else -intercept / coef_peak

    print("--- SUMMARY ---")
    print("samples:", len(df))
    print("mean protest:", float(df["peak_protest_mean"].mean()))
    print("std protest:", float(df["peak_protest_mean"].std()))
    print("elite fracture probability:", float(df[target].mean()))
    print("mean stability:", float(df["mean_stab_mean"].mean()))
    print("mean elite:", float(df["mean_elite_mean"].mean()))
    print("--- BIFURCATION ESTIMATE ---")
    print("critical protest intensity ≈", threshold)
    print("Model coefficients:")
    for name, coef in zip(features, model.coef_[0]):
        print(name, "=", round(float(coef), 4))
    print("intercept =", round(intercept, 4))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Jednolity CLI projektu")
    parser.add_argument("--config", default="config/config.yaml")

    subparsers = parser.add_subparsers(dest="command", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--scenario", choices=sorted(SUPPORTED_SCENARIOS))
    common.add_argument("--years", type=int)
    common.add_argument("--seed-base", dest="seed_base", type=int)
    common.add_argument("--rep-seed-stride", dest="rep_seed_stride", type=int)
    common.add_argument("--stab-crit", dest="stab_crit", type=float)
    common.add_argument("--elite-crit", dest="elite_crit", type=float)
    common.add_argument("--elite-streak-weeks", dest="elite_streak_weeks", type=int)
    common.add_argument("--n-jobs", dest="n_jobs", type=int)
    common.add_argument("--out-dir", dest="outputs_dir")
    common.add_argument("--model-name", dest="model_name")

    simulate_p = subparsers.add_parser(
        "simulate",
        parents=[common],
        help="Uruchom pojedynczą symulację i opcjonalnie MC",
    )
    simulate_p.add_argument("--mc-enabled", dest="mc_enabled", action="store_true")
    simulate_p.add_argument("--no-mc", dest="mc_enabled", action="store_false")
    simulate_p.add_argument("--mc", dest="mc_n", type=int)
    simulate_p.add_argument("--spread", dest="mc_spread", type=float)
    simulate_p.set_defaults(mc_enabled=None)

    morris_p = subparsers.add_parser(
        "morris",
        parents=[common],
        help="Uruchom screening Morrisa",
    )
    morris_p.add_argument("--n-reps", dest="n_reps", type=int)
    morris_p.add_argument("--morris-num-levels", dest="morris_num_levels", type=int)
    morris_p.add_argument("--morris-trajectories", dest="morris_trajectories", type=int)
    morris_p.add_argument("--morris-optimal-trajectories", dest="morris_optimal_trajectories", type=int)
    morris_p.add_argument("--morris-local-optimization", dest="morris_local_optimization", action="store_true")
    morris_p.add_argument("--no-morris-local-optimization", dest="morris_local_optimization", action="store_false")
    morris_p.set_defaults(morris_local_optimization=None)

    sobol_p = subparsers.add_parser(
        "sobol",
        parents=[common],
        help="Uruchom analizę Sobola",
    )
    sobol_p.add_argument("--n-reps", dest="n_reps", type=int)
    sobol_p.add_argument("--sobol-N", dest="sobol_N", type=int)
    sobol_p.add_argument("--sobol-calc-second-order", dest="sobol_calc_second_order", action="store_true")
    sobol_p.add_argument("--no-sobol-calc-second-order", dest="sobol_calc_second_order", action="store_false")
    sobol_p.set_defaults(sobol_calc_second_order=None)
    sobol_p.add_argument("--sobol-num-resamples", dest="sobol_num_resamples", type=int)
    sobol_p.add_argument("--sobol-conf-level", dest="sobol_conf_level", type=float)

    bif_p = subparsers.add_parser("bifurcation", help="Estymacja bifurkacji z danych Sobola")
    bif_p.add_argument("--data", default="outputs/sobol/sobol_model_outputs.csv")

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    # bifurcation nie wymaga config.yaml
    if args.command == "bifurcation":
        return run_bifurcation(args.data)

    raw_overrides = {
        k: v
        for k, v in vars(args).items()
        if k not in {"command", "config", "data"}
    }

    cfg = load_runtime_config(args.config, raw_overrides)

    if args.command == "simulate":
        return run_simulate(cfg)
    if args.command == "morris":
        return run_morris(cfg)
    if args.command == "sobol":
        return run_sobol(cfg)

    parser.error(f"Nieznana komenda: {args.command}")
    return 2