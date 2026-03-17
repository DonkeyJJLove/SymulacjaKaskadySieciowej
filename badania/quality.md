# QUALITY

```text
QUALITY

MODEL
  Name:        matj_4.m
  Repository:  DonkeyJJLove/SymulacjaKaskadySieciowej
  Status:      BARDZO DOBRY
  Score:       88.9394 / 100

CURRENT INTERPRETATION

  Model osiągnął stan używalnego modelu badawczego. Rdzeń symulacji jest
  stabilny formalnie, scenariusze są rozróżnialne, a testy nie wskazują
  już globalnego kolapsu wszystkich trajektorii.

  Model nie jest jeszcze końcowo skalibrowany empirycznie, ale przeszedł
  kluczowe testy formalne, dynamiczne i scenariuszowe. Obecna wersja może
  być używana jako referencyjny punkt do dalszego strojenia, walidacji
  MATLAB↔Python oraz analiz Sobol / GSA.

CURRENT QUALITY TABLE

  finite_bounds            : 100.0000 / 100.0000   [PASS]
  determinism              : 100.0000 / 100.0000   [PASS]
  monotonicity_sanctions   : 100.0000 / 100.0000   [PASS]
  local_stability          :  99.6215 / 100.0000   [PASS]
  realism                  :  62.5000 / 100.0000   [PASS]
  no_global_collapse       : 100.0000 / 100.0000   [PASS]
  stress_dynamic_range     : 100.0000 / 100.0000   [PASS]
  scenario_order           :  75.0000 / 100.0000   [PASS]
  monte_carlo              :  63.3333 / 100.0000   [PASS]
  python_compare           :   0.0000 /   0.0000   [SKIP]

KNOWN LIMITATIONS

  [1] Model nie jest jeszcze końcowo skalibrowany empirycznie.
  [2] Scenariusz "szybka_wojna" nadal wymaga dalszego strojenia.
  [3] python_compare ma status SKIP, jeśli nie podano python_outputs_dir.

RUN

  Fast validation

  r = matj_4('test', ...
      'save_figures', false, ...
      'save_tables', true, ...
      'save_reports', true, ...
      'save_workspace', true, ...
      'headless', true);

  Full report mode

  r = matj_4('test', ...
      'save_figures', true, ...
      'save_tables', true, ...
      'save_reports', true, ...
      'save_workspace', true, ...
      'headless', true);

  MATLAB ↔ Python validation

  r = matj_4('test', ...
      'python_outputs_dir', 'SCIEZKA_DO_WYNIKOW_PYTHONA', ...
      'include_python_compare', true, ...
      'save_figures', false, ...
      'save_tables', true, ...
      'save_reports', true, ...
      'save_workspace', true, ...
      'headless', true);

  Single scenario simulation

  df = matj_4('simulate', ...
      'scenario', 'impas', ...
      'years', 3, ...
      'seed', 12345);

  Metrics for existing trajectory

  m = matj_4('compute_metrics', df, 3, ...
      'stab_crit', 0.30, ...
      'elite_crit', 0.35, ...
      'elite_streak_weeks', 4);

  Monte Carlo

  mc = matj_4('monte_carlo', ...
      'scenario', 'impas', ...
      'years', 3, ...
      'n', 100, ...
      'spread', 0.20, ...
      'seed', 42);

  Model spec

  sp = matj_4('spec');

OUTPUT INSPECTION

  r.quality_table
  r.out_dir
  dir(r.out_dir)
  type(fullfile(r.out_dir,'report.txt'))

RECOMMENDED EXECUTION ORDER

  [1] Uruchom Fast validation.
  [2] Sprawdź r.quality_table oraz report.txt.
  [3] Jeżeli wynik jest akceptowalny, uruchom Full report mode.
  [4] Następnie wykonaj MATLAB ↔ Python validation.
  [5] Dopiero po zgodności MATLAB↔Python uruchamiaj Sobol / GSA.