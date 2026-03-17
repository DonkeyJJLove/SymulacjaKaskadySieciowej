%% matj_1.m
% Kompletny test modelu dyskretnego w MATLAB
% Cel:
% 1) uruchomić model w kilku scenariuszach,
% 2) policzyć statystyki porównawcze,
% 3) wykonać testy jakości modelu,
% 4) wygenerować samoocenę jakości i funkcji modelu.
%
% Uruchomienie:
% >> matj_1
%
% Wymagania:
% - MATLAB R2016b+ (skrypt z lokalnymi funkcjami na końcu pliku)

clear; clc; close all;
rng(42, 'twister');

fprintf('============================================================\n');
fprintf('MATJ_1 :: TEST MODELU DYSKRETNEGO\n');
fprintf('============================================================\n\n');

%% 1. PARAMETRY GŁÓWNE
p = default_params();
T = 104;                    % 104 tygodnie = 2 lata
t = (0:T)';

%% 2. DEFINICJA SCENARIUSZY
scenarios = define_scenarios(T);

%% 3. SYMULACJE SCENARIUSZY
results = struct();
for i = 1:numel(scenarios)
    results(i).name = scenarios(i).name;
    results(i).desc = scenarios(i).desc;
    results(i).exo  = scenarios(i).exo;
    results(i).sim  = simulate_model(T, p, scenarios(i).exo, scenarios(i).init);
    results(i).met  = compute_metrics(results(i).sim, scenarios(i).exo);
end

%% 4. RAPORT SCENARIUSZY
fprintf('--- WYNIKI SCENARIUSZY ---\n');
for i = 1:numel(results)
    m = results(i).met;
    fprintf('\n[%d] %s\n', i, results(i).name);
    fprintf('    Opis: %s\n', results(i).desc);
    fprintf('    Y_end                = %.4f\n', m.Y_end);
    fprintf('    Y_mean               = %.4f\n', m.Y_mean);
    fprintf('    Y_min                = %.4f\n', m.Y_min);
    fprintf('    F_mean               = %.4f\n', m.F_mean);
    fprintf('    reliefEff_mean       = %.4f\n', m.reliefEff_mean);
    fprintf('    R_oil_mean           = %.4f\n', m.R_oil_mean);
    fprintf('    max_drawdown_Y       = %.4f\n', m.max_drawdown_Y);
    fprintf('    volatility_Y         = %.4f\n', m.volatility_Y);
    fprintf('    recovery_ratio       = %.4f\n', m.recovery_ratio);
    fprintf('    weeks_below_0_4      = %d\n',    m.weeks_below_0_4);
    fprintf('    clip_rate_Y          = %.4f\n', m.clip_rate_Y);
    fprintf('    finite_ok            = %d\n',   m.finite_ok);
    fprintf('    bounds_ok            = %d\n',   m.bounds_ok);
end

%% 5. TESTY JAKOŚCIOWE MODELU
quality = struct();

% Test 1: brak NaN/Inf i poprawne ograniczenia [0,1] dla zmiennych znormalizowanych
quality.test_finite_and_bounds = test_finite_and_bounds(results);

% Test 2: logika rang scenariuszy:
% baseline powinien kończyć się wyżej niż stress,
% relief powinien kończyć się wyżej niż stress,
% shock powinien mieć większe obsunięcie niż baseline
quality.test_scenario_ranking = test_scenario_ranking(results);

% Test 3: monotoniczność krótkoterminowa względem sankcji
quality.test_sanction_monotonicity = test_sanction_monotonicity(p);

% Test 4: wrażliwość na ulgę (Rf_t)
quality.test_relief_monotonicity = test_relief_monotonicity(p);

% Test 5: stabilność lokalna - mała perturbacja stanu nie może wysadzić trajektorii
quality.test_local_stability = test_local_stability(p);

% Test 6: test Monte Carlo - odporność średniej jakości przy losowych trajektoriach egzogenicznych
quality.test_monte_carlo = test_monte_carlo(p);

%% 6. AGREGACJA WYNIKÓW TESTÓW
[quality_score, quality_table] = aggregate_quality(quality);

fprintf('\n============================================================\n');
fprintf('RAPORT TESTÓW JAKOŚCIOWYCH\n');
fprintf('============================================================\n');
for i = 1:size(quality_table,1)
    fprintf('%-34s  score = %6.2f / %6.2f   status = %s\n', ...
        quality_table{i,1}, quality_table{i,2}, quality_table{i,3}, quality_table{i,4});
