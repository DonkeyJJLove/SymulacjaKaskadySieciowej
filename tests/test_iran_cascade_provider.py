from __future__ import annotations

import dataclasses
import unittest
from unittest.mock import patch

from abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider import (
    DEFAULT_EXECUTION_CONFIG,
    MODEL_ID,
    MODEL_SOURCE_COMMIT,
    MODEL_SOURCE_REF,
    MODEL_SOURCE_REPOSITORY,
    MODEL_VERSION,
    DomainExecutionConfig,
    IranCascadeSimulationProvider,
    metrics_digest,
)
from abstrakcyjna_symulacja_kaskady_sieciowej.model_interface import run_model as domain_run_model
from abstrakcyjna_symulacja_kaskady_sieciowej.simulation_contracts import (
    EpistemicClass,
    SeedProvenance,
    SimulationContractError,
    SimulationRequest,
)

BASELINE = "50bec9e781bb9df0da7c2e302107386553096728"


def make_request(
    provider: IranCascadeSimulationProvider,
    *,
    descriptor=None,
    scenario: str = "impas",
    parameters=None,
    seed: SeedProvenance | None = None,
    configuration_id: str | None = None,
    configuration_digest: str | None = None,
) -> SimulationRequest:
    config = provider.execution_config()
    return SimulationRequest.from_parameters(
        descriptor=descriptor or provider.descriptor(),
        scenario_id=scenario,
        configuration_id=configuration_id or config.configuration_id,
        configuration_digest=configuration_digest or config.digest(),
        parameters={} if parameters is None else parameters,
        seed=seed or SeedProvenance("fixed-single", (12345,)),
    )


class IranCascadeProviderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.provider = IranCascadeSimulationProvider()

    def test_descriptor_binds_exact_domain_model_source(self):
        item = self.provider.descriptor()
        self.assertEqual(item.model_id, MODEL_ID)
        self.assertEqual(item.model_version, MODEL_VERSION)
        self.assertEqual(item.source_repository, MODEL_SOURCE_REPOSITORY)
        self.assertEqual(item.source_commit, MODEL_SOURCE_COMMIT)
        self.assertEqual(item.source_commit, BASELINE)
        self.assertEqual(item.source_ref, MODEL_SOURCE_REF)

    def test_descriptor_substitution_fails_before_domain_execution(self):
        bad = dataclasses.replace(self.provider.descriptor(), model_version="other")
        request = make_request(self.provider, descriptor=bad)
        with patch(
            "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider.run_model"
        ) as mocked:
            with self.assertRaises(SimulationContractError):
                self.provider.run(request)
            mocked.assert_not_called()

    def test_configuration_identifier_and_digest_are_exactly_bound(self):
        for request in (
            make_request(self.provider, configuration_id="other-config"),
            make_request(self.provider, configuration_digest="0" * 64),
        ):
            with self.subTest(request=request), patch(
                "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider.run_model"
            ) as mocked:
                with self.assertRaises(SimulationContractError):
                    self.provider.run(request)
                mocked.assert_not_called()

    def test_execution_config_digest_is_deterministic_and_execution_scoped(self):
        first = DomainExecutionConfig().validate()
        second = DomainExecutionConfig().validate()
        self.assertEqual(first.digest(), second.digest())
        self.assertNotEqual(first.digest(), dataclasses.replace(first, years=2).digest())
        self.assertNotIn("configuration_id", first.execution_dict())

    def test_unsupported_scenario_is_rejected_before_domain_fallback(self):
        request = make_request(self.provider, scenario="silent-fallback-world")
        with patch(
            "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider.run_model"
        ) as mocked:
            with self.assertRaises(SimulationContractError):
                self.provider.run(request)
            mocked.assert_not_called()

    def test_domain_parameter_gate_rejects_unknown_bool_nested_and_nonfinite(self):
        invalid = (
            {"not_a_param": 1.0},
            {"k_cons": True},
            {"k_cons": {"nested": 1}},
            {"k_cons": float("nan")},
            {"k_cons": float("inf")},
        )
        for parameters in invalid:
            with self.subTest(parameters=parameters), patch(
                "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider.run_model"
            ) as mocked:
                with self.assertRaises(SimulationContractError):
                    self.provider.run(make_request(self.provider, parameters=parameters))
                mocked.assert_not_called()

    def test_materialized_seeds_are_consumed_once_in_exact_order(self):
        seed = SeedProvenance("explicit-set", (17, 3, 99)).validate()
        request = make_request(self.provider, seed=seed)
        with patch(
            "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider.run_model",
            return_value={"metric": 1.0},
        ) as mocked:
            result = self.provider.run(request)
        self.assertEqual([call.kwargs["seed"] for call in mocked.call_args_list], [17, 3, 99])
        self.assertEqual(len(result.output_hashes), 3)

    def test_derived_sequence_executes_materialized_seeds_without_rederivation(self):
        seed = SeedProvenance(
            strategy="derived-sequence",
            seeds=(7, 11, 13),
            root_seed=7,
            derivation_algorithm="splitmix64",
            derivation_version="1",
            derivation_parameters_json='{"count":3}',
        ).validate()
        with patch(
            "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider.run_model",
            return_value={"metric": 2.0},
        ) as mocked:
            self.provider.run(make_request(self.provider, seed=seed))
        self.assertEqual([call.kwargs["seed"] for call in mocked.call_args_list], [7, 11, 13])

    def test_duplicate_domain_outputs_are_legal_and_one_hash_is_emitted_per_seed(self):
        seed = SeedProvenance("explicit-set", (1, 2)).validate()
        expected = metrics_digest({"same": 4.0})
        with patch(
            "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider.run_model",
            return_value={"same": 4.0},
        ):
            result = self.provider.run(make_request(self.provider, seed=seed))
        self.assertEqual(result.output_hashes, (expected, expected))

    def test_output_hash_matches_canonical_direct_domain_metrics(self):
        request = make_request(self.provider)
        config = self.provider.execution_config()
        direct = domain_run_model(
            params={},
            seed=12345,
            scenario="impas",
            years=config.years,
            stab_crit=float(config.stab_crit),
            elite_crit=float(config.elite_crit),
            elite_streak_weeks=config.elite_streak_weeks,
        )
        result = self.provider.run(request)
        self.assertEqual(result.output_hashes, (metrics_digest(direct),))

    def test_same_request_has_stable_result_digest(self):
        request = make_request(self.provider, parameters={"k_cons": 0.11})
        first = self.provider.run(request)
        second = self.provider.run(request)
        self.assertEqual(first.output_hashes, second.output_hashes)
        self.assertEqual(first.result_digest(), second.result_digest())

    def test_seed_substitution_changes_result_identity_even_if_domain_output_is_equal(self):
        first_request = make_request(
            self.provider, seed=SeedProvenance("fixed-single", (1,)).validate()
        )
        second_request = make_request(
            self.provider, seed=SeedProvenance("fixed-single", (2,)).validate()
        )
        with patch(
            "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider.run_model",
            return_value={"same": 1.0},
        ):
            first = self.provider.run(first_request)
            second = self.provider.run(second_request)
        self.assertEqual(first.output_hashes, second.output_hashes)
        self.assertNotEqual(first.request.provenance_digest(), second.request.provenance_digest())
        self.assertNotEqual(first.result_digest(), second.result_digest())

    def test_provider_always_returns_simulated_epistemic_class(self):
        with patch(
            "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider.run_model",
            return_value={"metric": 1.0},
        ):
            result = self.provider.run(make_request(self.provider))
        self.assertIs(result.epistemic_class, EpistemicClass.SIMULATED)
        self.assertNotEqual(result.epistemic_class.value, "OBSERVED")

    def test_domain_execution_failure_does_not_return_success_result_or_issue_digest(self):
        with patch(
            "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider.run_model",
            side_effect=RuntimeError("domain execution failed"),
        ):
            with self.assertRaisesRegex(RuntimeError, "domain execution failed"):
                self.provider.run(make_request(self.provider))
        self.assertEqual(self.provider._issued_result_digests, set())

    def test_execution_config_rejects_ambiguous_or_invalid_values(self):
        invalid = (
            DomainExecutionConfig(years=True),
            DomainExecutionConfig(years=0),
            DomainExecutionConfig(elite_streak_weeks=False),
            DomainExecutionConfig(stab_crit=float("nan")),
            DomainExecutionConfig(elite_crit=1.1),
        )
        for config in invalid:
            with self.subTest(config=config), self.assertRaises(SimulationContractError):
                config.validate()

    def test_adapter_exposes_only_execution_and_process_local_issuance_state(self):
        self.assertEqual(
            set(self.provider.__dict__),
            {"_execution_config", "_issued_result_digests"},
        )
        self.assertEqual(self.provider._issued_result_digests, set())
        module_name = "abstrakcyjna_symulacja_kaskady_sieciowej.iran_cascade_provider"
        module = __import__(module_name, fromlist=["*"])
        for name in ("monte_carlo", "morris", "sobol", "authority", "capability", "permission"):
            self.assertFalse(hasattr(module, name), name)


if __name__ == "__main__":
    unittest.main()
