%% K5 Continuous 데이터 처리 스크립트
% 이 스크립트는 encode_all.m에서 K5 continuous 데이터 처리 부분을 분리한 것입니다.
% K5 데이터의 연속 조건 에너지 효율성 분석을 수행합니다.

close all; clear

% 환경 설정
mp = mfilename('fullpath');
if contains(mp, 'AppData'),  mp = matlab.desktop.editor.getActiveFilename; end
cd(fileparts(mp));

run('setup.m')
data_dir = getenv('DATA_DIR');

% 기본 파라미터 설정
tau = 41.78;

% continuous param grid
disc_p = [0.04, 0.04; 0.04, 0.11; 0.04, 0.18; ...
    0.11, 0.04; 0.11, 0.11; 0.11, 0.18; ...
    0.18, 0.04; 0.18, 0.11; 0.18, 0.18];
[pg_x, pg_y] = meshgrid(0.04:0.001:0.18, 0.04:0.001:0.18);

% 파라미터 및 피험자 정보 로드
opts = detectImportOptions("h10_param.csv");
opts = setvartype(opts, opts.VariableNames, "string");
param = readtable('h10_param.csv', opts);

opts = detectImportOptions("sub_info.csv");
opts = setvartype(opts, opts.VariableNames, "string");
sub_info = readtable('sub_info.csv', opts);

% 구간 정보 로드
interval_stand = readtable('k5_arrange.xlsx', 'Sheet', 'stand');
interval_walk = readtable('k5_arrange.xlsx', 'Sheet', 'walk');

walks = param.Properties.VariableNames(2:end);
n_sub = height(sub_info);
sub_pass = 5;

% enc_rs.mat 로드 (nat_ee와 disc_st 값이 필요)
load(fullfile(data_dir, 'export', 'enc_rs.mat'), 'rs');

%% K5 Continuous 데이터 수집 루프
% 이 루프는 모든 피험자의 15분 continuous 데이터를 수집합니다.
% 주요 단계: 피험자 정보 로드 → Continuous 조건 필터링 → 데이터 수집 → 통합 Koller 모델 피팅

% 전체 데이터 수집을 위한 변수 초기화 (5m, 10m, 15m 각각)
all_stack_p = cell(3, 1);  % {5m, 10m, 15m}
all_stack_t = cell(3, 1);
all_stack_ee = cell(3, 1);
all_trial = cell(3, 1);
all_sub_name = cell(3, 1);
all_walk_name = cell(3, 1);
trial_counter = [0, 0, 0];  % [5m, 10m, 15m] trial 번호 카운터

