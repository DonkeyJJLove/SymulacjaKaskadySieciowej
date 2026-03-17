function out = matj_4(action, varargin)
% MATJ_4
% Wierny port MATLAB modelu z repozytorium SymulacjaKaskadySieciowej
% + test_suite
% + Monte Carlo
% + hooki GSA/Sobol
% + artefakty SPEC / manifest / porównania MATLAB<->Python
%
% Użycie:
%   r  = matj_4('test');
%   df = matj_4('simulate','scenario','impas','years',3,'seed',12345);
%   m  = matj_4('compute_metrics', df, 3, 'stab_crit',0.30,'elite_crit',0.35,'elite_streak_weeks',4);
%   mc = matj_4('monte_carlo','scenario','impas','years',3,'n',100,'spread',0.20,'seed',42);
%   sp = matj_4('spec');
%
% Wymagania:
%   MATLAB R2022b+
%   Dla pełnej części GSA przydaje się Statistics and Machine Learning Toolbox.
%
% Noty:
%   - krok modelu: 1 tydzień
%   - dynamika jest deterministyczna; RNG ma znaczenie dla MC / Sobol
%   - wszystkie stany unit są clipowane do [0,1]
%   - CPI > 0, Displaced >= 0

    if nargin == 0 || isempty(action)
        action = 'test';
    end
    action = lower(string(action));

    switch action
        case "default_params"
            out = default_params();

        case "default_thresholds"
            out = default_thresholds();

        case "spec"
            out = build_spec_struct(default_params(), default_thresholds());

        case "simulate"
            out = action_simulate(varargin{:});

        case "compute_metrics"
            out = action_compute_metrics(varargin{:});

        case "compute_extra_metrics"
            if nargin < 2
                error('matj_4:compute_extra_metrics', 'Podaj tabelę symulacji.');
            end
            out = compute_extra_metrics(varargin{1});

        case "monte_carlo"
            out = action_monte_carlo(varargin{:});

        case "transform_unit_samples_to_params"
            out = action_transform_unit_samples(varargin{:});

        case "aggregate_replicates"
            out = action_aggregate_replicates(varargin{:});

        case "sobol"
            out = action_sobol(varargin{:});

        case "test"
            out = action_test(varargin{:});

        otherwise
            error('matj_4:unknownAction', 'Nieznana akcja: %s', action);
    end
end

%% =====================================================================
%% ACTIONS
%% =====================================================================
function df = action_simulate(varargin)
    p = inputParser;
    addParameter(p, 'scenario', 'impas');
    addParameter(p, 'years', 3);
    addParameter(p, 'seed', 42);
    addParameter(p, 'params', default_params());
    addParameter(p, 'init_state', []);
    parse(p, varargin{:});

    df = simulate_model(p.Results.params, char(p.Results.scenario), ...
        p.Results.years, p.Results.seed, p.Results.init_state);
end

function met = action_compute_metrics(varargin)
    if nargin < 1
        error('matj_4:compute_metrics', 'Podaj tabelę symulacji jako pierwszy argument.');
    end

    df = varargin{1};
    start_idx = 2;

    if nargin >= 2 && isnumeric(varargin{2}) && isscalar(varargin{2})
        start_idx = 3; % years jest ignorowane, ale wspierane dla zgodności wywołania
    end

    thr = default_thresholds();
    if nargin >= start_idx
        p = inputParser;
        addParameter(p, 'stab_crit', thr.stab_crit);
        addParameter(p, 'elite_crit', thr.elite_crit);
        addParameter(p, 'elite_streak_weeks', thr.elite_streak_weeks);
        parse(p, varargin{start_idx:end});
        thr.stab_crit = p.Results.stab_crit;
        thr.elite_crit = p.Results.elite_crit;
        thr.elite_streak_weeks = p.Results.elite_streak_weeks;
    end

    met = compute_metrics(df, thr);
end

function mc = action_monte_carlo(varargin)
    p = inputParser;
    addParameter(p, 'scenario', 'impas');
    addParameter(p, 'years', 3);
    addParameter(p, 'n', 100);
    addParameter(p, 'spread', 0.20);
    addParameter(p, 'seed', 42);
    addParameter(p, 'params', default_params());
    addParameter(p, 'mc_use_python_rng', false);
    parse(p, varargin{:});

    mc = monte_carlo_model(p.Results.params, char(p.Results.scenario), ...
        p.Results.years, p.Results.n, p.Results.seed, p.Results.spread, ...
        p.Results.mc_use_python_rng);
end

function out = action_transform_unit_samples(varargin)
    if nargin < 1
        error('matj_4:transform', 'Podaj macierz U z [0,1].');
    end
    U = varargin{1};
    specs = default_gsa_param_specs();
    if nargin >= 2 && ~isempty(varargin{2})
        specs = varargin{2};
    end
    out = transform_unit_samples_to_params(U, specs);
end

function out = action_aggregate_replicates(varargin)
    if nargin < 1
        error('matj_4:aggregate_replicates', 'Podaj tablicę wyników replik.');
    end
    out = aggregate_replicates(varargin{1});
end

function out = action_sobol(varargin)
    p = inputParser;
    addParameter(p, 'scenario', 'impas');
    addParameter(p, 'years', 3);
    addParameter(p, 'N', 256);
    addParameter(p, 'seed_base', 42);
    addParameter(p, 'replicates', 1);
    addParameter(p, 'rep_seed_stride', 1000);
    addParameter(p, 'use_python_salib', false);
    addParameter(p, 'out_dir', '');
    parse(p, varargin{:});

    out = sobol_suite(char(p.Results.scenario), p.Results.years, ...
        p.Results.N, p.Results.seed_base, p.Results.replicates, ...
        p.Results.rep_seed_stride, p.Results.use_python_salib, char(p.Results.out_dir));
end

function report = action_test(varargin)
    p = inputParser;
    addParameter(p, 'years', 3);
    addParameter(p, 'seed', 42);
    addParameter(p, 'out_root', 'outputs_matlab');
    addParameter(p, 'python_outputs_dir', '');
    addParameter(p, 'run_sobol', false);
    addParameter(p, 'sobol_N', 128);
    addParameter(p, 'monte_carlo_n', 120);
    addParameter(p, 'mc_spread', 0.20);
    addParameter(p, 'mc_use_python_rng', false);
    parse(p, varargin{:});

    report = test_suite(p.Results.years, p.Results.seed, char(p.Results.out_root), ...
        char(p.Results.python_outputs_dir), p.Results.run_sobol, ...
        p.Results.sobol_N, p.Results.monte_carlo_n, p.Results.mc_spread, ...
        p.Results.mc_use_python_rng);
