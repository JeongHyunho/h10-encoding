%% encode_all.m — H10 실험 통합 인코딩 파이프라인
% K5 대사, 지면반력(FP), H10 외골격, 로그 데이터를 통합하여
% 각 참여자·시도별 결과를 구조체(enc_rs.mat)로 저장한다.
%
% 의존성:
%   - setup.m, config.m (환경 및 상수 설정)
%   - h10_param.csv, sub_info.csv, k5_arrange.xlsx (메타데이터)
%   - DATA_DIR 환경변수가 가리키는 데이터 폴더
%
% 출력:
%   - DATA_DIR/export/enc_rs.mat (rs 구조체)
%
% 파이프라인 순서: insane_check → post_log_process → [이 스크립트] → k5_continuous_processing

close all; clear
mp = mfilename('fullpath');
if contains(mp, 'AppData'),  mp = matlab.desktop.editor.getActiveFilename; end
cd(fileparts(mp));

%% 환경 설정 및 메타데이터 로드
run('setup.m')
run('config.m')
data_dir = getenv('DATA_DIR');

tau = TAU_ICM;

use_log_cache = true;

log_rs = struct();
log_cache_file = fullfile(data_dir, 'export', 'log_rs.mat');
if use_log_cache && exist(log_cache_file, 'file')
    tmp = load(log_cache_file, 'log_rs');
    if isfield(tmp, 'log_rs')
        log_rs = tmp.log_rs;
    end
end

for_vel = TREADMILL_SPEED;

fp_freq = FP_FREQ;
calmat_left = readmatrix(fullfile(data_dir, 'fp', 'cal_mat_left.txt'));   % 지면반력계 보정 행렬 (좌 발판)
calmat_right = readmatrix(fullfile(data_dir, 'fp', 'cal_mat_right.txt')); % 지면반력계 보정 행렬 (우 발판)

opts = detectImportOptions("h10_param.csv");
opts = setvartype(opts, opts.VariableNames, "string");
param = readtable('h10_param.csv', opts);

opts = detectImportOptions("sub_info.csv");
opts = setvartype(opts, opts.VariableNames, "string");
sub_info = readtable('sub_info.csv', opts);

%% 결과 구조체 초기화
rs = struct();
rs.param = param;
rs.sub_info = sub_info;
rs.n_sub = height(rs.sub_info);
rs.p_name = ["T^{Max}_{Swing}", "T^{Max}_{Stance}"];
rs.sub_pass = N_PILOT_SUBJECTS;

walks = param.Properties.VariableNames(2:end);

interval_stand = readtable('k5_arrange.xlsx', 'Sheet', 'stand');
interval_walk = readtable('k5_arrange.xlsx', 'Sheet', 'walk');

% continuous param grid
disc_p = DISC_TORQUE_GRID;
pg_x = PG_X; pg_y = PG_Y;

rs.pg_x = pg_x;
rs.pg_y = pg_y;

% pooled discrete data for mixed-effects fit (shared slopes, subject intercept)
all_disc_x = [];
all_disc_y = [];
all_disc_z = [];
all_disc_sub = {};

% units metadata for enc_rs.mat
rs.units = struct();
rs.units.param = "Nm/kg (disc) or min (cont, string labels)";
rs.units.sub_info = struct( ...
    'age', "yr", ...
    'height', "m", ...
    'weight', "kg", ...
    'non_exo', "index", ...
    'transparent', "index", ...
    'eval_fail', "index", ...
    'stand_fail', "index", ...
    'disc_train', "index", ...
    'disc_eval', "index", ...
    'cont_train', "index", ...
    'cont_eval', "index", ...
    'day_1', "index", ...
    'day_2', "index", ...
    'day_3', "index", ...
    'day_4', "index", ...
    'flx_srt_ph', "percent gait", ...
    'flx_dur_ph', "percent gait", ...
    'ext_srt_ph', "percent gait", ...
    'ext_dur_ph', "percent gait" ...
    );
rs.units.p_name = "Nm/kg";
rs.units.pg_x = "Nm/kg";
rs.units.pg_y = "Nm/kg";
rs.units.walk = struct( ...
    'ee_walk', "W", ...
    'ee_stand', "W", ...
    'eet', "disc: [s, W], cont: [s, W, index]", ...
    'p', "Nm/kg", ...
    'len', "min (string label)", ...
    'double_log', "bool", ...
    'p_sync', "Nm/kg", ...
    'log_t', "datetime", ...
    'log_p', "Nm/kg", ...
    'y0', "W", ...
    'H', "[W/(Nm/kg), W/(Nm/kg), W]", ...
    'ee_est', "W", ...
    'MSE', "W^2", ...
    'Sig', "W", ...
    'pg_ee', "W", ...
    'p_ee', "[Nm/kg, Nm/kg, W]", ...
    'nav_p_ee', "W", ...
    'ssT', "[s, s]", ...
    'dsT', "[s, s]", ...
    'ssTt', "[s, s]", ...
    'dsTt', "[s, s]", ...
    'freq', "[BPM, BPM]", ...
    'freqt', "[s, BPM]", ...
    'com_pow', "W", ...
    'com_powt', "[s, W, W]" ...
    );
