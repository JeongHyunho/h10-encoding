function data = read_fp_table(fp_file, freq, cm_left, cm_right, cutoff_hz)
%READ_FP_TABLE  지면반력 TDMS 파일을 표준 테이블로 변환
%
%   data = READ_FP_TABLE(fp_file, freq, cm_left, cm_right)
%   data = READ_FP_TABLE(fp_file, freq, cm_left, cm_right, cutoff_hz)
%
%   TDMS 원시 데이터에 보정 행렬을 적용하고, 좌표계를 변환하여
%   표준 지면반력 테이블을 생성한다.
%
%   입력:
%     fp_file   — TDMS 파일 경로 [string 또는 char]
%     freq      — 샘플링 주파수 [scalar, Hz]
%     cm_left   — 좌측 힘판 보정 행렬 [6x6]
%     cm_right  — 우측 힘판 보정 행렬 [6x6]
%     cutoff_hz — 저역통과 필터 차단 주파수 [scalar, Hz] (선택)
%                 미지정 또는 빈 값이면 필터링 생략
%
%   출력:
%     data — 변환된 지면반력 테이블 [table]
%            열: LFx, LFy, LFz, LMx, LMy, LMz,
%                RFx, RFy, RFz, RMx, RMy, RMz, t
%            좌표계: Fx=전후, Fy=수직, Fz=좌우
%
%   알고리즘:
%     1) TDMS 파일 읽기 → 12채널 원시 데이터
%     2) 보정 행렬 곱 적용 (좌/우 각각 6x6)
%     3) 선택적 6차 Butterworth 저역통과 필터 (filtfilt)
%     4) 좌표계 재배열 (TDMS 내부 축 → 표준 축)
%     5) 시간 벡터 생성 (0 ~ (N-1)/freq)
%
%   참고: detect_evt, fp_to_freq, fp_to_power, fp_to_ssds_time

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


