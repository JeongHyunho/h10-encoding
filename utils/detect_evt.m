function [hs_rv, to_rv] = detect_evt(fz)
%DETECT_EVT  수직 지면반력(GRF)에서 보행 이벤트(heel-strike, toe-off) 검출
%
%   [hs_rv, to_rv] = DETECT_EVT(fz)
%
%   2단계 임계값 알고리즘을 사용한다:
%     1) 1차 검출: 150 N 임계값으로 대략적 이벤트 위치 탐색
%     2) 정밀 보정: 전후 150 샘플 내에서 30 N 임계값으로 정확한 교차점 결정
%   heel-strike 이후 가장 가까운 toe-off를 쌍으로 매칭한다.
%
%   입력:
%     fz — 수직 지면반력 벡터 (단일 발) [Nx1, N]
%
%   출력:
%     hs_rv — heel-strike 인덱스 벡터 [Mx1, sample index]
%     to_rv — 대응하는 toe-off 인덱스 벡터 [Mx1, sample index]
%             각 hs_rv(i)에 대해 to_rv(i) > hs_rv(i)
%
%   알고리즘:
%     1차 임계값(fThFirst=150 N)으로 후보 검출 후,
%     정밀 임계값(fThreshold=30 N)으로 교차점을 보정한다.
%     hs-to 쌍이 매칭되지 않는 이벤트는 제거된다.
%
%   참고: fp_to_freq, fp_to_ssds_time, fp_to_power

% detection setting
fThreshold = 30;
minLen = 100;

% event detect (heel-strike, toe-off)
fThFirst = 150;
hs = find((fz(1:end-1) < fThFirst) .* (fz(2:end) > fThFirst))';
to = find((fz(1:end-1) > fThFirst) .* (fz(2:end) < fThFirst))';

hs(hs - 150 <= 0) = [];
for i = 1:length(hs)
    fs = fz(hs(i)-150:hs(i));
    cross = find((fs(1:end-1) < fThreshold) .* (fs(2:end) > fThreshold));
    if isempty(cross)
        hs(i) = nan;
    else
        gap = length(fs) - cross(end);
        hs(i) = hs(i) - gap;
    end
end
hs = hs(~isnan(hs));
to(to + 150 > length(fz)) = [];
for i = 1:length(to)
    fs = fz(to(i):to(i)+150);
    cross = find((fs(1:end-1) > fThreshold) .* (fs(2:end) < fThreshold));
    if isempty(cross)
        to(i) = nan;
    else
        gap = cross(1) - 1;
        to(i) = to(i) + gap;
    end
end
to = to(~isnan(to));

to_rv = nan(size(to));
for i = 1:length(hs)
    idx = find(to  > hs(i), 1);
    if ~isempty(idx)
        to_rv(i) = to(idx);
    end
end
hs_rv = hs(~isnan(to_rv));
to_rv = to_rv(~isnan(to_rv));

end
