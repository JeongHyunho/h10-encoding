function emg_norm = emg_normalization_and_activation(idx_info, muscle_names, emg_proc)
%==========================================================================
% emg_normalization_and_activation(idx_info, muscle_names, emg_proc)
%
% ⦿ 기능:
%   - emg_proc 구조를 입력받아 비외골(non-exo) 보행 기반 정규화 수행
%   - stride 정보가 있는 케이스에 대해 iEMG/activation/CCI 계산
%   - 결과 구조체 emg_norm 반환 및 DATA_DIR/emg/emg_norm.mat로 저장
%
% ⦿ 입력:
%   - idx_info     : 피험자별 조건 인덱스 정보 구조체
%   - muscle_names : 근육 라벨 기준 배열
%   - emg_proc     : 전처리 후 EMG 데이터 구조체
%
% ⦿ 출력:
%   - emg_norm     : 정규화/활성화/CCI가 포함된 결과 구조체
%==========================================================================

% 환경 설정
mfile_dir = fileparts(mfilename('fullpath'));
cd(mfile_dir)
run('../../setup.m')
data_dir = getenv('DATA_DIR');

% 초기화
emg_norm = emg_proc; % 구조 뼈대 복사 (원본 보존)

subjects = fieldnames(emg_proc);
for s = 1:numel(subjects)
    sub_name = subjects{s};
    if ~isfield(idx_info, sub_name), continue, end

    % 비외골격 기반 정규화 계수 계산
    fprintf('[%s] 비외골격 보행 기반 정규화 계수 계산 중...\n', sub_name);
    norm_factors = calc_non_exo_norm_factors(emg_proc, sub_name, muscle_names, idx_info);

    walks = fieldnames(emg_proc.(sub_name));
    for w = 1:numel(walks)
        walk_name = walks{w};
        if ~isfield(emg_proc.(sub_name), walk_name), continue, end

        walk_data = emg_proc.(sub_name).(walk_name);
        % walk index와 해당 일자(day_1~day_4) 결정
        walk_num_token = regexp(walk_name, '\d+', 'match', 'once');
        if ~isempty(walk_num_token)
            walk_idx_num = str2double(walk_num_token);
        else
            walk_idx_num = NaN;
        end
        day_label = '';
        day_labels_local = {"day_1","day_2","day_3","day_4"};
        sub_idx_info = idx_info.(sub_name);
        for di = 1:numel(day_labels_local)
            dl = day_labels_local{di};
            if isfield(sub_idx_info, dl) && any(sub_idx_info.(dl) == walk_idx_num)
                day_label = dl;
                break
            end
        end
        all_cases = fieldnames(walk_data);
        dyn_cases = all_cases(contains(all_cases, 'dyn'));

        % 이 walk에 적용할 일자별 정규화 계수 보관 (walk 레벨에 저장)
        if ~isempty(day_label) && isfield(norm_factors, day_label)
            nf_day = norm_factors.(day_label);
        else
            % 해당 일자에 non_exo가 없어 NaN으로 채운 스케일 구성
            nf_day = struct();
            for mi = 1:numel(muscle_names)
                nf_day.(muscle_names{mi}) = NaN;
            end
        end
        emg_norm.(sub_name).(walk_name).norm_factors = nf_day;

        % dyn 간 집계를 위한 누적 버퍼 (walk 레벨)
        act_agg = struct();
        for mi = 1:numel(muscle_names)
            mlabel = muscle_names{mi};
            act_agg.(mlabel) = struct('total', [], 'stance', [], 'swing', []);
        end
        cci_agg = struct();
        cci_names_walk = {'VL_BF','VL_ST','RF_BF','RF_ST','VM_BF','VM_ST'};

        for c = 1:numel(dyn_cases)
            emg_case = dyn_cases{c};
            if ~isfield(walk_data, emg_case), continue, end
            emg_dat = walk_data.(emg_case);
            if ~isstruct(emg_dat), continue, end

            % 정규화: 표준 근육 라벨 기준으로 원신호 선택(select_emg_channel) 후 정규화 저장
            target_muscles = muscle_names;
            for m = 1:numel(target_muscles)
                muscle = target_muscles{m};
                % VM/RF의 다채널(VM1/VM2, RF1/RF2) 포함하여 원신호 선택
                raw_data = select_emg_channel(emg_dat, muscle, 'VL');
                if isnumeric(raw_data) && ismatrix(raw_data)
                    % 일자별(norm_factors.day_x) 스케일 적용 (walk 레벨에 저장된 nf_day 사용)
                    emg_norm.(sub_name).(walk_name).(emg_case).(muscle) = emg_normalize(raw_data, nf_day, muscle);
                end
            end

            % stride 정보가 있을 때만 iEMG/Activation/CCI 계산
            has_stride_info = isfield(emg_dat, 'stance_swing') && isfield(emg_dat, 'stride_time');
            if has_stride_info
                for m = 1:numel(target_muscles)
                    muscle = target_muscles{m};
                    if isfield(emg_norm.(sub_name).(walk_name).(emg_case), muscle)
                        data_mat = emg_norm.(sub_name).(walk_name).(emg_case).(muscle);
                        % 형상 체크: 첫 번째 차원이 301 이어야 함 (301 x strides)
                        if size(data_mat, 1) ~= 301
                            error('[activation] 형상 불일치: %s %s %s %s → size=(%dx%d), 기대 형상=301xN', ...
                                sub_name, walk_name, emg_case, muscle, size(data_mat,1), size(data_mat,2));
                        end
                        stance_swing_local = emg_dat.stance_swing;
                        if ~isequal(size(stance_swing_local), size(data_mat))
                            error('[activation] stance_swing 형상 불일치: %s %s %s %s → ss=(%dx%d), data=(%dx%d)', ...
                                sub_name, walk_name, emg_case, muscle, size(stance_swing_local,1), size(stance_swing_local,2), size(data_mat,1), size(data_mat,2));
                        end

                        n_stride = size(data_mat, 2);
                        iemg_total = zeros(n_stride, 1);
                        iemg_stance = zeros(n_stride, 1);
                        iemg_swing = zeros(n_stride, 1);
                        activation_total = zeros(n_stride, 1);
                        activation_stance = zeros(n_stride, 1);
                        activation_swing = zeros(n_stride, 1);
                        for stride_idx = 1:n_stride
                            stride_data = data_mat(:, stride_idx);
                            stride_phase = stance_swing_local(:, stride_idx);

                            stride_len = emg_dat.stride_time(stride_idx);
                            n_total = sum(~isnan(stride_data));
                            if ~isfinite(stride_len) || stride_len <= 0 || n_total == 0
                                iemg_total(stride_idx) = NaN;
                                iemg_stance(stride_idx) = NaN;
                                iemg_swing(stride_idx) = NaN;
                                activation_total(stride_idx) = NaN;
                                activation_stance(stride_idx) = NaN;
                                activation_swing(stride_idx) = NaN;
                                continue
                            end

                            % 전체 구간
                            total_y = stride_data(~isnan(stride_data));
                            time_total = linspace(0, stride_len, numel(total_y));
                            iemg_total(stride_idx) = trapz(time_total, total_y);

                            % stance 구간 (NaN 제거)
                            stance_mask = (stride_phase == 1);
                            y_stance = stride_data(stance_mask);
                            y_stance = y_stance(~isnan(y_stance));
                            n_stance_eff = numel(y_stance);
                            stance_time = stride_len * (sum(stance_mask) / numel(stride_phase));
                            if n_stance_eff > 1 && stance_time > 0
                                time_stance = linspace(0, stance_time, n_stance_eff);
                                iemg_stance(stride_idx) = trapz(time_stance, y_stance);
                                activation_stance(stride_idx) = iemg_stance(stride_idx) / stance_time;
                            else
                                iemg_stance(stride_idx) = NaN;
                                activation_stance(stride_idx) = NaN;
                            end

                            % swing 구간 (NaN 제거)
                            swing_mask = (stride_phase == 0);
                            y_swing = stride_data(swing_mask);
                            y_swing = y_swing(~isnan(y_swing));
                            n_swing_eff = numel(y_swing);
                            swing_time = stride_len * (sum(swing_mask) / numel(stride_phase));
                            if n_swing_eff > 1 && swing_time > 0
                                time_swing = linspace(0, swing_time, n_swing_eff);
                                iemg_swing(stride_idx) = trapz(time_swing, y_swing);
                                activation_swing(stride_idx) = iemg_swing(stride_idx) / swing_time;
                            else
                                iemg_swing(stride_idx) = NaN;
                                activation_swing(stride_idx) = NaN;
                            end

                            % 전체 활성도 (전체 iEMG / stride 길이)
                            activation_total(stride_idx) = iemg_total(stride_idx) / stride_len;
                        end

                        % 보폭 유효성 기준(라인 190의 통계 NaN 기준과 동일한 임계 사용)
                        % invalid if (total<0.03) OR (total>3) OR (stance>3) OR (swing>=3)
                        valid_strides = ~( (activation_total < 0.03) | (activation_total > 3) | ...
                                           (activation_stance > 3) | (activation_swing >= 3) );
                        % 유효 보폭만 남기는 것이 아니라, 무효 보폭을 NaN으로 채워 길이를 유지
                        activation_total_new = activation_total;
                        activation_total_new(~valid_strides) = NaN;
                        activation_stance_new = activation_stance;
                        activation_stance_new(~valid_strides) = NaN;
                        activation_swing_new = activation_swing;
                        activation_swing_new(~valid_strides) = NaN;

                        emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).total = activation_total_new;
                        emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stance = activation_stance_new;
                        emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).swing = activation_swing_new;

                        emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats = struct();
                        mean_total = mean(activation_total, 'omitnan');
                        mean_stance = mean(activation_stance, 'omitnan');
                        mean_swing = mean(activation_swing, 'omitnan');
                        if (mean_total < 0.03 || mean_total > 3 || mean_stance > 3 || mean_swing >= 3)
                            emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats.total_mean = nan;
                            emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats.total_std = nan;
                            emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats.stance_mean = nan;
                            emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats.stance_std = nan;
                            emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats.swing_mean = nan;
                            emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats.swing_std = nan;
                            warning('[activation 평균 이상치] sub: %s, walk: %s, case: %s, muscle: %s, activation_total_mean=%.4f', ...
                                sub_name, walk_name, emg_case, muscle, mean_total);
                        else
                            emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats.total_mean = mean_total;
                            emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats.total_std = std(activation_total, 'omitnan');
                            emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats.stance_mean = mean_stance;
                            emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats.stance_std = std(activation_stance, 'omitnan');
                            emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats.swing_mean = mean_swing;
                            emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats.swing_std = std(activation_swing, 'omitnan');
                        end

                        % dyn 집계를 위해 누적 (NaN 유지)
                        act_agg.(muscle).total = [act_agg.(muscle).total; activation_total_new(:)];
                        act_agg.(muscle).stance = [act_agg.(muscle).stance; activation_stance_new(:)];
                        act_agg.(muscle).swing = [act_agg.(muscle).swing; activation_swing_new(:)];

                        n_stride_log = n_stride;
                        fprintf('[%s] 활성도 계산 완료 (non-exo 정규화) → %s %s %s (n=%d 보폭)\n', ...
                            sub_name, walk_name, emg_case, muscle, n_stride_log);
                    end
                end

                % CCI 계산 (stride 기반) - 정규화되지 않은 원신호(emg_proc) 사용
                cci_pairs = {{'VL', 'BF'}, {'VL', 'ST'}, {'RF', 'BF'}, {'RF', 'ST'}, {'VM', 'BF'}, {'VM', 'ST'}};
                cci_names = {'VL_BF', 'VL_ST', 'RF_BF', 'RF_ST', 'VM_BF', 'VM_ST'};
                for p = 1:numel(cci_pairs)
                    m1 = cci_pairs{p}{1}; m2 = cci_pairs{p}{2};
                    emg_case_raw = emg_proc.(sub_name).(walk_name).(emg_case);
                    emg1 = select_emg_channel(emg_case_raw, m1, m2);
                    emg2 = select_emg_channel(emg_case_raw, m2, m1);
                    % 형상 확인: (301 x strides) 이어야 함. 자동 전치/보정 금지
                    if size(emg1,1) ~= 301 || size(emg2,1) ~= 301
                        error('[CCI 계산 생략] 형상 불일치: %s %s %s (%s-%s) → emg1=(%dx%d), emg2=(%dx%d); 기대 형상=301xN', ...
                            sub_name, walk_name, emg_case, m1, m2, size(emg1,1), size(emg1,2), size(emg2,1), size(emg2,2));
                    end
                    % emg1, emg2 모두 (301 x strides)이어야 함
                    n_stride = size(emg1, 2);
                    cci = nan(n_stride, 1);
                    cci_st = nan(n_stride, 1);
                    cci_sw = nan(n_stride, 1);
                    % stance/swing 마스크를 (301 x strides)로 정렬
                    ss_ps = emg_dat.stance_swing;

                    for stride_idx = 1:n_stride
                        % 보폭별 시계열에서 NaN/무신호 보폭은 제외 (activation 기준과 정합)
                        x = emg1(:, stride_idx); 
                        y = emg2(:, stride_idx);
                        if any(isnan(x)) || any(isnan(y))
                            cci(stride_idx) = nan;
                            cci_st(stride_idx) = nan;
                            cci_sw(stride_idx) = nan;
                            continue
                        end

                        numer = 2 * sum(min(x, y), 'omitnan');
                        denom = sum(x + y, 'omitnan');
                        if denom > 0
                            cci(stride_idx) = numer / denom;
                        else
                            cci(stride_idx) = nan;
                        end
                        
                        % stance-only CCI (구간 무신호 검사 포함)
                        stance_mask = (ss_ps(:, stride_idx) == 1);
                        xs = x(stance_mask);
                        ys = y(stance_mask);
                        ns = 2 * sum(min(xs, ys), 'omitnan');
                        ds = sum(xs + ys, 'omitnan');
                        if ds > 0
                            cci_st(stride_idx) = ns / ds;
                        else
                            cci_st(stride_idx) = nan;
                        end

                        % swing-only CCI (구간 무신호 검사 포함)
                        swing_mask = (ss_ps(:, stride_idx) == 0);
                        xw = x(swing_mask);
                        yw = y(swing_mask);
                        nw = 2 * sum(min(xw, yw), 'omitnan');
                        dw = sum(xw + yw, 'omitnan');
                        if dw > 0
                            cci_sw(stride_idx) = nw / dw;
                        else
                            cci_sw(stride_idx) = nan;
                        end
                    end
                    if ~isfield(emg_norm.(sub_name).(walk_name).(emg_case), 'cci')
                        emg_norm.(sub_name).(walk_name).(emg_case).cci = struct();
                    end
                    emg_norm.(sub_name).(walk_name).(emg_case).cci.(cci_names{p}) = cci;
                    % 추가: stance/swing CCI 저장
                    if ~isfield(emg_norm.(sub_name).(walk_name).(emg_case), 'cci_total')
                        emg_norm.(sub_name).(walk_name).(emg_case).cci_total = struct();
                    end
                    if ~isfield(emg_norm.(sub_name).(walk_name).(emg_case), 'cci_stance')
                        emg_norm.(sub_name).(walk_name).(emg_case).cci_stance = struct();
                    end
                    if ~isfield(emg_norm.(sub_name).(walk_name).(emg_case), 'cci_swing')
                        emg_norm.(sub_name).(walk_name).(emg_case).cci_swing = struct();
                    end
                    emg_norm.(sub_name).(walk_name).(emg_case).cci_total.(cci_names{p}) = cci;
                    emg_norm.(sub_name).(walk_name).(emg_case).cci_stance.(cci_names{p}) = cci_st;
                    emg_norm.(sub_name).(walk_name).(emg_case).cci_swing.(cci_names{p}) = cci_sw;
                    % CCI 통계(activation과 유사한 mean/std) 저장
                    if ~isfield(emg_norm.(sub_name).(walk_name).(emg_case), 'cci_stats')
                        emg_norm.(sub_name).(walk_name).(emg_case).cci_stats = struct();
                    end
                    cci_stat_struct = struct();
                    cci_stat_struct.total_mean  = mean(cci, 'omitnan');
                    cci_stat_struct.total_std   = std(cci, 'omitnan');
                    cci_stat_struct.stance_mean = mean(cci_st, 'omitnan');
                    cci_stat_struct.stance_std  = std(cci_st, 'omitnan');
                    cci_stat_struct.swing_mean  = mean(cci_sw, 'omitnan');
                    cci_stat_struct.swing_std   = std(cci_sw, 'omitnan');
                    emg_norm.(sub_name).(walk_name).(emg_case).cci_stats.(cci_names{p}) = cci_stat_struct;
                    % dyn 집계를 위해 누적
                    cname = cci_names{p};
                    if ~isfield(cci_agg, cname)
                        cci_agg.(cname) = struct('total', [], 'stance', [], 'swing', []);
                    end
                    cci_agg.(cname).total = [cci_agg.(cname).total; cci(:)];
                    cci_agg.(cname).stance = [cci_agg.(cname).stance; cci_st(:)];
                    cci_agg.(cname).swing = [cci_agg.(cname).swing; cci_sw(:)];
                end
            end
        end

        % === dyn 집계: walk 내 모든 dyn 데이터를 concat 후 stats 재계산 ===
        % Activation 집계
        for mi = 1:numel(muscle_names)
            muscle = muscle_names{mi};
            at = act_agg.(muscle).total; as = act_agg.(muscle).stance; aw = act_agg.(muscle).swing;
            mean_total = mean(at, 'omitnan');
            mean_stance = mean(as, 'omitnan');
            mean_swing = mean(aw, 'omitnan');
            if (mean_total < 0.03 || mean_total > 3 || mean_stance > 3 || mean_swing >= 3)
                stats_out = struct('total_mean', nan, 'total_std', nan, 'stance_mean', nan, 'stance_std', nan, 'swing_mean', nan, 'swing_std', nan);
            else
                stats_out = struct('total_mean', mean_total, 'total_std', std(at, 'omitnan'), ...
                                   'stance_mean', mean_stance, 'stance_std', std(as, 'omitnan'), ...
                                   'swing_mean', mean_swing, 'swing_std', std(aw, 'omitnan'));
            end
            for c = 1:numel(dyn_cases)
                emg_case = dyn_cases{c};
                if isfield(emg_norm.(sub_name).(walk_name).(emg_case), 'activation') && ...
                        isfield(emg_norm.(sub_name).(walk_name).(emg_case).activation, muscle)
                    emg_norm.(sub_name).(walk_name).(emg_case).activation.(muscle).stats = stats_out;
                end
            end
        end

        % CCI 집계
        for p = 1:numel(cci_names_walk)
            cname = cci_names_walk{p};
            if ~isfield(cci_agg, cname), continue, end
            ct = cci_agg.(cname).total; cs = cci_agg.(cname).stance; cw = cci_agg.(cname).swing;
            cstats = struct();
            cstats.total_mean  = mean(ct, 'omitnan');
            cstats.total_std   = std(ct, 'omitnan');
            cstats.stance_mean = mean(cs, 'omitnan');
            cstats.stance_std  = std(cs, 'omitnan');
            cstats.swing_mean  = mean(cw, 'omitnan');
            cstats.swing_std   = std(cw, 'omitnan');
            for c = 1:numel(dyn_cases)
                emg_case = dyn_cases{c};
                if ~isfield(emg_norm.(sub_name).(walk_name).(emg_case), 'cci_stats')
                    emg_norm.(sub_name).(walk_name).(emg_case).cci_stats = struct();
                end
                emg_norm.(sub_name).(walk_name).(emg_case).cci_stats.(cname) = cstats;
            end
        end
    end
