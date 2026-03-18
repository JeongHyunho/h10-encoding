function [y0, H, y_est] = fitKoller22(xseries, yseries, tseries, msmt, trials, tau)
% 2D & 2nd order fit

n = length(unique(trials));
m = length(msmt);
A = zeros(m, n+6);

grp_idx = findgroups(trials);
x_cell = splitapply(@(x) {x}, xseries, grp_idx);
y_cell = splitapply(@(x) {x}, yseries, grp_idx);
t_cell = splitapply(@(x) {x}, tseries, grp_idx);

last_row = 0;
for i = 1:n
    m_i = sum(trials == i);

    for j = 1:m_i
        x = x_cell{i}(j);
        y = y_cell{i}(j);

        if j == 1
            A(last_row+j, i) = 1;       % i==1: [1, 0, ..., 0], i==2: [0, 1, ..., 0]
            continue
        end

        h = t_cell{i}(j) - t_cell{i}(j-1);
        A(last_row+j, i) = (1-h/tau)*A(last_row+j-1,i);
        A(last_row+j, end-5) = (1-h/tau)*A(last_row+j-1,end-5)+h/tau*x^2;
        A(last_row+j, end-4) = (1-h/tau)*A(last_row+j-1,end-4)+h/tau*y^2;
        A(last_row+j, end-3) = (1-h/tau)*A(last_row+j-1,end-3)+h/tau*x*y;
        A(last_row+j, end-2) = (1-h/tau)*A(last_row+j-1,end-2)+h/tau*x;
        A(last_row+j, end-1) = (1-h/tau)*A(last_row+j-1,end-1)+h/tau*y;
        A(last_row+j, end) = (1-h/tau)*A(last_row+j-1,end)+h/tau*1;

    end

    last_row = last_row + m_i;
end

coe = inv(A' * A) * A' * msmt;
y_est = A*coe;

y0 = coe(1:n);
lxx = coe(end-5);
lyy = coe(end-4);
lxy = coe(end-3);
lx = coe(end-2);
ly = coe(end-1);
l0 = coe(end);
H = [lxx, 1/2*lxy, 1/2*lx; 1/2*lxy, lyy, 1/2*ly; 1/2*lx, 1/2*ly, l0];

end