end

%% =====================================================================
%% CORE MODEL
%% =====================================================================
function p = default_params()
    p = struct();

    p.oil_export_cap = 1.00;
    p.k_san_oil = 0.60;
    p.k_war_oil = 0.70;
    p.k_rev = 0.12;
    p.k_war_spend = 0.10;
    p.k_subsidy = 0.06;
    p.k_san_leak = 0.04;

    p.pi_base = 0.35;
    p.pi_target = 0.10;
    p.k_pi_san = 0.25;
    p.k_pi_war = 0.35;
    p.k_pi_fisc = 0.20;

    p.a_inf = 4.0;
    p.a_fisc = 3.0;
    p.a_war = 2.0;

    p.r0 = 0.90;
    p.r_w = 0.30;

    p.k_mob = 0.08;
    p.k_demob = 0.10;

    p.b1 = 2.5;
    p.b2 = 1.2;
    p.b3 = 1.0;
    p.b4 = 0.8;
    p.b5 = 2.2;

    p.c1 = 2.0;
    p.c2 = 1.0;
    p.c3 = 0.6;

    p.k_rally = 0.06;
    p.tau_rally = 26.0;
    p.k_fatigue = 0.05;
    p.k_price = 0.015;
    p.k_disp = 0.004;
    p.k_morale_recover = 0.03;

    p.k_cons = 0.075;
    p.k_info = 0.02;
    p.k_loss_p = 0.060;
    p.k_loss_e = 0.040;
    p.k_loss_w = 0.030;
    p.k_rally_s = 0.05;
    p.k_stab_recover = 0.070;

    p.k_elite_rally = 0.02;
    p.k_elite_cost = 0.02;
    p.k_elite_protest = 0.015;
    p.k_elite_recover = 0.12;

    p.k_pay = 0.05;
    p.k_loss_l = 0.04;
    p.k_split = 0.03;
    p.k_loyal_recover = 0.02;

    p.k_info_invest = 0.03;
    p.k_info_emerg = 0.04;
    p.k_info_deg_w = 0.03;
    p.k_info_decay_calm = 0.01;

    p.k_troop_up = 0.05;
    p.k_troop_down = 0.04;
    p.k_troop_attr = 0.02;

    p.k_disp_w = 0.05;
    p.k_disp_p = 0.03;
    p.k_disp_e = 0.01;
    p.k_return = 0.03;

    p.oil_price_base = 1.00;
    p.k_price_shock = 0.50;
end

function thr = default_thresholds()
    thr = struct();
    thr.stab_crit = 0.30;
    thr.elite_crit = 0.35;
    thr.elite_streak_weeks = 4;
    thr.eps = 1e-9;
end

function spec = build_spec_struct(p, thr)
    spec = struct();
    spec.model_name = 'matj_4';
    spec.repo = 'DonkeyJJLove/SymulacjaKaskadySieciowej';
    spec.dt = '1_week';
    spec.horizon_default_weeks = 156;
    spec.state_vars = {'Stab','Elite','Loyal','Info','Morale','Protest','Fiscal','CPI','Troops','Displaced'};
    spec.derived_vars = {'Infl','EStress','Repr','War','Sanctions','OilPrice','OilRevIndex'};
    spec.thresholds = thr;
    spec.params = p;
    spec.gsa_param_names = default_gsa_param_names();
end

function [war, sanctions] = scenario_exog(t_week, scenario)
    switch scenario
        case 'szybka_wojna'
            if t_week < 8
                war = 1.0;
            elseif t_week < 12
                war = 0.5;
            else
                war = 0.1;
            end

            if t_week < 26
                sanctions = 0.7;
            else
                sanctions = 0.5;
            end

        case 'dlugotrwala_wojna'
            if t_week < 52
                war = 0.8;
            else
                war = 0.6;
            end
            sanctions = 0.85;

        case 'impas'
            war = 0.5 + 0.15 * sin(2*pi*t_week/26);
            sanctions = 0.75;

        case 'eskalacja_regionalna'
            if t_week < 26
                war = 0.9;
            else
                war = 0.7;
            end
            sanctions = 0.9;

        otherwise
            war = 0.0;
            sanctions = 0.3;
    end

    war = clip(war, 0.0, 1.0);
    sanctions = clip(sanctions, 0.0, 1.0);
end

