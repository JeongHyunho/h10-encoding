function [A, ld, V_inv, y_est] = fitKoller(param, tseries, msmt, tau, order)
m = length(msmt);
A = zeros(m-1, order+2);

for i = 1:m
    p = param(i);
    for j = 1:order+2
        if i == 1
            if j == 1
                A(i, j) = 1;
            end
            continue
        end

        h = tseries(i) - tseries(i-1);
        if j == 1
            A(i, j) = (1-h/tau)*A(i-1,j);
        else
            A(i,j) = (1-h/tau)*A(i-1,j)+h/tau*p^(j-2);
        end
    end
end

y_msmt = msmt(1:end);
% coe = inv(A' * A) * A' * y_msmt;
coe = A \ y_msmt;
y_est = A*coe;
ld = flipud(coe(2:end));

n = m - 1;
d = order + 2;
ssq = 1/(n - d) * sum((y_msmt - y_est).^2);
sel_mat = [zeros(order+1, 1), eye(order+1)];
cov = ssq * sel_mat * inv(A' * A) * sel_mat';
nu1 = d - 1;
nu2 = n - d;
F = finv(0.95, nu1, nu2);
V_inv = F * d * cov;

end
