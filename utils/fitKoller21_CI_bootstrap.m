function [CI_lower, CI_upper, y_pred_grid] = fitKoller21_CI_bootstrap(xseries, yseries, tseries, msmt, trials, tau, x_grid, y_grid, n_bootstrap)
% Bootstrap 방법을 사용해서 confidence interval을 계산
% 시간적 상관관계와 모델 불확실성을 모두 고려합니다.
%
% 입력:
%   xseries, yseries, tseries, msmt, trials, tau: fitKoller21과 동일
%   x_grid, y_grid: 예측할 파라미터 그리드
%   n_bootstrap: bootstrap 반복 횟수 (기본값: 1000)
%
% 출력:
%   CI_lower, CI_upper: 각 그리드 포인트에서의 95% CI 하한/상한
%   y_pred_grid: 예측값 그리드

if nargin < 9
    n_bootstrap = 1000;
end

fprintf('Bootstrap CI 계산 시작 (반복 횟수: %d)\n', n_bootstrap);

% 1. 원본 데이터로 기본 모델 피팅
[y0, H, y_est, MSE, Sig] = fitKoller21(xseries, yseries, tseries, msmt, trials, tau);

% 2. 그리드 크기 확인
[n_grid_x, n_grid_y] = size(x_grid);
y_pred_grid = zeros(n_grid_x, n_grid_y);

% 3. Bootstrap 예측값 저장용 배열
bootstrap_predictions = zeros(n_grid_x, n_grid_y, n_bootstrap);

% 4. Bootstrap 반복
unique_trials = unique(trials);
n_trials = length(unique_trials);

for b = 1:n_bootstrap
    if mod(b, 100) == 0
        fprintf('Bootstrap 진행률: %d/%d\n', b, n_bootstrap);
    end
    
    % Trial 자체를 bootstrap 샘플링 (trial 단위로 복원 추출)
    bootstrap_trials = [];
    bootstrap_x = [];
    bootstrap_y = [];
    bootstrap_t = [];
    bootstrap_msmt = [];
    
    % Trial 번호를 복원 추출로 샘플링
    selected_trial_numbers = randsample(unique_trials, n_trials, true);
    
    for i = 1:n_trials
        % 선택된 trial 번호
        selected_trial = selected_trial_numbers(i);
        trial_idx = trials == selected_trial;
        
        % 해당 trial의 모든 데이터 추가
        bootstrap_trials = [bootstrap_trials; i * ones(sum(trial_idx), 1)];
        bootstrap_x = [bootstrap_x; xseries(trial_idx)];
        bootstrap_y = [bootstrap_y; yseries(trial_idx)];
        bootstrap_t = [bootstrap_t; tseries(trial_idx)];
        bootstrap_msmt = [bootstrap_msmt; msmt(trial_idx)];
    end
    
    % Bootstrap 데이터로 모델 피팅 (특이 행렬 문제 해결)
    try
        [y0_b, H_b, ~, ~, ~] = fitKoller21(bootstrap_x, bootstrap_y, bootstrap_t, bootstrap_msmt, bootstrap_trials, tau);
        
        % 계수가 유효한지 확인
        if any(isnan(H_b)) || any(isinf(H_b))
            error('Invalid coefficients');
        end
        
        % 그리드에서 예측값 계산
        for i = 1:n_grid_x
            for j = 1:n_grid_y
                x_curr = x_grid(i, j);
                y_curr = y_grid(i, j);
                
                % 예측값 계산
                y_pred = H_b(1) * x_curr + H_b(2) * y_curr + H_b(3);
                
                % 예측값이 유효한지 확인
                if isnan(y_pred) || isinf(y_pred)
                    y_pred = H(1) * x_curr + H(2) * y_curr + H(3);  % 원본 사용
                end
                
                bootstrap_predictions(i, j, b) = y_pred;
            end
        end
    catch ME
        % 피팅 실패 시 원본 예측값 사용
        for i = 1:n_grid_x
            for j = 1:n_grid_y
                x_curr = x_grid(i, j);
                y_curr = y_grid(i, j);
                bootstrap_predictions(i, j, b) = H(1) * x_curr + H(2) * y_curr + H(3);
            end
        end
    end
end

% 5. 원본 예측값 계산
for i = 1:n_grid_x
    for j = 1:n_grid_y
        x_curr = x_grid(i, j);
        y_curr = y_grid(i, j);
        y_pred_grid(i, j) = H(1) * x_curr + H(2) * y_curr + H(3);
    end
end

% 6. Bootstrap에서 CI 계산
CI_lower = zeros(n_grid_x, n_grid_y);
CI_upper = zeros(n_grid_x, n_grid_y);

for i = 1:n_grid_x
    for j = 1:n_grid_y
        predictions = squeeze(bootstrap_predictions(i, j, :));
        predictions = predictions(~isnan(predictions));  % NaN 제거
        
        if length(predictions) > 0
            CI_lower(i, j) = prctile(predictions, 2.5);
            CI_upper(i, j) = prctile(predictions, 97.5);
        else
            CI_lower(i, j) = y_pred_grid(i, j);
            CI_upper(i, j) = y_pred_grid(i, j);
        end
    end
end

fprintf('Bootstrap CI 계산 완료\n');

end
