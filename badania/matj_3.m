%% matj_3.m
% MATJ_3
% Kompletny model referencyjny zapisany w MATLAB, gotowy do późniejszego
% rozpisania testów, kalibracji i analizy wrażliwości.
%
% Zawartość:
% 1) default_params()
% 2) default_thresholds()
% 3) scenario_exog()
% 4) step_model()
% 5) simulate_model()
% 6) compute_metrics()
% 7) compute_extra_metrics()
% 8) build_spec_struct()
% 9) run_demo()
%
% Uruchomienie:
% >> matj_3
%
% Skrypt:
% - uruchamia 4 scenariusze,
% - rysuje podstawowe wykresy,
% - liczy metryki krytyczne,
% - zapisuje wynikową strukturę SPEC do workspace.
%
% Uwagi:
% - krok modelu: 1 tydzień
% - wszystkie stany poza CPI i Displaced są ograniczane do [0,1]
% - CPI > 0, Displaced >= 0
%
% Gotowe pod dalsze dodanie:
% - test_suite()
% - sobol_suite()
% - eksport CSV / Parquet
% - walidacja MATLAB <-> Python tydzień po tygodniu

clear; clc; close all;

fprintf('=============================================================\n');
fprintf('MATJ_3 :: MODEL REFERENCYJNY W MATLAB\n');
fprintf('=============================================================\n\n');

params = default_params();
thr = default_thresholds();
SPEC = build_spec_struct(params, thr);

results = run_demo(params, thr);

assignin('base', 'MODEL_SPEC_v1', SPEC);
assignin('base', 'MODEL_RESULTS_v1', results);

fprintf('\nZapisano do workspace:\n');
fprintf('  MODEL_SPEC_v1\n');
fprintf('  MODEL_RESULTS_v1\n');
fprintf('\nKoniec MATJ_3.\n');

%% =====================================================================
%% GŁÓWNY DEMO RUN
%% =====================================================================
function results = run_demo(params, thr)

    scenarios = {'szybka_wojna','dlugotrwala_wojna','impas','eskalacja_regionalna'};
    years = 3;
    seed = 42;

    results = struct([]);

    fprintf('--- SYMULACJE SCENARIUSZY ---\n');
    for i = 1:numel(scenarios)
        sim = simulate_model(params, scenarios{i}, years, seed + i, []);
        met = compute_metrics(sim, thr);
        ext = compute_extra_metrics(sim);

        results(i).name = scenarios{i};
        results(i).sim = sim;
        results(i).metrics = met;
        results(i).extra = ext;

        fprintf('\n[%d] %s\n', i, scenarios{i});
        fprintf('  Tcrit                    = %7.2f\n', met.Tcrit);
        fprintf('  elite_fracture_prob      = %7.2f\n', met.elite_fracture_prob);
        fprintf('  time_to_elite_fracture   = %7.2f\n', met.time_to_elite_fracture);
        fprintf('  peak_protest             = %7.4f\n', met.peak_protest);
        fprintf('  min_stab                 = %7.4f\n', met.min_stab);
        fprintf('  mean_stab                = %7.4f\n', met.mean_stab);
        fprintf('  mean_elite               = %7.4f\n', met.mean_elite);
        fprintf('  avg_loyal                = %7.4f\n', met.avg_loyal);
        fprintf('  end_displaced            = %7.4f\n', met.end_displaced_m);
        fprintf('  stress_auc               = %7.4f\n', ext.stress_area);
        fprintf('  drawdown_stab            = %7.4f\n', ext.max_drawdown_stab);
    end

    plot_results(results);
end

