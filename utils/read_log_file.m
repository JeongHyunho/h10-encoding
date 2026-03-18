function [t_log, start_time, end_time, param] = read_log_file(log_file)
%READ_LOG_FILE  H10 외골격 TDMS 로그 파일 파싱
%
%   [t_log, start_time, end_time, param] = READ_LOG_FILE(log_file)
%
%   H10 외골격 제어기의 TDMS 로그 파일을 읽어 시간 벡터와
%   보조 파라미터(swing tmax, stance tmax)를 추출한다.
%   여러 파일이 분할 저장된 경우 재귀적으로 병합한다.
%
%   입력:
%     log_file — TDMS 로그 파일 정보 [struct 또는 struct array]
%                dir() 출력 형식 (folder, name 필드 필수)
%                numel > 1 이면 자동 병합
%
%   출력:
%     t_log      — 로그 타임스탬프 벡터 [datetime array]
%     start_time — 로그 시작 시각 [datetime]
%     end_time   — 로그 종료 시각 [datetime]
%     param      — 보조 파라미터 행렬 [Nx2, swing_tmax / stance_tmax]
%
%   알고리즘:
%     파일명에서 날짜를 추출(read_file_time)하고, TDMS 내 hour/min/sec/ms를
%     결합하여 절대 datetime을 생성한다.
%     다중 파일 입력 시 순차적으로 재귀 호출하여 연결한다.
%
%   참고: get_log_cache, read_fp_table

if numel(log_file) > 1       % 나뉘어 저장된 경우
    t_log = [];
    param = [];

    for i = 1:numel(log_file)
        [t_log_, start_time_, end_time_, param_] = read_log_file(log_file(i));
        t_log = [t_log; t_log_];
        param = [param; param_];

        if i == 1
            start_time = start_time_;
        elseif i == numel(log_file)
            end_time = end_time_;
        end
    end
else
    dt = read_file_time(log_file);
    read = tdmsread(fullfile(log_file.folder, log_file.name));
    tdms_T = read{1};

    t_log = datetime(dt.Year, dt.Month, dt.Day, tdms_T.hour(:), tdms_T.min(:), tdms_T.sec(:), tdms_T.ms(:));
    start_time = ...
        datetime(dt.Year, dt.Month, dt.Day, tdms_T.hour(1), tdms_T.min(1), tdms_T.sec(1), tdms_T.ms(1));
    end_time = ...
        datetime(dt.Year, dt.Month, dt.Day, tdms_T.hour(end), tdms_T.min(end), tdms_T.sec(end), tdms_T.ms(end));
    param = [tdms_T.("swing tmax"), tdms_T.("stance tmax")];
end
end
