function [y_fit, r2, tau_fit] = fit_ee_step(t, x, u_init, u_final, t0)
tau0 = 41;
tau_fit = fminunc(@(tau) ee_sim_cost(tau, x, t, u_init, u_final, t0), tau0);

L = length(t);
uE = u_final * ones(L,1);
uE(t < t0) = u_init;
sysE = ss(-1/tau_fit, 1/tau_fit, 1, 0);
y_fit = lsim(sysE, uE, t-t(1), 0);

% r2 계산
idx = (t >= t0);
RSS = sum((x(idx) - y_fit(idx)).^2);
SST = sum((x(idx) - mean(y_fit(idx))).^2);
r2 = 1 - RSS / SST;
end

function cost = ee_sim_cost(tau, xd, td, u_init, u_final, t0)
L = length(td);
uE = u_final * ones(L,1);
uE(td < t0) = u_init;
sysE = ss(-1/tau, 1/tau, 1, 0);
y_sim = lsim(sysE, uE, td-td(1), 0);

idx = (td >= t0);   % only fit after step perturbation
diff_sq = (xd(idx) - y_sim(idx)) .^ 2;
intnd = diff_sq(2:end) .* diff(td(idx));
cost = sum(intnd(~isnan(intnd)));
end