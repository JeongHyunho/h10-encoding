function [t, t_pow, pow_stat] = fp_to_power(fp_T, for_vel, fp_freq, init, dur)
if init < 0
    init = fp_T.t(end);
end

if dur < 0
    rg = logical((fp_T.t < init) .* (fp_T.t > (init + dur)));
else
    rg = logical((fp_T.t > init) .* (fp_T.t < (init + dur)));
end

rg_T = fp_T(rg, :);
[hs_left, to_left] = detect_evt(rg_T.LFy);
[hs_right, to_right] = detect_evt(rg_T.RFy);

if length(for_vel) ~= 1
    for_vel = for_vel(rg);
end

[~, ~, ~, ~, ~, pow_left] = integrate_fp(rg_T, hs_left, to_left, 'left', for_vel, fp_freq);
[~, ~, ~, ~, ~, pow_right] = integrate_fp(rg_T, hs_right, to_right, 'right', for_vel, fp_freq);

% Donelan, “Simultaneous positive and negative external mechanical work in human walking”. JBM, 2002
t = [rg_T.t(hs_left(2:end)); rg_T.t(hs_right(2:end))];
t_pow = [pow_left; pow_right];
pow_stat = [mean(t_pow)', std(t_pow)'];

[t, I] = sort(t);
t_pow = t_pow(I, :);
end

function [frc_ips, frc_cont, pow_ips, pow_cont, vel, pow] = integrate_fp(fp_T, hs, to, RL, for_vel, fp_freq)

num_st = length(hs);
dt = 1 / fp_freq;
m = mean(fp_T.LFy + fp_T.RFy) / 9.81;

frc_ips = cell(num_st-1, 1);
frc_cont = cell(num_st-1, 1);
vel = cell(num_st-1, 1);
t_lapse = cell(num_st-1, 1);

if strcmpi(RL, 'Left')
    ips_plate = [fp_T.LFx, fp_T.LFy fp_T.LFz];
    cont_plate = [fp_T.RFx, fp_T.RFy fp_T.RFz];
elseif strcmpi(RL, 'Right')
    ips_plate = [fp_T.RFx, fp_T.RFy fp_T.RFz];
    cont_plate = [fp_T.LFx, fp_T.LFy fp_T.LFz];
else
    assert(true, 'unexpected argument for RL: %s', RL)
end

% integrate once
for i = 1:num_st-1
    f_ips = ips_plate(hs(i):hs(i+1), :);
    f_cont = cont_plate(hs(i):hs(i+1), :);

    if length(for_vel) == 1
        fv = for_vel;
    else
        fv = for_vel(hs(i));
    end

    acc =(f_ips+f_cont) / m - [0, 9.81, 0];
    dv = cumsum(acc - mean(acc, 1), 1) * dt;
    v = [fv, 0, 0] + dv - mean(dv, 1);

    frc_ips{i} = f_ips;
    frc_cont{i} = f_cont;
    vel{i} = v;
    t_lapse{i} = (hs(i+1) - hs(i)) * dt;
end

% power and com work
pow_ips = cellfun(@(x, y) sum(x.*y, 2), frc_ips, vel, 'UniformOutput', false);
pow_cont = cellfun(@(x, y) sum(x.*y, 2), frc_cont, vel, 'UniformOutput', false);
pow = [cellfun(@(x, y, t) sum(x(x>=0)) * dt/t + sum(y(y>=0)) * dt/t, pow_ips, pow_cont, t_lapse), ...
    cellfun(@(x, y, t) sum(-x(x<0)) * dt/t + sum(-y(y<0)) * dt/t, pow_ips, pow_cont, t_lapse)];
end