function state_next = step_model(state, t_week, p, scenario)
    [war, sanctions] = scenario_exog(t_week, scenario);

    oil_price = p.oil_price_base * (1.0 + p.k_price_shock * war);
    revenue = p.oil_export_cap ...
        * (1.0 - p.k_san_oil * sanctions) ...
        * (1.0 - p.k_war_oil * war) ...
        * oil_price;
    revenue = max(0.0, revenue);

    fiscal = state.Fiscal;
    inflation = p.pi_base ...
        + p.k_pi_san * sanctions ...
        + p.k_pi_war * war ...
        + p.k_pi_fisc * max(0.0, 0.5 - fiscal);
    inflation = max(0.0, inflation);

    cpi = state.CPI * (1.0 + inflation / 52.0);
    estress = sigmoid(p.a_inf * (inflation - p.pi_target) + p.a_fisc * (0.5 - fiscal) + p.a_war * war);
    calm = (1.0 - war) * (1.0 - state.Protest);

    elite = state.Elite;
    loyal = state.Loyal;
    info = state.Info;
    repr_cap = clip((p.r0 * loyal * elite + p.r_w * war) * info, 0.0, 1.0);

    morale = state.Morale;
    displaced = state.Displaced;
    rally_term = p.k_rally * war * exp(-t_week / p.tau_rally);

    morale_next = clip(morale + rally_term - p.k_fatigue * (war + estress) - p.k_price * inflation ...
        - p.k_disp * displaced + p.k_morale_recover * calm * (1.0 - morale), 0.0, 1.0);

    inflow = p.k_rev * revenue;
    outflow = p.k_war_spend * war + p.k_subsidy * (1.0 - morale_next) + p.k_san_leak * sanctions;
    fiscal_next = clip(fiscal + inflow - outflow + 0.01 * calm * (1.0 - fiscal), 0.0, 1.0);

    info_next = clip(info + p.k_info_invest * fiscal_next + p.k_info_emerg * (war + state.Protest) ...
        - p.k_info_deg_w * war - p.k_info_decay_calm * calm * info, 0.0, 1.0);

    protest = state.Protest;
    mobilize = p.k_mob * sigmoid(p.b1 * estress + p.b2 * (1.0 - morale_next) + p.b3 * (1.0 - state.Stab) ...
        + p.b4 * (1.0 - info_next) - p.b5 * repr_cap);
    demobilize = p.k_demob * sigmoid(p.c1 * repr_cap + p.c2 * war + p.c3 * protest) + 0.02 * calm * protest;
    protest_next = clip(protest + mobilize - demobilize, 0.0, 1.0);

    stab = state.Stab;
    elite_eq = clip(0.38 + 0.28 * stab, 0.22, 0.82);
    elite_damage = p.k_elite_cost * (0.75 * estress + 0.45 * war) + 1.20 * p.k_elite_protest * protest_next;
    elite_next = clip(elite + p.k_elite_rally * war * (1.0 - elite) - elite_damage * elite ...
        + 0.75 * p.k_elite_recover * (elite_eq - elite), 0.0, 1.0);

    loyal_next = clip(loyal + p.k_pay * fiscal_next - p.k_loss_l * (war + estress) ...
        - p.k_split * (1.0 - elite_next) + p.k_loyal_recover * calm * (1.0 - loyal), 0.0, 1.0);

    stab_next = clip(stab + p.k_cons * (elite_next * loyal_next * fiscal_next) + p.k_info * info_next ...
        + 0.015 * morale_next + p.k_rally_s * war * exp(-t_week / p.tau_rally) ...
        - p.k_loss_p * protest_next - p.k_loss_e * estress - p.k_loss_w * war ...
        + p.k_stab_recover * calm * (1.0 - stab), 0.0, 1.0);

    troops = state.Troops;
    troops_next = clip(troops + p.k_troop_up * war * (1.0 - troops) ...
        - p.k_troop_down * (1.0 - war) * troops - p.k_troop_attr * war * troops, 0.0, 1.0);

    new_disp = p.k_disp_w * war + p.k_disp_p * protest_next * repr_cap + p.k_disp_e * estress;
    returns = p.k_return * (1.0 - war) * (1.0 - protest_next) * state.Displaced;
    displaced_next = max(0.0, state.Displaced + new_disp - returns);

    state_next = struct('Stab',stab_next,'Elite',elite_next,'Loyal',loyal_next,'Info',info_next, ...
        'Morale',morale_next,'Protest',protest_next,'Fiscal',fiscal_next,'CPI',cpi,'Infl',inflation, ...
        'EStress',estress,'Repr',repr_cap,'Troops',troops_next,'Displaced',displaced_next, ...
        'War',war,'Sanctions',sanctions,'OilPrice',oil_price,'OilRevIndex',revenue);
end

function df = simulate_model(p, scenario, years, seed, init_state)
    rng(seed, 'twister'); %#ok<NASGU>
    steps = years * 52;

    if isempty(init_state)
        state = struct('Stab',0.60,'Elite',0.65,'Loyal',0.75,'Info',0.70,'Morale',0.55, ...
            'Protest',0.20,'Fiscal',0.45,'CPI',100.0,'Troops',0.20,'Displaced',0.0);
    else
        state = init_state;
    end

    week = (0:steps-1)';
    year = week / 52.0;
    vars = {'Stab','Elite','Loyal','Info','Morale','Protest','Fiscal','CPI','Infl','EStress','Repr','Troops','Displaced','War','Sanctions','OilPrice','OilRevIndex'};
    data = zeros(steps, numel(vars));

    for t = 0:steps-1
        state = step_model(state, t, p, scenario);
        for j = 1:numel(vars)
            data(t+1,j) = state.(vars{j});
        end
    end

    df = table(week, year);
    for j = 1:numel(vars)
        df.(vars{j}) = data(:,j);
    end
end

function met = compute_metrics(df, thr)
    max_weeks = height(df);
    idx = find(df.Stab < thr.stab_crit, 1, 'first');
    if isempty(idx)
        Tcrit = max_weeks + 1;
    else
        Tcrit = idx - 1;
    end

    streak = 0;
    fracture = 0.0;
    t_frac = max_weeks + 1;
    for i = 1:height(df)
        value = df.Elite(i);
        if value < thr.elite_crit
            streak = streak + 1;
            if streak >= thr.elite_streak_weeks
                fracture = 1.0;
                t_frac = i - thr.elite_streak_weeks;
                break;
            end
        else
            streak = 0;
        end
    end

    met = struct();
    met.Tcrit = double(Tcrit);
    met.elite_fracture_prob = double(fracture);
    met.time_to_elite_fracture = double(t_frac);
    met.weeks_below_elite_crit = double(sum(df.Elite < thr.elite_crit));
    met.avg_loyal = mean(df.Loyal);
    met.peak_protest = max(df.Protest);
    met.end_displaced_m = df.Displaced(end);
    met.mean_elite = mean(df.Elite);
    met.min_elite = min(df.Elite);
    met.mean_stab = mean(df.Stab);
    met.min_stab = min(df.Stab);
end

