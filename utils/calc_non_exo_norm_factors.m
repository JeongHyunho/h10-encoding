function norm_factors = calc_non_exo_norm_factors(emg_proc, sub_name, muscle_names, idx_info)
%==========================================================================
% calc_non_exo_norm_factors(emg_proc, sub_name, muscle_names, idx_info)
%
% ⦿ 목적
%   - 비외골(non-exo) 보행 데이터에서 근육별 정규화 기준값(스케일)을 계산
%   - 평균 envelope의 피크값을 근육별 정규화 기준으로 사용
%
% ⦿ 입력
%   - emg_proc     : 전처리된 EMG 구조체 (sub → walk → dyn → 근육)
%   - sub_name     : 피험자 ID (예: 'S023')
%   - muscle_names : 근육 라벨 셀 배열
%   - idx_info     : 피험자별 조건 인덱스 정보 (idx_info.(sub).non_exo 등)
%
% ⦿ 출력
%   - norm_factors : struct, 일자별(day_1~day_4) 하위에 근육 라벨을 필드로 하는
%                    정규화 스케일 값. 해당 일자에 non_exo가 없으면 NaN 저장.
%==========================================================================

% 기본 설정
MIN_FACTOR = 1e-6;        % 0 나누기 방지 최소값

% 출력 구조 초기화 (day별 내부 근육 스케일 구성)
day_labels = {"day_1","day_2","day_3","day_4"};
norm_factors = struct();
for d = 1:numel(day_labels)
    day_label = day_labels{d};
    norm_factors.(day_label) = struct();
    for i = 1:numel(muscle_names)
        norm_factors.(day_label).(muscle_names{i}) = NaN; %#ok<*AGROW>
    end
end

% 피험자 유효성 확인
if ~isfield(emg_proc, sub_name)
    return
end

% day별로 non_exo 보행을 필터링하여 근육별 norm factor 계산
if ~isfield(idx_info, sub_name)
    return
end
sub_idx = idx_info.(sub_name);

for d = 1:numel(day_labels)
    day_label = day_labels{d};
    if ~isfield(sub_idx, day_label), continue, end
    day_walks = sub_idx.(day_label);
    % 해당 일자 내 non_exo만 선택
    non_exo_idx = [];
    if isfield(sub_idx, 'non_exo') && ~isempty(sub_idx.non_exo)
        non_exo_idx = intersect(day_walks(:), sub_idx.non_exo(:));
    end
    if isempty(non_exo_idx) || all(isnan(non_exo_idx))
        % 요구사항: non_exo가 없으면 NaN 유지
        continue
    end
    non_exo_walk_names = arrayfun(@(w) sprintf('walk%d', w), non_exo_idx, 'UniformOutput', false);

    for mi = 1:numel(muscle_names)
        muscle = muscle_names{mi};
        mean_envelopes = [];
        for wi = 1:numel(non_exo_walk_names)
            walk_name = non_exo_walk_names{wi};
            if ~isfield(emg_proc.(sub_name), walk_name), continue, end
            walk_data = emg_proc.(sub_name).(walk_name);
            case_names = fieldnames(walk_data);
            dyn_cases = case_names(contains(case_names, 'dyn'));
            for ci = 1:numel(dyn_cases)
                emg_case = dyn_cases{ci};
                if ~isfield(walk_data, emg_case), continue, end
                emg_dat = walk_data.(emg_case);
                if ~isstruct(emg_dat), continue, end
                % 표준 라벨 입력('VM','RF' 등)에서도 다채널(VM1/VM2, RF1/RF2) 선택되도록 처리
                sig = local_select_emg_signal(emg_dat, muscle);
                if isempty(sig), continue, end
                if ~isnumeric(sig) || ~ismatrix(sig), continue, end
                if size(sig,1) ~= 301
                    error('[calc_non_exo_norm_factors] 형상 불일치: %s %s %s %s → size(sig)=(%dx%d), 기대 형상=301xN', ...
                        sub_name, walk_name, emg_case, muscle, size(sig,1), size(sig,2));
                end
                % 301 x strides 가정: 보행 평균 envelope 계산 (301 요소 row 벡터)
                mean_env = mean(sig, 2, 'omitnan')';
                if any(isfinite(mean_env))
                    mean_envelopes = [mean_envelopes; mean_env];
                end
            end
        end
        if ~isempty(mean_envelopes)
            overall_env = mean(mean_envelopes, 1, 'omitnan');
            peak_val = max(overall_env, [], 'omitnan');
            if ~isfinite(peak_val) || peak_val < MIN_FACTOR
                peak_val = NaN;
            end
            norm_factors.(day_label).(muscle) = peak_val;
        else
            norm_factors.(day_label).(muscle) = NaN;
        end
    end
end

end



% === 로컬 보조 함수: 표준 라벨에서 다채널 선택 처리 ===
function sig = local_select_emg_signal(emg_case_struct, muscle)
% 한국어 주석: muscle이 'VM' 또는 'RF'인 경우 다채널을 우선순위에 따라 선택
%  - 우선 동일 라벨 필드(VM, RF)가 있으면 이를 최우선 사용
%  - VM: (단일 라벨 없을 때) VM2 우선, 없으면 VM1
%  - RF: (단일 라벨 없을 때) RF1 우선, 없으면 RF2
%  - 그 외: 해당 근육 필드 직접 사용
% 반환값이 비어 있으면 상위 로직에서 continue

sig = [];
try
    % 1) 동일 라벨 필드 최우선
    if isfield(emg_case_struct, muscle) && any(any(~isnan(emg_case_struct.(muscle))))
        sig = emg_case_struct.(muscle);
        return
    end
    if strcmp(muscle, 'VM')
        if isfield(emg_case_struct, 'VM2') && any(any(~isnan(emg_case_struct.VM2)))
            sig = emg_case_struct.VM2;
        elseif isfield(emg_case_struct, 'VM1') && any(any(~isnan(emg_case_struct.VM1)))
            sig = emg_case_struct.VM1;
        end
    elseif strcmp(muscle, 'RF')
        if isfield(emg_case_struct, 'RF1') && any(any(~isnan(emg_case_struct.RF1)))
            sig = emg_case_struct.RF1;
        elseif isfield(emg_case_struct, 'RF2') && any(any(~isnan(emg_case_struct.RF2)))
            sig = emg_case_struct.RF2;
        end
    else
        if isfield(emg_case_struct, muscle)
            sig = emg_case_struct.(muscle);
        end
    end
catch
    % 조용히 실패: sig=[] 유지
end
end
