function [y0, H, y_est, MSE, Sig, subj_intercept, subj_list] = fitKoller21_agg(xseries, yseries, tseries, msmt, trials, subjects, tau)
% Aggregated ICM fit with shared slopes and subject-specific intercepts.

xseries = xseries(:);
yseries = yseries(:);
tseries = tseries(:);
msmt = msmt(:);
trials = trials(:);
subjects = subjects(:);

trial_grp = findgroups(trials);
n_trial = max(trial_grp);

subj_grp = findgroups(subjects);
n_sub = max(subj_grp);
subj_list = splitapply(@(x) x(1), subjects, subj_grp);

subj_per_trial = splitapply(@(x) x(1), subj_grp, trial_grp);
subj_count = splitapply(@(x) numel(unique(x)), subj_grp, trial_grp);
if any(subj_count > 1)
    error('Each trial must map to a single subject.');
end
subj_col = n_trial + (1:n_sub);
n_sub_cols = n_sub;
coef_offset = n_trial + n_sub_cols;

n = length(msmt);
A = zeros(n, n_trial + n_sub_cols + 2);

grp_idx = findgroups(trial_grp);
x_cell = splitapply(@(x) {x}, xseries, grp_idx);
y_cell = splitapply(@(x) {x}, yseries, grp_idx);
t_cell = splitapply(@(x) {x}, tseries, grp_idx);

last_row = 0;
for i = 1:n_trial
    m_i = numel(x_cell{i});
    subj_idx = subj_per_trial(i);
    subj_col_idx = subj_col(subj_idx);

    for j = 1:m_i
        row = last_row + j;
        if j == 1
            A(row, i) = 1;
            continue
        end
        h = t_cell{i}(j) - t_cell{i}(j-1);
        A(row, i) = (1 - h / tau) * A(row - 1, i);

        A(row, subj_col_idx) = (1 - h / tau) * A(row - 1, subj_col_idx) + h / tau;
        A(row, coef_offset + 1) = (1 - h / tau) * A(row - 1, coef_offset + 1) + h / tau * x_cell{i}(j);
        A(row, coef_offset + 2) = (1 - h / tau) * A(row - 1, coef_offset + 2) + h / tau * y_cell{i}(j);
    end
    last_row = last_row + m_i;
end

coe = (A' * A) \ (A' * msmt);
y_est = A * coe;

y0 = coe(1:n_trial);
subj_intercept = coe(n_trial + 1:n_trial + n_sub);

lx = coe(coef_offset + 1);
ly = coe(coef_offset + 2);
H = [lx, ly];

MSE = sum((y_est - msmt).^2) / n;
sel_mat = [zeros(2, coef_offset), eye(2)];
Sig = sel_mat * ((A' * A) \ eye(size(A, 2))) * sel_mat';
end
