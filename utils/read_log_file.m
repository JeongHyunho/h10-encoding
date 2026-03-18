function [t_log, start_time, end_time, param] = read_log_file(log_file)
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
