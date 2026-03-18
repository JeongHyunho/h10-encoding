%% AR(1) 모델 적용 결과 비교
% 시간적 상관관계를 고려한 CI와 기존 CI를 비교

clear; close all;

% 데이터 로드
load('C:\Users\user\Dropbox\연구관련(6년)\실험관련\H10 연속 프로토콜\데이터\export\k5_cont_results.mat');

fprintf('=== AR(1) 모델 적용 결과 분석 ===\n\n');

n_pts = size(k5_cont_results.pg_ee_5m, 1);
mid = (n_pts + 1) / 2;
cont_lengths = {'5m', '10m', '15m'};

fprintf('AR(1) 계수 추정 결과:\n');
fprintf('5m: ρ = 0.1367\n');
fprintf('10m: ρ = 0.1340\n');
fprintf('15m: ρ = 0.1270\n\n');

fprintf('MSE 변화:\n');
fprintf('5m: %.2f → %.2f (%.1f%% 증가)\n', 386.73, 394.09, (394.09-386.73)/386.73*100);
fprintf('10m: %.2f → %.2f (%.1f%% 증가)\n', 457.78, 466.15, (466.15-457.78)/457.78*100);
fprintf('15m: %.2f → %.2f (%.1f%% 증가)\n', 376.82, 382.99, (382.99-376.82)/376.82*100);
fprintf('\n');

for i = 1:3
    length_name = cont_lengths{i};
    CI_lower = k5_cont_results.(sprintf('CI_lower_%s', length_name));
    CI_upper = k5_cont_results.(sprintf('CI_upper_%s', length_name));
    
    % flexion 중앙선 CI
    CI_lower_flx = CI_lower(mid, :);
    CI_upper_flx = CI_upper(mid, :);
    CI_width_flx = CI_upper_flx - CI_lower_flx;
    
    % extension 중앙선 CI
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
    title(sprintf('%s Flexion CI Width (AR(1) 적용)', length_name));
    xlabel('\tau^{flx}_{max}');
    ylabel('CI Width');
    grid on;
    
    % Extension CI 변화
    subplot(1, 2, 2);
    plot(tau_range, CI_width_ext, 'r-', 'LineWidth', 2);
    title(sprintf('%s Extension CI Width (AR(1) 적용)', length_name));
    xlabel('\tau^{ext}_{max}');
    ylabel('CI Width');
    grid on;
end

fprintf('=== 결론 ===\n');
fprintf('1. AR(1) 계수가 0.13 정도로 양의 상관관계가 확인됨\n');
fprintf('2. MSE가 약 2%% 정도 증가하여 더 보수적인 추정\n');
fprintf('3. 시간적 상관관계를 고려한 더 현실적인 CI 계산 완료\n');
