```text
QUALITY

MODEL
  Name:        matj_4_current_test.m
  Repository:  DonkeyJJLove/SymulacjaKaskadySieciowej
  Status:      BARDZO DOBRY
  Score:       88.9394 / 100

CURRENT INTERPRETATION

  Model osiągnął stan używalnego modelu badawczego. Rdzeń symulacji jest
  stabilny formalnie, scenariusze są rozróżnialne, a testy nie wskazują
  już globalnego kolapsu wszystkich trajektorii.

  Jednocześnie model pozostaje częściowo wrażliwy kalibracyjnie. Najbardziej
  obciążony pozostaje scenariusz "szybka_wojna", w którym występuje pełne
  załamanie stabilności i maksymalny pik protestu.

SCENARIOS

  [szybka_wojna]
    Tcrit                =  91.0000
    elite_fracture_prob  =   1.0000
    peak_protest         =   1.0000
    min_stab             =   0.0000
    mean_stab            =   0.4840
    final_stab           =   0.0000
    stress_area          =   0.8015
    drawdown             =   1.0000

  [dlugotrwala_wojna]
    Tcrit                = 157.0000
    elite_fracture_prob  =   0.0000
    peak_protest         =   0.2090
    min_stab             =   0.6556
    mean_stab            =   0.9530
    final_stab           =   0.8612
    stress_area          =   0.9033
    drawdown             =   0.1388

  [impas]
    Tcrit                = 157.0000
    elite_fracture_prob  =   0.0000
    peak_protest         =   0.4386
    min_stab             =   0.6632
    mean_stab            =   0.8784
    final_stab           =   0.7319
    stress_area          =   0.8761
    drawdown             =   0.2888

  [eskalacja_regionalna]
    Tcrit                = 157.0000
    elite_fracture_prob  =   0.0000
    peak_protest         =   0.1860
    min_stab             =   0.6499
    mean_stab            =   0.8917
    final_stab           =   0.7432
    stress_area          =   0.9129
    drawdown             =   0.2568

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

  [1] Model nie wpada już automatycznie w pełny kolaps we wszystkich
      scenariuszach. Test no_global_collapse przechodzi.

  [2] Stres nie jest już całkowicie nasycony we wszystkich przebiegach.
      Test stress_dynamic_range przechodzi.

  [3] Logika scenariuszy jest obecnie akceptowalna jakościowo.
      Test scenario_order przechodzi.

  [4] Monte Carlo przechodzi, ale z umiarkowanym wynikiem 63.3333 / 100,
      co oznacza, że model pozostaje wrażliwy na perturbacje parametrów.

KNOWN LIMITATIONS

  [1] Model nie jest jeszcze końcowo skalibrowany empirycznie.

  [2] Scenariusz "szybka_wojna" nadal generuje pełne załamanie stabilności,
      pełny drawdown i maksymalny protest. To wymaga dalszego strojenia.

  [3] Test realism przechodzi, ale wynik 62.5000 / 100 wskazuje, że część
      trajektorii nadal znajduje się blisko granic przestrzeni stanów.

  [4] python_compare ma status SKIP, jeśli nie podano katalogu
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

RUN

  Fast validation

  r = matj_4_current_test('test', ...
      'save_figures', false, ...
      'save_tables', true, ...
      'save_reports', true, ...
      'save_workspace', true, ...
      'headless', true);

  Full report mode

  r = matj_4_current_test('test', ...
      'save_figures', true, ...
      'save_tables', true, ...
      'save_reports', true, ...
      'save_workspace', true, ...
      'headless', true);

  MATLAB ↔ Python validation

  r = matj_4_current_test('test', ...
      'python_outputs_dir', 'SCIEZKA_DO_WYNIKOW_PYTHONA', ...
      'include_python_compare', true, ...
      'save_figures', false, ...
      'save_tables', true, ...
      'save_reports', true, ...
      'save_workspace', true, ...
      'headless', true);

  Single scenario simulation

  df = matj_4_current_test('simulate', ...
      'scenario', 'impas', ...
      'years', 3, ...
      'seed', 12345);

  Metrics for existing trajectory

  m = matj_4_current_test('compute_metrics', df, 3, ...
      'stab_crit', 0.30, ...
      'elite_crit', 0.35, ...
      'elite_streak_weeks', 4);

  Monte Carlo

  mc = matj_4_current_test('monte_carlo', ...
      'scenario', 'impas', ...
      'years', 3, ...
      'n', 100, ...
      'spread', 0.20, ...
      'seed', 42);

  Model spec

  sp = matj_4_current_test('spec');

OUTPUT INSPECTION

  r.quality_table
  r.out_dir
  dir(r.out_dir)
  type(fullfile(r.out_dir,'report.txt'))

NEXT STEPS

  [1] Dalsza kalibracja scenariusza "szybka_wojna".
  [2] Walidacja MATLAB↔Python tydzień po tygodniu.
  [3] Uruchomienie Sobol / GSA dla aktualnej kalibracji.
  [4] Zawężenie rozkładów parametrów Monte Carlo po kolejnej iteracji.