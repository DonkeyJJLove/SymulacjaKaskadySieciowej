from __future__ import annotations

import dataclasses
import hashlib
import unittest

from abstrakcyjna_symulacja_kaskady_sieciowej.simulation_contracts import (
    EpistemicClass,
    ModelDescriptor,
    ModelRiskStatement,
    SeedProvenance,
    SimulationContractError,
    SimulationRequest,
    SimulationResult,
    contract_field_names,
)

BASE_COMMIT = "d25fcaa26221bb542f7ff5776fb8f6824bf27cc5"
CONFIG_DIGEST = hashlib.sha256(b"config:v1").hexdigest()
OUTPUT_DIGEST = hashlib.sha256(b"output:v1").hexdigest()


def descriptor() -> ModelDescriptor:
    return ModelDescriptor(
        model_id="iran-cascade",
        model_version="0.1.0",
        source_repository="DonkeyJJLove/SymulacjaKaskadySieciowej",
        source_commit=BASE_COMMIT,
        source_ref="refs/heads/main",
        domain_of_validity="domain-specific research simulation; not a forecast",
        assumptions=("equations and parameters define a model world",),
        limitations=("simulation frequency is not empirical probability",),
    ).validate()


def request(parameters=None) -> SimulationRequest:
    return SimulationRequest.from_parameters(
        descriptor=descriptor(),
        scenario_id="impas",
        configuration_id="default-v1",
        configuration_digest=CONFIG_DIGEST,
        parameters=parameters or {"years": 1, "threshold": 0.25},
        seed=SeedProvenance("fixed-single", (12345,)),
    )


class SimulationContractTests(unittest.TestCase):
    def test_descriptor_requires_model_source_domain_assumptions_and_limitations(self):
        base = descriptor()
        mutations = {
            "model_id": "",
            "model_version": "",
            "source_repository": "not-a-repository",
            "source_commit": "a" * 39,
            "source_ref": "",
            "domain_of_validity": "",
            "assumptions": (),
            "limitations": (),
        }
        for field, value in mutations.items():
            with self.subTest(field=field), self.assertRaises(SimulationContractError):
                dataclasses.replace(base, **{field: value}).validate()

    def test_seed_strategy_is_explicit_and_bounded(self):
        SeedProvenance("fixed-single", (12345,)).validate()
        SeedProvenance("explicit-set", (1, 2, 3)).validate()
        SeedProvenance("derived-sequence", (7,)).validate()
        for invalid in (
            SeedProvenance("unknown", (1,)),
            SeedProvenance("fixed-single", (1, 2)),
            SeedProvenance("explicit-set", ()),
            SeedProvenance("fixed-single", (-1,)),
            SeedProvenance("fixed-single", (True,)),
        ):
            with self.assertRaises(SimulationContractError):
                invalid.validate()

    def test_scenario_configuration_and_seed_provenance_are_reconstructable(self):
        item = request()
        payload = item.canonical_dict()
        self.assertEqual(payload["descriptor"]["source_commit"], BASE_COMMIT)
        self.assertEqual(payload["scenario_id"], "impas")
        self.assertEqual(payload["configuration_id"], "default-v1")
        self.assertEqual(payload["configuration_digest"], CONFIG_DIGEST)
        self.assertEqual(payload["seed"], {"strategy": "fixed-single", "seeds": [12345]})

    def test_equal_semantic_inputs_have_equal_canonical_provenance_digest(self):
        first = request({"alpha": 1, "nested": {"z": 2, "a": [3, 4]}})
        second = request({"nested": {"a": [3, 4], "z": 2}, "alpha": 1})
        self.assertEqual(first.parameters_json, second.parameters_json)
        self.assertEqual(first.provenance_digest(), second.provenance_digest())

    def test_noncanonical_or_ambiguous_parameter_values_fail_closed(self):
        with self.assertRaises(SimulationContractError):
            request({"bad": float("nan")})
        with self.assertRaises(SimulationContractError):
            request({"bad": object()})
        base = request()
        with self.assertRaises(SimulationContractError):
            dataclasses.replace(base, parameters_json='{"b":2, "a":1}').validate()

    def test_invalid_configuration_digest_fails_closed(self):
        base = request()
        with self.assertRaises(SimulationContractError):
            dataclasses.replace(base, configuration_digest="not-sha256").validate()

    def test_result_is_simulated_or_derived_never_observed(self):
        simulated = SimulationResult(request(), (OUTPUT_DIGEST,), EpistemicClass.SIMULATED).validate()
        derived = SimulationResult(request(), (OUTPUT_DIGEST,), EpistemicClass.DERIVED).validate()
        self.assertNotEqual(simulated.epistemic_class.value, "OBSERVED")
        self.assertNotEqual(derived.epistemic_class.value, "OBSERVED")
        with self.assertRaises(SimulationContractError):
            SimulationResult(request(), (OUTPUT_DIGEST,), "OBSERVED").validate()  # type: ignore[arg-type]

    def test_result_preserves_exact_model_config_seed_and_output_provenance(self):
        result = SimulationResult(request(), (OUTPUT_DIGEST,), EpistemicClass.SIMULATED).validate()
        self.assertEqual(result.request.descriptor.source_commit, BASE_COMMIT)
        self.assertEqual(result.request.configuration_digest, CONFIG_DIGEST)
        self.assertEqual(result.request.seed.seeds, (12345,))
        self.assertEqual(result.output_hashes, (OUTPUT_DIGEST,))
        self.assertEqual(len(result.result_digest()), 64)

    def test_model_risk_statement_must_bind_to_exact_result(self):
        result = SimulationResult(request(), (OUTPUT_DIGEST,), EpistemicClass.SIMULATED).validate()
        statement = ModelRiskStatement(
            result.result_digest(),
            assumptions=("model structure is assumed",),
            limitations=("convergence does not establish model correctness",),
            known_failure_modes=("parameter regime may leave the domain of validity",),
        ).validate_against(result)
        self.assertEqual(statement.result_digest, result.result_digest())
        with self.assertRaises(SimulationContractError):
            dataclasses.replace(statement, result_digest="0" * 64).validate_against(result)

    def test_contracts_do_not_contain_authority_or_capability_semantics(self):
        forbidden = {"authority", "authority_grant", "capability", "capabilities", "permission"}
        for contract_type in (ModelDescriptor, SeedProvenance, SimulationRequest, SimulationResult, ModelRiskStatement):
            self.assertTrue(contract_field_names(contract_type).isdisjoint(forbidden), contract_type.__name__)

    def test_invalid_result_output_hash_fails_closed(self):
        with self.assertRaises(SimulationContractError):
            SimulationResult(request(), ("not-a-hash",), EpistemicClass.SIMULATED).validate()


if __name__ == "__main__":
    unittest.main()
