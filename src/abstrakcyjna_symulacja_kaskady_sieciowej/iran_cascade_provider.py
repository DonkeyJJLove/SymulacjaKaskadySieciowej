"""Effect-free adapter from the Iran cascade domain model to SimulationProvider."""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import math
from typing import Any, Mapping

from .config import SUPPORTED_SCENARIOS
from .model_interface import default_params_dict, run_model
from .simulation_contracts import (
    EpistemicClass,
    ModelDescriptor,
    SimulationContractError,
    SimulationRequest,
    SimulationResult,
)

MODEL_ID = "iran-cascade-system-dynamics"
MODEL_VERSION = "0.1.0"
MODEL_SOURCE_REPOSITORY = "DonkeyJJLove/SymulacjaKaskadySieciowej"
MODEL_SOURCE_COMMIT = "50bec9e781bb9df0da7c2e302107386553096728"
MODEL_SOURCE_REF = "refs/heads/main"


@dataclass(frozen=True)
class DomainExecutionConfig:
    configuration_id: str = "iran-cascade-deterministic-v1"
    years: int = 3
    stab_crit: float = 0.30
    elite_crit: float = 0.35
    elite_streak_weeks: int = 4

    def validate(self) -> "DomainExecutionConfig":
        if not isinstance(self.configuration_id, str) or not self.configuration_id.strip():
            raise SimulationContractError("configuration_id must be a non-empty string")
        if isinstance(self.years, bool) or not isinstance(self.years, int) or self.years <= 0:
            raise SimulationContractError("years must be a positive integer")
        if (
            isinstance(self.elite_streak_weeks, bool)
            or not isinstance(self.elite_streak_weeks, int)
            or self.elite_streak_weeks <= 0
        ):
            raise SimulationContractError("elite_streak_weeks must be a positive integer")
        for name in ("stab_crit", "elite_crit"):
            value = getattr(self, name)
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                raise SimulationContractError(f"{name} must be numeric")
            numeric = float(value)
            if not math.isfinite(numeric) or not 0.0 <= numeric <= 1.0:
                raise SimulationContractError(f"{name} must be finite and within [0,1]")
        return self

    def execution_dict(self) -> dict[str, Any]:
        self.validate()
        return {
            "elite_crit": float(self.elite_crit),
            "elite_streak_weeks": self.elite_streak_weeks,
            "stab_crit": float(self.stab_crit),
            "years": self.years,
        }

    def digest(self) -> str:
        raw = json.dumps(
            self.execution_dict(), sort_keys=True, separators=(",", ":"), ensure_ascii=False
        ).encode("utf-8")
        return hashlib.sha256(raw).hexdigest()


DEFAULT_EXECUTION_CONFIG = DomainExecutionConfig().validate()


def canonical_metrics_json(metrics: Mapping[str, Any]) -> str:
    if not isinstance(metrics, Mapping) or not metrics:
        raise SimulationContractError("domain metrics must be a non-empty mapping")
    normalized: dict[str, float] = {}
    for key, value in metrics.items():
        if not isinstance(key, str) or not key:
            raise SimulationContractError("domain metric names must be non-empty strings")
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise SimulationContractError(f"metric {key} must be numeric")
        try:
            numeric = float(value)
        except (OverflowError, ValueError) as exc:
            raise SimulationContractError(f"metric {key} is not canonical numeric data") from exc
        if not math.isfinite(numeric):
            raise SimulationContractError(f"metric {key} must be finite")
        normalized[key] = numeric
    return json.dumps(normalized, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def metrics_digest(metrics: Mapping[str, Any]) -> str:
    return hashlib.sha256(canonical_metrics_json(metrics).encode("utf-8")).hexdigest()


def _validate_domain_parameters(parameters: Mapping[str, Any]) -> dict[str, float]:
    allowed = set(default_params_dict())
    normalized: dict[str, float] = {}
    unknown = sorted(set(parameters) - allowed)
    if unknown:
        raise SimulationContractError(f"unknown domain parameter(s): {unknown}")
    for key, value in parameters.items():
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise SimulationContractError(f"domain parameter {key} must be numeric and not bool")
        try:
            numeric = float(value)
        except (OverflowError, ValueError) as exc:
            raise SimulationContractError(f"domain parameter {key} is not canonical numeric data") from exc
        if not math.isfinite(numeric):
            raise SimulationContractError(f"domain parameter {key} must be finite")
        normalized[key] = numeric
    return normalized


class IranCascadeSimulationProvider:
    """Thin adapter. It does not alter model equations or promote simulation authority."""

    def __init__(self, execution_config: DomainExecutionConfig = DEFAULT_EXECUTION_CONFIG) -> None:
        self._execution_config = execution_config.validate()

    def descriptor(self) -> ModelDescriptor:
        return ModelDescriptor(
            model_id=MODEL_ID,
            model_version=MODEL_VERSION,
            source_repository=MODEL_SOURCE_REPOSITORY,
            source_commit=MODEL_SOURCE_COMMIT,
            source_ref=MODEL_SOURCE_REF,
            domain_of_validity="Iran-specific system-dynamics research model; scenario analysis, not an empirical forecast",
            assumptions=(
                "domain equations and parameters define a research model world",
                "execution configuration is bound by identifier and digest",
            ),
            limitations=(
                "simulation outputs are not empirical observations or forecasts",
                "seed provenance is preserved even when current deterministic equations do not consume RNG state",
            ),
        ).validate()

    def execution_config(self) -> DomainExecutionConfig:
        return self._execution_config

    def _validate_request(self, request: SimulationRequest) -> dict[str, float]:
        request.validate()
        if request.descriptor != self.descriptor():
            raise SimulationContractError("request model descriptor does not match this provider")
        if request.configuration_id != self._execution_config.configuration_id:
            raise SimulationContractError("request configuration_id does not match this provider")
        if request.configuration_digest != self._execution_config.digest():
            raise SimulationContractError("request configuration_digest does not match this provider")
        if request.scenario_id not in SUPPORTED_SCENARIOS:
            raise SimulationContractError("scenario is not supported by the Iran cascade provider")
        parameters = json.loads(request.parameters_json)
        return _validate_domain_parameters(parameters)

    def run(self, request: SimulationRequest) -> SimulationResult:
        parameters = self._validate_request(request)
        output_hashes: list[str] = []
        for seed in request.seed.seeds:
            metrics = run_model(
                params=parameters,
                seed=seed,
                scenario=request.scenario_id,
                years=self._execution_config.years,
                stab_crit=float(self._execution_config.stab_crit),
                elite_crit=float(self._execution_config.elite_crit),
                elite_streak_weeks=self._execution_config.elite_streak_weeks,
            )
            output_hashes.append(metrics_digest(metrics))
        return SimulationResult(
            request=request,
            output_hashes=tuple(output_hashes),
            epistemic_class=EpistemicClass.SIMULATED,
        ).validate()