for i = sub_pass+1:n_sub
    % 피험자별 기본 정보 로드
    sub_name = sub_info.ID(i);
    sub_param = param(i, :);
    
    % 실험 조건 인덱스 정보 설정 (continuous 조건만)
    idx_info = struct(...
        'cont', str2double(split(sub_info(i, :).cont_eval)), ...
        'eval_fail', str2double(split(sub_info(i, :).eval_fail)) ...
        );
    
    % 각 보행 조건별 처리
    for j = 1:numel(walks)
        walk = walks{j};
        if strcmp(sub_param.(walk), "null")
            continue
        end
        
        % Continuous 조건만 필터링
        if ~ismember(j, idx_info.cont)
            continue
        end
        
        % continuous 길이 확인 (5m, 10m, 15m)
        cont_length = sub_param.(walk);
        if strcmp(cont_length, "5m")
            cont_idx = 1;
        elseif strcmp(cont_length, "10m")
            cont_idx = 2;
        elseif strcmp(cont_length, "15m")
            cont_idx = 3;
        else
            continue  % 5m, 10m, 15m이 아닌 경우 스킵
        end
        
        % K5 및 로그 파일 경로 설정
        k5_dir = dir(fullfile(data_dir, 'k5', sub_name, [walk, '*.xlsx']));
        k5_file = k5_dir(arrayfun(@(x) ~isempty(regexp(x.name,  ['^', walk, '(_\d+)?.xlsx'], 'once')), k5_dir));
        log_dir = dir(fullfile(data_dir, 'log', sub_name, [walk, '*.tdms']));
        log_file = log_dir(arrayfun(@(x) ~isempty(regexp(x.name,  ['^', walk, '(_\d+)?.tdms'], 'once')), log_dir));
        
        % K5 측정 성공 시에만 처리
        if ~ismember(j, idx_info.eval_fail) && ~isempty(k5_file)
            k5_table = read_k5_table(fullfile(k5_file.folder, k5_file.name));    % 파일 1개 가정
            
            if numel(k5_file) == 1
                % 각 로그 파일별 시간 동기화 및 데이터 수집
                for k = 1:numel(log_file)
                    % K5와 로그 파일 시간 동기화
                    [k5_start, ~, ~] = read_k5_time(fullfile(k5_file.folder, k5_file.name));
                    t_k5 = k5_start + seconds(k5_table.t);
                    [t_log, ~, ~, p] = read_log_file(log_file(k));
                    
                    % 로그 파라미터를 K5 시간축에 보간
                    p_sync = interp1(t_log, p, t_k5);
                    assert(any(~isnan(p_sync(:))), 'log is out of k5 range!\n')
                    
                    % K5 데이터에서 에너지 효율성 계산
                    [t_, ee_, ~, ~] = k5_to_ee(k5_table);
                    if numel(log_file) > 1, t_margin = 10; else t_margin = 0; end
                    k5_valid = t_log(1) <= t_k5 & t_k5 <= t_log(end) - seconds(t_margin);
                    p_sync = p_sync(k5_valid, :);
                    t_ = t_(k5_valid);
                    ee_ = ee_(k5_valid);
                    
                    % 에너지 효율성을 nat_ee와 disc_st를 이용해서 정규화
                    sub_rs = rs.(sub_name);
                    ee_norm = (ee_ - sub_rs.nat_ee) ./ (sub_rs.nat_ee - sub_rs.disc_st) * 100;
                    
                    % trial 번호 증가
                    trial_counter(cont_idx) = trial_counter(cont_idx) + 1;
                    
                    % 해당 길이의 데이터 스택에 추가 (정규화된 값)
                    all_stack_p{cont_idx} = [all_stack_p{cont_idx}; p_sync];
                    all_stack_t{cont_idx} = [all_stack_t{cont_idx}; t_];
                    all_stack_ee{cont_idx} = [all_stack_ee{cont_idx}; ee_norm];
                    all_trial{cont_idx} = [all_trial{cont_idx}; trial_counter(cont_idx) * ones(length(t_), 1)];
                end
                
                fprintf('[Data Collection] %s %s (%s) 완료!\n', sub_name, walk, cont_length)
            else
                warning('[Cont] %s %s k5 2개 이상, 스킵', sub_name, walk)
            end
        end
    end
end

%% 각 길이별 Koller 모델 피팅
% 5m, 10m, 15m 각각에 대해 개별 Koller 모델 피팅

cont_lengths = ["5m", "10m", "15m"];
k5_cont_results = struct();