%% =====================================================================
%% PARAMETRY MODELU
%% =====================================================================
function p = default_params()
    % kanał energetyczno-dochodowy
    p.oilExportCap = 1.00;
    p.k_san_oil    = 0.60;
    p.k_war_oil    = 0.70;
    p.oil_price_base = 1.00;
    p.k_price_shock  = 0.50;

    % fiskalność i inflacja
    p.k_rev      = 0.12;
    p.k_warsp    = 0.10;
    p.k_sub      = 0.06;
    p.k_leak     = 0.04;

    p.pi0        = 0.35;
    p.pi_target  = 0.10;
    p.k_pi_san   = 0.25;
    p.k_pi_war   = 0.35;
    p.k_pi_fisc  = 0.20;

    % stres ekonomiczno-społeczny
    p.a_pi = 4.0;
    p.a_F  = 3.0;
    p.a_W  = 2.0;

    % represja / kontrola
    p.r0   = 0.90;
    p.rW   = 0.30;

    % morale
    p.k_rally = 0.06;
    p.tau_rally = 26.0;
    p.k_fatigue = 0.05;
    p.k_price   = 0.015;
    p.k_disp    = 0.004;
    p.k_mrec    = 0.03;

    % protest
    p.k_mob   = 0.08;
    p.k_demob = 0.10;
    p.b1 = 2.5;
    p.b2 = 1.2;
    p.b3 = 1.0;
    p.b4 = 0.8;
    p.b5 = 2.2;
    p.c1 = 2.0;
    p.c2 = 1.0;
    p.c3 = 0.6;

    % informacja
    p.k_iinv = 0.03;
    p.k_iem  = 0.04;
    p.k_ideg = 0.03;
    p.k_idec = 0.01;

    % elity
    p.k_ecost  = 0.02;
    p.k_eprot  = 0.015;
    p.k_erally = 0.02;
    p.k_erec   = 0.12;

    % lojalność aparatu
    p.k_pay   = 0.05;
    p.k_lloss = 0.04;
    p.k_split = 0.03;
    p.k_lrec  = 0.02;

    % stabilność systemowa
    p.k_cons  = 0.075;
    p.k_info  = 0.02;
    p.k_srally = 0.05;
    p.k_sp    = 0.060;
    p.k_se    = 0.040;
    p.k_sw    = 0.030;
    p.k_srec  = 0.070;

    % ekspozycja wojskowa
    p.k_tup   = 0.05;
    p.k_tdown = 0.04;
    p.k_tattr = 0.02;

    % humanitarne
    p.k_dw  = 0.05;
    p.k_dp  = 0.03;
    p.k_de  = 0.01;
    p.k_ret = 0.03;
end

function thr = default_thresholds()
    thr.stab_crit = 0.30;
    thr.elite_crit = 0.35;
    thr.elite_streak_weeks = 4;
    thr.eps = 1e-9;
end

%% =====================================================================
%% SPEC / KONTRAKT MODELU
%% =====================================================================
function spec = build_spec_struct(params, thr)
    spec = struct();

    spec.model_name = 'MODEL_SPEC_v1';
    spec.dt = '1_week';
    spec.horizon_default_weeks = 156;

    spec.state_vars = { ...
        'Stab','Elite','Loyal','Info','Morale', ...
        'Protest','Fiscal','CPI','Troops','Displaced'};

    spec.exogenous = { ...
        'War','Sanctions','ExternalStress','Relief','OilPrice','Hazard'};

    spec.derived = { ...
        'OilRevIndex','Infl','EStress','Repr','Calm'};

    spec.thresholds = thr;
    spec.params = params;

    spec.notes = { ...
        'Stany poza CPI i Displaced są ograniczane do [0,1].', ...
        'CPI jest dodatnim indeksem cen.', ...
        'Displaced jest nieujemne.', ...
        'Model jest dyskretny, tygodniowy i gotowy do testów wrażliwości.'};
end

%% =====================================================================
%% NARZĘDZIA POMOCNICZE
%% =====================================================================
function y = clip(x, lo, hi)
    if nargin < 2, lo = 0.0; end
    if nargin < 3, hi = 1.0; end
    y = max(lo, min(hi, x));
end

function y = sigmoid(x)
    x = max(-60.0, min(60.0, x));
    y = 1.0 ./ (1.0 + exp(-x));
end

%% =====================================================================
%% SCENARIUSZE EGZOGENICZNE
%% =====================================================================
function exo = scenario_exog(t_week, scenario)

    switch scenario
        case 'szybka_wojna'
            if t_week < 8
                W = 1.0;
            elseif t_week < 12
                W = 0.5;
            else
                W = 0.1;
            end

            if t_week < 26
                San = 0.70;
            else
                San = 0.50;
            end

            X  = 0.35 + 0.20 * W;
            Rf = 0.20 + 0.05 * (1 - W);
            O  = 1.00 + 0.30 * W;
            H  = 0.20 + 0.30 * W;

        case 'dlugotrwala_wojna'
            if t_week < 52
                W = 0.80;
            else
                W = 0.60;
            end

            San = 0.85;
            X   = 0.55 + 0.15 * W;
            Rf  = 0.12;
            O   = 1.00 + 0.40 * W;
            H   = 0.35 + 0.20 * W;

        case 'impas'
            W = 0.50 + 0.15 * sin(2*pi*t_week/26);
            San = 0.75;
            X   = 0.45 + 0.10 * sin(2*pi*t_week/13);
            Rf  = 0.18;
            O   = 1.05 + 0.20 * W;
            H   = 0.28 + 0.10 * W;

        case 'eskalacja_regionalna'
            if t_week < 26
                W = 0.90;
            else
                W = 0.70;
            end

            San = 0.90;
            X   = 0.65 + 0.15 * W;
            Rf  = 0.08;
            O   = 1.00 + 0.50 * W;
            H   = 0.45 + 0.20 * W;

        otherwise
            W = 0.0;
            San = 0.3;
            X = 0.2;
            Rf = 0.2;
            O = 1.0;
            H = 0.1;
    end

    exo = struct();
    exo.War = clip(W);
    exo.Sanctions = clip(San);
    exo.ExternalStress = clip(X);
    exo.Relief = clip(Rf);
    exo.OilPrice = max(0.01, O);
    exo.Hazard = clip(H);
