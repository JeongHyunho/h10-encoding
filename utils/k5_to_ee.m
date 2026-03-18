function [t, ee, rg, ee_stat] = k5_to_ee(k5_table, t_start, t_end)
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