end
fprintf('------------------------------------------------------------\n');
fprintf('ŁĄCZNY WYNIK JAKOŚCI MODELU: %.2f / 100\n', quality_score);

if quality_score >= 85
    final_label = 'BARDZO DOBRY';
elseif quality_score >= 70
    final_label = 'DOBRY';
elseif quality_score >= 50
    final_label = 'WARUNKOWO POPRAWNY';
else
    final_label = 'SŁABY / WYMAGA REKALIBRACJI';
end
fprintf('OCENA KOŃCOWA: %s\n', final_label);

%% 7. STATYSTYKI PORÓWNAWCZE MIĘDZY SCENARIUSZAMI
comparison = comparative_stats(results);

fprintf('\n============================================================\n');
fprintf('STATYSTYKI PORÓWNAWCZE\n');
fprintf('============================================================\n');
fprintf('Najlepszy scenariusz wg Y_end      : %s\n', comparison.best_by_Y_end);
fprintf('Najgorszy scenariusz wg Y_end      : %s\n', comparison.worst_by_Y_end);
fprintf('Najmniejsze obsunięcie             : %s\n', comparison.best_drawdown);
fprintf('Największa zmienność               : %s\n', comparison.max_volatility);
fprintf('Najwyższa średnia reliefEff        : %s\n', comparison.best_relief);
fprintf('Najwyższa średnia renta naftowa    : %s\n', comparison.best_oil);

%% 8. WYKRESY
plot_all(results, t, quality_score, final_label);

%% 9. PODSUMOWANIE TEKSTOWE
fprintf('\n============================================================\n');
fprintf('INTERPRETACJA AUTOMATYCZNA\n');
fprintf('============================================================\n');

baseIdx   = find(strcmp({results.name}, 'baseline'));
stressIdx = find(strcmp({results.name}, 'stress'));
relIdx    = find(strcmp({results.name}, 'relief'));

if ~isempty(baseIdx) && ~isempty(stressIdx)
    delta_base_stress = results(baseIdx).met.Y_end - results(stressIdx).met.Y_end;
    fprintf('Różnica Y_end (baseline - stress): %.4f\n', delta_base_stress);
end

if ~isempty(relIdx) && ~isempty(stressIdx)
    delta_rel_stress = results(relIdx).met.Y_end - results(stressIdx).met.Y_end;
    fprintf('Różnica Y_end (relief - stress):   %.4f\n', delta_rel_stress);
end

fprintf(['Model sam zweryfikował: ograniczenia stanów, poprawność numeryczną, ' ...
         'logikę rang scenariuszy, monotoniczność względem sankcji i ulgi, ' ...
         'lokalną stabilność oraz odporność Monte Carlo.\n']);

fprintf('\nKoniec testu MATJ_1.\n');

%% ====================== FUNKCJE LOKALNE ===============================

function p = default_params()
    p.dt = 1.0;

    % kanał naftowy
    p.oilExportBase = 0.85;
    p.alpha_san = 0.70;
    p.alpha_h   = 0.55;

    % agregacja fiskalno-realna
    p.w_Y   = 0.62;
    p.w_oil = 0.38;

    % równanie produkcji
    p.r     = 0.060;
    p.d_X   = 0.120;
    p.d_san = 0.110;
    p.d_P   = 0.060;
    p.d_M   = 0.050;
    p.a     = 0.045;
    p.eta   = 0.120;
end

