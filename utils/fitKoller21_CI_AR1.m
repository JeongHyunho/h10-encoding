function [CI_lower, CI_upper, y_pred_grid] = fitKoller21_CI_AR1(xseries, yseries, tseries, msmt, trials, tau, x_grid, y_grid)
% fitKoller21.m의 결과를 이용해서 AR(1) 모델을 고려한 confidence interval을 계산
% 시간적 상관관계를 고려하여 더 현실적인 CI를 제공합니다.
%
% 입력:
%   xseries, yseries, tseries, msmt, trials, tau: fitKoller21과 동일
%   x_grid, y_grid: 예측할 파라미터 그리드
%
% 출력:
%   CI_lower, CI_upper: 각 그리드 포인트에서의 95% CI 하한/상한
%   y_pred_grid: 예측값 그리드

% 1. 기본 Koller 모델 피팅
[y0, H, y_est, MSE, Sig] = fitKoller21(xseries, yseries, tseries, msmt, trials, tau);

% 2. 잔차 계산 및 AR(1) 모델 피팅
residuals = msmt - y_est;

% Trial별로 AR(1) 계수 추정
unique_trials = unique(trials);
rho_estimates = [];
n_obs_per_trial = [];

for i = 1:length(unique_trials)
    trial_idx = trials == unique_trials(i);
    trial_residuals = residuals(trial_idx);
    
    if length(trial_residuals) > 10  % 충분한 데이터가 있는 경우만
        % AR(1) 모델 피팅: r_t = ρ*r_{t-1} + ε_t
        if length(trial_residuals) > 1
            % 자기상관계수 추정
            rho_i = corr(trial_residuals(1:end-1), trial_residuals(2:end));
            rho_estimates = [rho_estimates; rho_i];
            n_obs_per_trial = [n_obs_per_trial; length(trial_residuals)];
        end
    end
end

% 전체 평균 AR(1) 계수 계산 (가중 평균)
if ~isempty(rho_estimates)
    rho_avg = sum(rho_estimates .* n_obs_per_trial) / sum(n_obs_per_trial);
    rho_avg = max(min(rho_avg, 0.99), -0.99);  % -1 < ρ < 1 제한
else
    rho_avg = 0;  % AR(1) 효과가 없는 경우
end

fprintf('AR(1) 계수 추정: ρ = %.4f\n', rho_avg);

% 3. 수정된 공분산 행렬 계산
n = length(msmt);
m = length(unique_trials);

% AR(1) 상관관계 행렬 생성
V = zeros(n, n);
for i = 1:n
    for j = 1:n
        if trials(i) == trials(j)  % 같은 trial 내에서만 상관관계
            V(i, j) = rho_avg^abs(i - j);
        else
            V(i, j) = 0;  % 다른 trial 간에는 독립
        end
    end
end

% 수정된 MSE 계산 (AR(1) 고려)
% AR(1) 모델에서 실제 잔차 분산은 σ²_ε = σ²_r / (1 - ρ²)
sigma2_epsilon = MSE / (1 - rho_avg^2);

% 수정된 공분산 행렬 (fitKoller21의 구조에 맞게)
% A 행렬을 다시 구성해야 함
A = zeros(n, m+3);
grp_idx = findgroups(trials);
x_cell = splitapply(@(x) {x}, xseries, grp_idx);
y_cell = splitapply(@(x) {x}, yseries, grp_idx);
t_cell = splitapply(@(x) {x}, tseries, grp_idx);

last_row = 0;
for i = 1:m
    m_i = sum(trials == i);

    for j = 1:m_i
        x = x_cell{i}(j);
        y = y_cell{i}(j);

        if j == 1
            A(last_row+j, i) = 1;
            continue
        end

        h = t_cell{i}(j) - t_cell{i}(j-1);
        A(last_row+j, i) = (1-h/tau)*A(last_row+j-1,i);
        A(last_row+j, end-2) = (1-h/tau)*A(last_row+j-1,end-2)+h/tau*x;
        A(last_row+j, end-1) = (1-h/tau)*A(last_row+j-1,end-1)+h/tau*y;
        A(last_row+j, end) = (1-h/tau)*A(last_row+j-1,end)+h/tau*1;
    end

    last_row = last_row + m_i;
end

% AR(1) 고려한 수정된 공분산 행렬
Sig_AR1_full = inv(A' * inv(V) * A) * sigma2_epsilon;
sel_mat = [repmat(zeros(3, 1), 1, m), eye(3)];
Sig_AR1 = sel_mat * Sig_AR1_full * sel_mat';

% 4. 그리드에서 예측값 및 CI 계산
[n_grid_x, n_grid_y] = size(x_grid);
CI_lower = zeros(n_grid_x, n_grid_y);
CI_upper = zeros(n_grid_x, n_grid_y);
y_pred_grid = zeros(n_grid_x, n_grid_y);

% 자유도 계산 (AR(1) 모델 고려)
df = m - 3;  % trial 수 - 계수 수
t_critical = tinv(0.975, df);

for i = 1:n_grid_x
    for j = 1:n_grid_y
        x_curr = x_grid(i, j);
        y_curr = y_grid(i, j);
        
        % 예측값 계산
        % H = [lx, ly, l0] - 1차 모델이므로 cross effect 없음
        y_pred = H(1) * x_curr + H(2) * y_curr + H(3);
        y_pred_grid(i, j) = y_pred;
        
        % 예측값의 표준오차 계산 (AR(1) 고려)
        grad = [x_curr, y_curr, 1];
        var_pred = grad * Sig_AR1 * grad';
        SE_pred = sqrt(var_pred);
        
        % Confidence interval 계산
        CI_lower(i, j) = y_pred - t_critical * SE_pred;
        CI_upper(i, j) = y_pred + t_critical * SE_pred;
    end
end

fprintf('AR(1) 모델 기반 CI 계산 완료\n');
fprintf('수정된 MSE: %.2f (원본: %.2f)\n', sigma2_epsilon, MSE);
fprintf('자유도: %d\n', df);

end