end

% 결과 저장 (덮어쓰기 방지)
out_dir = fullfile(data_dir, 'emg');
if ~exist(out_dir, 'dir'), mkdir(out_dir), end
save(fullfile(out_dir, 'emg_norm.mat'), 'emg_norm', '-v7.3')
fprintf('EMG 정규화 완료. 결과가 emg_norm.mat에 저장되었습니다.\n')

end

% === 내부 보조 함수: VM/RF 채널 선택 규칙 ===
function emg_data = select_emg_channel(emg_dat, muscle, ref_muscle)
    % 우선순위 1) 동일 라벨 필드가 존재하고 유효하면 즉시 사용
    if isfield(emg_dat, muscle) && any(any(~isnan(emg_dat.(muscle))))
        emg_data = emg_dat.(muscle);
        return
    end
    if strcmp(muscle, 'VM')
        ch2_name = 'VM2';
        ch1_name = 'VM1';
        if isfield(emg_dat, ch2_name) && any(any(~isnan(emg_dat.(ch2_name))))
            emg_data = emg_dat.(ch2_name);
        elseif isfield(emg_dat, ch1_name) && any(any(~isnan(emg_dat.(ch1_name))))
            emg_data = emg_dat.(ch1_name);
        elseif isfield(emg_dat, ref_muscle)
            emg_data = nan(size(emg_dat.(ref_muscle)));
        else
            emg_data = nan(1, 301);
        end
    elseif strcmp(muscle, 'RF')
        ch1_name = 'RF1';
        ch2_name = 'RF2';
        % 우선순위 1단계에서 RF 단일 필드를 이미 확인했으므로 여기서는 1/2 채널 우선순위만 수행
        if isfield(emg_dat, ch1_name) && any(any(~isnan(emg_dat.(ch1_name))))
            emg_data = emg_dat.(ch1_name);
        elseif isfield(emg_dat, ch2_name) && any(any(~isnan(emg_dat.(ch2_name))))
            emg_data = emg_dat.(ch2_name);
        elseif isfield(emg_dat, ref_muscle)
            emg_data = nan(size(emg_dat.(ref_muscle)));
        else
            emg_data = nan(1, 301);
        end
    else
        if isfield(emg_dat, muscle)
            emg_data = emg_dat.(muscle);
        elseif isfield(emg_dat, ref_muscle)
            emg_data = nan(size(emg_dat.(ref_muscle)));
        else
            emg_data = nan(1, 301);
        end
    end
end