for cont_idx = 1:3
    if isempty(all_stack_ee{cont_idx})
        fprintf('%s 데이터가 없습니다.\n', cont_lengths(cont_idx));
        continue
    end
    
    fprintf('%s: 총 %d개의 데이터 포인트 수집 완료\n', cont_lengths(cont_idx), length(all_stack_ee{cont_idx}));
    fprintf('%s Koller 모델 피팅 시작...\n', cont_lengths(cont_idx));
    
    % Koller 모델 피팅 (각 길이별로)
    [y0, H, ee_est, MSE, Sig] = fitKoller21(all_stack_p{cont_idx}(:, 1), all_stack_p{cont_idx}(:, 2), all_stack_t{cont_idx}, all_stack_ee{cont_idx}, all_trial{cont_idx}, tau);
    
    % Bootstrap 방법을 사용한 Confidence interval 계산
    [CI_lower, CI_upper, pg_ee] = fitKoller21_CI_bootstrap(all_stack_p{cont_idx}(:, 1), all_stack_p{cont_idx}(:, 2), all_stack_t{cont_idx}, all_stack_ee{cont_idx}, all_trial{cont_idx}, tau, pg_x, pg_y, 1000);
    
    % 결과 구조체 생성
    k5_cont_results.(sprintf('y0_%s', cont_lengths(cont_idx))) = y0;
    k5_cont_results.(sprintf('H_%s', cont_lengths(cont_idx))) = H;
    k5_cont_results.(sprintf('ee_est_%s', cont_lengths(cont_idx))) = ee_est;
    k5_cont_results.(sprintf('MSE_%s', cont_lengths(cont_idx))) = MSE;
    k5_cont_results.(sprintf('Sig_%s', cont_lengths(cont_idx))) = Sig;
    
    % 파라미터 그리드에서 에너지 효율성 예측 (landscape 생성)
    k5_cont_results.(sprintf('pg_ee_%s', cont_lengths(cont_idx))) = pg_ee;
    k5_cont_results.(sprintf('CI_lower_%s', cont_lengths(cont_idx))) = CI_lower;
    k5_cont_results.(sprintf('CI_upper_%s', cont_lengths(cont_idx))) = CI_upper;
    k5_cont_results.(sprintf('p_ee_%s', cont_lengths(cont_idx))) = [disc_p, poly2val(H, disc_p(:, 1), disc_p(:, 2))];
    
    % naive version
    % poly11 fit without Curve Fitting Toolbox
    nav_X = [ones(size(all_stack_p{cont_idx},1),1), all_stack_p{cont_idx}];
    nav_b = nav_X \ all_stack_ee{cont_idx};
    k5_cont_results.(sprintf('nav_p_ee_%s', cont_lengths(cont_idx))) = nav_b(1) + nav_b(2)*pg_x + nav_b(3)*pg_y;
    
    fprintf('%s Koller 모델 피팅 완료!\n', cont_lengths(cont_idx));
end

% 원본 데이터 저장
k5_cont_results.all_stack_p = all_stack_p;
k5_cont_results.all_stack_t = all_stack_t;
k5_cont_results.all_stack_ee = all_stack_ee;
k5_cont_results.all_trial = all_trial;

%% 하위 피험자 그룹 분석 (랜덤 샘플링)
% 5명, 10명 피험자 그룹을 각각 10번 랜덤 샘플링하여 Koller 모델 피팅

fprintf('\n=== 하위 피험자 그룹 분석 시작 ===\n');

% 사용 가능한 피험자 목록 (sub_pass+1부터 n_sub까지)
available_subjects = (sub_pass+1):n_sub;
n_available = length(available_subjects);

% 하위 그룹 설정 (1부터 14까지 촘촘하게)
subgroup_sizes = 1:14;
n_subsets = 10;

% 하위 그룹 결과 초기화 (1부터 14까지)
for group_size = subgroup_sizes
    group_name = sprintf('subgroup_%d', group_size);
    k5_cont_results.(group_name) = struct();
end

