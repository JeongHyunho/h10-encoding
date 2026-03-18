function [start_time, write_time] = read_fp_time(fp_file, freq)
if numel(fp_file) > 1       % 나뉘어 저장된 경우
    [start_time, ~] = read_fp_time(fp_file(1), freq);
    [~, write_time] = read_fp_time(fp_file(end), freq);
else
    write_time = read_file_time(fp_file);

    read = tdmsread(fullfile(fp_file.folder, fp_file.name));
    tdms_T = read{1};

    start_time = write_time - seconds(height(tdms_T) / freq);
end
end
