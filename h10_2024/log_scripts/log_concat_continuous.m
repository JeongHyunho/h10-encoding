function log_rs = log_concat_continuous(log_rs, idx_info, sub_info, param, data_dir, sub_pass)
% 연속(continuous) 조건 로그 병합/정리
% - 여러 개로 끊어진 연속 로그를 시간 정렬/병합
% - 파일이 여러 개인 경우 마지막 구간 10초 제외 규칙 적용 (encode_all 준용)
% - 전체 시작 시각 기준 상대시간(sec) 벡터 생성

    arguments
        log_rs (1,1) struct
        idx_info (1,1) struct
        sub_info table
        param table
        data_dir (1,1) string
        sub_pass (1,1) double = 2
    end

    walks = param.Properties.VariableNames(2:end);

    for i = 1+sub_pass:height(sub_info)
        sub_name = sub_info.ID(i);
        if ~isfield(idx_info, sub_name) || ~isfield(log_rs, sub_name)
            continue
        end
        info = idx_info.(sub_name);

        for j = reshape(info.cont, 1, [])
            if isnan(j) || j <= 0 || j > numel(walks)
                continue
            end
            walk = walks{j};
            if ~isfield(log_rs.(sub_name), walk)
                % 원 데이터가 없으면 파일 시스템에서 직접 처리 시도
                log_dir = dir(fullfile(data_dir, 'log', sub_name, [walk, '*.tdms']));
                log_file = log_dir(arrayfun(@(x) ~isempty(regexp(x.name, ['^', walk, '(_\d+)?\.tdms'], 'once')), log_dir));
                if isempty(log_file)
                    continue
                end
            else
                % 파일 목록 재구성 (상대시간 계산 위해 파일 경계 필요)
                log_dir = dir(fullfile(data_dir, 'log', sub_name, [walk, '*.tdms']));
                log_file = log_dir(arrayfun(@(x) ~isempty(regexp(x.name, ['^', walk, '(_\d+)?\.tdms'], 'once')), log_dir));
            end

            t_rel_all = [];
            p_all = [];
            if isempty(log_file)
                continue
            end

            % 전체 시작 시각 (첫 파일의 첫 샘플)
            [t0_first, ~, ~, ~] = read_log_file(log_file(1));
            if isempty(t0_first)
                continue
            end
            t0 = t0_first(1);

            for k = 1:numel(log_file)
                [t_log, ~, ~, p] = read_log_file(log_file(k));
                if isempty(t_log)
                    continue
                end
                % 여러 로그가 있으면(깨짐) 마지막 10초 제외 (마지막 파일 제외)
                if numel(log_file) > 1 && k < numel(log_file)
                    t_keep_end = t_log(end) - seconds(10);
                    keep_idx = t_log <= t_keep_end;
                    t_log = t_log(keep_idx);
                    p = p(keep_idx, :);
                end

                t_rel = seconds(t_log - t0);
                t_rel_all = [t_rel_all; t_rel]; %#ok<AGROW>
                p_all = [p_all; p]; %#ok<AGROW>
            end

            if ~isfield(log_rs.(sub_name), walk)
                log_rs.(sub_name).(walk) = struct();
            end
            log_rs.(sub_name).(walk).t_rel = t_rel_all;
            log_rs.(sub_name).(walk).p_rel = p_all;
            log_rs.(sub_name).(walk).double_log = numel(log_file) > 1;
        end
    end
end
