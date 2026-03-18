function [t_avg, x_avg] = trial_avg(t_cell, x_cell)
t_min = inf;
t_max = -inf;
for i = 1:length(t_cell)
    t_data = t_cell{i};
    if t_data(1) < t_min
        t_min = t_data(1);
    end
    if t_data(end) > t_max
        t_max = t_data(end);
    end
end

t = t_min:t_max;
x = [];
for i = 1:length(x_cell)
    t_data = t_cell{i};
    x_data = x_cell{i};

    [~, uniq_idx] = unique(t_data, 'first');
    x_data = x_data(uniq_idx);
    t_data = t_data(uniq_idx);

    x = [x; interp1(t_data, x_data, t, 'linear', nan)];
end

t_avg = t';
x_avg = mean(x, 1, 'omitnan')';
end
