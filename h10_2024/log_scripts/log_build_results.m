function log_rs = log_build_results(idx_info, sub_info, param, data_dir, sub_pass, issues)
% 로그 파라미터/시계열 추출 + 연속 조건 병합을 통합 수행
% - issues 테이블을 입력 받아 issue.type 별 특이 처리를 할 수 있도록 구조화

    arguments
        idx_info (1,1) struct
        sub_info table
        param table
        data_dir (1,1) string
        sub_pass (1,1) double = 2
        issues table = table()
    end

    walks = param.Properties.VariableNames(2:end);
    log_rs = struct();

    % 이슈 테이블 인덱싱 준비
    has_issues = istable(issues) && ~isempty(issues) && ...
        all(ismember({'subject','walk','type'}, issues.Properties.VariableNames));

    for i = 1+sub_pass:height(sub_info)
        sub_name = sub_info.ID(i);
        sub_out = struct();

        for j = 1:numel(walks)
            walk = walks{j};
            if strcmp(param(i, :).(walk), "null")
                continue
            end

            % 이슈 필터 (해당 subject/walk에 해당하는 모든 이슈 수집)
            if has_issues
                issue_rows = issues(issues.subject == sub_name & issues.walk == string(walk), :);
            else
                issue_rows = table();
            end

            % 로그 파일 수집
            log_dir = dir(fullfile(data_dir, 'log', sub_name, [walk, '*.tdms']));
            log_file = log_dir(arrayfun(@(x) ~isempty(regexp(x.name, ['^', walk, '(_\d+)?\.tdms'], 'once')), log_dir));
            if isempty(log_file)
                % 로그 없음: 이슈가 따로 저장되어 있을 것이므로 건너뜀
                continue
            end

            % 통합 결과 컨테이너
            walk_rs = struct();

            % 공통 수집: 원시 로그 시계열 및 파라미터
            log_t = datetime.empty(0,1);
            log_p = [];
            for k = 1:numel(log_file)
                [t_log, ~, ~, p] = read_log_file(log_file(k));
                log_t = [log_t; t_log]; %#ok<AGROW>
                log_p = [log_p; p]; %#ok<AGROW>
            end
            if ~isempty(log_p)
                walk_rs.p_median = median(log_p, 1);
            else
                walk_rs.p_median = [nan, nan];
            end
            walk_rs.log_t = log_t;
            walk_rs.log_p = log_p;

            % 특이 처리 훅: issue.type 에 따라 처리 분기할 수 있도록 구조만 마련
            % 예) multi_tdms: 병합 시 마지막 10초 트리밍 등
            do_trim_10s = any(strcmp(string(issue_rows.type), "multi_tdms"));

            % 연속 조건 처리: t_rel/p_rel 생성 및 병합
            is_cont = false;
            if isfield(idx_info.(sub_name), 'cont')
                is_cont = ismember(j, idx_info.(sub_name).cont);
            end
            if is_cont
                t_rel_all = [];
                p_all = [];
                % 전체 시작 시각 계산: 첫 파일의 첫 샘플 기준
                [t0_first, ~, ~, ~] = read_log_file(log_file(1));
                if isempty(t0_first)
                    % 비어있으면 스킵
                else
                    t0 = t0_first(1);
                    for k = 1:numel(log_file)
                        [t_log, ~, ~, p] = read_log_file(log_file(k));
                        if isempty(t_log)
                            continue
                        end
                        if do_trim_10s && k < numel(log_file)
                            t_keep_end = t_log(end) - seconds(10);
                            trim_idx = t_log > t_keep_end;
                            p(trim_idx, :) = NaN;
                        end
                        t_rel = seconds(t_log - t0);
                        t_rel_all = [t_rel_all; t_rel]; %#ok<AGROW>
                        p_all = [p_all; p]; %#ok<AGROW>
                    end
                end
                walk_rs.t_rel = t_rel_all;
                walk_rs.p_rel = p_all;
                walk_rs.double_log = numel(log_file) > 1;
            end

            % 이슈 기록 및 오프셋 메타 보관
            if has_issues
                walk_rs.issues = issue_rows;
            end

            sub_out.(walk) = walk_rs;
        end

        log_rs.(sub_name) = sub_out;
    end

    % 전역 메타
    log_rs_meta = struct();
    log_rs_meta.created_at = datetime('now');
    log_rs_meta.note = "built by log_build_results with issues";
    log_rs.meta = log_rs_meta;
end

