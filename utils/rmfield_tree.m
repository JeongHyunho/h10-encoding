function s_removed = rmfield_tree(s, str_contain, str_not)
% str_contain 포함하고, str_not 포함하고 있지 않으면 삭제

fields = fieldnames(s);
s_removed = struct();

for i = 1:length(fields)
    name = fields{i};
    if ~(contains(name, str_contain) && ~contains(name, str_not))
        if isstruct(s.(name))
            s_removed.(name) = rmfield_tree(s.(name), str_contain, str_not);
        else
            s_removed.(name) = s.(name);
        end
    end
end

end
