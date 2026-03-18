function[hs_left, to_left, hs_right, to_right] = evt_from_fp(fp_T, dur)
last_t = fp_T.t(end);
rg = logical((fp_T.t < last_t - 10) .* (fp_T.t > (last_t -10 - dur)));
rg_T = fp_T(rg, :);
[hs_left, to_left] = detect_evt(rg_T.LFy);
[hs_right, to_right] = detect_evt(rg_T.RFy);
end
