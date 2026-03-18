function [t, t_freq, freq_stat] = fp_to_freq(fp_T, init, dur)
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
