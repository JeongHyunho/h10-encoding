function issues = log_file_checks(idx_info, sub_info, param, data_dir, fp_freq, sub_pass)
% 로그 파일 점검 함수
% - fp 시작 시간과 log 시작 시간의 정합성 확인 (1분 기준)
% - 비-연속 조건에서 param 테이블과 log 파라미터(중앙값) 일치 여부 확인
% - 로그 파일 존재 여부 확인

% 반환: issues (table) - subject, walk, type, message

    arguments
        idx_info (1,1) struct
        sub_info table
        param table
        data_dir (1,1) string
        fp_freq (1,1) double = 500
        sub_pass (1,1) double = 2
    end

	% 병렬 처리 설정
	if isempty(gcp('nocreate')), parpool("Processes", 6); end
    walks = param.Properties.VariableNames(2:end);
    issues_cells = cell(height(sub_info), 1);

    % 수동 설명 리스트: {subject, walk_idx, note}
    manual_explanation_list = {
        'S025', 20, "all splitted";
        'S025', 23, "all splitted";
        'S028', 21, "c3d late stopped";
        'S028', 22, "c3d late started";
        'S031', 20, "all splitted";
    };

    parfor i = 1+sub_pass:height(sub_info)
        sub_name = sub_info.ID(i);

        if ~isfield(idx_info, sub_name)
            issues_cells{i} = cell(0,4);
            continue
        end
        info = idx_info.(sub_name);
        local_rows = cell(0, 7);

        for j = 1:numel(walks)
            walk = walks{j};
            if strcmp(param(i, :).(walk), "null")
                continue
            end
            % trial type 분류
            if ismember(j, info.non_exo)
                trial_type = "nat";
            elseif ismember(j, info.transparent)
                trial_type = "trans";
            elseif ismember(j, info.disc)
                trial_type = "disc";
            elseif ismember(j, info.cont)
                trial_type = "cont";
            else
                trial_type = "unknown";
            end
            % 안내: walk 검사 시작
            prev_n = size(local_rows, 1);
            fprintf('[로그 점검] %s %s 검사 시작...\n', sub_name, walk);
            p_declared = str2double(split(param(i, :).(walk)))'; %#ok<*ST2NM>

            % 수동 노트 조회
            note_str = "";
            for mx = 1:size(manual_explanation_list, 1)
                if strcmp(sub_name, manual_explanation_list{mx, 1}) && j == manual_explanation_list{mx, 2}
                    note_str = string(manual_explanation_list{mx, 3});
                    break
                end
            end

            % 파일 목록 수집 (encode_all과 동일 규칙)
            fp_dir = dir(fullfile(data_dir, 'fp', sub_name, [walk, '*.tdms']));
            fp_file = fp_dir(arrayfun(@(x) ~isempty(regexp(x.name, ['^', walk, '(_\d+)?\.tdms'], 'once')), fp_dir));
            log_dir = dir(fullfile(data_dir, 'log', sub_name, [walk, '*.tdms']));
            log_file = log_dir(arrayfun(@(x) ~isempty(regexp(x.name, ['^', walk, '(_\d+)?\.tdms'], 'once')), log_dir));

            % c3d 목록(매핑 계산용) - 폴더 유무와 상관없이 미리 시도
            c3d_dir_early = fullfile(data_dir, 'c3d', sub_name, walk);
            if isfolder(c3d_dir_early)
                c3d_list_early = dir(fullfile(c3d_dir_early, '*dyn*.c3d'));
            else
                c3d_list_early = [];
            end

            % 로그 존재 여부
            if isempty(log_file)
                local_rows(end+1,:) = {sub_name, string(walk), trial_type, "log_missing", "log 파일이 존재하지 않습니다.", note_str, ""}; %#ok<AGROW>
                continue
            end
            % 한 트라이얼 내 TDMS가 여러 개인 경우 (walk%d_%d.tdms 패턴 포함)
            if numel(log_file) > 1
                names = string({log_file.name});
                % 매핑: tdms_n개, c3d_m개 → 1..n-1은 1:1, 마지막 tdms가 나머지 c3d 모두 매핑
                tdms_n = numel(log_file);
                c3d_n = numel(c3d_list_early);
                map_parts = strings(1, tdms_n);
                if c3d_n == 0
                    for ii = 1:tdms_n
                        map_parts(ii) = sprintf('%d:[]', ii);
                    end
                elseif c3d_n >= tdms_n
                    for ii = 1:tdms_n
                        if ii < tdms_n
                            map_parts(ii) = sprintf('%d:[%d]', ii, ii);
                        else
                            if c3d_n >= ii
                                rest = ii:c3d_n;
                                map_parts(ii) = sprintf('%d:[%s]', ii, strjoin(string(rest), ','));
                            else
                                map_parts(ii) = sprintf('%d:[]', ii);
                            end
                        end
                    end
                else
                    % c3d가 tdms보다 적은 경우: 1..c3d_n만 매핑, 나머지는 빈 매핑
                    for ii = 1:tdms_n
                        if ii <= c3d_n
                            map_parts(ii) = sprintf('%d:[%d]', ii, ii);
                        else
                            map_parts(ii) = sprintf('%d:[]', ii);
                        end
                    end
                end
                map_str = strjoin(map_parts, ';');
                local_rows(end+1,:) = {sub_name, string(walk), trial_type, "multi_tdms", sprintf('동일 트라이얼에 TDMS %d개 (%s)', numel(log_file), strjoin(names, ', ')), note_str, map_str}; %#ok<AGROW>
            end

            % fp 시작/끝 시간
            [fp_start, ~] = read_fp_time(fp_file, fp_freq); 

            % 각 로그 파일에 대해 시작/끝/파라미터 수집
            log_starts = NaT(0,1);
            log_ends = NaT(0,1);
            log_params = [];
            for k = 1:numel(log_file)
                [~, log_start, log_end, p] = read_log_file(log_file(k));
                log_starts(end+1,1) = log_start; %#ok<AGROW>
                log_ends(end+1,1) = log_end; %#ok<AGROW>
                log_params = [log_params; p]; %#ok<AGROW>
            end

            % 시간 정합성: fp_start vs 첫 로그 시작
            if ~isnat(fp_start) && ~isempty(log_starts)
                if abs(fp_start - log_starts(1)) > minutes(1)
                    local_rows(end+1,:) = {sub_name, string(walk), trial_type, "time_mismatch", sprintf('fp_start와 log_start 차이가 큽니다 (%.0f s)', seconds(fp_start - log_starts(1))), note_str, ""}; %#ok<AGROW>
                end
            end

            % 파라미터 일치성 (비-연속 && 비-non_exo)
            is_cont = ismember(j, info.cont);
            is_non_exo = ismember(j, info.non_exo);
            if ~isempty(log_params) && ~is_cont && ~is_non_exo
                p_logged = median(log_params, 1);
                if ~(all(abs(p_logged - p_declared) < 1e-3))
                    local_rows(end+1,:) = {sub_name, string(walk), trial_type, "param_mismatch", sprintf('파라미터 불일치 (declared=%s, logged=%s)', num2str(p_declared), num2str(p_logged)), note_str, ""}; %#ok<AGROW>
                end
            end

            % c3d 총 길이 vs tdms 길이 검증
            % - c3d는 시작시간 불명 -> 개별 파일 길이 합산
            % - 규칙: sum(c3d_dur) <= tdms_dur 이어야 하며, 너무 작으면 issue
            if ~isempty(log_starts) && ~isempty(log_ends)
                tdms_dur_sec = seconds(max(log_ends) - min(log_starts));
                % c3d 파일 검색: data_dir/c3d/<sub>/<walk> 경로에서 dyn 파일만
                c3d_dir = fullfile(data_dir, 'c3d', sub_name, walk);
                if ~isfolder(c3d_dir)
                    local_rows(end+1,:) = {sub_name, string(walk), trial_type, "c3d_dir_missing", sprintf('c3d 보행 폴더가 없습니다. (경로: %s)', c3d_dir), note_str, ""}; %#ok<AGROW>
                else
                    c3d_list = dir(fullfile(c3d_dir, '*dyn*.c3d'));
                    if isempty(c3d_list)
                        local_rows(end+1,:) = {sub_name, string(walk), trial_type, "c3d_missing", sprintf('dyn c3d 파일이 없습니다. (경로: %s)', c3d_dir), note_str, ""}; %#ok<AGROW>
                    else
                    c3d_sum_sec = 0;
                    for kk = 1:numel(c3d_list)
                        fpath = fullfile(c3d_list(kk).folder, c3d_list(kk).name);
                        c3d = ezc3dRead(char(fpath));
                        rate = double(c3d.header.points.frameRate);
                        nFrames = size(c3d.data.points, 3);
                        c3d_sum_sec = c3d_sum_sec + (nFrames - 1) / rate;
                    end
                    % 허용 비율/허용 초 설정
                    short_ratio = 0.9; % c3d 합이 tdms의 90% 미만이면 too short
                    over_eps = 1.0;    % tdms보다 1초 이상 크면 초과
                    if c3d_sum_sec < tdms_dur_sec * short_ratio
                        local_rows(end+1,:) = {sub_name, string(walk), trial_type, "c3d_too_short", sprintf('c3d 합계 길이(%.1fs)가 tdms(%.1fs)에 비해 너무 짧음', c3d_sum_sec, tdms_dur_sec), note_str, ""}; %#ok<AGROW>
                    elseif c3d_sum_sec > tdms_dur_sec + over_eps
                        local_rows(end+1,:) = {sub_name, string(walk), trial_type, "c3d_exceeds_tdms", sprintf('c3d 합계 길이(%.1fs)가 tdms(%.1fs)를 초과', c3d_sum_sec, tdms_dur_sec), note_str, ""}; %#ok<AGROW>
                    end
                    end
                end
            end

            % 안내: walk 검사 완료 및 이슈 개수 출력
            new_rows = size(local_rows, 1) - prev_n;
            fprintf('[로그 점검] %s %s 검사 완료 (이슈 %d건)\n', sub_name, walk, new_rows);
        end
        issues_cells{i} = local_rows;
    end

    p = gcp('nocreate');
	if ~isempty(p), delete(p), end

    all_rows = vertcat(issues_cells{:});
    if isempty(all_rows)
        issues = table('Size', [0 7], 'VariableTypes', {'string','string','string','string','string','string','string'}, ...
            'VariableNames', {'subject','walk','trial','type','message','note','mapping'});
    else
        subject_col = string(all_rows(:, 1));
        walk_col    = string(all_rows(:, 2));
        trial_col   = string(all_rows(:, 3));
        type_col    = string(all_rows(:, 4));
        message_col = string(all_rows(:, 5));
        note_col    = string(all_rows(:, 6));
        mapping_col = string(all_rows(:, 7));
        issues = table(subject_col, walk_col, trial_col, type_col, message_col, note_col, mapping_col, ...
            'VariableNames', {'subject','walk','trial','type','message','note','mapping'});
    end

    % 결과 저장: DATA_DIR/log/log_issues.csv
    out_dir = fullfile(data_dir, 'log');
    if ~isfolder(out_dir)
        mkdir(out_dir);
    end
    out_csv = fullfile(out_dir, 'log_issues.csv');
    writetable(issues, out_csv);
    fprintf('[로그 점검] 이슈 테이블 저장: %s\n', out_csv);
end
