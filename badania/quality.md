# QUALITY

```text
QUALITY

MODEL
  Name:        matj_4.m
  Repository:  DonkeyJJLove/SymulacjaKaskadySieciowej
  Status:      BARDZO DOBRY
  Score:       88.94 / 100

CURRENT INTERPRETATION

  Model przeszedł z etapu formalnie poprawnej implementacji do etapu
  używalnego modelu badawczego. Rdzeń symulacji działa stabilnie,
  scenariusze są rozróżnialne, a testy nie wskazują już globalnego
  kolapsu wszystkich trajektorii.

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

WHAT THIS MEANS

  [1] Model nie wpada już automatycznie w pełny kolaps dla wszystkich
      scenariuszy. Test no_global_collapse przechodzi.

  [2] Stres nie jest już stale nasycony dla wszystkich trajektorii.
      Test stress_dynamic_range przechodzi.

  [3] Logika scenariuszy jest obecnie zgodna z oczekiwanym porządkiem
      jakościowym. Test scenario_order przechodzi.

KNOWN LIMITATIONS

  [1] Model nie jest jeszcze końcowo skalibrowany empirycznie.

  [2] Scenariusz "szybka_wojna" nadal może uruchamiać późny mechanizm
      załamania przez kanał protestowy.

  [3] python_compare ma status SKIP, jeśli nie podano katalogu
      python_outputs_dir.

QUALITY CRITERIA

  Model jest uznawany za używalny badawczo, gdy:

  - wszystkie stany ograniczone do [0,1] pozostają w zakresie,
  - nie pojawiają się NaN ani Inf,
  - dla stałego seeda model jest deterministyczny,
  - wzrost sankcji nie poprawia dochodu naftowego ani nie obniża inflacji,
  - model nie kończy wszystkich scenariuszy globalnym kolapsem,
  - stres nie jest stale nasycony dla wszystkich scenariuszy,
  - scenariusze zachowują poprawną logikę porządku jakościowego,
  - Monte Carlo nie wskazuje dominacji trajektorii kolapsowych,
  - MATLAB↔Python nie wykazuje istotnych odchyleń, jeśli walidacja działa.

HOW TO RUN

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
  type(fullfile(r.out_dir,'report.txt'))
  dir(r.out_dir)

NEXT STEPS

  [1] Kalibracja scenariusza "szybka_wojna".
  [2] Walidacja MATLAB↔Python tydzień po tygodniu.
  [3] Uruchomienie Sobol / GSA dla aktualnej kalibracji.
  [4] Zawężenie rozkładów parametrów Monte Carlo po kolejnej iteracji.