%% inv_dyn_report.m — 역동역학 분석 리포트
% idyn_summary.mat의 관절 토크·일률 데이터를 분석하여
% 생체 관절 일률, 외골격 기여 일률, 보행 역학 지표를 산출한다.
%
% 의존성:
%   - setup.m, config.m
%   - DATA_DIR/export/enc_rs.mat, idyn_summary.mat
%
% 출력:
%   - 분석 결과 (워크스페이스), 리포트 Figure
close all; clear
mp = mfilename('fullpath');
if contains(mp, 'AppData'),  mp = matlab.desktop.editor.getActiveFilename; end
cd(fileparts(mp));

run('setup.m')
run('config.m')
data_dir = getenv('DATA_DIR');

load(fullfile(data_dir, 'export', 'enc_rs.mat'), 'rs')
param = rs.param;
sub_info = rs.sub_info;
sub_pass = rs.sub_pass;

n_sub = height(sub_info);
n = N_PHASE_POINTS;
ph = linspace(0, 100, n);

d = TORQUE_SHAPE_EXP;

fric_c = 0.00;  % 쿨롱 마찰 계수 (현재 비활성)
fric_v = 0.00;  % 점성 마찰 계수 (현재 비활성)

%% load all inv_dyn date
rs_inv = struct();

for i = 1+sub_pass:n_sub
    sub_name = sub_info.ID(i);
    load(fullfile(data_dir, 'c3d_v3d', sprintf('sub_inv_%s.mat', sub_name)), 'sub_inv')

    rs_inv.(sub_name) = sub_inv;
    fprintf("%s sub_inv loaded...\n", sub_name)
end

%% calcuate parameters (rom, peak torque, peak power)
idyn_rs = struct();

