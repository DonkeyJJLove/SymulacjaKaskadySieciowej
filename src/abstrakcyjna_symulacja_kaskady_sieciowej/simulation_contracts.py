"""Generic, effect-free contracts for reproducible simulation providers.

These contracts preserve simulation provenance and epistemic class. They do
not grant authority, capabilities, or permission to perform external effects.
"""
from __future__ import annotations

from dataclasses import dataclass, fields
from enum import Enum
import hashlib
import json
import math
import re
from typing import Any, Mapping, Protocol

_REPOSITORY_RE = re.compile(r"^[^/\s]+/[^/\s]+$")
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_GIT_COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
_SEED_STRATEGIES = {"fixed-single", "explicit-set", "derived-sequence"}


class SimulationContractError(ValueError):
    """Raised when a simulation contract would lose required provenance."""


class EpistemicClass(str, Enum):
    SIMULATED = "SIMULATED"
    DERIVED = "DERIVED"


def _text(name: str, value: Any) -> str:
    if not isinstance(value, str) or not value.strip():
        raise SimulationContractError(f"{name} must be a non-empty string")
    return value


def _text_tuple(name: str, values: Any) -> tuple[str, ...]:
    if not isinstance(values, tuple) or not values:
        raise SimulationContractError(f"{name} must be a non-empty tuple")
    if any(not isinstance(value, str) or not value.strip() for value in values):
        raise SimulationContractError(f"{name} entries must be non-empty strings")
    return values


def _json_safe(value: Any) -> None:
    if isinstance(value, bool) or value is None or isinstance(value, str):
        return
    if isinstance(value, int):
        return
    if isinstance(value, float):
        if not math.isfinite(value):
            raise SimulationContractError("non-finite values are not canonical")
        return
    if isinstance(value, list):
        for item in value:
            _json_safe(item)
        return
    if isinstance(value, dict):
        if any(not isinstance(key, str) or not key for key in value):
            raise SimulationContractError("parameter keys must be non-empty strings")
        for item in value.values():
            _json_safe(item)
        return
    raise SimulationContractError(f"unsupported canonical JSON value: {type(value).__name__}")