end

%% =====================================================================
%% JEDEN KROK MODELU
%% =====================================================================
function state_next = step_model(state, exo, params, t_week)

    % kanał energetyczny
    oilRev = max(0.0, ...
        params.oilExportCap ...
        * (1 - params.k_san_oil * exo.Sanctions) ...
        * (1 - params.k_war_oil * exo.War) ...
        * exo.OilPrice);

    % inflacja i CPI
    infl = max(0.0, ...
        params.pi0 ...
        + params.k_pi_san  * exo.Sanctions ...
        + params.k_pi_war  * exo.War ...
        + params.k_pi_fisc * max(0.0, 0.5 - state.Fiscal));

    cpi_next = state.CPI * (1.0 + infl / 52.0);

    % stres ekonomiczno-społeczny
    estress = sigmoid( ...
        params.a_pi * (infl - params.pi_target) ...
      + params.a_F  * (0.5 - state.Fiscal) ...
      + params.a_W  * exo.War ...
      + 0.60 * exo.ExternalStress);

    % spokój i zdolność represyjna
    calm = (1.0 - exo.War) * (1.0 - state.Protest);

    repr = clip( ...
        (params.r0 * state.Loyal * state.Elite + params.rW * exo.War) * state.Info, ...
        0.0, 1.0);

    % morale
    morale_next = clip( ...
        state.Morale ...
      + params.k_rally * exo.War * exp(-t_week / params.tau_rally) ...
      - params.k_fatigue * (exo.War + estress) ...
      - params.k_price * infl ...
      - params.k_disp * state.Displaced ...
      + params.k_mrec * calm * (1.0 - state.Morale) ...
      + 0.04 * exo.Relief, ...
      0.0, 1.0);

    % fiskalność
    fiscal_next = clip( ...
        state.Fiscal ...
      + params.k_rev * oilRev ...
      - params.k_warsp * exo.War ...
      - params.k_sub * (1.0 - morale_next) ...
      - params.k_leak * exo.Sanctions ...
      + 0.01 * calm * (1.0 - state.Fiscal) ...
      + 0.05 * exo.Relief, ...
      0.0, 1.0);

    % informacja
    info_next = clip( ...
        state.Info ...
      + params.k_iinv * fiscal_next ...
      + params.k_iem  * (exo.War + state.Protest) ...
      - params.k_ideg * exo.War ...
      - params.k_idec * calm * state.Info ...
      + 0.02 * exo.Relief, ...
      0.0, 1.0);

    % protest
    mob = params.k_mob * sigmoid( ...
        params.b1 * estress ...
      + params.b2 * (1.0 - morale_next) ...
      + params.b3 * (1.0 - state.Stab) ...
      + params.b4 * (1.0 - info_next) ...
      - params.b5 * repr);

    demob = params.k_demob * sigmoid( ...
        params.c1 * repr ...
      + params.c2 * exo.War ...
      + params.c3 * state.Protest) ...
      + 0.02 * calm * state.Protest ...
      + 0.03 * exo.Relief;

    protest_next = clip(state.Protest + mob - demob, 0.0, 1.0);

    % elity
    elite_eq = clip(0.38 + 0.28 * state.Stab, 0.22, 0.82);

    damage_elite = ...
        params.k_ecost * (0.75 * estress + 0.45 * exo.War + 0.25 * exo.ExternalStress) ...
      + 1.20 * params.k_eprot * protest_next;

    elite_next = clip( ...
        state.Elite ...
      + params.k_erally * exo.War * (1.0 - state.Elite) ...
      - damage_elite * state.Elite ...
      + 0.75 * params.k_erec * (elite_eq - state.Elite), ...
      0.0, 1.0);

    % lojalność
    loyal_next = clip( ...
        state.Loyal ...
      + params.k_pay * fiscal_next ...
      - params.k_lloss * (exo.War + estress + 0.40 * exo.ExternalStress) ...
      - params.k_split * (1.0 - elite_next) ...
      + params.k_lrec * calm * (1.0 - state.Loyal), ...
      0.0, 1.0);

    % stabilność
    stab_next = clip( ...
        state.Stab ...
      + params.k_cons * (elite_next * loyal_next * fiscal_next) ...
      + params.k_info * info_next ...
      + 0.015 * morale_next ...
      + params.k_srally * exo.War * exp(-t_week / params.tau_rally) ...
      - params.k_sp * protest_next ...
      - params.k_se * estress ...
      - params.k_sw * exo.War ...
      - 0.020 * exo.Hazard ...
      + params.k_srec * calm * (1.0 - state.Stab), ...
      0.0, 1.0);

    % wojsko
    troops_next = clip( ...
        state.Troops ...
      + params.k_tup * exo.War * (1.0 - state.Troops) ...
      - params.k_tdown * (1.0 - exo.War) * state.Troops ...
      - params.k_tattr * exo.War * state.Troops, ...
      0.0, 1.0);

    % wysiedlenia
    new_disp = ...
        params.k_dw * exo.War ...
      + params.k_dp * protest_next * repr ...
      + params.k_de * estress ...
      + 0.02 * exo.Hazard;

    returns = params.k_ret * (1.0 - exo.War) * (1.0 - protest_next) * state.Displaced;

    displaced_next = max(0.0, state.Displaced + new_disp - returns);

    % wynik
    state_next = struct();
    state_next.Stab = stab_next;
    state_next.Elite = elite_next;
    state_next.Loyal = loyal_next;
    state_next.Info = info_next;
    state_next.Morale = morale_next;
    state_next.Protest = protest_next;
    state_next.Fiscal = fiscal_next;
    state_next.CPI = cpi_next;
    state_next.Troops = troops_next;
    state_next.Displaced = displaced_next;

    % pochodne / diagnostyczne
    state_next.Infl = infl;
    state_next.EStress = estress;
    state_next.Repr = repr;
    state_next.Calm = calm;
    state_next.OilRevIndex = oilRev;

    % egzogeniczne zapisane w przebiegu
    state_next.War = exo.War;
    state_next.Sanctions = exo.Sanctions;
    state_next.ExternalStress = exo.ExternalStress;
    state_next.Relief = exo.Relief;
    state_next.OilPrice = exo.OilPrice;
    state_next.Hazard = exo.Hazard;
