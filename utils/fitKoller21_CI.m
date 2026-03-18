function [CI_lower, CI_upper, y_pred_grid] = fitKoller21_CI(xseries, yseries, tseries, msmt, trials, tau, x_grid, y_grid)
% fitKoller21.m의 결과를 이용해서 confidence interval을 계산
% 
% Inputs:
%   xseries, yseries, tseries, msmt, trials, tau: fitKoller21과 동일
%   x_grid, y_grid: 예측할 파라미터 그리드
%
% Outputs:
%   CI_lower, CI_upper: 각 그리드 포인트에서의 95% confidence interval
%   y_pred_grid: 예측값 그리드

% fitKoller21 모델 피팅
[y0, H, y_est, MSE, Sig] = fitKoller21(xseries, yseries, tseries, msmt, trials, tau);

% 데이터 포인트 수와 자유도
n = length(unique(trials));
m = length(msmt);
df = m - (n + 3);  % 자유도 = 데이터 수 - 계수 수

% 95% confidence interval을 위한 t-분포 임계값
t_critical = tinv(0.975, df);

% 잔차 표준오차
sigma_hat = sqrt(MSE);

% 그리드 크기
[ny, nx] = size(x_grid);
CI_lower = zeros(ny, nx);
CI_upper = zeros(ny, nx);
y_pred_grid = zeros(ny, nx);

% 각 그리드 포인트에서 confidence interval 계산
for i = 1:ny
    for j = 1:nx
        % 현재 그리드 포인트
        x_curr = x_grid(i, j);
        y_curr = y_grid(i, j);
        
        % 예측값 계산 (Koller 모델)
        y_pred = H(1) * x_curr + H(2) * y_curr + H(3);
        y_pred_grid(i, j) = y_pred;
        
        % 예측값의 표준오차 계산
        % 새로운 점에서의 gradient
        grad = [x_curr, y_curr, 1];  % [∂y/∂lx, ∂y/∂ly, ∂y/∂l0]
        
        % 예측값의 분산 = grad * Sig * grad'
        var_pred = grad * Sig * grad';
        SE_pred = sqrt(var_pred);
        
        % Confidence interval 계산
        CI_lower(i, j) = y_pred - t_critical * SE_pred;
        CI_upper(i, j) = y_pred + t_critical * SE_pred;
    end
end

end
