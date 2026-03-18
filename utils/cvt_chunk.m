function data_ch = cvt_chunk(data, evt, fq_ratio)
data_ch = struct();
fields = fieldnames(data);

for i = 1:length(fields)
    name = fields{i};
    if ismember(name, {'infos'})
        continue
    end

    if isstruct(data.(name))
        data_ch.(name) = cvt_chunk(data.(name), evt, fq_ratio);
    else
        ch_cell = cell(length(evt), 1);
        for j = 1:length(evt)
            signal = data.(name);
            span = round(evt(j, 1)/fq_ratio):round(evt(j, 2)/fq_ratio);
            ch_cell{j} = signal(span);
        end
        data_ch.(name) = ch_cell;
    end
end
end