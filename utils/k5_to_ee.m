function [t, ee, rg, ee_stat] = k5_to_ee(k5_table, t_start, t_end)
%K5_TO_EE  K5 호흡가스 데이터를 에너지 소모율(W)로 변환
%
%   [t, ee, rg, ee_stat] = K5_TO_EE(k5_table)
%   [t, ee, rg, ee_stat] = K5_TO_EE(k5_table, t_start, t_end)
%
%   Brockway (1987) 방정식을 사용하여 VO2, VCO2로부터 에너지 소모율을 산출한다.
%     EE = (1/60) * (16.58 * VO2 + 4.51 * VCO2)  [W]
%
%   입력:
%     k5_table — K5 호흡가스 테이블 (필수 열: t, VO2, VCO2) [table]
%     t_start  — 분석 시작 시각 [s] (기본값: k5_table.t(1))
%                음수이면 종료 시각으로부터의 상대 시간으로 해석
%     t_end    — 분석 종료 시각 [s] (기본값: k5_table.t(end))
%                0 이하이면 테이블 마지막 시각 사용
%
%   출력:
%     t       — 전체 시간 벡터 [s]
%     ee      — 전체 에너지 소모율 벡터 [W]
%     rg      — t_start~t_end 구간의 논리 인덱스 [logical]
%     ee_stat — 구간 내 통계 [mean(W), std(W), SEM(W)]
%               구간이 비어 있으면 [NaN, NaN]
%
%   알고리즘:
%     Brockway (1987) 열량계 방정식을 breath-by-breath 데이터에 적용.
%     구간 평균은 사다리꼴 적분(trapezoidal) 기반 시간 가중 평균으로 계산.
%
%   참고: fitKoller21

if nargin < 2, t_start = k5_table.t(1); end
if nargin < 3, t_end = k5_table.t(end); end

if t_start < 0
    rg1 = k5_table.t >= (k5_table.t(end) + t_start);
else
    rg1 = k5_table.t >= t_start;
end
if t_end <= 0
    rg2 = k5_table.t <= k5_table.t(end);
else
    rg2 = k5_table.t <= t_end;
end
rg = and(rg1, rg2);

% equation from Brockway 1987
t = k5_table.t;
ee = 1/60 * (16.58 * k5_table.VO2 + 4.51 * k5_table.VCO2);      % in W

t_rg = t(rg);
ee_rg = ee(rg);
if isempty(t_rg) % failed trial
    ee_stat = [nan, nan];
else
    ee_mean = sum(diff(t_rg) .* ee_rg(1:end-1)) / (t_rg(end) - t_rg(1));
    ee_std = std(ee(rg));
    ee_stat = [ee_mean, ee_std, ee_std/sqrt(sum(rg))];
end
end
