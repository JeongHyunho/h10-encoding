%% Raw EMG plot for insanity check
% 이 스크립트는 각 trial의 EMG 신호를 시각화하여 채널 품질을 검토합니다.
% 결과로 emg_channel_success_auto.csv 파일을 생성합니다.

function emg_raw_plot_check(idx_info, sub_info, sub_pass, n_sub)
    % 환경 설정
    mfile_dir = fileparts(mfilename('fullpath'));
    if contains(mfile_dir,'Editor')
        mfile_dir = fileparts(matlab.desktop.editor.getActiveFilename);
    end
    cd(mfile_dir)
    
    run('../setup.m')
    data_dir = getenv('DATA_DIR');
    v3d_dir = getenv('V3D_PATH');
    
    csv_file = fullfile(mfile_dir, '../emg_channel_success_auto.csv');
    pass_ch = cell(0, 3);
    
    muscle_names = {'VM', 'VM1', 'VM2', 'VL', 'RF', 'RF1', 'RF2', 'BF', 'ST', 'TA', 'GL', 'GM', 'SOL'};
    
    % ─── 수동 skip 리스트 정의 ───
    % 특정 피험자, walk, dyn을 수동으로 skip하기 위한 리스트
    % 형식: {피험자ID, walk번호, dyn번호}
    manual_skip_list = {
        % 예시: {'S025', 17, 1},  % S025의 walk17, dyn_1을 skip
        % {'S030', 5, 2},        % S030의 walk5, dyn_2를 skip
        % 추가할 항목들을 여기에 작성
        {'S025', 17, 1}, ...
        {'S026', 1, 1}, ...
        {'S029', 16, 1},
    };
    
    % 병렬 처리 설정
    p = gcp('nocreate');
    if isempty(p), p = parpool("Processes", 6); end
    
    % 피험자별 처리
    parfor i = 1+sub_pass:n_sub
        sub_name = sub_info.ID(i);
        sub_idx_info = idx_info.(sub_name);
        
        set_name = 'set2';
        if ismember(sub_name, ["S017", "S018"]), set_name = 'set1'; end
        
        rep_dir = fullfile(data_dir, 'emg', 'report_emg_raw');
        if ~exist(rep_dir, 'dir'), mkdir(rep_dir), end
        
        % 각 parfor 워커가 독립적으로 사용하는 임시 변수
        sub_ch = cell(0, 3);
        
        walk_dirs = dir(fullfile(data_dir, 'c3d', sub_name, 'walk*'));
        for j = 1:numel(walk_dirs)
            walk = walk_dirs(j).name;
            reg_out = regexp(walk_dirs(j).name, '\d+$', 'match');
            walk_idx = str2double(reg_out{1});
            walk_dir = fullfile(walk_dirs(j).folder, walk_dirs(j).name);
            
            % 실험 조건 분류
            if ismember(walk_idx, sub_idx_info.non_exo)
                type = 'nat';
            elseif ismember(walk_idx, sub_idx_info.transparent)
                type = 'trans';
            elseif ismember(walk_idx, sub_idx_info.disc)
                type = 'disc';
            elseif ismember(walk_idx, sub_idx_info.cont)
                type = 'cont';
            else
                type = 'unknown';
                warning('[%s] Exceptional walk_idx(%d)!\n', sub_name, walk_idx)
            end
            
            % V3D 경로에서 dyn 데이터 처리
            v3d_walk_dir = fullfile(v3d_dir, sub_name, walk);
            if exist(v3d_walk_dir, 'dir')
                emg_list = dir(fullfile(v3d_walk_dir, 'emg_exported_*.txt'));
                
                if ~isempty(emg_list)
                    % 모든 emg_exported 파일들을 순서대로 처리
                    for k = 1:numel(emg_list)
                        try
                            % ─── 수동 skip 검증 ───
                            % 현재 처리 중인 trial이 skip 리스트에 있는지 확인
                            skip_this_trial = false;
                            for skip_idx = 1:size(manual_skip_list, 1)
                                skip_sub = manual_skip_list{skip_idx}{1};
                                skip_walk = manual_skip_list{skip_idx}{2};
                                skip_dyn = manual_skip_list{skip_idx}{3};
                                
                                if strcmp(sub_name, skip_sub) && walk_idx == skip_walk && k == skip_dyn
                                    fprintf('[Raw EMG plot] manually skip %s walk%d dyn_%d\n', sub_name, walk_idx, k);
                                    skip_this_trial = true;
                                    break;
                                end
                            end
                            
                            if skip_this_trial
                                continue;
                            end
                            
                            emg_file = fullfile(emg_list(k).folder, emg_list(k).name);
                            % 빈/무효 EMG export 파일은 스킵
                            if is_empty_emg_exported(emg_file)
                                fprintf('[Raw EMG plot] skip empty emg_exported (%s)\n', emg_list(k).name);
                                continue
                            end
                            
                            emg_case = sprintf('dyn_%d', k);
                            trial_id = sprintf('%s_%s_%s', walk, type, emg_case);
                            filename = fullfile(rep_dir, sub_name + "_" + trial_id + ".png");
                            
                            % emg_exported 파일에서 직접 EMG 데이터 읽기
                            emg_data = emg_dyn_process(emg_file, set_name);
                            
                            % 이벤트 데이터 읽기
                            evt_file = fullfile(emg_list(k).folder, sprintf('events_%d.txt', k));
                            evt = read_events_struct(evt_file);
                            
                            valid_channels = emg_raw_txt_plot(emg_data, filename, evt, type);
                            
                            sub_ch(end+1, :) = {sub_name, trial_id, valid_channels};
                        catch ME
                            fprintf('오류 발생(dyn %d): %s\n', k, ME.message)
                        end
                    end
                    
                    fprintf('[Raw EMG plot] %s walk#%d dyn (%d files) done!\n', sub_name, walk_idx, numel(emg_list))
                end
            end
            
            % MVC trial 처리
            c3d_dir = dir(fullfile(walk_dir, "*.c3d"));
            c3d_files = {c3d_dir.name};
            mvc_files = c3d_files(contains(lower(c3d_files), 'mvc'));
            
            for k = 1:numel(c3d_dir)
                try
                    if contains(c3d_dir(k).name, 'static'), continue, end  % static 파일은 처리에서 제외
                    if contains(c3d_dir(k).name, "dyn"), continue, end     % dyn 파일은 처리에서 제외 (V3D에서 처리됨)
                    
                    % MVC 파일만 처리
                    if contains(c3d_dir(k).name, "mvc")
                        mvc_idx = find(strcmp(c3d_dir(k).name, mvc_files));
                        emg_case = sprintf('mvc%d', mvc_idx);
                        
                        c3d_file = fullfile(c3d_dir(k).folder, c3d_dir(k).name);
                        c3d = ezc3dRead(char(c3d_file));
                        
                        trial_id = sprintf('%s_%s_%s', walk, type, emg_case);
                        filename = fullfile(rep_dir, sub_name + "_" + trial_id + ".png");
                        mvc_rs = emg_mvc_process(c3d, set_name);
                        valid_channels = emg_raw_mvc_plot(mvc_rs, filename);
                        
                        sub_ch(end+1, :) = {sub_name, trial_id, valid_channels};
                    end
                catch ME
            fprintf('[Raw MVC plot] 오류 발생(MVC): %s\n', ME.message)
                end
            end
            
            % 피험자별 결과 수집
            pass_ch{i} = sub_ch;
            
            fprintf('[Raw EMG plot] %s walk#%d done!\n', sub_name, walk_idx)
        end
    end
    
    % 모든 결과를 취합하여 CSV 파일에 저장
    final_data = vertcat(pass_ch{:});
    T = cell2table(final_data, 'VariableNames', {'subject_id', 'trial', 'successful_channels'});
    % walk 번호 기준 오름차순 정렬 (trial에서 'walk%d'의 %d 추출)
    trial_str = string(T.trial);
    tok = regexp(trial_str, 'walk(\d+)', 'tokens', 'once');
    walk_num = nan(height(T), 1);
    for ii = 1:height(T)
        if ~isempty(tok{ii})
            % tokens는 1x1 셀일 수 있으므로 한 번 더 풀어 숫자로 변환
            walk_num(ii) = str2double(tok{ii}{1});
        end
    end
    % 피험자 ID 우선 정렬 + 같은 ID 내에서는 walk 번호 오름차순 정렬
    subj_str = string(T.subject_id);
    key_tbl = table(subj_str, walk_num);
    [~, order_idx] = sortrows(key_tbl, [1 2]);
    T = T(order_idx, :);
    
    writetable(T, csv_file);

    % 병렬 풀 정리
    p = gcp('nocreate');
    if ~isempty(p), delete(p), end
    
    fprintf('Raw EMG plot check completed. Results saved to %s\n', csv_file);
end

function s = read_events_struct(evt_file)
% read events.txt
s = struct();
rd = readcell(evt_file);
fields = rd(2, 2:end);
data_c = rd(6:end, 2:end);
missed = cellfun(@ismissing, data_c);
data_c(missed) = {nan};
data = cell2mat(data_c);

for i = 1:length(fields)
    f = fields{i};
    f_data = data(:, i);
    f_data = f_data(~isnan(f_data));    % remove nan

    switch f
        case 'Right Foot Off'
            s.rfo = f_data;
        case 'Right Foot Strike'
            s.rfs = f_data;
        case 'Left Foot Off'
            s.lfo = f_data;
        case 'Left Foot Strike'
            s.lfs = f_data;
    end
end
end