for group_idx = 1:length(subgroup_sizes)
    group_size = subgroup_sizes(group_idx);
    group_name = sprintf('subgroup_%d', group_size);
    
    fprintf('%d명 피험자 그룹 분석 시작 (10번 랜덤 샘플링)...\n', group_size);
    
    % 각 서브셋별 결과 저장을 위한 구조체 초기화
    k5_cont_results.(group_name).subjects_used = cell(n_subsets, 1);
    
    for subset_idx = 1:n_subsets
        fprintf('  서브셋 %d/%d 처리 중...\n', subset_idx, n_subsets);
        
        % 랜덤 피험자 선택
        selected_subjects = available_subjects(randperm(n_available, group_size));
        k5_cont_results.(group_name).subjects_used{subset_idx} = selected_subjects;
        
        % 선택된 피험자들의 데이터만 수집
        subset_stack_p = cell(3, 1);  % {5m, 10m, 15m}
        subset_stack_t = cell(3, 1);
        subset_stack_ee = cell(3, 1);
        subset_trial = cell(3, 1);
        subset_trial_counter = [0, 0, 0];  % [5m, 10m, 15m] trial 번호 카운터
        
        % 선택된 피험자들의 데이터 수집
        for i = 1:group_size
            sub_idx = selected_subjects(i);
            sub_name = sub_info.ID(sub_idx);
            sub_param = param(sub_idx, :);
            
            % 실험 조건 인덱스 정보 설정 (continuous 조건만)
            idx_info = struct(...
                'cont', str2double(split(sub_info(sub_idx, :).cont_eval)), ...
                'eval_fail', str2double(split(sub_info(sub_idx, :).eval_fail)) ...
                );
            
            % 각 보행 조건별 처리
            for j = 1:numel(walks)
                walk = walks{j};
                if strcmp(sub_param.(walk), "null")
                    continue
                end
                
                % Continuous 조건만 필터링
                if ~ismember(j, idx_info.cont)
                    continue
                end
                
                % continuous 길이 확인 (5m, 10m, 15m)
                cont_length = sub_param.(walk);
                if strcmp(cont_length, "5m")
                    cont_idx = 1;
                elseif strcmp(cont_length, "10m")
                    cont_idx = 2;
                elseif strcmp(cont_length, "15m")
                    cont_idx = 3;
                else
                    continue  % 5m, 10m, 15m이 아닌 경우 스킵
                end
                
                % K5 및 로그 파일 경로 설정
                k5_dir = dir(fullfile(data_dir, 'k5', sub_name, [walk, '*.xlsx']));
                k5_file = k5_dir(arrayfun(@(x) ~isempty(regexp(x.name,  ['^', walk, '(_\d+)?.xlsx'], 'once')), k5_dir));
                log_dir = dir(fullfile(data_dir, 'log', sub_name, [walk, '*.tdms']));
                log_file = log_dir(arrayfun(@(x) ~isempty(regexp(x.name,  ['^', walk, '(_\d+)?.tdms'], 'once')), log_dir));
                
                % K5 측정 성공 시에만 처리
                if ~ismember(j, idx_info.eval_fail) && ~isempty(k5_file)
                    k5_table = read_k5_table(fullfile(k5_file.folder, k5_file.name));
                    
                    if numel(k5_file) == 1
                        % 각 로그 파일별 시간 동기화 및 데이터 수집
                        for k = 1:numel(log_file)
                            % K5와 로그 파일 시간 동기화
                            [k5_start, ~, ~] = read_k5_time(fullfile(k5_file.folder, k5_file.name));
                            t_k5 = k5_start + seconds(k5_table.t);
                            [t_log, ~, ~, p] = read_log_file(log_file(k));
                            
                            % 로그 파라미터를 K5 시간축에 보간
                            p_sync = interp1(t_log, p, t_k5);
                            assert(any(~isnan(p_sync(:))), 'log is out of k5 range!\n')
                            
                            % K5 데이터에서 에너지 효율성 계산
                            [t_, ee_, ~, ~] = k5_to_ee(k5_table);
                            if numel(log_file) > 1, t_margin = 10; else t_margin = 0; end
                            k5_valid = t_log(1) <= t_k5 & t_k5 <= t_log(end) - seconds(t_margin);
                            p_sync = p_sync(k5_valid, :);
                            t_ = t_(k5_valid);
                            ee_ = ee_(k5_valid);
                            
                            % 에너지 효율성을 nat_ee와 disc_st를 이용해서 정규화
                            sub_rs = rs.(sub_name);
                            ee_norm = (ee_ - sub_rs.nat_ee) ./ (sub_rs.nat_ee - sub_rs.disc_st) * 100;
                            
                            % trial 번호 증가
                            subset_trial_counter(cont_idx) = subset_trial_counter(cont_idx) + 1;
                            
                            % 해당 길이의 데이터 스택에 추가 (정규화된 값)
                            subset_stack_p{cont_idx} = [subset_stack_p{cont_idx}; p_sync];
                            subset_stack_t{cont_idx} = [subset_stack_t{cont_idx}; t_];
                            subset_stack_ee{cont_idx} = [subset_stack_ee{cont_idx}; ee_norm];
                            subset_trial{cont_idx} = [subset_trial{cont_idx}; subset_trial_counter(cont_idx) * ones(length(t_), 1)];
                        end
                    end
                end
            end
        end
        
        % 각 길이별 Koller 모델 피팅 (서브셋별)
        subset_name = sprintf('subset_%d', subset_idx);
        k5_cont_results.(group_name).(subset_name) = struct();
        
        for cont_idx = 1:3
            if isempty(subset_stack_ee{cont_idx})
                fprintf('    %s: 데이터 없음\n', cont_lengths(cont_idx));
                continue
            end
            
            fprintf('    %s: %d개 데이터 포인트로 Koller 모델 피팅...\n', cont_lengths(cont_idx), length(subset_stack_ee{cont_idx}));
            
            % Koller 모델 피팅 (서브셋별)
            [y0, H, ee_est, MSE, Sig] = fitKoller21(subset_stack_p{cont_idx}(:, 1), subset_stack_p{cont_idx}(:, 2), subset_stack_t{cont_idx}, subset_stack_ee{cont_idx}, subset_trial{cont_idx}, tau);
            
            % Bootstrap 방법을 사용한 Confidence interval 계산
            [CI_lower, CI_upper, pg_ee] = fitKoller21_CI_bootstrap(subset_stack_p{cont_idx}(:, 1), subset_stack_p{cont_idx}(:, 2), subset_stack_t{cont_idx}, subset_stack_ee{cont_idx}, subset_trial{cont_idx}, tau, pg_x, pg_y, 1000);
            
            % 결과 구조체 생성
            k5_cont_results.(group_name).(subset_name).(sprintf('y0_%s', cont_lengths(cont_idx))) = y0;
            k5_cont_results.(group_name).(subset_name).(sprintf('H_%s', cont_lengths(cont_idx))) = H;
            k5_cont_results.(group_name).(subset_name).(sprintf('ee_est_%s', cont_lengths(cont_idx))) = ee_est;
            k5_cont_results.(group_name).(subset_name).(sprintf('MSE_%s', cont_lengths(cont_idx))) = MSE;
            k5_cont_results.(group_name).(subset_name).(sprintf('Sig_%s', cont_lengths(cont_idx))) = Sig;
            
            % 파라미터 그리드에서 에너지 효율성 예측 (landscape 생성)
            k5_cont_results.(group_name).(subset_name).(sprintf('pg_ee_%s', cont_lengths(cont_idx))) = pg_ee;
            k5_cont_results.(group_name).(subset_name).(sprintf('CI_lower_%s', cont_lengths(cont_idx))) = CI_lower;
            k5_cont_results.(group_name).(subset_name).(sprintf('CI_upper_%s', cont_lengths(cont_idx))) = CI_upper;
            k5_cont_results.(group_name).(subset_name).(sprintf('p_ee_%s', cont_lengths(cont_idx))) = [disc_p, poly2val(H, disc_p(:, 1), disc_p(:, 2))];
            
            % naive version
            % poly11 fit without Curve Fitting Toolbox
            nav_X2 = [ones(size(subset_stack_p{cont_idx},1),1), subset_stack_p{cont_idx}];
            nav_b2 = nav_X2 \ subset_stack_ee{cont_idx};
            k5_cont_results.(group_name).(subset_name).(sprintf('nav_p_ee_%s', cont_lengths(cont_idx))) = nav_b2(1) + nav_b2(2)*pg_x + nav_b2(3)*pg_y;
            
            % 원본 데이터 저장
            k5_cont_results.(group_name).(subset_name).(sprintf('all_stack_p_%s', cont_lengths(cont_idx))) = subset_stack_p{cont_idx};
            k5_cont_results.(group_name).(subset_name).(sprintf('all_stack_t_%s', cont_lengths(cont_idx))) = subset_stack_t{cont_idx};
            k5_cont_results.(group_name).(subset_name).(sprintf('all_stack_ee_%s', cont_lengths(cont_idx))) = subset_stack_ee{cont_idx};
            k5_cont_results.(group_name).(subset_name).(sprintf('all_trial_%s', cont_lengths(cont_idx))) = subset_trial{cont_idx};
        end
        
        fprintf('  서브셋 %d/%d 완료!\n', subset_idx, n_subsets);
    end
    
    fprintf('%d명 피험자 그룹 분석 완료!\n', group_size);
end

fprintf('=== 하위 피험자 그룹 분석 완료 ===\n\n');

%% 결과 저장
save(fullfile(data_dir, 'export', 'k5_cont_results.mat'), 'k5_cont_results')
fprintf('K5 Continuous 데이터 처리 완료! 결과가 k5_cont_results.mat에 저장되었습니다.\n')
