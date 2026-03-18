function [start_time, dur, end_time] = read_k5_time(k5FilePath)

if exist(k5FilePath, "file")
    C = readcell(k5FilePath);

    ymd = C{1, 5};
    hms = C{2, 5};
    hms = strrep(hms, 'PM', '오후');
    hms = strrep(hms, 'AM', '오전');

    start_time = datetime([ymd, ' ', hms], 'InputFormat', 'yyyy-MM-dd a hh:mm:ss', 'Locale', 'ko_KR');
    dur = seconds(24 * 3600 * C{4, 5});
    end_time = start_time + dur;
else
    start_time = nan;
    dur = nan;
    end_time = nan;
end
end
