function [isAbnormal, reason] = is_abnormal_emg(emg_data)
%IS_ABNORMAL_EMG EMG 신호의 이상 여부를 GEMINI.md의 기준에 따라 판단합니다.
%
%   [isAbnormal, reason] = is_abnormal_emg(emg_data)
%
%   입력:
%       emg_data - N x M 행렬. (N: 스트라이드 수, M: 주기 내 데이터 포인트 수)
%
%   출력:
%       isAbnormal - 논리값 (true: 이상 채널, false: 정상 채널)
%       reason     - 이상 판정 시, 그 이유를 담은 코드 형식의 문자열

% --- 이상 판정을 위한 임계값 정의 ---
NO_SIGNAL_STD_THRESHOLD = 1e-7; % '신호 없음'으로 판단할 표준편차 임계값 (기존 1e-4)
OUTLIER_MEAN_THRESHOLD = 0.1;   % '이상치 존재' 확인을 시작할 평균값 상한선
OUTLIER_SPIKE_FACTOR = 15;      % 평균 대비 최대값이 이 배율을 초과하면 스파이크로 간주
LACK_OF_PERIODICITY_ZERO_THRESHOLD = 1e-6; % 이 값 미만은 '신호 없음'으로 처리 (기존 1e-3)
LACK_OF_PERIODICITY_PERCENTAGE = 0.5; % 스트라이드 내 '신호 없음' 비율이 이 값을 넘으면 주기성 부족으로 의심
LACK_OF_PERIODICITY_STRIDE_COUNT = 0.3; % 주기성 부족으로 의심되는 스트라이드가 전체의 이 비율을 넘으면 최종 판정
HIGH_VARIABILITY_THRESHOLD = 0.5; % 주기 간 변동성(std)이 평균 신호의 피크 대비 이 비율을 넘으면 변동성이 높다고 판단
REPRESENTATIVENESS_DEVIATION_PERCENTAGE = 0.7; % 평균선이 데이터 구름을 70% 이상 벗어나면 대표성 부족

% --- 초기 상태: 정상으로 가정 ---
isAbnormal = false;
reason = 'Normal';

% 입력 데이터 유효성 검사
if isempty(emg_data) || ~ismatrix(emg_data) || size(emg_data, 1) < 2
    isAbnormal = true;
    reason = 'INVALID_INPUT';
    return;
end

[N, M] = size(emg_data);

% --- 판정 기준 1: 신호 없음 (거의 플랫 라인) ---
if std(emg_data(:)) < NO_SIGNAL_STD_THRESHOLD
    isAbnormal = true;
    reason = 'NO_SIGNAL';
    return;
end

% --- 판정 기준 2: 이상치 존재 (평균은 낮은데 큰 스파이크가 있음) ---
overall_mean = mean(emg_data(:), 'omitnan');
overall_max = max(emg_data(:));
% 평균이 0에 가까운데, 최대값이 비정상적으로 큰 경우
if overall_mean < OUTLIER_MEAN_THRESHOLD && overall_max > (overall_mean * OUTLIER_SPIKE_FACTOR)
    isAbnormal = true;
    reason = 'OUTLIER';
    return;
end

% --- 판정 기준 3: 높은 변동성 (주기별 패턴이 일관되지 않음) ---
mean_curve_for_var = mean(emg_data, 1, 'omitnan');
std_curve = std(emg_data, [], 1);
peak_of_mean = max(mean_curve_for_var);

if peak_of_mean > 1e-5 % 아주 작은 신호는 이 검사를 건너뜀
    variability_ratio = mean(std_curve, 'omitnan') / peak_of_mean;
    if variability_ratio > HIGH_VARIABILITY_THRESHOLD
        isAbnormal = true;
        reason = 'HIGH_VARIABILITY';
        return;
    end
end

% --- 판정 기준 4: 주기성 부족 (신호가 부분적으로만 존재) ---
sparse_strides = 0;
for i = 1:N
    stride = emg_data(i, :);
    % 한 스트라이드 내에서 신호가 거의 0인 데이터 포인트의 비율 계산
    zero_points_percentage = sum(stride < LACK_OF_PERIODICITY_ZERO_THRESHOLD) / M;
    if zero_points_percentage > LACK_OF_PERIODICITY_PERCENTAGE
        sparse_strides = sparse_strides + 1;
    end
end

% 주기성이 부족한 스트라이드가 일정 비율 이상이면 이상 채널로 판정
if (sparse_strides / N) > LACK_OF_PERIODICITY_STRIDE_COUNT
    isAbnormal = true;
    reason = 'INTERMITTENT_SIGNAL';
    return;
end

% --- 판정 기준 4: 대표성 부족 (평균선이 데이터 구름을 벗어남) ---
mean_curve = mean(emg_data, 1, 'omitnan');
% 각 데이터 포인트(열)별로 20-80 백분위수 범위를 계산하여 '데이터 구름'의 경계로 삼음
percentile_bounds = prctile(emg_data, [20, 80], 1);
lower_bound = percentile_bounds(1, :);
upper_bound = percentile_bounds(2, :);

% 평균 곡선이 데이터 구름의 경계를 벗어나는 비율을 계산
outside_bounds_count = sum(mean_curve < lower_bound | mean_curve > upper_bound);
if (outside_bounds_count / M) > REPRESENTATIVENESS_DEVIATION_PERCENTAGE
    isAbnormal = true;
    reason = 'POOR_REPRESENTATION';
    return;
end

end
