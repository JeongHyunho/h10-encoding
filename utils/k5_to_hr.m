function [t, hr, hr_stat] = k5_to_hr(k5_table, dur, from_end)
if nargin < 2, dur = k5_table.t(end); end
if nargin < 3, from_end = false; end

t = k5_table.t;
hr = k5_table.HR;       % in bpm

% remove 0 hr
[t, I] = unique(t);
hr = hr(I);
idx_zero = (hr == 0);
if isempty(~idx_zero)
    hr(idx_zero) = interp1(t(~idx_zero), hr(~idx_zero), t(idx_zero));
end

if from_end
    rg = t > (t(end) - dur);
else
    rg = t < (t(1) + dur);
end

t_rg = t(rg);
hr_rg = hr(rg);
hr_mean = sum(diff(t_rg) .* hr_rg(1:end-1)) / (t_rg(end) - t_rg(1));
hr_std = std(hr(rg));
hr_stat = [hr_mean, hr_std];
end
