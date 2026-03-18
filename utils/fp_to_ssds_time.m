function [t_ss, ss, t_ds, ds, ss_stat, ds_stat] = fp_to_ssds_time(fp_T, init, dur)
%FP_TO_SSDS_TIME  지면반력에서 단각지지(SS)/양각지지(DS) 시간 산출
%
%   [t_ss, ss, t_ds, ds, ss_stat, ds_stat] = FP_TO_SSDS_TIME(fp_T, init, dur)
%
%   양발 지면반력으로부터 보행 이벤트를 검출하고, 각 보행 주기 내
%   단각지지(single support) 및 양각지지(double support) 구간 시간을 계산한다.
%
%   입력:
%     fp_T — 지면반력 테이블 (필수 열: t, LFy, RFy) [table]
%     init — 분석 시작 시각 [s] (음수이면 종료 시각으로 해석)
%     dur  — 분석 구간 길이 [s] (음수이면 init로부터 역방향)
%
%   출력:
%     t_ss    — 단각지지 구간 중앙 시각 벡터 [s]
%     ss      — 단각지지 시간 벡터 [s]
%     t_ds    — 양각지지 구간 중앙 시각 벡터 [s]
%     ds      — 양각지지 시간 벡터 [s]
%     ss_stat — 단각지지 통계 [mean(s), std(s)]
%     ds_stat — 양각지지 통계 [mean(s), std(s)]
%
%   알고리즘:
%     detect_evt로 좌/우 heel-strike, toe-off를 검출한 뒤,
%     연속된 보행 주기 내에서 SS = toe-off ~ 반대쪽 heel-strike,
%     DS = heel-strike ~ 동측 toe-off 구간으로 분할한다.
%     0.5th/99.5th 백분위수 기준으로 이상치를 제거한다.
%
%   참고: detect_evt, fp_to_freq

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

[hs_left, to_left] = detect_evt(fz_left);
[hs_right, to_right] = detect_evt(fz_right);

t_hs = t_rg(sort([hs_left, hs_right]));
t_freq = 60 ./ diff(t_hs);
t = t_hs(2:end);

% ss: to - hs
% ds: hs - to

t_ss = [];
ss = [];
t_ds = [];
ds = [];
for i = 1:numel(hs_left)-1
    to_in = hs_left(i) < to_right & to_right < hs_left(i+1);
    hs_in = hs_left(i) < hs_right & hs_right < hs_left(i+1);
    if sum(hs_in) ~= 1 && sum(to_in) ~= 1, continue, end

    t_lhs = t_rg(hs_left(i));
    t_rto = t_rg(to_right(to_in));
    t_rhs = t_rg(hs_right(hs_in));
    t_lto = t_rg(to_left(i));
    t_lhsn = t_rg(hs_left(i+1));
    
    t_ss = [t_ss; (t_rto + t_rhs) / 2; (t_lto + t_lhsn) / 2];
    ss = [ss; t_rhs - t_rto; t_lhsn - t_lto];

    t_ds = [t_ds; (t_lhs+t_rto)/2; (t_rhs+t_lto)/2];
    ds = [ds; t_rto-t_lhs; t_lto-t_rhs];
end
for i = 1:numel(hs_right)-1
    to_in = hs_right(i) < to_left & to_left < hs_right(i+1);
    hs_in = hs_right(i) < hs_left & hs_left < hs_right(i+1);
    if sum(hs_in) ~= 1 && sum(to_in) ~= 1, continue, end

    t_rhs = t_rg(hs_right(i));
    t_lto = t_rg(to_left(to_in));
    t_lhs = t_rg(hs_left(hs_in));
    t_rto = t_rg(to_right(i));
    t_rhsn = t_rg(hs_right(i+1));

    t_ss = [t_ss; (t_lto + t_lhs) / 2; (t_rto + t_rhsn) / 2];
    ss = [ss; t_lhs - t_lto; t_rhsn - t_rto];

    t_ds = [t_ds; (t_rhs+t_lto)/2; (t_lhs+t_rto)/2];
    ds = [ds; t_lto-t_rhs; t_rto-t_lhs];
end

% filter outlier
ss_lb = prctile(ss , 0.5);
ss_ub = prctile(ss , 99.5);
idx = (ss >= ss_lb & ss <= ss_ub);
t_ss = t_ss(idx);
ss = ss(idx);

[t_ss, I] = sort(t_ss);
ss = ss(I);

ds_lb = prctile(ds , 0.5);
ds_ub = prctile(ds , 99.5);
idx = (ds >= ds_lb & ds <= ds_ub);
t_ds = t_ds(idx);
ds = ds(idx);

[t_ds, I] = sort(t_ds);
ds = ds(I);

ss_stat = [mean(ss), std(ss)];
ds_stat = [mean(ds), std(ds)];
end