rs.units.subject = struct( ...
    'age', "yr", ...
    'height', "m", ...
    'weight', "kg", ...
    'idx_info', "index", ...
    'nat_ee', "W", ...
    'nat_st', "W", ...
    'nat_freq', "BPM", ...
    'nat_com_pow', "W", ...
    'nat_ssT', "s", ...
    'nat_dsT', "s", ...
    'disc_p', "Nm/kg", ...
    'disc_ee', "W", ...
    'disc_ee_fit1', "W", ...
    'disc_ee_fit2', "W", ...
    'disc_trs', "W", ...
    'disc_st', "W" ...
    );
rs.units.h10 = struct( ...
    'time', "s", ...
    'record_time', "s", ...
    'stance_keep', "bool", ...
    'inc_deg', "deg", ...
    'jvel_deg', "deg/s", ...
    'tau_ref', "Nm", ...
    'tau_act', "Nm", ...
    'pow', "W/kg", ...
    'fric_pow_c', "rad/s/kg", ...
    'fric_pow_v', "(rad/s)^2/kg" ...
    );

cont_list = CONT_DURATIONS;
cont_stack_p = cell(numel(cont_list), 1);
cont_stack_t = cell(numel(cont_list), 1);
cont_stack_ee = cell(numel(cont_list), 1);
cont_stack_trial = cell(numel(cont_list), 1);
cont_stack_sub = cell(numel(cont_list), 1);
cont_trial_counter = zeros(numel(cont_list), 1);
%% 참여자별 인코딩 루프
% K5(대사), FP(지면반력), H10(외골격), Log(파라미터) 데이터를 시도별로 처리

