function y = emg_normalize(x, norm_factors, muscle)
%==========================================================================
% emg_normalize(x, norm_factors, muscle)
%
% ⦿ 목적
%   - 근육별 스케일 팩터로 EMG 신호를 정규화
%   - 0 나누기 방지 및 NaN 안전 처리
%
% ⦿ 입력
%   - x            : EMG 행렬 (stride x 301 또는 301 x stride)
%   - norm_factors : struct, 근육별 스케일 값
%   - muscle       : 현재 근육 라벨 (char/string)
%
% ⦿ 출력
%   - y            : 정규화된 EMG 행렬 (입력과 동일한 형상 유지)
%==========================================================================

if nargin < 3
    error('emg_normalize: invalid inputs');
end

if isfield(norm_factors, muscle)
    scale = norm_factors.(muscle);
else
    scale = NaN; % 스케일 정보 없음
end

% 스케일이 유효하지 않으면 NaN으로 채워 정상적으로 '정규화 불가'를 표시
if ~(isfinite(scale) && scale > 0)
    y = NaN(size(x));
    return
end

% 입력 형상 유지하면서 정규화
y = x ./ scale;

end


