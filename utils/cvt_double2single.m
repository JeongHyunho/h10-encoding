function s = cvt_double2single(data)

    s = struct();
    fields = fieldnames(data);

    for i = 1:length(fields)
        name = fields{i};
        if ismember(name, {'infos'})
            continue
        end

        if isstruct(data.(name))
            s.(name) = cvt_double2single(data.(name));
        else
            signal = data.(name);
            if isa(signal, 'double')
                s.(name) = single(signal);
            else
                s.(name) = signal;
            end
        end
    end

end