for i = rs.sub_pass+1:rs.n_sub
    sub_name = rs.sub_info.ID(i);
    sub_param = rs.param(i, :);
    sub_stand = interval_stand(interval_stand.ID == sub_name, :);
    sub_walk = interval_walk(interval_walk.ID == sub_name, :);

    idx_info = struct(...
        'non_exo', str2double(split(rs.sub_info(i, :).non_exo)), ...
        'train', str2double(split(rs.sub_info(i, :).disc_train)), ...
        'transparent', str2double(split(rs.sub_info(i, :).transparent)), ...
        'disc', str2double(split(rs.sub_info(i, :).disc_eval)), ...
        'cont', str2double(split(rs.sub_info(i, :).cont_eval)), ...
        'cont_name', nan, ...
        'eval_fail', str2double(split(rs.sub_info(i, :).eval_fail)), ...
        'stand_fail', str2double(split(rs.sub_info(i, :).stand_fail)), ...
        'day_1', str2double(split(rs.sub_info(i, :).day_1)), ...
        'day_2', str2double(split(rs.sub_info(i, :).day_2)), ...
        'day_3', str2double(split(rs.sub_info(i, :).day_3)), ...
        'day_4', str2double(split(rs.sub_info(i, :).day_4)), ...
        'flx_srt', str2double(rs.sub_info(i,:).flx_srt_ph), ...
        'flx_dur', str2double(rs.sub_info(i,:).flx_dur_ph), ...
        'ext_srt', str2double(rs.sub_info(i,:).ext_srt_ph), ...
        'ext_dur', str2double(rs.sub_info(i,:).ext_dur_ph) ...
        );

    % cont indice sorting
    [~, idx] = ismember(arrayfun(@(x) sub_param.(sprintf("walk%d", x)), idx_info.cont), cont_list);
    [idx_sorted, sort_idx] = sort(idx);
    idx_info.cont = idx_info.cont(sort_idx);        % 5m, 10m, 15m 순서
    idx_info.cont_name = cont_list(idx_sorted);

    sub_rs = struct(...
        'age', str2double(split(rs.sub_info(i, :).age)), ...
        'height', str2double(split(rs.sub_info(i, :).height)), ...
        'weight', str2double(split(rs.sub_info(i, :).weight)), ...
        'idx_info', idx_info ...
        );

    for j = 1:numel(walks)
        walk_rs = struct();

        walk = walks{j};
        if strcmp(rs.param(i, :).(walk), "null")
            continue
        end
        p = str2double(split(rs.param(i, :).(walk)))';

        k5_dir = dir(fullfile(data_dir, 'k5', sub_name, [walk, '*.xlsx']));
        k5_file = k5_dir(arrayfun(@(x) ~isempty(regexp(x.name,  ['^', walk, '(_\d+)?.xlsx'], 'once')), k5_dir));
        h10_dir = dir(fullfile(data_dir, 'h10', sub_name, [walk, '*.csv']));
        h10_file = h10_dir(arrayfun(@(x) ~isempty(regexp(x.name,  ['^', walk, '(_\d+)?.csv'], 'once')), h10_dir));
        fp_dir = dir(fullfile(data_dir, 'fp', sub_name, [walk, '*.tdms']));
        fp_file = fp_dir(arrayfun(@(x) ~isempty(regexp(x.name,  ['^', walk, '(_\d+)?.tdms'], 'once')), fp_dir));
        log_dir = dir(fullfile(data_dir, 'log', sub_name, [walk, '*.tdms']));
        log_file = log_dir(arrayfun(@(x) ~isempty(regexp(x.name,  ['^', walk, '(_\d+)?.tdms'], 'once')), log_dir));
        log_cache = get_log_cache(log_rs, sub_name, walk);

        % K5
        if ~ismember(j, idx_info.eval_fail)      % K5 측정 성공 시
            k5_table = read_k5_table(fullfile(k5_file.folder, k5_file.name));    % 파일 1개 가정
            if  ismember(j, [idx_info.non_exo; idx_info.train; idx_info.transparent; idx_info.disc])   % discrete protocol

                % walking ee
                w_int = sub_walk.(walk);
                if ~iscell(w_int) || isempty(w_int{1})
                    [t_, ee_, ~, ee_walk] = k5_to_ee(k5_table, -120, -1);  % 마지막 120초~1초 전 구간 (정상상태 walking)
                else
                    w_int = str2num(w_int{1});
                    ee_tmp = [];
                    ee_sum = 0;
                    ee_dur = 0;
                    for int = w_int'
                        [t_, ee_, rg, ~] = k5_to_ee(k5_table, int(1), int(2));
                        ee_tmp = [ee_tmp; ee_(rg)];
                        t__ = t_(rg);
                        ee__ = ee_(rg);
                        ee_sum = ee_sum + sum(diff(t_(rg)) .* ee__(1:end-1));
                        ee_dur = ee_dur + t__(end) - t__(1);
                    end
                    ee_mean = ee_sum / ee_dur;
                    ee_std = std(ee_tmp);
                    ee_walk = [ee_mean, ee_std, ee_std/numel(ee_tmp)];
                end
                walk_rs.ee_walk = ee_walk;
                walk_rs.eet = [t_, ee_];

                % standing ee
                if ~ismember(j, idx_info.stand_fail)
                    st_int = sub_stand.(walk);
                    if ~iscell(st_int) || isempty(st_int{1})
                        [~, ~, ~, ee_stand] = k5_to_ee(k5_table, 0, 60);
                    else
                        st_int = str2num(st_int{1});
                        [~, ~, ~, ee_stand] = k5_to_ee(k5_table, st_int(1), st_int(2));
                    end
                    walk_rs.ee_stand = ee_stand;
                end

                % parameter
                if ismember(j, [idx_info.train; idx_info.disc; idx_info.cont])
                    if log_cache.available
                        walk_rs.p = log_cache.p_median;
                    elseif ~isempty(log_file)
                        [~, ~, ~, p_log] = read_log_file(log_file);
                        walk_rs.p =  median(p_log, 1);
                    else
                        walk_rs.p = p;
                    end
                end

            elseif ismember(j, idx_info.cont)    % continuous protocol
                % TODO: k5 두개 이상일 때 처리
                % TODO: t_log 가 여러 개인 경우, 즉 깨진 경우 마지막 10초 제외

                walk_rs.len = sub_param.(walk);

                if numel(k5_file) == 1
                    if log_cache.available
                        log_t = log_cache.log_t;
                        log_p = log_cache.log_p;
                        walk_rs.double_log = log_cache.double_log;
                    else
                        if numel(log_file) > 1
                            warning('[Cont] %s %s log 2개 이상', sub_name, walk)
                            walk_rs.double_log = true;
                        else
                            walk_rs.double_log = false;
                        end
                        log_t = [];
                        log_p = [];
                    end

                    stack_p = [];
                    stack_t = [];
                    stack_ee = [];
                    trial = [];

                    if log_cache.available
                        if ~isempty(log_t)
                            [k5_start, ~, ~] = read_k5_time(fullfile(k5_file.folder, k5_file.name));
                            t_k5 = k5_start + seconds(k5_table.t);
                            [t_, ee_, ~, ~] = k5_to_ee(k5_table);

                            log_valid = all(~isnan(log_p), 2);
                            t_log = log_t(log_valid);
                            p = log_p(log_valid, :);
                            if numel(t_log) < 2
                                warning('[Cont] %s %s log cache invalid', sub_name, walk)
                            else
                                p_sync = interp1(t_log, p, t_k5);
                                assert(any(~isnan(p_sync(:))), 'log is out of k5 range!\n')

                                if walk_rs.double_log, t_margin = 10; else t_margin = 0; end
                                k5_valid = t_log(1) <= t_k5 & t_k5 <= t_log(end) - seconds(t_margin);
                                p_sync = p_sync(k5_valid, :);
                                t_ = t_(k5_valid);
                                ee_ = ee_(k5_valid);

                                stack_p = p_sync;
                                stack_t = t_;
                                stack_ee = ee_;
                                trial = ones(size(t_));
                                if size(log_cache.t_ranges, 1) > 1
                                    trial = map_time_to_trials(t_k5(k5_valid), log_cache.t_ranges);
                                end
                            end
                        end
                    else
                        for k = 1:numel(log_file)
                            % time sync
                            [k5_start, ~, ~] = read_k5_time(fullfile(k5_file.folder, k5_file.name));
                            t_k5 = k5_start + seconds(k5_table.t);
                            [t_log, ~, ~, p] = read_log_file(log_file(k));
                            log_t = [log_t; t_log];
                            log_p = [log_p; p];

                            p_sync = interp1(t_log, p, t_k5);
                            assert(any(~isnan(p_sync(:))), 'log is out of k5 range!\n')

                            [t_, ee_, ~, ~] = k5_to_ee(k5_table);
                            if numel(log_file) > 1, t_margin = 10; else t_margin = 0; end
                            k5_valid = t_log(1) <= t_k5 & t_k5 <= t_log(end) - seconds(t_margin);
                            p_sync = p_sync(k5_valid, :);
                            t_ = t_(k5_valid);
                            ee_ = ee_(k5_valid);

                            stack_p = [stack_p; p_sync];
                            stack_t = [stack_t; t_];
                            stack_ee = [stack_ee; ee_];
                            trial = [trial; k * ones(size(t_))];
                        end
                    end

                    walk_rs.eet = [stack_t, stack_ee, trial];
                    walk_rs.p_sync = stack_p;
                    walk_rs.log_t = log_t;
                    walk_rs.log_p = log_p;

                    % pooled continuous data (fit after all subjects)
                    cont_idx = find(cont_list == string(walk_rs.len), 1);
                    if isempty(cont_idx)
                        warning('[Cont] %s %s length not matched: %s', sub_name, walk, string(walk_rs.len))
                    else
                        trial_offset = cont_trial_counter(cont_idx);
                        trial = trial + trial_offset;
                        cont_trial_counter(cont_idx) = max(trial);
                        cont_stack_p{cont_idx} = [cont_stack_p{cont_idx}; stack_p];
                        cont_stack_t{cont_idx} = [cont_stack_t{cont_idx}; stack_t];
                        cont_stack_ee{cont_idx} = [cont_stack_ee{cont_idx}; stack_ee];
                        cont_stack_trial{cont_idx} = [cont_stack_trial{cont_idx}; trial];
                        cont_stack_sub{cont_idx} = [cont_stack_sub{cont_idx}; repmat({char(sub_name)}, size(stack_p, 1), 1)];
                    end

                else
                    warning('[Cont] %s %s k5 2개 이상, 스킵', sub_name, walk)
                end
                
            else
                error('%s walk%d is not in  or continuous protocol indices.\n', sub_name, j)
            end
        end

        % FP
        if ~isempty(fp_file)
            t_rg = [];
            for k = 1:numel(log_file)
                [t_log, ~, ~, p] = read_log_file(log_file(k));
                t_rg = [t_rg; t_log(1), t_log(end)];
            end

            fp_T = [];
            for k = 1:length(fp_file)
                fp_file_ = fullfile(fp_file(k).folder, fp_file(k).name);
                T_ = read_fp_table(fp_file_, fp_freq, calmat_left, calmat_right);
                if k > 1
                    t_gap = seconds(t_rg(k, 1) - t_rg(1, 1));
                    T_.t = T_.t + t_gap;
                end 
                fp_T = [fp_T; T_];
            end
            
            % todo: cont 도 처리하도록
            if ismember(j, [idx_info.non_exo; idx_info.train; idx_info.transparent; idx_info.disc])
                [~, ~, ~, ~, ss_stat, ds_stat] = fp_to_ssds_time(fp_T, -1, -120);  % 마지막 120초~1초 전 (정상상태)
                walk_rs.ssT = ss_stat;
                walk_rs.dsT = ds_stat;

                [~, ~, freq_stat] = fp_to_freq(fp_T, -1, -120);  % 마지막 120초~1초 전 (정상상태)
                walk_rs.freq = freq_stat;
                [freq_t, freq, ~] = fp_to_freq(fp_T, 0, Inf);
                walk_rs.freqt = [freq_t, freq];
                [~, ~, pow_stat] = fp_to_power(fp_T, for_vel, fp_freq, -1, -120);  % 마지막 120초~1초 전 (정상상태)
                walk_rs.com_pow = pow_stat;
            elseif ismember(j, idx_info.cont)
                [t_ss, ss, t_ds, ds, ss_stat, ds_stat] = fp_to_ssds_time(fp_T, 0, Inf);
                walk_rs.ssTt = [t_ss, ss];
                walk_rs.dsTt = [t_ds, ds];

                [freq_t, freq, ~] = fp_to_freq(fp_T, 0, Inf);
                walk_rs.freqt = [freq_t, freq];
                [pow_t, pow, ~] = fp_to_power(fp_T, for_vel, fp_freq, 0, Inf);
                walk_rs.com_powt = [pow_t, pow];
            else
                error('%s walk%d is not in  or continuous protocol indices.\n', sub_name, j)
            end
        end

        % % Mocap
        % mocap_file = fullfile(data_dir, 'visual3d', 'processed', sub_name, walk, [walk, '.c3d']);
        % evt_file = fullfile(data_dir, 'visual3d', 'processed', sub_name, walk, 'events.txt');
        % if exist(mocap_file, "file")
        %     c3d = ezc3dRead(char(mocap_file));
        %     evt = read_events_struct(evt_file);
        % 
        %     % step length
        %     [~, ~, slen_stat] = fp_to_slen(c3d, evt, for_vel, true);
        %     walk_rs.slen = slen_stat;
        % 
        %     % emg
        % 
        % end

        % H10
        if ~isempty(h10_file)
            if numel(h10_file) == 1
                walk_rs.h10 = h10_process(h10_file, fp_T, 0, sub_rs.weight);
            else
                t0 = [];
                for k = 1:numel(log_file)
                    [t_log, ~, ~, ~] = read_log_file(log_file(k));
                    t0 = [t0; t_log(1)];
                end
                t0 = seconds(t0 - t0(1));
                walk_rs.h10 = h10_process(h10_file, fp_T, t0, sub_rs.weight);
            end
        end
       
        % TODO: param-ee 매칭 정리

        sub_rs.(walk) = walk_rs;
    end

    %% 자연 보행(non-exo) 기준값 할당
    % 각 실험일의 비보조 보행 EE를 해당일 보조 시도에 매핑

    % day 별 natural ee, stand, freq, pow, ssT, dsT 계산
    for j = setdiff(idx_info.non_exo, idx_info.eval_fail)'
        idx_day = cellfun(@(x) ismember(j, x), {idx_info.day_1, idx_info.day_2, idx_info.day_3, idx_info.day_4});
        src_day = sprintf("day_%d", find(idx_day));
        walk_src = sprintf("walk%d", j);
        nat_ee = sub_rs.(walk_src).ee_walk(1);
        nat_freq = sub_rs.(walk_src).freq(1);
        nat_com_pow = sub_rs.(walk_src).com_pow(1);
        nat_ssT = sub_rs.(walk_src).ssT(1);
        nat_dsT = sub_rs.(walk_src).dsT(1);

        for k = setdiff(idx_info.(src_day), j)'
            walk_tg = sprintf("walk%d", k);
            if ismember('nat_ee', fieldnames(sub_rs.(walk_tg)))
                sub_rs.(walk_tg).nat_ee = [sub_rs.(walk_tg).nat_ee; nat_ee];
                sub_rs.(walk_tg).nat_freq = [sub_rs.(walk_tg).nat_freq; nat_freq];
                sub_rs.(walk_tg).nat_com_pow = [sub_rs.(walk_tg).nat_com_pow; nat_com_pow];
                sub_rs.(walk_tg).nat_ssT = [sub_rs.(walk_tg).nat_ssT; nat_ssT];
                sub_rs.(walk_tg).nat_dsT = [sub_rs.(walk_tg).nat_dsT; nat_dsT];
            else
                sub_rs.(walk_tg).nat_ee = nat_ee;
                sub_rs.(walk_tg).nat_freq = nat_freq;
                sub_rs.(walk_tg).nat_com_pow = nat_com_pow;
                sub_rs.(walk_tg).nat_ssT = nat_ssT;
                sub_rs.(walk_tg).nat_dsT = nat_dsT;
            end
        end
    end

    for j = setdiff(idx_info.non_exo, [idx_info.eval_fail; idx_info.stand_fail])'
        idx_day = cellfun(@(x) ismember(j, x), {idx_info.day_1, idx_info.day_2, idx_info.day_3, idx_info.day_4});
        src_day = sprintf("day_%d", find(idx_day));
        walk_src = sprintf("walk%d", j);
        nat_st = sub_rs.(walk_src).ee_stand(1);

        for k = setdiff(idx_info.(src_day), j)'
            walk_tg = sprintf("walk%d", k);
            if ismember('nat_st', fieldnames(sub_rs.(walk_tg)))
                sub_rs.(walk_tg).nat_st = [sub_rs.(walk_tg).nat_st; nat_st];
            else
                sub_rs.(walk_tg).nat_st = nat_st;
            end
        end
    end

    % day 에 여러 natural ee, freq, com_pow, ssT, dsT 있다면 평균
    for j = [idx_info.day_1; idx_info.day_2; idx_info.day_3; idx_info.day_4]'
        if isnan(j), continue, end
        walk = sprintf("walk%d", j);
        if ismember("nat_ee", fieldnames(sub_rs.(walk))) && ~isscalar(sub_rs.(walk).nat_ee)
            sub_rs.(walk).nat_ee = mean(sub_rs.(walk).nat_ee);
        end
        if ismember("nat_st", fieldnames(sub_rs.(walk))) && ~isscalar(sub_rs.(walk).nat_st)
            sub_rs.(walk).nat_st = mean(sub_rs.(walk).nat_st);
        end
        if ismember("nat_freq", fieldnames(sub_rs.(walk))) && ~isscalar(sub_rs.(walk).nat_freq)
            sub_rs.(walk).nat_freq = median(sub_rs.(walk).nat_freq);
        end
        if ismember("nat_com_pow", fieldnames(sub_rs.(walk))) && ~isscalar(sub_rs.(walk).nat_com_pow)
            sub_rs.(walk).nat_com_pow = median(sub_rs.(walk).nat_com_pow);
        end
        if ismember("nat_ssT", fieldnames(sub_rs.(walk))) && ~isscalar(sub_rs.(walk).nat_ssT)
            sub_rs.(walk).nat_ssT = median(sub_rs.(walk).nat_ssT);
        end
        if ismember("nat_dsT", fieldnames(sub_rs.(walk))) && ~isscalar(sub_rs.(walk).nat_dsT)
            sub_rs.(walk).nat_dsT = median(sub_rs.(walk).nat_dsT);
        end
    end

    %% 이산 프로토콜 결과 요약
    % 참여자별 9점 격자의 EE, transparent EE, standing EE 집계

    % ee summary 저장
    idx_w = setdiff(idx_info.disc, idx_info.eval_fail);
    idx_w_trs = setdiff(idx_info.transparent, idx_info.eval_fail);
    idx_w_na = setdiff(idx_info.non_exo, idx_info.eval_fail);
    idx_st = setdiff([idx_info.disc; idx_info.transparent], [idx_info.eval_fail; idx_info.stand_fail]);
    idx_st_na = setdiff(idx_info.non_exo, [idx_info.eval_fail; idx_info.stand_fail]);

    p_exo = cell2mat(arrayfun(@(x) sub_rs.(sprintf('walk%d', x)).p, idx_w, 'UniformOutput', false));
    p_exo = round(p_exo, 2);

    w_exo = arrayfun(@(x) sub_rs.(sprintf('walk%d', x)).ee_walk(1), idx_w);
    w_trs = mean(arrayfun(@(x) sub_rs.(sprintf('walk%d', x)).ee_walk(1), idx_w_trs));
    w_no_exo = mean(arrayfun(@(x) sub_rs.(sprintf('walk%d', x)).ee_walk(1), idx_w_na));
    st_exo = mean(arrayfun(@(x) sub_rs.(sprintf('walk%d', x)).ee_stand(1), idx_st));
    st_no_exo = mean(arrayfun(@(x) sub_rs.(sprintf('walk%d', x)).ee_stand(1), idx_st_na));
    freq_no_exo = mean(arrayfun(@(x) sub_rs.(sprintf('walk%d', x)).freq(1), idx_w_na));
    com_pow_no_exo = mean(arrayfun(@(x) sub_rs.(sprintf('walk%d', x)).com_pow(1), idx_w_na));
    ssT_no_exo = mean(arrayfun(@(x) sub_rs.(sprintf('walk%d', x)).ssT(1), idx_w_na));
    dsT_no_exo = mean(arrayfun(@(x) sub_rs.(sprintf('walk%d', x)).ssT(1), idx_w_na));

    sub_rs.nat_ee = w_no_exo;
    sub_rs.nat_st = st_no_exo;
    sub_rs.nat_freq = freq_no_exo;
    sub_rs.nat_com_pow = com_pow_no_exo;
    sub_rs.nat_ssT = ssT_no_exo;
    sub_rs.nat_dsT = dsT_no_exo;

    [is_mem1, sort_idx] = ismember(disc_p, p_exo, 'rows');
    if all(sort_idx > 0)
        sub_rs.disc_p = p_exo(sort_idx, :);
        sub_rs.disc_ee = w_exo(sort_idx);
    else
        warning("[%s disc] non-usual disc_p!\n", sub_name)
        is_mem2 = ismember(p_exo, disc_p, 'rows');
        p_exo(~is_mem2, :) = disc_p(~is_mem1, :); 

        [~, sort_idx] = ismember(disc_p, p_exo, 'rows');
        sub_rs.disc_p = p_exo(sort_idx, :);
        sub_rs.disc_ee = w_exo(sort_idx);
        sub_rs.disc_ee(~is_mem1) = nan;
    end

    % collect for mixed-effects fit (subject intercept, shared slopes)
    valid_disc = isfinite(sub_rs.disc_ee);
    if any(valid_disc)
        all_disc_x = [all_disc_x; sub_rs.disc_p(valid_disc, 1)];
        all_disc_y = [all_disc_y; sub_rs.disc_p(valid_disc, 2)];
        all_disc_z = [all_disc_z; sub_rs.disc_ee(valid_disc)];
        all_disc_sub = [all_disc_sub; repmat({char(sub_name)}, sum(valid_disc), 1)];
    end

    sub_rs.disc_trs = w_trs;
    sub_rs.disc_st = st_exo;

    rs.(sub_name) = sub_rs;
    fprintf('[Encoding] %s done!\n', sub_name)