function ext = compute_extra_metrics(df)
    peak = -Inf;
    max_dd = 0.0;
    for i = 1:height(df)
        peak = max(peak, df.Stab(i));
        if peak > 0
            dd = (peak - df.Stab(i)) / peak;
            max_dd = max(max_dd, dd);
        end
    end

    ext = struct();
    ext.final_stab = df.Stab(end);
    ext.final_elite = df.Elite(end);
    ext.final_fiscal = df.Fiscal(end);
    ext.final_cpi = df.CPI(end);
    ext.max_drawdown_stab = max_dd;
    ext.stress_area = mean(df.EStress);

    key_vars = {'Stab','Elite','Loyal','Info','Morale','Protest','Fiscal','Troops'};
    sat_hi = struct();
    sat_lo = struct();
    for i = 1:numel(key_vars)
        v = df.(key_vars{i});
        sat_hi.(key_vars{i}) = mean(v > 0.995);
        sat_lo.(key_vars{i}) = mean(v < 0.005);
    end
    ext.sat_hi = sat_hi;
    ext.sat_lo = sat_lo;

    ext.bounds_ok = all(df.Stab >= 0 & df.Stab <= 1) ...
        && all(df.Elite >= 0 & df.Elite <= 1) ...
        && all(df.Loyal >= 0 & df.Loyal <= 1) ...
        && all(df.Info >= 0 & df.Info <= 1) ...
        && all(df.Morale >= 0 & df.Morale <= 1) ...
        && all(df.Protest >= 0 & df.Protest <= 1) ...
        && all(df.Fiscal >= 0 & df.Fiscal <= 1) ...
        && all(df.Troops >= 0 & df.Troops <= 1) ...
        && all(df.Displaced >= 0) ...
        && all(df.CPI > 0) ...
        && all(df.Infl >= 0);
    ext.finite_ok = all(isfinite(table2array(df(:,3:end))), 'all');
end

%% =====================================================================
%% MONTE CARLO
%% =====================================================================
function mc = monte_carlo_model(base_params, scenario, years, n, seed, spread, use_python_rng)
    param_names = fieldnames(base_params);
    metric_names = {'Tcrit','elite_fracture_prob','peak_protest','min_stab','mean_stab','end_displaced_m'};
    raw = zeros(n, numel(metric_names));

    if use_python_rng
        U = maybe_python_uniform(n, numel(param_names), seed);
    else
        rng(seed, 'twister');
        U = rand(n, numel(param_names));
    end

    for i = 1:n
        p = base_params;
        for k = 1:numel(param_names)
            key = param_names{k};
            value = base_params.(key);
            lo = value * (1 - spread);
            hi = value * (1 + spread);
            if contains(key, 'target')
                lo = max(lo, 0.0);
            end
            p.(key) = lo + (hi - lo) * U(i,k);
        end

        df = simulate_model(p, scenario, years, seed + i, []);
        met = compute_metrics(df, default_thresholds());

        raw(i,1) = met.Tcrit;
        raw(i,2) = met.elite_fracture_prob;
        raw(i,3) = met.peak_protest;
        raw(i,4) = met.min_stab;
        raw(i,5) = met.mean_stab;
        raw(i,6) = met.end_displaced_m;
    end

    mc = array2table(raw, 'VariableNames', metric_names);
end

%% =====================================================================
%% GSA / PARAM DISTRIBUTIONS
%% =====================================================================
function names = default_gsa_param_names()
    names = {'k_rev','k_pi_san','k_loss_p','k_loss_e','k_pay','k_split','k_info_invest','k_info_emerg','k_stab_recover','k_price_shock'};
end

function specs = default_gsa_param_specs()
    specs = struct();
    specs.k_rev = struct('dist','beta','a',2,'b',6,'lo',0.05,'hi',0.20);
    specs.k_pi_san = struct('dist','beta','a',2,'b',5,'lo',0.10,'hi',0.40);
    specs.k_loss_p = struct('dist','beta','a',2,'b',4,'lo',0.02,'hi',0.12);
    specs.k_loss_e = struct('dist','beta','a',2,'b',5,'lo',0.01,'hi',0.08);
    specs.k_pay = struct('dist','beta','a',2,'b',5,'lo',0.02,'hi',0.09);
    specs.k_split = struct('dist','beta','a',2,'b',5,'lo',0.01,'hi',0.06);
    specs.k_info_invest = struct('dist','beta','a',2,'b',5,'lo',0.01,'hi',0.06);
    specs.k_info_emerg = struct('dist','beta','a',2,'b',5,'lo',0.01,'hi',0.08);
    specs.k_stab_recover = struct('dist','beta','a',3,'b',3,'lo',0.02,'hi',0.15);
    specs.k_price_shock = struct('dist','truncnorm','mu',0.50,'sigma',0.18,'lo',0.10,'hi',1.20);
end

function tbl = transform_unit_samples_to_params(U, specs)
    if ~ismatrix(U)
        error('U musi być macierzą NxD.');
    end

    names = fieldnames(specs);
    D = numel(names);
    if size(U,2) ~= D
        error('Liczba kolumn U (%d) musi równać się liczbie parametrów (%d).', size(U,2), D);
    end

    X = zeros(size(U));
    for j = 1:D
        s = specs.(names{j});
        u = min(max(U(:,j), eps), 1-eps);

        switch lower(s.dist)
            case 'beta'
                z = betainv(u, s.a, s.b);
                X(:,j) = s.lo + (s.hi - s.lo) * z;

            case 'truncnorm'
                a = (s.lo - s.mu) / s.sigma;
                b = (s.hi - s.mu) / s.sigma;
                Fa = normcdf_local(a);
                Fb = normcdf_local(b);
                z = Fa + u .* (Fb - Fa);
                X(:,j) = s.mu + s.sigma .* norminv_local(z);

            otherwise
                error('Nieobsługiwany rozkład: %s', s.dist);
        end
    end

    tbl = array2table(X, 'VariableNames', names);
end

function agg = aggregate_replicates(X)
    if isempty(X)
        agg = struct('mean', [], 'std', [], 'min', [], 'max', []);
        return;
    end

    if istable(X)
        A = table2array(X);
        names = X.Properties.VariableNames;
    else
        A = X;
        names = compose("x%d", 1:size(A,2));
    end

    agg = struct();
    agg.mean = array2table(mean(A,1,'omitnan'), 'VariableNames', cellstr(names));
    agg.std  = array2table(std(A,0,1,'omitnan'), 'VariableNames', cellstr(names));
    agg.min  = array2table(min(A,[],1), 'VariableNames', cellstr(names));
    agg.max  = array2table(max(A,[],1), 'VariableNames', cellstr(names));
end

