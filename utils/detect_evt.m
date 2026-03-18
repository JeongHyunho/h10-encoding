function [hs_rv, to_rv] = detect_evt(fz)
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
