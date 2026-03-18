function data = read_fp_table(fp_file, freq, cm_left, cm_right, cutoff_hz)
% TDMS 힘판 데이터를 표준 형태로 변환
% - 입력 인자
%   fp_file   : TDMS 파일 경로
%   freq      : 출력 시간 벡터 샘플링 주파수(Hz)
%   cm_left   : 좌측 보정 행렬(6x6)
%   cm_right  : 우측 보정 행렬(6x6)
%   cutoff_hz : (선택) 저역통과 필터 차단 주파수(Hz). 제공되지 않으면 필터링 생략
tdms_rs = tdmsread(fp_file);
data = tdms_rs{1};
data.Properties.VariableNames = ["LFx", "LFy", "LFz", "LMx", "LMy", "LMz", ...
    "RFx", "RFy", "RFz", "RMx", "RMy", "RMz"];

sig_left = cm_left * [data.LFx, data.LFy, data.LFz, data.LMx, data.LMy, data.LMz]';
sig_right = cm_right * [data.RFx, data.RFy, data.RFz, data.RMx, data.RMy, data.RMz]';

% 선택적 필터링: cutoff_hz가 주어지면 6차 저역통과 필터 적용, 아니면 생략
if nargin >= 5 && ~isempty(cutoff_hz) && isfinite(cutoff_hz) && cutoff_hz > 0
    [b, a] = butter(6, cutoff_hz/(freq/2));
    sig_left = filtfilt(b, a, sig_left');
    sig_right = filtfilt(b, a, sig_right');
else
    sig_left = sig_left';
    sig_right = sig_right';
end

data.LFx = - sig_left(:, 2);
data.LFy = sig_left(:, 3);
data.LFz = sig_left(:, 1);
data.LMx = - sig_left(:, 5);
data.LMy = sig_left(:, 6);
data.LMz = sig_left(:, 4);
data.RFx = - sig_right(:, 2);
data.RFy = sig_right(:, 3);
data.RFz = sig_right(:, 1);
data.RMx = - sig_right(:, 5);
data.RMy = sig_right(:, 6);
data.RMz = sig_right(:, 4);

data.t = (0:1/freq:(height(data)-1)/ freq)';
end


