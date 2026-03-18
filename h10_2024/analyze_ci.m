%% CI 분석 스크립트
% 2차원 파라미터 공간에서 flexion과 extension 중앙선의 CI 변화를 분석

clear; close all;

% 데이터 로드
load('C:\Users\user\Dropbox\연구관련(6년)\실험관련\H10 연속 프로토콜\데이터\export\k5_cont_results.mat');

fprintf('=== 2차원 파라미터 공간 중앙선 CI 분석 ===\n\n');

n_pts = size(k5_cont_results.pg_ee_5m, 1);
mid = (n_pts + 1) / 2;
cont_lengths = {'5m', '10m', '15m'};

for i = 1:3
    length_name = cont_lengths{i};
    CI_lower = k5_cont_results.(sprintf('CI_lower_%s', length_name));
    CI_upper = k5_cont_results.(sprintf('CI_upper_%s', length_name));
    
    % flexion 중앙선 (τ^flx_max 변화, τ^ext_max = 0.11 고정)
    CI_lower_flx = CI_lower(mid, :);
    CI_upper_flx = CI_upper(mid, :);
    CI_width_flx = CI_upper_flx - CI_lower_flx;
    
    % extension 중앙선 (τ^ext_max 변화, τ^flx_max = 0.11 고정)
    CI_lower_ext = CI_lower(:, mid);
    CI_upper_ext = CI_upper(:, mid);
    CI_width_ext = CI_upper_ext - CI_lower_ext;
    
    fprintf('%s:\n', length_name);
    fprintf('  Flexion 중앙선 CI:\n');
    fprintf('    최소: %.4f, 최대: %.4f, 평균: %.4f, 표준편차: %.4f\n', ...
        min(CI_width_flx), max(CI_width_flx), mean(CI_width_flx), std(CI_width_flx));
    fprintf('  Extension 중앙선 CI:\n');
    fprintf('    최소: %.4f, 최대: %.4f, 평균: %.4f, 표준편차: %.4f\n', ...
        min(CI_width_ext), max(CI_width_ext), mean(CI_width_ext), std(CI_width_ext));
    fprintf('\n');
    
    % CI 변화 시각화
    figure('Position', [100 + (i-1)*50, 100 + (i-1)*50, 800, 400]);
    
    % Flexion CI 변화
    subplot(1, 2, 1);
    tau_range = 0.04:0.001:0.18;
    plot(tau_range, CI_width_flx, 'b-', 'LineWidth', 2);
    title(sprintf('%s Flexion CI Width', length_name));
    xlabel('\tau^{flx}_{max}');
    ylabel('CI Width');
    grid on;
    
    % Extension CI 변화
    subplot(1, 2, 2);
    plot(tau_range, CI_width_ext, 'r-', 'LineWidth', 2);
    title(sprintf('%s Extension CI Width', length_name));
    xlabel('\tau^{ext}_{max}');
    ylabel('CI Width');
    grid on;
end