end

%% 풀링된 연속 프로토콜 ICM 적합 (Koller 모델)
% 전체 참여자 데이터를 합쳐 공유 기울기 + 참여자별 절편 추정

% pooled continuous fit (shared slopes, all subjects)
if any(~cellfun(@isempty, cont_stack_ee))
    rs.cont_fit = struct();
    for cont_idx = 1:numel(cont_list)
        if isempty(cont_stack_ee{cont_idx})
            continue
        end
        [y0, H, ee_est, MSE, Sig, subj_intercept, subj_list] = fitKoller21_agg( ...
            cont_stack_p{cont_idx}(:, 1), cont_stack_p{cont_idx}(:, 2), ...
            cont_stack_t{cont_idx}, cont_stack_ee{cont_idx}, ...
            cont_stack_trial{cont_idx}, cont_stack_sub{cont_idx}, tau);

        n_sub = numel(subj_intercept);
        pg_ee_all = nan([size(rs.pg_x), n_sub]);
        p_ee_all = nan(size(disc_p, 1), 3, n_sub);
        for s = 1:n_sub
            lambda0 = subj_intercept(s);
            if ~isfinite(lambda0)
                continue
            end
            pg_ee_all(:, :, s) = poly2val([H, lambda0], rs.pg_x, rs.pg_y);
            p_ee_all(:, :, s) = [disc_p, poly2val([H, lambda0], disc_p(:, 1), disc_p(:, 2))];
        end
        % poly11 fit without Curve Fitting Toolbox: z = b0 + b1*x + b2*y
        nav_X = [ones(size(cont_stack_p{cont_idx},1),1), cont_stack_p{cont_idx}];
        nav_b = nav_X \ cont_stack_ee{cont_idx};
        nav_p_ee = nav_b(1) + nav_b(2)*rs.pg_x + nav_b(3)*rs.pg_y;

        rs.cont_fit.(sprintf('y0_%s', cont_list(cont_idx))) = y0;
        rs.cont_fit.(sprintf('H_%s', cont_list(cont_idx))) = H;
        rs.cont_fit.(sprintf('ee_est_%s', cont_list(cont_idx))) = ee_est;
        rs.cont_fit.(sprintf('MSE_%s', cont_list(cont_idx))) = MSE;
        rs.cont_fit.(sprintf('Sig_%s', cont_list(cont_idx))) = Sig;
        rs.cont_fit.(sprintf('pg_ee_%s', cont_list(cont_idx))) = pg_ee_all;
        rs.cont_fit.(sprintf('pg_ee_%s_subjects', cont_list(cont_idx))) = string(subj_list);
        rs.cont_fit.(sprintf('p_ee_%s', cont_list(cont_idx))) = p_ee_all;
        rs.cont_fit.(sprintf('p_ee_%s_subjects', cont_list(cont_idx))) = string(subj_list);
        rs.cont_fit.(sprintf('nav_p_ee_%s', cont_list(cont_idx))) = nav_p_ee;
        if ~isempty(subj_list)
            subj_tbl = table(string(subj_list), subj_intercept(:), 'VariableNames', ["subject", "lambda0"]);
            rs.cont_fit.(sprintf('sub_lambda0_%s', cont_list(cont_idx))) = subj_tbl;
        end

        for i = rs.sub_pass+1:rs.n_sub
            sub_name = rs.sub_info.ID(i);
            if ~isfield(rs, sub_name)
                continue
            end
            sub_rs = rs.(sub_name);
            if ~isfield(sub_rs, 'idx_info') || ~isfield(sub_rs.idx_info, 'cont')
                continue
            end
            cont_walks = sub_rs.idx_info.cont;
            cont_walks = cont_walks(~isnan(cont_walks));
            lambda0 = nan;
            if ~isempty(subj_list)
                subj_idx = find(string(subj_list) == string(sub_name), 1);
                if ~isempty(subj_idx)
                    lambda0 = subj_intercept(subj_idx);
                end
            end
            for j = 1:numel(cont_walks)
                walk = sprintf("walk%d", cont_walks(j));
                if ~isfield(sub_rs, walk)
                    continue
                end
                walk_rs = sub_rs.(walk);
                if ~isfield(walk_rs, 'len') || string(walk_rs.len) ~= cont_list(cont_idx)
                    continue
                end
                walk_rs.H = [H, lambda0];
                walk_rs.MSE = MSE;
                walk_rs.Sig = Sig;
                if isfinite(lambda0)
                    walk_rs.pg_ee = poly2val([H, lambda0], rs.pg_x, rs.pg_y);
                    walk_rs.p_ee = [disc_p, poly2val([H, lambda0], disc_p(:, 1), disc_p(:, 2))];
                else
                    walk_rs.pg_ee = nan(size(rs.pg_x));
                    walk_rs.p_ee = [disc_p, nan(size(disc_p, 1), 1)];
                end
                walk_rs.nav_p_ee = nav_p_ee;
                walk_rs.y0 = nan;
                if isfield(walk_rs, 'eet')
                    walk_rs.ee_est = nan(size(walk_rs.eet, 1), 1);
                else
                    walk_rs.ee_est = nan;
                end
                sub_rs.(walk) = walk_rs;
            end
            rs.(sub_name) = sub_rs;
        end
    end