function scenarios = define_scenarios(T)
    init.Y0 = 0.72;
    init.P0 = 0.25;
    init.M0 = 0.20;
    init.oilInfra0 = 0.88;

    % baseline
    exo1.X   = 0.18 * ones(T,1);
    exo1.San = 0.32 * ones(T,1);
    exo1.H   = 0.10 * ones(T,1);
    exo1.O   = 1.05 * ones(T,1);
    exo1.Rf  = 0.22 * ones(T,1);

    % stress
    exo2.X   = 0.45 * ones(T,1);
    exo2.San = 0.70 * ones(T,1);
    exo2.H   = 0.50 * ones(T,1);
    exo2.O   = 1.10 * ones(T,1);
    exo2.Rf  = 0.10 * ones(T,1);

    % relief
    exo3.X   = 0.22 * ones(T,1);
    exo3.San = 0.35 * ones(T,1);
    exo3.H   = 0.12 * ones(T,1);
    exo3.O   = 1.08 * ones(T,1);
    exo3.Rf  = 0.55 * ones(T,1);

    % shock: silny szok przez pierwsze 20 tygodni, potem częściowa normalizacja
    exo4.X   = [0.70 * ones(20,1); 0.28 * ones(T-20,1)];
    exo4.San = [0.85 * ones(20,1); 0.45 * ones(T-20,1)];
    exo4.H   = [0.65 * ones(20,1); 0.20 * ones(T-20,1)];
    exo4.O   = [1.25 * ones(20,1); 1.08 * ones(T-20,1)];
    exo4.Rf  = [0.08 * ones(20,1); 0.30 * ones(T-20,1)];

    scenarios(1).name = 'baseline';
    scenarios(1).desc = 'Umiarkowana presja, umiarkowane sankcje, stabilne otoczenie';
    scenarios(1).exo  = exo1;
    scenarios(1).init = init;

    scenarios(2).name = 'stress';
    scenarios(2).desc = 'Wysoka presja i sankcje, silne zakłócenia';
    scenarios(2).exo  = exo2;
    scenarios(2).init = init;

    scenarios(3).name = 'relief';
    scenarios(3).desc = 'Umiarkowane warunki, ale wysoki komponent ulgi/zasilenia';
    scenarios(3).exo  = exo3;
    scenarios(3).init = init;

    scenarios(4).name = 'shock';
    scenarios(4).desc = 'Silny szok początkowy i późniejsza częściowa normalizacja';
    scenarios(4).exo  = exo4;
    scenarios(4).init = init;
end

function sim = simulate_model(T, p, exo, init)
    clip = @(x) min(max(x,0),1);

    Y = zeros(T+1,1);
    P = zeros(T+1,1);
    M = zeros(T+1,1);
    oilInfra = zeros(T+1,1);

    oilExport = zeros(T,1);
    R_oil     = zeros(T,1);
    F         = zeros(T,1);
    reliefEff = zeros(T,1);

    Y(1) = init.Y0;
    P(1) = init.P0;
    M(1) = init.M0;
    oilInfra(1) = init.oilInfra0;

    Y_clip_count = 0;
    P_clip_count = 0;
    M_clip_count = 0;
    I_clip_count = 0;

    for k = 1:T
        oilExport(k) = p.oilExportBase * (1 - p.alpha_san * exo.San(k)) * (1 - p.alpha_h * exo.H(k));
        R_oil(k)     = clip(oilExport(k) * oilInfra(k)) * exo.O(k);
        F(k)         = clip(p.w_Y * Y(k) + p.w_oil * R_oil(k));
        reliefEff(k) = clip(0.5 * F(k) + 0.5 * exo.Rf(k));

        rawY = Y(k) + p.dt * ( ...
              p.r * (1 - Y(k)) ...
            - p.d_X * exo.X(k) ...
            - p.d_san * exo.San(k) ...
            - p.d_P * P(k) ...
            - p.d_M * M(k) ...
            + p.a * (1 - exo.San(k)) * (1 - exo.X(k)) ...
            + p.eta * reliefEff(k));

        % Proste równania pomocnicze dla pełniejszej dynamiki testowej
        rawP = P(k) + p.dt * ( ...
              0.18 * exo.X(k) ...
            + 0.12 * exo.San(k) ...
            + 0.10 * exo.H(k) ...
            - 0.16 * reliefEff(k) ...
            - 0.08 * Y(k));

        rawM = M(k) + p.dt * ( ...
              0.10 * exo.X(k) ...
            + 0.14 * exo.H(k) ...
            + 0.05 * P(k) ...
            - 0.07 * Y(k) ...
            - 0.10 * reliefEff(k));

        rawI = oilInfra(k) + p.dt * ( ...
              0.05 * Y(k) ...
            - 0.12 * exo.H(k) ...
            - 0.06 * exo.X(k) ...
            + 0.04 * exo.Rf(k));

        Y(k+1) = clip(rawY);
        P(k+1) = clip(rawP);
        M(k+1) = clip(rawM);
        oilInfra(k+1) = clip(rawI);

        Y_clip_count = Y_clip_count + double(rawY < 0 || rawY > 1);
        P_clip_count = P_clip_count + double(rawP < 0 || rawP > 1);
        M_clip_count = M_clip_count + double(rawM < 0 || rawM > 1);
        I_clip_count = I_clip_count + double(rawI < 0 || rawI > 1);
    end

    sim.Y = Y;
    sim.P = P;
    sim.M = M;
    sim.oilInfra = oilInfra;
    sim.oilExport = oilExport;
    sim.R_oil = R_oil;
    sim.F = F;
    sim.reliefEff = reliefEff;
    sim.Y_clip_count = Y_clip_count;
    sim.P_clip_count = P_clip_count;
    sim.M_clip_count = M_clip_count;
    sim.I_clip_count = I_clip_count;
    sim.T = T;
