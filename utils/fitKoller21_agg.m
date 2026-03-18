function [y0, H, y_est, MSE, Sig, subj_intercept, subj_list] = fitKoller21_agg(xseries, yseries, tseries, msmt, trials, subjects, tau)
%FITKOLLER21_AGG  다중 참여자 집단(aggregated) ICM 모델 적합
%
%   [y0, H, y_est, MSE, Sig, subj_intercept, subj_list] = ...
%       FITKOLLER21_AGG(xseries, yseries, tseries, msmt, trials, subjects, tau)
%
%   공유 기울기(H) + 참여자별 절편(subj_intercept)을 추정한다.
%   각 trial은 단일 참여자에 매핑되어야 한다.
%
%   입력:
%     xseries  — 첫 번째 입력 변수 (예: 굴곡 토크 크기) [Nx1, Nm/kg]
%     yseries  — 두 번째 입력 변수 (예: 신전 토크 크기) [Nx1, Nm/kg]
%     tseries  — 시간 벡터 [Nx1, s]
%     msmt     — 관측된 대사 응답 벡터 [Nx1, W]
%     trials   — 시행(trial) 번호 벡터 [Nx1, integer]
%     subjects — 참여자 식별자 벡터 [Nx1]
%     tau      — 대사 응답 시상수 [scalar, s]
%
%   출력:
%     y0             — 각 trial의 초기값(절편) [n_trial x 1]
%     H              — 공유 ICM 계수 [lx, ly] — 기울기 2개
%     y_est          — 모델 추정값 [Nx1]
%     MSE            — 평균 제곱 오차 [scalar]
%     Sig            — ICM 계수(H)의 공분산 행렬 [2x2]
%     subj_intercept — 참여자별 절편 [n_sub x 1]
%     subj_list      — 참여자 식별자 목록 [n_sub x 1]
%
%   알고리즘:
%     fitKoller21과 동일한 지수 wash-in 구조를 사용하되, 참여자별 절편 열을
%     추가하여 개인 간 기저 대사 차이를 흡수한다. 기울기(H)는 모든 참여자가 공유.
%
%   참고: fitKoller21, fitKoller21_CI_bootstrap

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
