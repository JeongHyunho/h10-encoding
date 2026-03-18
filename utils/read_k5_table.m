function k5_table = read_k5_table(k5FilePath)
measures = {'t', 'Rf', 'VT', 'VE', 'VO2', 'VCO2', 'RQ', 'VE/VO2', ...
    'VO2/Kg', 'METS', 'HR', 'VO2/HR', 'EEm', 'EEh'};
C = readcell(k5FilePath);

idx = 1;
var_names = cell(size(measures));
data = cell(size(measures));
for i = 10:69
    name = C{1, i};
    if ~ismember(name, measures)
        continue
    end

    if strcmp(name, 't')
        data{idx} = 24 * 3600 * cell2mat(C(4:end, i));
    else
        target = C(4:end, i);
        for j = 1:length(target)
            if ischar(target{j})
                target{j} = NaN;
            end
        end
        data{idx} = cell2mat(target);
    end
    var_names{idx} = replace(name, '/', 'Per');
    idx = idx + 1;
end

var_names_ = var_names(~cellfun(@isempty, data));
data_ = data(~cellfun(@isempty, data));

k5_table = table(data_{:}, 'VariableNames', var_names_);

% time uniqueness
[~, idx, ~] = unique(k5_table.t);
k5_table = k5_table(idx, :);
end