function out = sobol_suite(scenario, years, N, seed_base, replicates, rep_seed_stride, use_python_salib, out_dir)
    if nargin < 7, use_python_salib = false; end
    if nargin < 8 || isempty(out_dir)
        out_dir = fullfile('outputs_matlab', ['sobol_' datestr(now,'yyyymmdd_HHMMSSFFF')]);
    end
    ensure_dir_local(out_dir);

    specs = default_gsa_param_specs();
    names = fieldnames(specs);
    D = numel(names);

    if use_python_salib
        U = maybe_python_sobol(N, D, seed_base);
        source = 'python_salib_or_fallback';
    else
        U = matlab_sobol_unit_samples(N, D, seed_base);
        source = 'matlab_sobolset';
    end

    param_tbl = transform_unit_samples_to_params(U, specs);

    rows = [];
    for i = 1:height(param_tbl)
        rep_metrics = zeros(replicates, 6);
        for r = 1:replicates
            p = default_params();
            for j = 1:numel(names)
                p.(names{j}) = param_tbl{i,j};
            end
            seed = seed_base + (i-1) * rep_seed_stride + (r-1);
            df = simulate_model(p, scenario, years, seed, []);
            met = compute_metrics(df, default_thresholds());
            rep_metrics(r,:) = [met.Tcrit, met.elite_fracture_prob, met.peak_protest, met.min_stab, met.mean_stab, met.end_displaced_m];
        end
        agg = aggregate_replicates(rep_metrics);
        row = [table(i, 'VariableNames', {'sample_id'}), param_tbl(i,:), addprefix(agg.mean, 'mean_'), addprefix(agg.std, 'std_')];
        rows = [rows; row]; %#ok<AGROW>
    end

    writetable(rows, fullfile(out_dir, 'sobol_model_outputs.csv'));
    out = struct();
    out.out_dir = out_dir;
    out.source = source;
    out.samples = param_tbl;
    out.outputs = rows;
end

%% =====================================================================
%% TEST SUITE
%% =====================================================================
function report = test_suite(years, seed, out_root, python_outputs_dir, run_sobol, sobol_N, monte_carlo_n, mc_spread, mc_use_python_rng)
    if nargin < 3 || isempty(out_root)
        out_root = 'outputs_matlab';
    end
    ensure_dir_local(out_root);
    ts = datestr(now, 'yyyymmdd_HHMMSSFFF');
    out_dir = fullfile(out_root, ts);
    ensure_dir_local(out_dir);

    p = default_params();
    thr = default_thresholds();
    spec = build_spec_struct(p, thr);

    scenarios = {'szybka_wojna','dlugotrwala_wojna','impas','eskalacja_regionalna'};
    results = struct([]);

    for i = 1:numel(scenarios)
        df = simulate_model(p, scenarios{i}, years, seed, []);
        met = compute_metrics(df, thr);
        ext = compute_extra_metrics(df);
        results(i).name = scenarios{i};
        results(i).df = df;
        results(i).metrics = met;
        results(i).extra = ext;
        writetable(df, fullfile(out_dir, sprintf('matlab_run_%s.csv', scenarios{i})));
    end

    test = struct();

    finite_bounds_ok = true;
    for i = 1:numel(results)
        finite_bounds_ok = finite_bounds_ok && results(i).extra.finite_ok && results(i).extra.bounds_ok;
    end
    test.finite_bounds = make_test('finite_bounds', 100 * double(finite_bounds_ok), 100, finite_bounds_ok);

    d1 = simulate_model(p, 'impas', years, seed, []);
    d2 = simulate_model(p, 'impas', years, seed, []);
    same = isequaln(d1, d2);
    test.determinism = make_test('determinism', 100 * double(same), 100, same);

    test.monotonicity_sanctions = test_monotonicity_sanctions(p);
    test.local_stability = test_local_stability(p, years, seed);
    test.realism = test_realism(results);
    test.scenario_order = test_scenario_order(results);

    mc = monte_carlo_model(p, 'impas', years, monte_carlo_n, seed + 111, mc_spread, mc_use_python_rng);
    writetable(mc, fullfile(out_dir, 'matlab_monte_carlo.csv'));
    save_mc_fig(mc, out_dir);

    collapse_rate = mean(mc.min_stab < 0.05);
    mc_score = max(0, 100 * (1 - collapse_rate));
    test.monte_carlo = make_test('monte_carlo', mc_score, 100, mc_score >= 60);

    compare = [];
    test.python_compare = make_test('python_compare', 50, 100, false);
    if ~isempty(python_outputs_dir) && isfolder(python_outputs_dir)
        compare = compare_with_python(results, python_outputs_dir, out_dir);
        if ~isempty(compare)
            max_abs = max(compare.abs_diff, [], 'omitnan');
            sc = 100 * double(max_abs < 1e-8) + 80 * double(max_abs < 1e-6 & max_abs >= 1e-8) ...
               + 60 * double(max_abs < 1e-4 & max_abs >= 1e-6) + 0 * double(max_abs >= 1e-4);
            test.python_compare = make_test('python_compare', sc, 100, sc >= 60);
        end
    end

    sobol_info = [];
    if run_sobol
        sobol_info = sobol_suite('impas', years, sobol_N, seed + 777, 1, 1000, false, fullfile(out_dir, 'sobol'));
    end

    [quality_score, qtbl] = aggregate_quality(test);

    write_spec_yaml(spec, fullfile(out_dir, 'SPEC.yaml'));
    write_run_manifest(out_dir, years, seed, scenarios, quality_score, mc_use_python_rng);
    write_report_txt(out_dir, results, test, quality_score);
    save_scenario_fig(results, out_dir);

    report = struct();
    report.out_dir = out_dir;
    report.results = results;
    report.tests = test;
    report.quality_score = quality_score;
    report.quality_label = quality_label(quality_score);
    report.quality_table = qtbl;
    report.monte_carlo = mc;
    report.python_compare_long = compare;
    report.sobol = sobol_info;

    save(fullfile(out_dir, 'matj_4_workspace.mat'), 'report');

    fprintf('=============================================================\n');
    fprintf('MATJ_4 TEST SUITE\n');
    fprintf('=============================================================\n');
    fprintf('out_dir        : %s\n', out_dir);
    fprintf('quality_score  : %.2f / 100\n', quality_score);
    fprintf('quality_label  : %s\n', report.quality_label);
end

function out = make_test(name, score, max_score, pass)
    out = struct('name',name,'score',score,'max_score',max_score,'pass',pass);
end

