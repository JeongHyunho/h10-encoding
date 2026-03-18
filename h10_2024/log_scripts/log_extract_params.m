function log_rs = log_extract_params(idx_info, sub_info, param, data_dir, sub_pass)
% 로그 파라미터/시계열 추출
% - 각 피험자/보행별 로그(.tdms)를 읽어 시간과 파라미터를 병합
% - 보행 단위 중앙값 파라미터 계산(p_median)

    arguments
        idx_info (1,1) struct
        sub_info table
        param table
        data_dir (1,1) string
        sub_pass (1,1) double = 2
    end

    walks = param.Properties.VariableNames(2:end);
    log_rs = struct();

    for i = 1+sub_pass:height(sub_info)
        sub_name = sub_info.ID(i);

        sub_rs = struct();

        for j = 1:numel(walks)
            walk = walks{j};
            if strcmp(param(i, :).(walk), "null")
                continue
            end

            log_dir = dir(fullfile(data_dir, 'log', sub_name, [walk, '*.tdms']));
            log_file = log_dir(arrayfun(@(x) ~isempty(regexp(x.name, ['^', walk, '(_\d+)?\.tdms'], 'once')), log_dir));

            if isempty(log_file)
                continue
            end

            % 여러 로그 파일의 시간/파라미터 병합
            log_t = datetime.empty(0,1);
            log_p = [];
            for k = 1:numel(log_file)
                [t_log, ~, ~, p] = read_log_file(log_file(k));
                log_t = [log_t; t_log]; %#ok<AGROW>
                log_p = [log_p; p]; %#ok<AGROW>
            end

            walk_rs = struct();
            walk_rs.log_t = log_t;
            walk_rs.log_p = log_p;
            if ~isempty(log_p)
                walk_rs.p_median = median(log_p, 1);
            else
                walk_rs.p_median = [nan, nan];
            end
            walk_rs.n_logs = numel(log_file);
            walk_rs.double_log = numel(log_file) > 1;

            sub_rs.(walk) = walk_rs;
        end

        log_rs.(sub_name) = sub_rs;
    end
end


