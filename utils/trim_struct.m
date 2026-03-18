function s_trimmed = trim_struct(s, str_contain, str_not)

fields = fieldnames(s);
s_trimmed = struct();

for i = 1:length(fields)
    name = fields{i};
    if contains(name, str_contain) && ~contains(name, str_not)
        s_trimmed.(name) = s.(name);
    end
end

end