function out = test_monotonicity_sanctions(p)
    s = struct('Stab',0.60,'Elite',0.65,'Loyal',0.75,'Info',0.70,'Morale',0.55,'Protest',0.20,'Fiscal',0.45,'CPI',100.0,'Troops',0.20,'Displaced',0.0);
    exo_low = struct('War',0.6,'Sanctions',0.2);
    exo_hi  = struct('War',0.6,'Sanctions',0.9);

    a = step_with_fixed_exog(s, exo_low, p, 0);
    b = step_with_fixed_exog(s, exo_hi,  p, 0);

    ok1 = b.OilRevIndex <= a.OilRevIndex + 1e-12;
    ok2 = b.Infl >= a.Infl - 1e-12;
    score = 100 * mean([ok1 ok2]);
    out = make_test('monotonicity_sanctions', score, 100, score == 100);
end

function state_next = step_with_fixed_exog(state, exo, p, t_week)
    war = clip(exo.War, 0.0, 1.0);
    sanctions = clip(exo.Sanctions, 0.0, 1.0);

    oil_price = p.oil_price_base * (1.0 + p.k_price_shock * war);
    revenue = p.oil_export_cap * (1.0 - p.k_san_oil * sanctions) * (1.0 - p.k_war_oil * war) * oil_price;
    revenue = max(0.0, revenue);

    fiscal = state.Fiscal;
    inflation = p.pi_base + p.k_pi_san * sanctions + p.k_pi_war * war + p.k_pi_fisc * max(0.0, 0.5 - fiscal);
    inflation = max(0.0, inflation);
    cpi = state.CPI * (1.0 + inflation / 52.0);

    estress = sigmoid(p.a_inf * (inflation - p.pi_target) + p.a_fisc * (0.5 - fiscal) + p.a_war * war);
    calm = (1.0 - war) * (1.0 - state.Protest);
    repr_cap = clip((p.r0 * state.Loyal * state.Elite + p.r_w * war) * state.Info, 0.0, 1.0);

    morale_next = clip(state.Morale + p.k_rally * war * exp(-t_week / p.tau_rally) - p.k_fatigue * (war + estress) ...
        - p.k_price * inflation - p.k_disp * state.Displaced + p.k_morale_recover * calm * (1.0 - state.Morale), 0.0, 1.0);
    fiscal_next = clip(fiscal + p.k_rev * revenue - p.k_war_spend * war - p.k_subsidy * (1.0 - morale_next) ...
        - p.k_san_leak * sanctions + 0.01 * calm * (1.0 - fiscal), 0.0, 1.0);
    info_next = clip(state.Info + p.k_info_invest * fiscal_next + p.k_info_emerg * (war + state.Protest) ...
        - p.k_info_deg_w * war - p.k_info_decay_calm * calm * state.Info, 0.0, 1.0);

    mobilize = p.k_mob * sigmoid(p.b1 * estress + p.b2 * (1.0 - morale_next) + p.b3 * (1.0 - state.Stab) ...
        + p.b4 * (1.0 - info_next) - p.b5 * repr_cap);
    demobilize = p.k_demob * sigmoid(p.c1 * repr_cap + p.c2 * war + p.c3 * state.Protest) + 0.02 * calm * state.Protest;
    protest_next = clip(state.Protest + mobilize - demobilize, 0.0, 1.0);

    elite_eq = clip(0.38 + 0.28 * state.Stab, 0.22, 0.82);
    elite_damage = p.k_elite_cost * (0.75 * estress + 0.45 * war) + 1.20 * p.k_elite_protest * protest_next;
    elite_next = clip(state.Elite + p.k_elite_rally * war * (1.0 - state.Elite) - elite_damage * state.Elite ...
        + 0.75 * p.k_elite_recover * (elite_eq - state.Elite), 0.0, 1.0);

    loyal_next = clip(state.Loyal + p.k_pay * fiscal_next - p.k_loss_l * (war + estress) - p.k_split * (1.0 - elite_next) ...
        + p.k_loyal_recover * calm * (1.0 - state.Loyal), 0.0, 1.0);

    stab_next = clip(state.Stab + p.k_cons * (elite_next * loyal_next * fiscal_next) + p.k_info * info_next + 0.015 * morale_next ...
        + p.k_rally_s * war * exp(-t_week / p.tau_rally) - p.k_loss_p * protest_next - p.k_loss_e * estress - p.k_loss_w * war ...
        + p.k_stab_recover * calm * (1.0 - state.Stab), 0.0, 1.0);

    troops_next = clip(state.Troops + p.k_troop_up * war * (1.0 - state.Troops) - p.k_troop_down * (1.0 - war) * state.Troops ...
        - p.k_troop_attr * war * state.Troops, 0.0, 1.0);

    new_disp = p.k_disp_w * war + p.k_disp_p * protest_next * repr_cap + p.k_disp_e * estress;
    returns = p.k_return * (1.0 - war) * (1.0 - protest_next) * state.Displaced;
    displaced_next = max(0.0, state.Displaced + new_disp - returns);

    state_next = struct('Stab',stab_next,'Elite',elite_next,'Loyal',loyal_next,'Info',info_next,'Morale',morale_next, ...
        'Protest',protest_next,'Fiscal',fiscal_next,'CPI',cpi,'Infl',inflation,'EStress',estress,'Repr',repr_cap, ...
        'Troops',troops_next,'Displaced',displaced_next,'War',war,'Sanctions',sanctions,'OilPrice',oil_price,'OilRevIndex',revenue);
end

function out = test_local_stability(p, years, seed)
    s1 = struct('Stab',0.60,'Elite',0.65,'Loyal',0.75,'Info',0.70,'Morale',0.55,'Protest',0.20,'Fiscal',0.45,'CPI',100.0,'Troops',0.20,'Displaced',0.0);
    s2 = s1;
    s2.Stab = s2.Stab + 0.005;
    s2.Elite = s2.Elite - 0.005;
    s2.Loyal = s2.Loyal + 0.005;
    s2.Fiscal = s2.Fiscal - 0.005;

    d1 = simulate_model(p, 'impas', years, seed, s1);
    d2 = simulate_model(p, 'impas', years, seed, s2);

    dist = abs(d1.Stab - d2.Stab) + abs(d1.Elite - d2.Elite) + abs(d1.Loyal - d2.Loyal);
    ratio = dist(end) / max(dist(1), 1e-9);
    score = max(0, min(100, 100 * (1 - min(ratio, 1.0))));
    out = make_test('local_stability', score, 100, score >= 60);
end