end

%% =====================================================================
%% SYMULACJA PEŁNEJ TRAJEKTORII
%% =====================================================================
function sim = simulate_model(params, scenario, years, seed, init_state)
    %#ok<INUSD>
    steps = years * 52;

    if isempty(init_state)
        state = struct();
        state.Stab = 0.60;
        state.Elite = 0.65;
        state.Loyal = 0.75;
        state.Info = 0.70;
        state.Morale = 0.55;
        state.Protest = 0.20;
        state.Fiscal = 0.45;
        state.CPI = 100.0;
        state.Troops = 0.20;
        state.Displaced = 0.0;
    else
        state = init_state;
    end

    week = (0:steps-1)';
    year = week / 52.0;

    vars = { ...
        'Stab','Elite','Loyal','Info','Morale','Protest','Fiscal','CPI','Troops','Displaced', ...
        'Infl','EStress','Repr','Calm','OilRevIndex', ...
        'War','Sanctions','ExternalStress','Relief','OilPrice','Hazard'};

    data = zeros(steps, numel(vars));

    for t = 0:steps-1
        exo = scenario_exog(t, scenario);
        state = step_model(state, exo, params, t);

        for j = 1:numel(vars)
            data(t+1,j) = state.(vars{j});
        end
    end

    sim = table(week, year);
    for j = 1:numel(vars)
        sim.(vars{j}) = data(:,j);
    end
end

%% =====================================================================
%% METRYKI
%% =====================================================================
function met = compute_metrics(sim, thr)
    n = height(sim);

    idx_crit = find(sim.Stab < thr.stab_crit, 1, 'first');
    if isempty(idx_crit)
        Tcrit = n + 1;
    else
        Tcrit = idx_crit - 1;
    end

    streak = 0;
    elite_frac = 0.0;
    t_frac = n + 1;

    for i = 1:n
        if sim.Elite(i) < thr.elite_crit
            streak = streak + 1;
            if streak >= thr.elite_streak_weeks
                elite_frac = 1.0;
                t_frac = i - thr.elite_streak_weeks;
                break
            end
        else
            streak = 0;
        end
    end

    met = struct();
    met.Tcrit = Tcrit;
    met.elite_fracture_prob = elite_frac;
    met.time_to_elite_fracture = t_frac;
    met.weeks_below_elite_crit = sum(sim.Elite < thr.elite_crit);

    met.avg_loyal = mean(sim.Loyal);
    met.peak_protest = max(sim.Protest);
    met.end_displaced_m = sim.Displaced(end);

    met.mean_elite = mean(sim.Elite);
    met.min_elite = min(sim.Elite);
    met.mean_stab = mean(sim.Stab);
    met.min_stab = min(sim.Stab);

    met.final_stab = sim.Stab(end);
    met.final_elite = sim.Elite(end);
    met.final_fiscal = sim.Fiscal(end);
    met.final_cpi = sim.CPI(end);
