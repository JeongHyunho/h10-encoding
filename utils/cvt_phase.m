function data_ph = cvt_phase(data_ch, num_pts)
data_ph = struct();
fields = fieldnames(data_ch);

for i = 1:length(fields)
    name = fields{i};
    if ismember(name, {'Properties', 'Row', 'Variables'})
        continue
    end

    if isstruct(data_ch.(name))
        data_ph.(name) = cvt_phase(data_ch.(name), num_pts);
    else
        ch_cell = data_ch.(name);
        num_cell = length(ch_cell);
        ph_mat = zeros(num_cell, num_pts);

        for j = 1:num_cell
            v = ch_cell{j};
            x = 1:length(v);
            xq = linspace(1, length(v), num_pts);
            ph_mat(j, :) = interp1(x, v, xq);
        end

        data_ph.(name) = ph_mat;
%         data_ph.([name, '_mean']) = mean(ph_mat, 1)';
%         data_ph.([name, '_std']) = std(ph_mat, 0, 1)';
    end
end
end
