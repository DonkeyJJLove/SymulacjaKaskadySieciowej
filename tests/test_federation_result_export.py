import importlib.util,pathlib,subprocess,sys,types,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
PKG=ROOT/"src/abstrakcyjna_symulacja_kaskady_sieciowej"
package=types.ModuleType("abstrakcyjna_symulacja_kaskady_sieciowej")
package.__path__=[str(PKG)]
sys.modules[package.__name__]=package

def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path)
 mod=importlib.util.module_from_spec(spec);sys.modules[name]=mod;spec.loader.exec_module(mod);return mod
contracts=load(package.__name__+".simulation_contracts",PKG/"simulation_contracts.py")
provider_mod=load(package.__name__+".federation_fixture_provider",PKG/"federation_fixture_provider.py")
class FederationResultExportTests(unittest.TestCase):
 def provider(self):
  head=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip()
  return provider_mod.DeterministicFederationSimulationProvider(head)
 def test_actual_provider_run_is_deterministic_and_simulated(self):
  p=self.provider();r1=p.run(provider_mod.fixture_request(p));r2=p.run(provider_mod.fixture_request(p))
  self.assertEqual(r1.result_digest(),r2.result_digest());self.assertEqual(r1.epistemic_class,contracts.EpistemicClass.SIMULATED)
  risk=p.model_risk_statement(r1);self.assertEqual(risk.result_digest,r1.result_digest())
 def test_result_does_not_claim_observation_or_authority(self):
  p=self.provider();r=p.run(provider_mod.fixture_request(p));self.assertNotEqual(r.epistemic_class.value,"OBSERVED")
if __name__=="__main__":unittest.main()
