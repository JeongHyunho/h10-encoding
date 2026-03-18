function cat_s = cat_struct(sa, sb)

cat_s = struct();
fields = fieldnames(sa);
assert(all(cellfun(@strcmp, fields, fields)), 'different fields in two structs!')

for i = 1:length(fields)
    name = fields{i};
    value_a = sa.(name);
    if ~ismember(name, fieldnames(sb))
        warning('CatStruct:NotCommon', '%s is in struct A, but not in B. Ignrored.', name)
        continue
    else
        value_b = sb.(name);
    end

    if isstruct(value_a)
        cat_s.(name) = cat_struct(value_a, value_b);
    else
        cat_s.(name) = [value_a; value_b];
    end
end

end