function out = test_realism(results)
    penalty = 0.0;
    total = 0.0;
    fields = {'Stab','Elite','Loyal','Info','Morale','Protest'};
    for i = 1:numel(results)
        total = total + numel(fields);
        ext = results(i).extra;
        for j = 1:numel(fields)
            if ext.sat_hi.(fields{j}) > 0.85 || ext.sat_lo.(fields{j}) > 0.85
                penalty = penalty + 1.0;
            end
        end
    end
    score = max(0, 100 * (1 - penalty / max(total,1)));
    out = make_test('realism', score, 100, score >= 50);
end

function out = test_scenario_order(results)
    names = {results.name};
    a = find(strcmp(names,'szybka_wojna'),1);
    b = find(strcmp(names,'dlugotrwala_wojna'),1);
    c = find(strcmp(names,'impas'),1);
    d = find(strcmp(names,'eskalacja_regionalna'),1);

    checks = [];
    if ~isempty(a) && ~isempty(b)
        checks(end+1) = results(a).metrics.mean_stab >= results(b).metrics.mean_stab; %#ok<AGROW>
    end
    if ~isempty(d) && ~isempty(a)
        checks(end+1) = results(d).metrics.peak_protest >= results(a).metrics.peak_protest; %#ok<AGROW>
    end
    if ~isempty(d) && ~isempty(b)
        checks(end+1) = results(d).metrics.end_displaced_m >= results(b).metrics.end_displaced_m; %#ok<AGROW>
    end
    if ~isempty(c) && ~isempty(a)
        checks(end+1) = results(c).extra.final_cpi >= results(a).extra.final_cpi; %#ok<AGROW>
    end

    if isempty(checks)
        score = 0;
    else
        score = 100 * mean(checks);
    end
    out = make_test('scenario_order', score, 100, score >= 75);
end

function [score, tbl] = aggregate_quality(q)
    names = fieldnames(q);
    total = 0;
    total_max = 0;
    tbl = cell(numel(names), 4);

    for i = 1:numel(names)
        item = q.(names{i});
        total = total + item.score;
        total_max = total_max + item.max_score;
        tbl{i,1} = item.name;
        tbl{i,2} = item.score;
        tbl{i,3} = item.max_score;
        tbl{i,4} = ternary(item.pass, 'PASS', 'FAIL');
    end

    score = 100 * total / max(total_max, eps);
end

function s = quality_label(score)
    if score >= 85
        s = 'BARDZO DOBRY';
    elseif score >= 70
        s = 'DOBRY';
    elseif score >= 55
        s = 'WARUNKOWO POPRAWNY';
    else
        s = 'WYMAGA REKALIBRACJI';
    end
end

%% =====================================================================
%% COMPARE MATLAB <-> PYTHON
%% =====================================================================
function long_tbl = compare_with_python(results, python_outputs_dir, out_dir)
    long_tbl = table();
    for i = 1:numel(results)
        scenario = results(i).name;
        py_path = fullfile(python_outputs_dir, sprintf('run_%s.csv', scenario));
        if ~isfile(py_path)
            py_path = fullfile(python_outputs_dir, sprintf('matlab_run_%s.csv', scenario));
        end
        if ~isfile(py_path)
            continue;
        end

        py = readtable(py_path);
        ma = results(i).df;
        common = intersect(py.Properties.VariableNames, ma.Properties.VariableNames, 'stable');
        common = setdiff(common, {'year'});
        if isempty(common)
            continue;
        end

        rows = [];
        for j = 1:numel(common)
            v = common{j};
            if ~isnumeric(py.(v)) || ~isnumeric(ma.(v))
                continue;
            end
            n = min(height(py), height(ma));
            variable = repmat(string(v), n, 1);
            week = ma.week(1:n);
            python_v = py.(v)(1:n);
            matlab_v = ma.(v)(1:n);
            diff_v = matlab_v - python_v;
            abs_diff = abs(diff_v);
            rows = [rows; table(variable, week, python_v, matlab_v, diff_v, abs_diff, ...
                'VariableNames', {'variable','week','python','matlab','diff','abs_diff'})]; %#ok<AGROW>
        end

        if ~isempty(rows)
            writetable(rows, fullfile(out_dir, sprintf('compare_%s_long.csv', scenario)));
            long_tbl = [long_tbl; rows]; %#ok<AGROW>
        end
    end
end

%% =====================================================================
%% ARTEFACTS / REPORTS
%% =====================================================================
function save_scenario_fig(results, out_dir)
    f = figure('Visible','off','Color','w','Name','matj_4_scenarios');
    tiledlayout(3,2);

    nexttile; hold on;
    for i = 1:numel(results), plot(results(i).df.week, results(i).df.Stab, 'LineWidth',1.4, 'DisplayName',results(i).name); end
    title('Stab'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results), plot(results(i).df.week, results(i).df.Elite, 'LineWidth',1.4, 'DisplayName',results(i).name); end
    title('Elite'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results), plot(results(i).df.week, results(i).df.Protest, 'LineWidth',1.4, 'DisplayName',results(i).name); end
    title('Protest'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results), plot(results(i).df.week, results(i).df.Fiscal, 'LineWidth',1.4, 'DisplayName',results(i).name); end
    title('Fiscal'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results), plot(results(i).df.week, results(i).df.CPI, 'LineWidth',1.4, 'DisplayName',results(i).name); end
    title('CPI'); grid on; legend('Location','best'); hold off;

    nexttile; hold on;
    for i = 1:numel(results), plot(results(i).df.week, results(i).df.Displaced, 'LineWidth',1.4, 'DisplayName',results(i).name); end
    title('Displaced'); grid on; legend('Location','best'); hold off;

    exportgraphics(f, fullfile(out_dir, 'matj_4_scenarios.png'), 'Resolution', 150);
    close(f);
end

function save_mc_fig(mc, out_dir)
    f = figure('Visible','off','Color','w','Name','matj_4_mc');
    tiledlayout(2,2);

    nexttile; histogram(mc.Tcrit); title('Tcrit'); grid on;
    nexttile; histogram(mc.min_stab); title('min\_stab'); grid on;
    nexttile; histogram(mc.peak_protest); title('peak\_protest'); grid on;
    nexttile; histogram(mc.end_displaced_m); title('end\_displaced\_m'); grid on;

    exportgraphics(f, fullfile(out_dir, 'matj_4_monte_carlo.png'), 'Resolution', 150);
    close(f);
