function [CI_lower, CI_upper, y_pred_grid] = fitKoller21_CI_scaled(xseries, yseries, tseries, msmt, trials, tau, x_grid, y_grid, scale_factor)
% 기존 CI에 스케일 팩터를 곱해서 확대하는 함수
% 실제 데이터의 불확실성을 반영하기 위해 CI를 확대합니다.
%
% 입력:
%   xseries, yseries, tseries, msmt, trials, tau: fitKoller21과 동일
%   x_grid, y_grid: 예측할 파라미터 그리드
%   scale_factor: CI 확대 팩터 (기본값: 10)
%
% 출력:
%   CI_lower, CI_upper: 각 그리드 포인트에서의 95% CI 하한/상한
%   y_pred_grid: 예측값 그리드

if nargin < 9
    scale_factor = 10;  % 기본값: 10배 확대
end

fprintf('스케일된 CI 계산 시작 (확대 팩터: %.1f)\n', scale_factor);

% 1. 기본 Koller 모델 피팅
[y0, H, y_est, MSE, Sig] = fitKoller21(xseries, yseries, tseries, msmt, trials, tau);

% 2. 그리드에서 예측값 및 CI 계산
[n_grid_x, n_grid_y] = size(x_grid);
CI_lower = zeros(n_grid_x, n_grid_y);
CI_upper = zeros(n_grid_x, n_grid_y);
y_pred_grid = zeros(n_grid_x, n_grid_y);

% 자유도 계산
m = length(unique(trials));
df = m - 3;  % trial 수 - 계수 수
t_critical = tinv(0.975, df);

for i = 1:n_grid_x
    for j = 1:n_grid_y
        x_curr = x_grid(i, j);
        y_curr = y_grid(i, j);
        
        % 예측값 계산
        y_pred = H(1) * x_curr + H(2) * y_curr + H(3);
        y_pred_grid(i, j) = y_pred;
        
        % 예측값의 표준오차 계산
        grad = [x_curr, y_curr, 1];
        var_pred = grad * Sig * grad';
        SE_pred = sqrt(var_pred);
        
        % 스케일된 Confidence interval 계산
        CI_lower(i, j) = y_pred - t_critical * SE_pred * scale_factor;
        CI_upper(i, j) = y_pred + t_critical * SE_pred * scale_factor;
    end
end

fprintf('스케일된 CI 계산 완료\n');
fprintf('원본 MSE: %.2f\n', MSE);
fprintf('자유도: %d\n', df);

end