else
    warning('No continuous data pooled for Koller fit.')
end

%% 이산 프로토콜 혼합효과 모델 (LME)
% 1차·2차 다항식 + 참여자 임의 절편

if ~isempty(all_disc_z)
    disc_all_T = table(all_disc_x, all_disc_y, all_disc_z, categorical(all_disc_sub), ...
        'VariableNames', ["x", "y", "z", "subject"]);
    lme_1st = fitlme(disc_all_T, 'z ~ x + y + (1|subject)');
    lme_2nd = fitlme(disc_all_T, 'z ~ x + y + x^2 + y^2 + (1|subject)');

    for i = rs.sub_pass+1:rs.n_sub
        sub_name = rs.sub_info.ID(i);
        if ~isfield(rs, sub_name)
            continue
        end
        sub_rs = rs.(sub_name);
        if ~isfield(sub_rs, 'disc_p')
            continue
        end
        subj_T = table(sub_rs.disc_p(:, 1), sub_rs.disc_p(:, 2), ...
            categorical(repmat({char(sub_name)}, size(sub_rs.disc_p, 1), 1)), ...
            'VariableNames', ["x", "y", "subject"]);
        sub_rs.disc_ee_fit1 = predict(lme_1st, subj_T, 'Conditional', true);
        sub_rs.disc_ee_fit2 = predict(lme_2nd, subj_T, 'Conditional', true);
        rs.(sub_name) = sub_rs;
    end
else
    warning('No valid discrete data for mixed-effects fit. disc_ee_fit1/2 skipped.')
end

%% 결과 저장
save(fullfile(data_dir, 'export', 'enc_rs.mat'), 'rs', '-v7.3')

%% functions