end

function write_spec_yaml(spec, path_out)
    fid = fopen(path_out, 'w');
    assert(fid > 0, 'Nie mogę zapisać SPEC.yaml');
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, 'model_name: %s\n', spec.model_name);
    fprintf(fid, 'repo: %s\n', spec.repo);
    fprintf(fid, 'dt: %s\n', spec.dt);
    fprintf(fid, 'horizon_default_weeks: %d\n', spec.horizon_default_weeks);

    fprintf(fid, 'state_vars:\n');
    for i = 1:numel(spec.state_vars)
        fprintf(fid, '  - %s\n', spec.state_vars{i});
    end

    fprintf(fid, 'derived_vars:\n');
    for i = 1:numel(spec.derived_vars)
        fprintf(fid, '  - %s\n', spec.derived_vars{i});
    end

    fprintf(fid, 'thresholds:\n');
    fprintf(fid, '  stab_crit: %.6f\n', spec.thresholds.stab_crit);
    fprintf(fid, '  elite_crit: %.6f\n', spec.thresholds.elite_crit);
    fprintf(fid, '  elite_streak_weeks: %d\n', spec.thresholds.elite_streak_weeks);

    fprintf(fid, 'params:\n');
    pnames = fieldnames(spec.params);
    for i = 1:numel(pnames)
        fprintf(fid, '  %s: %.12g\n', pnames{i}, spec.params.(pnames{i}));
    end

    fprintf(fid, 'gsa_param_names:\n');
    for i = 1:numel(spec.gsa_param_names)
        fprintf(fid, '  - %s\n', spec.gsa_param_names{i});
    end
end

function write_run_manifest(out_dir, years, seed, scenarios, quality_score, mc_use_python_rng)
    fid = fopen(fullfile(out_dir, 'run_manifest.txt'), 'w');
    assert(fid > 0, 'Nie mogę zapisać run_manifest.txt');
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, 'timestamp=%s\n', datestr(now, 31));
    fprintf(fid, 'matlab_version=%s\n', version);
    fprintf(fid, 'years=%d\n', years);
    fprintf(fid, 'seed=%d\n', seed);
    fprintf(fid, 'quality_score=%.6f\n', quality_score);
    fprintf(fid, 'mc_use_python_rng=%d\n', mc_use_python_rng);
    fprintf(fid, 'out_dir=%s\n', out_dir);
    fprintf(fid, 'scenarios=%s\n', strjoin(scenarios, ','));
    fprintf(fid, 'python_available=%d\n', python_available());
end

function write_report_txt(out_dir, results, tests, quality_score)
    fid = fopen(fullfile(out_dir, 'report.txt'), 'w');
    assert(fid > 0, 'Nie mogę zapisać report.txt');
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, 'MATJ_4 REPORT\n');
    fprintf(fid, '=============\n\n');
    fprintf(fid, 'quality_score=%.4f\n', quality_score);
    fprintf(fid, 'quality_label=%s\n\n', quality_label(quality_score));

    fprintf(fid, 'SCENARIOS\n');
    fprintf(fid, '---------\n');
    for i = 1:numel(results)
        m = results(i).metrics;
        e = results(i).extra;
        fprintf(fid, '[%s]\n', results(i).name);
        fprintf(fid, '  Tcrit=%.4f\n', m.Tcrit);
        fprintf(fid, '  elite_fracture_prob=%.4f\n', m.elite_fracture_prob);
        fprintf(fid, '  peak_protest=%.4f\n', m.peak_protest);
        fprintf(fid, '  min_stab=%.4f\n', m.min_stab);
        fprintf(fid, '  mean_stab=%.4f\n', m.mean_stab);
        fprintf(fid, '  final_stab=%.4f\n', e.final_stab);
        fprintf(fid, '  stress_area=%.4f\n', e.stress_area);
        fprintf(fid, '  drawdown=%.4f\n\n', e.max_drawdown_stab);
    end

    fprintf(fid, 'TESTS\n');
    fprintf(fid, '-----\n');
    names = fieldnames(tests);
    for i = 1:numel(names)
        x = tests.(names{i});
        fprintf(fid, '%s: %.4f / %.4f [%s]\n', x.name, x.score, x.max_score, ternary(x.pass,'PASS','FAIL'));
    end
end

%% =====================================================================
%% UTILITIES
%% =====================================================================
function y = clip(x, lo, hi)
    y = max(lo, min(hi, x));
end

function y = sigmoid(x)
    x = max(-60.0, min(60.0, x));
    y = 1.0 ./ (1.0 + exp(-x));
end

function p = normcdf_local(x)
    p = 0.5 * (1 + erf(x ./ sqrt(2)));
end

function x = norminv_local(p)
    p = min(max(p, eps), 1-eps);
    x = sqrt(2) * erfinv(2*p - 1);
end

function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end

function ensure_dir_local(pth)
    if ~isfolder(pth)
        mkdir(pth);
    end
end

function tf = python_available()
    try
        pe = pyenv;
        tf = ~strcmpi(pe.Status, "NotLoaded") || strlength(string(pe.Version)) > 0;
    catch
        tf = false;
    end
end

function U = maybe_python_uniform(n, d, seed)
    try
        if ~python_available()
            error('Python niedostępny');
        end
        code = [
            "import numpy as np", newline, ...
            "rng = np.random.default_rng(" + string(seed) + ")", newline, ...
            "U = rng.random((" + string(n) + "," + string(d) + "))"
        ];
        pyrun(code, "U");
        U = double(py.array.array('d', py.numpy.nditer(py.numpy.array(py.eval("U")))));
        U = reshape(U, [d, n])';
    catch
        rng(seed, 'twister');
        U = rand(n, d);
    end
end

function U = matlab_sobol_unit_samples(N, D, seed)
    try
        s = sobolset(D);
        s = scramble(s, 'MatousekAffineOwen');
        rng(seed, 'twister');
        U = net(s, N);
    catch
        rng(seed, 'twister');
        U = rand(N, D);
    end
    U = min(max(U, eps), 1-eps);
end

function U = maybe_python_sobol(N, D, seed)
    %#ok<INUSD>
    U = matlab_sobol_unit_samples(N, D, seed);
end
