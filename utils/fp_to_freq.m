function [t, t_freq, freq_stat] = fp_to_freq(fp_T, init, dur)
%FP_TO_FREQ  지면반력에서 보행 빈도(cadence) 계산
%
%   [t, t_freq, freq_stat] = FP_TO_FREQ(fp_T, init, dur)
%
%   양발 지면반력으로부터 heel-strike를 검출하고,
%   연속 heel-strike 간격의 역수로 순간 보행 빈도를 산출한다.
%
%   입력:
%     fp_T — 지면반력 테이블 (필수 열: t, LFy, RFy) [table]
%     init — 분석 시작 시각 [s] (음수이면 종료 시각으로 해석)
%     dur  — 분석 구간 길이 [s] (음수이면 init로부터 역방향)
%
%   출력:
%     t         — 보행 빈도 시각 벡터 (각 구간의 후반 HS 시점) [s]
%     t_freq    — 순간 보행 빈도 벡터 [steps/min, BPM]
%     freq_stat — 보행 빈도 통계 [mean(BPM), std(BPM)]
%
%   알고리즘:
%     detect_evt로 좌/우 heel-strike를 검출, 시간순 병합 후
%     freq = 60 / diff(t_hs) 로 순간 빈도를 산출한다.
%     0.5th/99.5th 백분위수 기준으로 이상치를 제거한다.
%
%   참고: detect_evt, fp_to_ssds_time

if init < 0
    init = fp_T.t(end);
end

if dur < 0
    rg = logical((fp_T.t < init) .* (fp_T.t > (init + dur)));
else
    rg = logical((fp_T.t > init) .* (fp_T.t < (init + dur)));
end

fz_left = fp_T.LFy(rg);
fz_right = fp_T.RFy(rg);
t_rg = fp_T.t(rg);

[hs_left, ~] = detect_evt(fz_left);
[hs_right, ~] = detect_evt(fz_right);

t_hs = t_rg(sort([hs_left, hs_right]));
t_freq = 60 ./ diff(t_hs);
t = t_hs(2:end);

% filter outlier
lb = prctile(t_freq , 0.5);
ub = prctile(t_freq , 99.5);
idx = (t_freq >= lb & t_freq <= ub);
t = t(idx);
t_freq = t_freq(idx);

freq_stat = [mean(t_freq), std(t_freq)];
end