end

function ext = compute_extra_metrics(sim)
    peak = -inf;
    max_dd = 0.0;

    for i = 1:height(sim)
        peak = max(peak, sim.Stab(i));
        if peak > 0
            dd = (peak - sim.Stab(i)) / peak;
            max_dd = max(max_dd, dd);
        end
    end

    ext = struct();
    ext.max_drawdown_stab = max_dd;
    ext.stress_area = mean(sim.EStress);

    ext.sat_rate_stab = mean(sim.Stab > 0.99);
    ext.sat_rate_elite = mean(sim.Elite > 0.99);
    ext.sat_rate_protest = mean(sim.Protest > 0.99);
    ext.sat_rate_loyal = mean(sim.Loyal > 0.99);

    ext.bounds_ok = ...
        all(sim.Stab >= 0 & sim.Stab <= 1) && ...
        all(sim.Elite >= 0 & sim.Elite <= 1) && ...
        all(sim.Loyal >= 0 & sim.Loyal <= 1) && ...
        all(sim.Info >= 0 & sim.Info <= 1) && ...
        all(sim.Morale >= 0 & sim.Morale <= 1) && ...
        all(sim.Protest >= 0 & sim.Protest <= 1) && ...
        all(sim.Fiscal >= 0 & sim.Fiscal <= 1) && ...
        all(sim.Troops >= 0 & sim.Troops <= 1) && ...
        all(sim.Displaced >= 0) && ...
        all(sim.CPI > 0);

    ext.finite_ok = all(isfinite(table2array(sim(:,3:end))));
end

%% =====================================================================
%% WYKRESY
%% =====================================================================
function plot_results(results)

    figure('Name','MATJ_3 :: Stany główne','Color','w');
    tiledlayout(3,2);

    nexttile; hold on;
    for i = 1:numel(results)
        plot(results(i).sim.week, results(i).sim.Stab, 'LineWidth',1.6, 'DisplayName',results(i).name);
    end
    title('Stab'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results)
        plot(results(i).sim.week, results(i).sim.Elite, 'LineWidth',1.6, 'DisplayName',results(i).name);
    end
    title('Elite'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results)
        plot(results(i).sim.week, results(i).sim.Loyal, 'LineWidth',1.6, 'DisplayName',results(i).name);
    end
    title('Loyal'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results)
        plot(results(i).sim.week, results(i).sim.Protest, 'LineWidth',1.6, 'DisplayName',results(i).name);
    end
    title('Protest'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results)
        plot(results(i).sim.week, results(i).sim.Fiscal, 'LineWidth',1.6, 'DisplayName',results(i).name);
    end
    title('Fiscal'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results)
        plot(results(i).sim.week, results(i).sim.CPI, 'LineWidth',1.6, 'DisplayName',results(i).name);
    end
    title('CPI'); grid on; legend('Location','best'); hold off;

    figure('Name','MATJ_3 :: Kanały pochodne','Color','w');
    tiledlayout(3,2);

    nexttile; hold on;
    for i = 1:numel(results)
        plot(results(i).sim.week, results(i).sim.EStress, 'LineWidth',1.6, 'DisplayName',results(i).name);
    end
    title('EStress'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results)
        plot(results(i).sim.week, results(i).sim.Repr, 'LineWidth',1.6, 'DisplayName',results(i).name);
    end
    title('Repr'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results)
        plot(results(i).sim.week, results(i).sim.OilRevIndex, 'LineWidth',1.6, 'DisplayName',results(i).name);
    end
    title('OilRevIndex'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results)
        plot(results(i).sim.week, results(i).sim.Troops, 'LineWidth',1.6, 'DisplayName',results(i).name);
    end
    title('Troops'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results)
        plot(results(i).sim.week, results(i).sim.Displaced, 'LineWidth',1.6, 'DisplayName',results(i).name);
    end
    title('Displaced'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results)
        plot(results(i).sim.week, results(i).sim.War, 'LineWidth',1.6, 'DisplayName',results(i).name);
    end
    title('War'); grid on; legend('Location','best'); hold off;
end
