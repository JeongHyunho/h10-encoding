function data_trial = cvt_trial(data, hs, fq_ratio, out_ratio)
data_trial = struct();
fields = fieldnames(data);

for i = 1:length(fields)
    name = fields{i};
    if ismember(name, {'infos'})
        continue
    end

    if isstruct(data.(name))
        data_trial.(name) = cvt_trial(data.(name), hs, fq_ratio, out_ratio);
    else
        signal = data.(name);
        span = 1 + (round((hs(1)-1)/fq_ratio):round((hs(end)-1)/fq_ratio));
        tar_sig = signal(span);
        if fq_ratio ~= out_ratio
            out_span = 1 + (round((hs(1)-1)/out_ratio):round((hs(end)-1)/out_ratio));
            out_int =  linspace(span(1), span(end), length(out_span));
            out_sig = interp1(span, tar_sig, out_int)';
        else
            out_sig = tar_sig;
        end
        data_trial.(name) = out_sig;
    end
end
end
