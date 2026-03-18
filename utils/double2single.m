function s_out = double2single(s_in)

fields = fieldnames(s_in);
s_out = s_in;

for i = 1:length(fields)
    name = fields{i};
    if isstruct(s_in.(name))
        s_out.(name) = double2single(s_in.(name));
    elseif isnumeric(s_in.(name))
            s_out.(name) = single(s_in.(name));
    else
        s_out.(name) = s_in.(name);
    end
end
end