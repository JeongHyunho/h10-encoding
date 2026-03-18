function [outlier_indices, correctedEMG] = find_emg_outliers(emg_data, threshold)
%==========================================================================
% find_emg_outliers(emg_data, threshold)
%
% ⦿ 기능:
%   - EMG 데이터(시간 x 보폭)의 각 보폭을 평균 보폭 파형과 비교하여 이상치 보폭 탐지
%   - 이상치로 판정된 보폭은 correctedEMG에서 전체 열을 NaN으로 마스킹(평균/표준편차 계산 제외)
%   - 시각화 시에는 원본 데이터로 outlier 보폭을 빨간 선으로 겹쳐 그릴 것을 권장
%
% ⦿ 입력:
%   - emg_data: EMG 데이터 (시간 x 보폭 행렬)
%   - threshold: RMSE 기준 임계 배수 (기본값: 3; median + threshold*MAD)
%
% ⦿ 출력:
%   - outlier_indices: 이상치로 판정된 보폭 인덱스(1-based)
%   - correctedEMG: outlier 보폭 열이 NaN으로 마스킹된 EMG 데이터
%==========================================================================

% 기본 임계값 설정
if nargin < 2
    threshold = 3;  % median + threshold * MAD
end

[n_time, n_strides] = size(emg_data);
correctedEMG = emg_data;

% 평균 보폭 파형(시간별 평균) 계산
mean_waveform = mean(emg_data, 2, 'omitnan');

% 각 보폭별 RMSE 계산
rmse_per_stride = nan(1, n_strides);
for stride_idx = 1:n_strides
    stride_data = emg_data(:, stride_idx);
    diff_vec = stride_data - mean_waveform;
    rmse_per_stride(stride_idx) = sqrt(mean(diff_vec.^2, 'omitnan'));
end

% Robust 통계 기반 임계값: median + threshold * MAD
valid_rmse = rmse_per_stride(~isnan(rmse_per_stride));
rmse_median = median(valid_rmse);
rmse_mad = mad(valid_rmse, 1); % 평균 절대편차(robust)

if rmse_mad == 0
    % 분산이 거의 없을 때 표준편차로 폴백
    rmse_std = std(valid_rmse, 'omitnan');
    cutoff = rmse_median + threshold * rmse_std;
else
    cutoff = rmse_median + threshold * rmse_mad;
end

% 이상치 보폭 인덱스 결정
outlier_indices = find(rmse_per_stride > cutoff);

% correctedEMG에서 이상치 보폭 열을 NaN으로 마스킹
if ~isempty(outlier_indices)
    correctedEMG(:, outlier_indices) = NaN;
end

end