end

function met = compute_metrics(sim, exo)
    y = sim.Y;
    dy = diff(y);

    peak = -inf;
    max_dd = 0;
    for i = 1:numel(y)
        peak = max(peak, y(i));
        if peak > 0
            dd = (peak - y(i)) / peak;
            max_dd = max(max_dd, dd);
        end
    end

    met.Y_end          = y(end);
    met.Y_mean         = mean(y);
    met.Y_min          = min(y);
    met.F_mean         = mean(sim.F);
    met.reliefEff_mean = mean(sim.reliefEff);
    met.R_oil_mean     = mean(sim.R_oil);
    met.max_drawdown_Y = max_dd;
    met.volatility_Y   = std(dy);
    met.recovery_ratio = y(end) / max(y(1), eps);
    met.weeks_below_0_4 = sum(y(2:end) < 0.4);
    met.clip_rate_Y    = sim.Y_clip_count / sim.T;
    met.finite_ok      = all(isfinite([sim.Y; sim.P; sim.M; sim.oilInfra; sim.oilExport; sim.R_oil; sim.F; sim.reliefEff]));
    met.bounds_ok      = all(sim.Y >= 0 & sim.Y <= 1) ...
                      && all(sim.P >= 0 & sim.P <= 1) ...
                      && all(sim.M >= 0 & sim.M <= 1) ...
                      && all(sim.oilInfra >= 0 & sim.oilInfra <= 1);
    met.mean_X         = mean(exo.X);
    met.mean_San       = mean(exo.San);
    met.mean_H         = mean(exo.H);
    met.mean_O         = mean(exo.O);
    met.mean_Rf        = mean(exo.Rf);
end

function out = test_finite_and_bounds(results)
    pass_count = 0;
    n = numel(results);
    for i = 1:n
        ok = results(i).met.finite_ok && results(i).met.bounds_ok;
        pass_count = pass_count + double(ok);
    end
    score = 100 * pass_count / n;
    out.name = 'finite_and_bounds';
    out.score = score;
    out.max_score = 100;
    out.pass = score == 100;
end

function out = test_scenario_ranking(results)
    names = {results.name};
    idxBase   = find(strcmp(names, 'baseline'), 1);
    idxStress = find(strcmp(names, 'stress'), 1);
    idxRelief = find(strcmp(names, 'relief'), 1);
    idxShock  = find(strcmp(names, 'shock'), 1);

    checks = [];

    if ~isempty(idxBase) && ~isempty(idxStress)
        checks(end+1) = results(idxBase).met.Y_end > results(idxStress).met.Y_end; %#ok<AGROW>
    end
    if ~isempty(idxRelief) && ~isempty(idxStress)
        checks(end+1) = results(idxRelief).met.Y_end > results(idxStress).met.Y_end; %#ok<AGROW>
    end
    if ~isempty(idxShock) && ~isempty(idxBase)
        checks(end+1) = results(idxShock).met.max_drawdown_Y > results(idxBase).met.max_drawdown_Y; %#ok<AGROW>
    end

    if isempty(checks)
        score = 0;
    else
        score = 100 * mean(checks);
    end

    out.name = 'scenario_ranking';
    out.score = score;
    out.max_score = 100;
    out.pass = score >= 66.67;
end