def canonical_json_object(value: Mapping[str, Any]) -> str:
    """Return stable JSON for an input object, rejecting ambiguous values."""
    if not isinstance(value, Mapping):
        raise SimulationContractError("parameters must be a mapping")
    copied = dict(value)
    _json_safe(copied)
    return json.dumps(copied, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _canonical_object_json(name: str, value: Any) -> str:
    if not isinstance(value, str):
        raise SimulationContractError(f"{name} must be canonical object JSON")
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError as exc:
        raise SimulationContractError(f"{name} must be canonical object JSON") from exc
    if not isinstance(parsed, dict) or canonical_json_object(parsed) != value:
        raise SimulationContractError(f"{name} must be canonical object JSON")
    return value


def _digest(payload: Mapping[str, Any]) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


@dataclass(frozen=True)
class ModelDescriptor:
    model_id: str
    model_version: str
    source_repository: str
    source_commit: str
    source_ref: str
    domain_of_validity: str
    assumptions: tuple[str, ...]
    limitations: tuple[str, ...]

    def validate(self) -> "ModelDescriptor":
        for name in ("model_id", "model_version", "source_repository", "source_ref", "domain_of_validity"):
            _text(name, getattr(self, name))
        if not _REPOSITORY_RE.fullmatch(self.source_repository):
            raise SimulationContractError("source_repository must use owner/name form")
        if not isinstance(self.source_commit, str) or not _GIT_COMMIT_RE.fullmatch(self.source_commit):
            raise SimulationContractError("source_commit must be an exact lowercase 40-hex commit")
        _text_tuple("assumptions", self.assumptions)
        _text_tuple("limitations", self.limitations)
        return self

    def canonical_dict(self) -> dict[str, Any]:
        self.validate()
        return {
            "model_id": self.model_id,
            "model_version": self.model_version,
            "source_repository": self.source_repository,
            "source_commit": self.source_commit,
            "source_ref": self.source_ref,
            "domain_of_validity": self.domain_of_validity,
            "assumptions": list(self.assumptions),
            "limitations": list(self.limitations),
        }


@dataclass(frozen=True)
class SeedProvenance:
    """Exact execution seeds plus derivation metadata when a sequence was derived.

    `seeds` always stores the fully materialized seed sequence actually consumed by
    the provider. `derived-sequence` additionally records how that exact sequence
    was derived so provenance is reconstructable rather than provider-defined.
    """

    strategy: str
    seeds: tuple[int, ...]
    root_seed: int | None = None
    derivation_algorithm: str | None = None
    derivation_version: str | None = None
    derivation_parameters_json: str | None = None

    def validate(self) -> "SeedProvenance":
        if self.strategy not in _SEED_STRATEGIES:
            raise SimulationContractError("seed strategy is not explicit/recognized")
        if not isinstance(self.seeds, tuple) or not self.seeds:
            raise SimulationContractError("at least one execution seed is required")
        if any(isinstance(seed, bool) or not isinstance(seed, int) or seed < 0 for seed in self.seeds):
            raise SimulationContractError("execution seeds must be non-negative integers")

        derivation_fields = (
            self.root_seed,
            self.derivation_algorithm,
            self.derivation_version,
            self.derivation_parameters_json,
        )
        if self.strategy == "fixed-single":
            if len(self.seeds) != 1:
                raise SimulationContractError("fixed-single requires exactly one seed")
            if any(value is not None for value in derivation_fields):
                raise SimulationContractError("fixed-single cannot carry derivation metadata")
        elif self.strategy == "explicit-set":
            if any(value is not None for value in derivation_fields):
                raise SimulationContractError("explicit-set cannot carry derivation metadata")
        else:
            if isinstance(self.root_seed, bool) or not isinstance(self.root_seed, int) or self.root_seed < 0:
                raise SimulationContractError("derived-sequence requires a non-negative root_seed")
            _text("derivation_algorithm", self.derivation_algorithm)
            _text("derivation_version", self.derivation_version)
            _canonical_object_json("derivation_parameters_json", self.derivation_parameters_json)
        return self

    def canonical_dict(self) -> dict[str, Any]:
        self.validate()
        payload: dict[str, Any] = {"strategy": self.strategy, "seeds": list(self.seeds)}
        if self.strategy == "derived-sequence":
            payload["derivation"] = {
                "root_seed": self.root_seed,
                "algorithm": self.derivation_algorithm,
                "version": self.derivation_version,
                "parameters": json.loads(self.derivation_parameters_json or "{}"),
            }
        return payload


@dataclass(frozen=True)
class SimulationRequest:
    descriptor: ModelDescriptor
    scenario_id: str
    configuration_id: str
    configuration_digest: str
    parameters_json: str
    seed: SeedProvenance

    @classmethod
    def from_parameters(
        cls,
        *,
        descriptor: ModelDescriptor,
        scenario_id: str,
        configuration_id: str,
        configuration_digest: str,
        parameters: Mapping[str, Any],
        seed: SeedProvenance,
    ) -> "SimulationRequest":
        return cls(
            descriptor=descriptor,
            scenario_id=scenario_id,
            configuration_id=configuration_id,
            configuration_digest=configuration_digest,
            parameters_json=canonical_json_object(parameters),
            seed=seed,
        ).validate()

    def validate(self) -> "SimulationRequest":
        self.descriptor.validate()
        self.seed.validate()
        _text("scenario_id", self.scenario_id)
        _text("configuration_id", self.configuration_id)
        if not isinstance(self.configuration_digest, str) or not _SHA256_RE.fullmatch(self.configuration_digest):
            raise SimulationContractError("configuration_digest must be lowercase sha256")
        try:
            parsed = json.loads(self.parameters_json)
        except (TypeError, json.JSONDecodeError) as exc:
            raise SimulationContractError("parameters_json must be canonical JSON") from exc
        if not isinstance(parsed, dict) or canonical_json_object(parsed) != self.parameters_json:
            raise SimulationContractError("parameters_json is not canonical object JSON")
        return self

    def canonical_dict(self) -> dict[str, Any]:
        self.validate()
        return {
            "descriptor": self.descriptor.canonical_dict(),
            "scenario_id": self.scenario_id,
            "configuration_id": self.configuration_id,
            "configuration_digest": self.configuration_digest,
            "parameters": json.loads(self.parameters_json),
            "seed": self.seed.canonical_dict(),
        }

    def provenance_digest(self) -> str:
        return _digest(self.canonical_dict())


@dataclass(frozen=True)
class SimulationResult:
    request: SimulationRequest
    output_hashes: tuple[str, ...]
    epistemic_class: EpistemicClass

    def validate(self) -> "SimulationResult":
        self.request.validate()
        if not isinstance(self.output_hashes, tuple) or not self.output_hashes:
            raise SimulationContractError("at least one output hash is required")
        if any(not isinstance(value, str) or not _SHA256_RE.fullmatch(value) for value in self.output_hashes):
            raise SimulationContractError("output hashes must be lowercase sha256")
        if not isinstance(self.epistemic_class, EpistemicClass):
            raise SimulationContractError("epistemic_class must be an EpistemicClass value")
        if self.epistemic_class not in (EpistemicClass.SIMULATED, EpistemicClass.DERIVED):
            raise SimulationContractError("simulation results may only be SIMULATED or DERIVED")
        return self

    def result_digest(self) -> str:
        self.validate()
        return _digest(
            {
                "request_provenance_digest": self.request.provenance_digest(),
                "output_hashes": list(self.output_hashes),
                "epistemic_class": self.epistemic_class.value,
            }
        )


@dataclass(frozen=True)
class ModelRiskStatement:
    result_digest: str
    assumptions: tuple[str, ...]
    limitations: tuple[str, ...]
    known_failure_modes: tuple[str, ...]

    def validate_against(self, result: SimulationResult) -> "ModelRiskStatement":
        result.validate()
        if self.result_digest != result.result_digest():
            raise SimulationContractError("model-risk statement is not bound to this result")
        _text_tuple("assumptions", self.assumptions)
        _text_tuple("limitations", self.limitations)
        _text_tuple("known_failure_modes", self.known_failure_modes)
        return self


class SimulationProvider(Protocol):
    def descriptor(self) -> ModelDescriptor: ...

    def run(self, request: SimulationRequest) -> SimulationResult: ...

    def model_risk_statement(self, result: SimulationResult) -> ModelRiskStatement: ...


def contract_field_names(contract_type: type[Any]) -> set[str]:
    """Expose contract shape for invariant tests without implementation coupling."""
    return {item.name for item in fields(contract_type)}
