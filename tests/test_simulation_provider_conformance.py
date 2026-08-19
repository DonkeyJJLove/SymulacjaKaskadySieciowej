from __future__ import annotations

import dataclasses
import inspect
import unittest
from unittest.mock import patch

from abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider import (
    DomainExecutionConfig,
    IranCascadeSimulationProvider,
)
from abstrakcyjna_symulacja_kaskady_sieciowej.simulation_contracts import (
    EpistemicClass,
    ModelRiskStatement,
    SeedProvenance,
    SimulationContractError,
    SimulationProvider,
    SimulationRequest,
    SimulationResult,
    contract_field_names,
)


def make_request(provider: IranCascadeSimulationProvider) -> SimulationRequest:
    config = provider.execution_config()
    return SimulationRequest.from_parameters(
        descriptor=provider.descriptor(),
        scenario_id="impas",
        configuration_id=config.configuration_id,
        configuration_digest=config.digest(),
        parameters={},
        seed=SeedProvenance("fixed-single", (12345,)),
    )


def fabricated_result(provider: IranCascadeSimulationProvider) -> SimulationResult:
    return SimulationResult(
        request=make_request(provider),
        output_hashes=("1" * 64,),
        epistemic_class=EpistemicClass.SIMULATED,
    ).validate()


def issued_result(provider: IranCascadeSimulationProvider) -> SimulationResult:
    with patch(
        "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider.run_model",
        return_value={"metric": 1.0},
    ):
        return provider.run(make_request(provider))


class SimulationProviderConformanceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.provider = IranCascadeSimulationProvider()

    def test_provider_protocol_requires_model_risk_statement(self):
        method = getattr(SimulationProvider, "model_risk_statement", None)
        self.assertIsNotNone(method)
        self.assertEqual(list(inspect.signature(method).parameters), ["self", "result"])

    def test_provider_risk_statement_binds_exact_result_and_preserves_descriptor_risk(self):
        result = issued_result(self.provider)
        statement = self.provider.model_risk_statement(result)
        descriptor = self.provider.descriptor()
        self.assertEqual(statement.result_digest, result.result_digest())
        self.assertTrue(set(descriptor.assumptions).issubset(statement.assumptions))
        self.assertTrue(set(descriptor.limitations).issubset(statement.limitations))
        self.assertGreaterEqual(len(statement.known_failure_modes), 3)
        statement.validate_against(result)

    def test_fabricated_same_provider_result_must_fail(self):
        result = fabricated_result(self.provider)
        with self.assertRaisesRegex(SimulationContractError, "not issued by this provider instance"):
            self.provider.model_risk_statement(result)

    def test_foreign_descriptor_result_substitution_fails_closed(self):
        result = issued_result(self.provider)
        foreign_descriptor = dataclasses.replace(result.request.descriptor, model_version="foreign")
        foreign_request = dataclasses.replace(result.request, descriptor=foreign_descriptor).validate()
        foreign_result = dataclasses.replace(result, request=foreign_request).validate()
        with self.assertRaises(SimulationContractError):
            self.provider.model_risk_statement(foreign_result)

    def test_foreign_execution_configuration_result_substitution_fails_closed(self):
        foreign_provider = IranCascadeSimulationProvider(DomainExecutionConfig(years=2))
        foreign_result = issued_result(foreign_provider)
        with self.assertRaises(SimulationContractError):
            self.provider.model_risk_statement(foreign_result)

    def test_model_risk_disclosure_does_not_reexecute_domain_model(self):
        result = issued_result(self.provider)
        with patch(
            "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider.run_model",
            side_effect=AssertionError("model-risk disclosure must not execute the model"),
        ) as mocked:
            statement = self.provider.model_risk_statement(result)
        mocked.assert_not_called()
        self.assertEqual(statement.result_digest, result.result_digest())

    def test_model_risk_statement_cannot_validate_against_another_result_digest(self):
        result = issued_result(self.provider)
        statement = self.provider.model_risk_statement(result)
        other_request = dataclasses.replace(
            result.request,
            seed=SeedProvenance("fixed-single", (54321,)).validate(),
        ).validate()
        other_result = dataclasses.replace(result, request=other_request).validate()
        with self.assertRaises(SimulationContractError):
            statement.validate_against(other_result)

    def test_mutated_output_hash_after_issuance_fails(self):
        result = issued_result(self.provider)
        mutated = dataclasses.replace(result, output_hashes=("2" * 64,)).validate()
        with self.assertRaisesRegex(SimulationContractError, "not issued by this provider instance"):
            self.provider.model_risk_statement(mutated)

    def test_result_issued_by_second_identical_provider_instance_fails(self):
        result = issued_result(self.provider)
        second_provider = IranCascadeSimulationProvider()
        self.assertEqual(second_provider.descriptor(), self.provider.descriptor())
        self.assertEqual(second_provider.execution_config(), self.provider.execution_config())
        with self.assertRaisesRegex(SimulationContractError, "not issued by this provider instance"):
            second_provider.model_risk_statement(result)

    def test_provider_rejects_epistemic_class_it_cannot_emit(self):
        result = issued_result(self.provider)
        derived = dataclasses.replace(result, epistemic_class=EpistemicClass.DERIVED).validate()
        with self.assertRaisesRegex(SimulationContractError, "only issues SIMULATED"):
            self.provider.model_risk_statement(derived)

    def test_reconstructed_exact_issued_result_digest_is_accepted(self):
        result = issued_result(self.provider)
        reconstructed = SimulationResult(
            request=result.request,
            output_hashes=tuple(result.output_hashes),
            epistemic_class=result.epistemic_class,
        ).validate()
        self.assertIsNot(reconstructed, result)
        self.assertEqual(reconstructed.result_digest(), result.result_digest())
        statement = self.provider.model_risk_statement(reconstructed)
        self.assertEqual(statement.result_digest, result.result_digest())

    def test_conformance_preserves_epistemic_and_authority_boundary(self):
        result = issued_result(self.provider)
        self.assertIs(result.epistemic_class, EpistemicClass.SIMULATED)
        self.assertNotEqual(result.epistemic_class.value, "OBSERVED")
        forbidden = {"authority", "authority_grant", "capability", "capabilities", "permission"}
        for contract_type in (SimulationResult, ModelRiskStatement):
            self.assertTrue(contract_field_names(contract_type).isdisjoint(forbidden), contract_type.__name__)
        statement = self.provider.model_risk_statement(result)
        self.assertTrue(contract_field_names(type(statement)).isdisjoint(forbidden))


if __name__ == "__main__":
    unittest.main()