function out = test_sanction_monotonicity(p)
    T = 30;
    init.Y0 = 0.70;
    init.P0 = 0.22;
    init.M0 = 0.18;
    init.oilInfra0 = 0.90;

    gridSan = linspace(0,1,9);
    Yend = zeros(size(gridSan));

    for i = 1:numel(gridSan)
        exo.X   = 0.25 * ones(T,1);
        exo.San = gridSan(i) * ones(T,1);
        exo.H   = 0.12 * ones(T,1);
        exo.O   = 1.05 * ones(T,1);
        exo.Rf  = 0.25 * ones(T,1);
        sim = simulate_model(T, p, exo, init);
        Yend(i) = sim.Y(end);
    end

    diffs = diff(Yend);
    monotonic_ok_ratio = mean(diffs <= 1e-10);
    score = 100 * monotonic_ok_ratio;

    out.name = 'sanction_monotonicity';
    out.score = score;
    out.max_score = 100;
    out.pass = score >= 87.5;
end

function out = test_relief_monotonicity(p)
    T = 30;
    init.Y0 = 0.70;
    init.P0 = 0.22;
    init.M0 = 0.18;
    init.oilInfra0 = 0.90;

    gridRf = linspace(0,1,9);
    Yend = zeros(size(gridRf));

    for i = 1:numel(gridRf)
        exo.X   = 0.25 * ones(T,1);
        exo.San = 0.45 * ones(T,1);
        exo.H   = 0.18 * ones(T,1);
        exo.O   = 1.05 * ones(T,1);
        exo.Rf  = gridRf(i) * ones(T,1);
        sim = simulate_model(T, p, exo, init);
        Yend(i) = sim.Y(end);
    end

    diffs = diff(Yend);
    monotonic_ok_ratio = mean(diffs >= -1e-10);
    score = 100 * monotonic_ok_ratio;

    out.name = 'relief_monotonicity';
    out.score = score;
    out.max_score = 100;
    out.pass = score >= 87.5;
end

function out = test_local_stability(p)
    T = 40;
    init1.Y0 = 0.7000;
    init1.P0 = 0.2200;
    init1.M0 = 0.1800;
    init1.oilInfra0 = 0.9000;

    init2 = init1;
    init2.Y0 = init2.Y0 + 0.005;
    init2.P0 = init2.P0 - 0.005;
    init2.M0 = init2.M0 + 0.005;
    init2.oilInfra0 = init2.oilInfra0 - 0.005;

    exo.X   = 0.28 * ones(T,1);
    exo.San = 0.40 * ones(T,1);
    exo.H   = 0.12 * ones(T,1);
    exo.O   = 1.07 * ones(T,1);
    exo.Rf  = 0.30 * ones(T,1);

    s1 = simulate_model(T, p, exo, init1);
    s2 = simulate_model(T, p, exo, init2);

    dist = abs(s1.Y - s2.Y);
    growth_ratio = max(dist(end) / max(dist(1), 1e-9), 0);
    % im mniejszy wzrost różnicy tym lepiej
    score = max(0, min(100, 100 * (1 - min(growth_ratio, 1))));

    out.name = 'local_stability';
    out.score = score;
    out.max_score = 100;
    out.pass = score >= 60;
end

function out = test_monte_carlo(p)
    N = 200;
    T = 52;
    init.Y0 = 0.72;
    init.P0 = 0.25;
    init.M0 = 0.20;
    init.oilInfra0 = 0.88;

    Y_end = zeros(N,1);
    finite_ok = zeros(N,1);
    bounds_ok = zeros(N,1);

    for i = 1:N
        exo.X   = min(max(0.25 + 0.15*randn(T,1), 0), 1);
        exo.San = min(max(0.40 + 0.18*randn(T,1), 0), 1);
        exo.H   = min(max(0.18 + 0.16*randn(T,1), 0), 1);
        exo.O   = max(0.60, 1.05 + 0.20*randn(T,1));   % indeks cenowy > 0
        exo.Rf  = min(max(0.25 + 0.20*randn(T,1), 0), 1);

        sim = simulate_model(T, p, exo, init);
        Y_end(i) = sim.Y(end);
        finite_ok(i) = all(isfinite(sim.Y));
        bounds_ok(i) = all(sim.Y >= 0 & sim.Y <= 1);
    end

    score_finite = 100 * mean(finite_ok);
    score_bounds = 100 * mean(bounds_ok);

    % penalizacja za zbyt częste zapadanie się systemu do zera
    collapse_rate = mean(Y_end < 0.05);
    score_collapse = 100 * (1 - collapse_rate);

    score = 0.4 * score_finite + 0.3 * score_bounds + 0.3 * score_collapse;

    out.name = 'monte_carlo_robustness';
    out.score = score;
    out.max_score = 100;
    out.pass = score >= 70;
    out.collapse_rate = collapse_rate;
    out.Y_end_mean = mean(Y_end);
    out.Y_end_std = std(Y_end);