for i = 1+sub_pass:n_sub
    sub_name = sub_info.ID(i);
    sub_rs = rs.(sub_name);
    sub_param = param(param.ID == sub_name, :);
    idx_info = rs.(sub_name).idx_info;
    idyn_rs.(sub_name) = struct();

    flx_srt = idx_info.flx_srt;
    flx_dur = idx_info.flx_dur;
    ext_srt = idx_info.ext_srt;
    ext_dur = idx_info.ext_dur;

    % load(fullfile(data_dir, 'c3d_v3d', sprintf('sub_inv_%s.mat', sub_name)), 'sub_inv')
    sub_inv = rs_inv.(sub_name);

    fn = fieldnames(sub_inv);
    tok = regexp(fn, '^walk(\d+)_(\d+)$', 'tokens', 'once');
    walks_idx  = unique(cellfun(@(t) str2double(t{1}), tok));

    % walking
    for j = 1:numel(walks_idx)
        walk = sprintf("walk%d", walks_idx(j));
        walk_rs = sub_rs.(walk);
        walk_param = sub_param.(walk);
        procs = fn(startsWith(fn, sprintf("walk%d_", walks_idx(j))));
        fprintf("[%s] walk%d processing...", sub_name, walks_idx(j))

        % TODO: 데이터 수정
        if sub_name == "S024" & walk == "walk12", continue, end
        if sub_name == "S032" & walk == "walk14", continue, end

        if numel(procs) > 1
            if ismember(walks_idx(j), idx_info.cont)
                % Multi-record continuous: merge segments with time offsets
                walk_v3d = merge_cont_v3d_segments(sub_inv, procs, walk_rs);
                fprintf(" [merged %d segments]", numel(procs));
            else
                warning("[%s] walk%d more than one record file, last file selected", sub_name, walks_idx(j))
            end
        end
        idyn_rs.(sub_name).(walk) = struct();

        if numel(procs) == 1 || ~ismember(walks_idx(j), idx_info.cont)
            proc = procs{end};
            walk_v3d = sub_inv.(proc);
        end

        % outlier removal
        [~, r_valid, ~] = removePhaseOutliers(walk_v3d.R_Knee_Angle.x', 2);
        [~, l_valid, ~] = removePhaseOutliers(walk_v3d.L_Knee_Angle.x', 2);

        % time
        dt_r = diff(walk_v3d.evt.rfs);
        dt_l = diff(walk_v3d.evt.lfs);
        idyn_rs.(sub_name).(walk).t = [walk_v3d.evt.rfs(r_valid); walk_v3d.evt.lfs(l_valid)];
        idyn_rs.(sub_name).(walk).dt = [dt_r(r_valid); dt_l(l_valid)];

        % toe off index
        rkeep = stance_keep(walk_v3d.evt.rfs, walk_v3d.evt.rfo, n);
        lkeep = stance_keep(walk_v3d.evt.lfs, walk_v3d.evt.lfo, n);

        rkeep = rkeep(:, r_valid);
        lkeep = lkeep(:, l_valid);

        % kinematics, kinetics
        for k = ["Hip", "Knee", "Ankle"]
            ang = [walk_v3d.(sprintf("R_%s_Angle", k)).x(:, r_valid), ...
                walk_v3d.(sprintf("L_%s_Angle", k)).x(:, l_valid)];
            mom = [walk_v3d.(sprintf("R_%s_Moment", k)).x(:, r_valid), ...
                walk_v3d.(sprintf("L_%s_Moment", k)).x(:, l_valid)];
            jvel = [walk_v3d.(sprintf("R_%s_JVel", k)).x(:, r_valid), ...
                walk_v3d.(sprintf("L_%s_JVel", k)).x(:, l_valid)];
            % V3D Power 대신 moment*jvel 직접 계산 (부호 일관성)
            pow = mom .* jvel * pi / 180;

            idyn_rs.(sub_name).(walk).(lower(k)+"_rom") = max(ang, [], 1) - min(ang, [], 1);
            idyn_rs.(sub_name).(walk).(lower(k)+"_peak_torque") = max(abs(mom), [], 1);
            idyn_rs.(sub_name).(walk).(lower(k)+"_peak_power") = max(abs(pow), [], 1);
            idyn_rs.(sub_name).(walk).(lower(k)+"_peak_jvel") = max(abs(jvel), [], 1);
            
            idyn_rs.(sub_name).(walk).(lower(k)+"_angle") = ang;
            idyn_rs.(sub_name).(walk).(lower(k)+"_moment") = mom;
            idyn_rs.(sub_name).(walk).(lower(k)+"_power") = pow;
            idyn_rs.(sub_name).(walk).(lower(k)+"_jvel") = jvel;

            % 양/음 일률 계산
            pow_pos = pow; pow_neg = pow;
            pow_pos(pow < 0) = 0;
            pow_neg(pow > 0) = 0;
            mpow_pos = mean(pow_pos, 1)';
            mpow_neg = mean(pow_neg, 1)';

            idyn_rs.(sub_name).(walk).(lower(k)+"_pow") = pow;
            idyn_rs.(sub_name).(walk).(lower(k)+"_mpow_pos") = mpow_pos;
            idyn_rs.(sub_name).(walk).(lower(k)+"_mpow_neg") = mpow_neg;

            % Stance 양/음 일 계산
            st_pow = pow;
            st_pow(~[rkeep, lkeep]) = 0;
            keep_fail = all(st_pow == 0, 1);

            st_pow_pos = st_pow; st_pow_neg = st_pow;
            st_pow_pos(st_pow < 0) = 0;
            st_pow_neg(st_pow > 0) = 0;
            st_mpow_pos = mean(st_pow_pos, 1)';
            st_mpow_neg = mean(st_pow_neg, 1)';

            st_pow(:, keep_fail) = nan;
            st_mpow_pos(keep_fail) = nan;
            st_mpow_neg(keep_fail) = nan;

            idyn_rs.(sub_name).(walk).(lower(k)+"_pow_st") = st_pow;
            idyn_rs.(sub_name).(walk).(lower(k)+"_mpow_pos_st") = st_mpow_pos;
            idyn_rs.(sub_name).(walk).(lower(k)+"_mpow_neg_st") = st_mpow_neg;

            % Swing 양/음 일 계산
            sw_pow = pow;
            sw_pow([rkeep, lkeep]) = 0;
            keep_fail = all(isnan(sw_pow), 1);

            sw_pow_pos = sw_pow; sw_pow_neg = sw_pow;
            sw_pow_pos(sw_pow < 0) = 0;
            sw_pow_neg(sw_pow > 0) = 0;
            sw_mpow_pos = mean(sw_pow_pos, 1)';
            sw_mpow_neg = mean(sw_pow_neg, 1)';

            sw_pow(:, keep_fail) = nan;
            sw_mpow_pos(keep_fail) = nan;
            sw_mpow_neg(keep_fail) = nan;

            idyn_rs.(sub_name).(walk).(lower(k)+"_pow_sw") = sw_pow;
            idyn_rs.(sub_name).(walk).(lower(k)+"_mpow_pos_sw") = sw_mpow_pos;
            idyn_rs.(sub_name).(walk).(lower(k)+"_mpow_neg_sw") = sw_mpow_neg;
        end

        % cont, calc p
        if ismember(walks_idx(j), idx_info.cont)
            log_dir = dir(fullfile(data_dir, 'log', sub_name, walk+"*.tdms"));
            log_file = log_dir(arrayfun(@(x) ~isempty(regexp(x.name,  ['^', walk, '(_\d+)?.tdms'], 'once')), log_dir));
            [t_dt, ~, ~, p] = read_log_file(log_file);
            t_log = seconds(t_dt - t_dt(1));

            stride_t = idyn_rs.(sub_name).(walk).t;
            t_end_mismatch = abs(t_log(end) - stride_t(end));
            if t_end_mismatch > 30
                warning("[%s, cont] walk%d t_end mismatch (%.1f sec). Skipping.\n", sub_name, walks_idx(j), t_end_mismatch)
                continue
            elseif t_end_mismatch > 10
                warning("[%s, cont] walk%d t_end mismatch (%.1f sec). Proceeding with caution.\n", sub_name, walks_idx(j), t_end_mismatch)
            end

            idyn_rs.(sub_name).(walk).p = interp1(t_log, p, stride_t, 'linear', 'extrap');
        end

        % 사람, 로봇 양/음 일률 계산
        if walk_param ~= "-1"
            if ismember(walks_idx(j), idx_info.cont)
                p = idyn_rs.(sub_name).(walk).p;
                tq_ = nan(size(p, 1), n);
                for k = 1:size(p, 1)
                    p_ = p(k , :);
                    [tq_(k, :), ~, ~] = makeTorqueProfile(ph, -p_(2), ext_srt, ext_dur, p_(1), flx_srt, flx_dur, d);
                end
            else
                p = str2double(split(walk_param));
                [tq_, ~, ~] = makeTorqueProfile(ph, -p(2), ext_srt, ext_dur, p(1), flx_srt, flx_dur, d);
            end

            hip_jvel = idyn_rs.(sub_name).(walk).hip_jvel;

            % 사람 양/음 일률 계산
            hip_tq_ = idyn_rs.(sub_name).(walk).hip_moment;
            bio_pow = (hip_tq_ - tq_') .* hip_jvel * pi / 180;
            bio_pow_pos = bio_pow; bio_pow_neg = bio_pow;
            bio_pow_pos(bio_pow < 0) = 0;
            bio_pow_neg(bio_pow > 0) = 0;
            bio_mpow_pos = mean(bio_pow_pos, 1)';
            bio_mpow_neg = mean(bio_pow_neg, 1)';

            idyn_rs.(sub_name).(walk).bio_moment = hip_tq_ - tq_';      % biological moment
            idyn_rs.(sub_name).(walk).bio_pow = bio_pow;
            idyn_rs.(sub_name).(walk).bio_mpow_pos = bio_mpow_pos;
            idyn_rs.(sub_name).(walk).bio_mpow_neg = bio_mpow_neg;

            % 로봇 마찰 일률 계산
            if ismember("h10", fieldnames(walk_rs))
                h10_t = mean(walk_rs.h10.time, 2);
                v3d_t = idyn_rs.(sub_name).(walk).t;
                fric_pow = fric_c * walk_rs.h10.fric_pow_c + fric_v * walk_rs.h10.fric_pow_v;

                fric_pow_sync = sync_window(v3d_t, h10_t, fric_pow', 2);
            else
                continue        % 마찰 포함되어 있지 않으면 로봇 일률 계산 X
            end

            % 로봇 양/음 일률 계산
            robot_pow = tq_' .* hip_jvel * pi / 180 - fric_pow_sync;
            robot_pow_pos = robot_pow; robot_pow_neg = robot_pow;
            robot_pow_pos(robot_pow < 0) = 0;
            robot_pow_neg(robot_pow > 0) = 0;
            robot_mpow_pos = mean(robot_pow_pos, 1)';
            robot_mpow_neg = mean(robot_pow_neg, 1)';

            idyn_rs.(sub_name).(walk).robot_pow = robot_pow;
            idyn_rs.(sub_name).(walk).robot_mpow_pos = robot_mpow_pos;
            idyn_rs.(sub_name).(walk).robot_mpow_neg = robot_mpow_neg;

            % 로봇, Stance 양/음 일률 계산
            st_pow = robot_pow;
            st_pow(~[rkeep, lkeep]) = 0;
            keep_fail = all(st_pow == 0, 1);

            st_pow_pos = st_pow; st_pow_neg = st_pow;
            st_pow_pos(st_pow < 0) = 0;
            st_pow_neg(st_pow > 0) = 0;
            st_mpow_pos = mean(st_pow_pos, 1)';
            st_mpow_neg = mean(st_pow_neg, 1)';

            st_pow(:, keep_fail) = nan;
            st_mpow_pos(keep_fail) = nan;
            st_mpow_neg(keep_fail) = nan;

            idyn_rs.(sub_name).(walk).robot_pow_st = st_pow;
            idyn_rs.(sub_name).(walk).robot_mpow_pos_st = st_mpow_pos;
            idyn_rs.(sub_name).(walk).robot_mpow_neg_st = st_mpow_neg;

            % 로봇, Swing 양/음 일 계산
            sw_pow = robot_pow;
            sw_pow([rkeep, lkeep]) = 0;
            keep_fail = all(sw_pow == 0, 1);

            sw_pow_pos = sw_pow; sw_pow_neg = sw_pow;
            sw_pow_pos(sw_pow < 0) = 0;
            sw_pow_neg(sw_pow > 0) = 0;
            sw_mpow_pos = mean(sw_pow_pos, 1)';
            sw_mpow_neg = mean(sw_pow_neg, 1)';

            sw_pow(:, keep_fail) = nan;
            sw_mpow_pos(keep_fail) = nan;
            sw_mpow_neg(keep_fail) = nan;

            idyn_rs.(sub_name).(walk).robot_pow_sw = sw_pow;
            idyn_rs.(sub_name).(walk).robot_mpow_pos_sw = sw_mpow_pos;
            idyn_rs.(sub_name).(walk).robot_mpow_neg_sw = sw_mpow_neg;
        end

        fprintf(" done!\n")
    end
end

fprintf("saving...")
save(fullfile(data_dir, 'c3d_v3d', 'idyn_summary.mat'), 'idyn_rs', '-v7.3')
fprintf(" done! finished!\n")

%% review kinematics, kinetics
close all
load(fullfile(data_dir, 'c3d_v3d', 'idyn_summary.mat'), 'idyn_rs')

for i = 1+sub_pass:n_sub
    sub_name = sub_info.ID(i);
    idx_info = rs.(sub_name).idx_info;
    sub_inv = idyn_rs.(sub_name);

    rep_dir = fullfile(data_dir, 'c3d_v3d', 'report', sub_name);
    if ~exist(rep_dir, 'dir'), mkdir(rep_dir), end

    % steady
    walks = fieldnames(sub_inv);
    for j = 1:numel(walks)
        walk = walks{j};
        reg_out = regexp(walk, '\d+$', 'match');
        walk_idx = str2double(reg_out{1});

        v3d = sub_inv.(walk);
        if isempty(fieldnames(v3d)), continue, end

        fh = figure('Name', sub_name, 'Position', [100, 100, 900, 600], 'Visible', 'off');
        for k = ["angle", "moment", "power"]
            for l = ["hip", "knee", "ankle"]
                data_ = v3d.(sprintf("%s_%s", l, k));
                data_m = mean(data_, 2, 'omitmissing');
                data_s = std(data_, [], 2, 'omitmissing');

                r_idx = find(ismember(["hip", "knee", "ankle"], l));
                c_idx = find(ismember(["angle", "moment", "power"], k));
                subplot(3, 3, 3*(c_idx-1) + r_idx)
                
                fill([ph, fliplr(ph)], [data_m - data_s; flipud(data_m + data_s)], [0.7 0.85 1], ...
                    'EdgeColor', 'none', 'FaceAlpha', 0.35); hold on
                plot(ph, data_m, 'k', "LineWidth", 1.0);
                plot(ph, data_, 'k', "LineWidth", 1.0);

                switch 3*(c_idx-1) + r_idx
                    case 1      % Hip Angle
                        title('Hip')
                        ylim([-40, 60])
                        ylabel("Angle deg")
                    case 2      % Knee Angle
                        title('Knee')
                        ylim([-80 20])
                    case 3      % Ankle Angle
                        title('Ankle')
                        ylim([-40 0])
                    case 4      % Hip Moment
                        ylim([-1, 1])
                        ylabel("Moment (Nm/kg)")
                    case 5      % Knee Moment
                        ylim([-1, 2])
                    case 6      % Ankle Moment
                        ylim([-3, 1])
                    case 7      % Hip Power
                        ylim([-2, 2])
                        ylabel("Power (W/kg)")
                        xlabel("phase (%)")
                    case 8      % Knee Power
                        ylim([-4, 3])
                    case 9      % Ankle Power
                        ylim([-7, 7])
                end
            end
        end

        if ismember(walk_idx, [idx_info.disc; idx_info.non_exo])
            w_type = 'disc';
        else
            w_type = 'cont';
        end

        saveas(fh, fullfile(data_dir, 'c3d_v3d', 'report', sub_name, sprintf('%s-%s-%s.jpg', sub_name, walk, w_type)))
        close(fh)
    end
end

%% review disc kinematics+kinetics
close all
load(fullfile(data_dir, 'c3d_v3d', 'idyn_summary.mat'), 'idyn_rs')
load(fullfile(data_dir, 'export', 'enc_rs.mat'), 'rs')

flx_c = distinguishable_colors(3);

for joint = ["hip", "knee", "ankle"]
    for type = ["angle", "moment", "power", "jvel"]

        rep_dir = fullfile(data_dir, 'c3d_v3d', 'report', joint+"_"+type);
        if ~exist(rep_dir, 'dir'), mkdir(rep_dir), end

        switch joint+type
            case "hipangle"
                ylim_ = [-20 40];
            case "kneeangle"
                ylim_ = [-80 20];
            case "ankleangle"
                ylim_ = [-40 10];
            case "hipmoment"
                ylim_ = [-1.5 1.5];
            case "kneemoment"
                ylim_ = [-1.5 2];
            case "anklemoment"
                ylim_ = [-3 1];
            case "hippower"
                ylim_ = [-3 3];
            case "kneepower"
                ylim_ = [-5 3];
            case "anklepower"
                ylim_ = [-3, 8];
            case "hipjvel"
                ylim_ = [-200 400];
            case "kneejvel"
                ylim_ = [-200 400];
            case "anklejvel"
                ylim_ = [-200 400];
        end

        for i = 1+rs.sub_pass:rs.n_sub
            sub_name = sub_info.ID(i);
            sub_rs = rs.(sub_name);
            idx_info = sub_rs.idx_info;
            sub_inv = idyn_rs.(sub_name);

            fh1 = figure('Name', sub_name, 'Position', [100, 100, 900, 600], 'Visible', 'off');
            fh2 = figure('Name', sub_name, 'Position', [100, 100, 900, 600], 'Visible', 'off');
            for walk_idx = idx_info.disc'
                walk = sprintf("walk%d", walk_idx);
                walk_rs = sub_rs.(walk);
                if ~ismember("p", fieldnames(walk_rs)), continue, end
                if ~ismember(walk, fieldnames(sub_inv)), continue, end
                walk_inv = sub_inv.(walk);

                if max(walk_inv.t) < 120
                    t_ss = true(size(walk_inv.t));
                else
                    t_end = walk_inv.t(end);
                    t_ss = t_end-120 < walk_inv.t & walk_inv.t < t_end-30;
                end
                data_ = walk_inv.(sprintf("%s_%s", joint, type));
                data_m = mean(data_(:, t_ss), 2, 'omitmissing');
                data_s = std(data_(:, t_ss), [], 2, 'omitmissing');

                p = round(walk_rs.p, 2);
                r_idx = find(ismember([0.04, 0.11, 0.18], p(1)));
                c_idx = find(ismember([0.04, 0.11, 0.18], p(2)));
                if isempty(r_idx) | isempty(c_idx), continue, end

                figure(fh1)
                subplot(3, 3, 3 * (r_idx-1) + c_idx)
                fill([ph, fliplr(ph)], [data_m - data_s; flipud(data_m + data_s)], [0.7 0.85 1], ...
                    'EdgeColor', 'none', 'FaceAlpha', 0.35); hold on
                plot(ph, data_m, 'Color', flx_c(r_idx, :), "LineWidth", c_idx);
                xlabel(sprintf("walk%d, (%.2f, %.2f)", walk_idx, p(1), p(2))), ylim(ylim_)

                switch 3*(r_idx-1) + c_idx
                    case 1
                        title('\tau_{ext}=0.04')
                        ylabel('\tau_{flx}=0.04')
                    case 2
                        title('\tau_{ext}=0.11')
                    case 3
                        title('\tau_{ext}=0.18')
                    case 4
                        ylabel('\tau_{flx}=0.11')
                    case 5
                    case 6
                    case 7
                        ylabel('\tau_{flx}=0.18')
                    case 8
                    case 9
                end

                figure(fh2)
                plot(ph, data_m,'Color', flx_c(r_idx, :), "LineWidth", c_idx); hold on
                ylim(ylim_)
            end

        saveas(fh1, fullfile(data_dir, 'c3d_v3d', 'report', joint+"_"+type, sprintf('%s.jpg', sub_name)))
        close(fh1)
        saveas(fh2, fullfile(data_dir, 'c3d_v3d', 'report', joint+"_"+type, sprintf('%s-overlap.jpg', sub_name)))
        close(fh2)
        end
    end
end

%% Functions

function d_b_sync = sync_window(t_a, t_b, d_b, T)
% sync_window - t_a를 기준으로 T초 이내 t_b에 해당하는 d_b를 평균하여 반환
%
% 입력:
%   t_a : 기준 시간 벡터 (Nx1)
%   t_b : 대상 시간 벡터 (Mx1)
%   d_b : 대상 데이터 (LxM)
%   T   : 허용 시간 오차 (초)
%
% 출력:
%   d_b_sync : t_a와 동기화된 d_b 평균값 (NaN 허용, Nx1)

    len = size(d_b, 1);
    d_b_sync = nan(len, numel(t_a));  % 결과 벡터 초기화

    for i = 1:length(t_a)
        dt = abs(t_b - t_a(i));
        idx = find(dt <= T);  % T초 이내의 인덱스

        if ~isempty(idx)
            d_b_sync(:, i) = mean(d_b(:, idx), 2);
        end
    end
end

function walk_v3d = merge_cont_v3d_segments(sub_inv, procs, walk_rs)
% merge_cont_v3d_segments - 멀티 레코드 연속 보행 V3D 데이터를 시간 오프셋으로 병합
%
% 입력:
%   sub_inv  : 피험자 V3D 구조체 (sub_inv.walk23_1, walk23_2, ...)
%   procs    : 레코드 필드명 셀 ({'walk23_1', 'walk23_2'})
%   walk_rs  : rs.(sub).(walk) 구조체 (log_t 포함)
%
% 출력:
%   walk_v3d : 병합된 V3D 구조체 (단일 레코드와 동일한 형식)

    procs = sort(procs);
    n_seg = numel(procs);

    % --- Compute time offsets from log_t ---
    if isfield(walk_rs, 'log_t')
        log_t = walk_rs.log_t;
        if isdatetime(log_t)
            log_t_sec = seconds(log_t - log_t(1));
        else
            log_t_sec = double(log_t(:)) - double(log_t(1));
        end

        % Detect pauses (dt > 5 sec)
        dt_log = diff(log_t_sec);
        pause_idx = find(dt_log > 5);
        pause_gaps = dt_log(pause_idx);
    else
        pause_idx = [];
        pause_gaps = [];
        log_t_sec = [];
    end

    % Compute each segment's max time (V3D internal)
    seg_max_t = zeros(n_seg, 1);
    for si = 1:n_seg
        rec = sub_inv.(procs{si});
        seg_max_t(si) = max([rec.evt.rfs; rec.evt.lfs]);
    end

    % Compute cumulative offsets
    offsets = zeros(n_seg, 1);
    if ~isempty(pause_idx) && numel(pause_idx) >= (n_seg - 1)
        % Use actual pause durations from log_t
        for si = 2:n_seg
            offsets(si) = offsets(si-1) + seg_max_t(si-1) + pause_gaps(si-1);
        end
    else
        % No pauses detected: distribute remaining time equally
        if ~isempty(log_t_sec)
            total_log = log_t_sec(end);
            total_seg = sum(seg_max_t);
            gap_per = max(0, (total_log - total_seg) / max(n_seg - 1, 1));
        else
            gap_per = 0;
        end
        for si = 2:n_seg
            offsets(si) = offsets(si-1) + seg_max_t(si-1) + gap_per;
        end
    end

    % --- Merge records ---
    walk_v3d = struct();
    walk_v3d.evt = struct('rfs', [], 'lfs', [], 'rfo', [], 'lfo', []);

    % Get kinematic/kinetic field names from first record
    rec1 = sub_inv.(procs{1});
    all_fields = fieldnames(rec1);
    kin_fields = setdiff(all_fields, {'evt'});

    for si = 1:n_seg
        rec = sub_inv.(procs{si});
        off = offsets(si);

        % Events (with time offset)
        evt_names = {'rfs', 'lfs', 'rfo', 'lfo'};
        for ei = 1:numel(evt_names)
            en = evt_names{ei};
            if isfield(rec.evt, en) && ~isempty(rec.evt.(en))
                walk_v3d.evt.(en) = [walk_v3d.evt.(en); rec.evt.(en) + off];
            end
        end

        % Kinematics/kinetics (concatenate along stride dimension)
        for fi = 1:numel(kin_fields)
            fn = kin_fields{fi};
            if ~isfield(rec, fn), continue; end
            if isstruct(rec.(fn)) && isfield(rec.(fn), 'x')
                if si == 1
                    walk_v3d.(fn) = struct('x', rec.(fn).x);
                else
                    walk_v3d.(fn).x = [walk_v3d.(fn).x, rec.(fn).x];
                end
            end
        end
    end

    fprintf(" offsets=[%s]", num2str(round(offsets'), '%.0f '));
end
