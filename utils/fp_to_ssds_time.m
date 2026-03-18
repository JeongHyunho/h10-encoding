function [t_ss, ss, t_ds, ds, ss_stat, ds_stat] = fp_to_ssds_time(fp_T, init, dur)
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