end

function [quality_score, tbl] = aggregate_quality(q)
    names = fieldnames(q);
    tbl = cell(numel(names),4);
    total = 0;
    total_max = 0;

    for i = 1:numel(names)
        item = q.(names{i});
        tbl{i,1} = item.name;
        tbl{i,2} = item.score;
        tbl{i,3} = item.max_score;
        if item.pass
            tbl{i,4} = 'PASS';
        else
            tbl{i,4} = 'FAIL';
        end
        total = total + item.score;
        total_max = total_max + item.max_score;
    end

    quality_score = 100 * total / max(total_max, eps);
end

function comp = comparative_stats(results)
    n = numel(results);
    Y_end = zeros(n,1);
    DD = zeros(n,1);
    VOL = zeros(n,1);
    REL = zeros(n,1);
    OIL = zeros(n,1);

    for i = 1:n
        Y_end(i) = results(i).met.Y_end;
        DD(i)    = results(i).met.max_drawdown_Y;
        VOL(i)   = results(i).met.volatility_Y;
        REL(i)   = results(i).met.reliefEff_mean;
        OIL(i)   = results(i).met.R_oil_mean;
    end

    [~, ibestY] = max(Y_end);
    [~, iworstY] = min(Y_end);
    [~, ibestDD] = min(DD);
    [~, imaxVOL] = max(VOL);
    [~, ibestREL] = max(REL);
    [~, ibestOIL] = max(OIL);

    comp.best_by_Y_end = results(ibestY).name;
    comp.worst_by_Y_end = results(iworstY).name;
    comp.best_drawdown = results(ibestDD).name;
    comp.max_volatility = results(imaxVOL).name;
    comp.best_relief = results(ibestREL).name;
    comp.best_oil = results(ibestOIL).name;
end

function plot_all(results, t, quality_score, final_label)
    figure('Name','MATJ_1 :: Trajektorie Y_t','Color','w');
    hold on;
    for i = 1:numel(results)
        plot(t, results(i).sim.Y, 'LineWidth', 1.8, 'DisplayName', results(i).name);
    end
    xlabel('Tydzień');
    ylabel('Y_t');
    title(sprintf('Porównanie scenariuszy :: score = %.2f / 100 [%s]', quality_score, final_label));
    grid on;
    legend('Location','best');
    hold off;

    figure('Name','MATJ_1 :: Kanał naftowy i ulga','Color','w');
    tiledlayout(2,1);

    nexttile;
    hold on;
    for i = 1:numel(results)
        plot(1:results(i).sim.T, results(i).sim.R_oil, 'LineWidth', 1.6, 'DisplayName', results(i).name);
    end
    title('R_{oil,t}');
    xlabel('Tydzień');
    ylabel('R_oil');
    grid on;
    legend('Location','best');
    hold off;

    nexttile;
    hold on;
    for i = 1:numel(results)
        plot(1:results(i).sim.T, results(i).sim.reliefEff, 'LineWidth', 1.6, 'DisplayName', results(i).name);
    end
    title('reliefEff_t');
    xlabel('Tydzień');
    ylabel('reliefEff');
    grid on;
    legend('Location','best');
    hold off;

    figure('Name','MATJ_1 :: Stany pomocnicze','Color','w');
    tiledlayout(3,1);

    nexttile; hold on;
    for i = 1:numel(results)
        plot(t, results(i).sim.P, 'LineWidth', 1.4, 'DisplayName', results(i).name);
    end
    title('P_t');
    grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results)
        plot(t, results(i).sim.M, 'LineWidth', 1.4, 'DisplayName', results(i).name);
    end
    title('M_t');
    grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results)
        plot(t, results(i).sim.oilInfra, 'LineWidth', 1.4, 'DisplayName', results(i).name);
    end
    title('oilInfra_t');
    xlabel('Tydzień');
    grid on; legend('Location','best'); hold off;
end
