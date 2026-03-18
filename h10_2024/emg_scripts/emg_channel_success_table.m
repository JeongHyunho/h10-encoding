%% EMG Channel Success Table
% 이 스크립트는 EMG 채널 성공 여부를 기록하는 CSV 테이블을 생성합니다.
% 각 피험자별, walk별, 채널별 성공 여부를 관리합니다.

function emg_channel_success_table(emg_rs)
    % 환경 설정
    mfile_dir = fileparts(mfilename('fullpath'));
    if contains(mfile_dir,'Editor')
        mfile_dir = fileparts(matlab.desktop.editor.getActiveFilename);
    end
    cd(mfile_dir)
    
    run('../setup.m')
    data_dir = getenv('DATA_DIR');
    
    % CSV 파일 경로
    csv_file = fullfile(mfile_dir, '../emg_channel_success.csv');
    channel_list = arrayfun(@(x) sprintf('ch%d', x), 1:10, 'UniformOutput', false);
    n_channel = numel(channel_list);
    
    % 기존 CSV 읽기 (없으면 빈 테이블 생성)
    if exist(csv_file, 'file')
        T_exist = readtable(csv_file, 'TextType', 'string');
    else
        T_exist = table('Size', [0, 2+n_channel], ...
            'VariableTypes', [repmat({'string'},1,2), repmat({'double'},1,n_channel)], ...
            'VariableNames', ['sub_name','walk', channel_list]);
    end
    
    subjects = fieldnames(emg_rs);
    new_rows = [];
    
    for s = 1:numel(subjects)
        sub_name = subjects{s};
        walks = fieldnames(emg_rs.(sub_name));
        
        % walk별로 loop
        for w = 1:numel(walks)
            walk = walks{w};
            
            % 이미 존재하는지 확인
            is_exist = any(T_exist.sub_name == sub_name & T_exist.walk == walk);
            if is_exist
                continue
            end
            
            % 디폴트: 모든 채널 성공(1)
            row = [{sub_name, walk}, num2cell(ones(1, n_channel))];
            new_rows = [new_rows; row];
        end
    end
    
    % 새 행이 있으면 테이블로 변환 후 합치기
    if ~isempty(new_rows)
        T_new = cell2table(new_rows, 'VariableNames', T_exist.Properties.VariableNames);
        T_all = [T_exist; T_new];
        
        % walk에서 숫자 추출
        walk_num = regexp(string(T_all.walk), '\d+', 'match', 'once');
        walk_num = cellfun(@str2double, walk_num);
        
        % 정렬용 테이블 생성
        T_sort = table(string(T_all.sub_name), walk_num, (1:height(T_all))', ...
                       'VariableNames', {'sub_name', 'walk_num', 'orig_idx'});
        T_sort = sortrows(T_sort, {'sub_name', 'walk_num'});
        T_all = T_all(T_sort.orig_idx, :);
        
        writetable(T_all, csv_file);
        fprintf('Added %d new rows to channel success table.\n', size(new_rows, 1));
    else
        disp('추가할 새로운 행이 없습니다.');
    end
    
    fprintf('Channel success table updated: %s\n', csv_file);
end 