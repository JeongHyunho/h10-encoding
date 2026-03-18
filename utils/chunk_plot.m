function handle = chunk_plot(ph_data, color, alpha)
if nargin < 3
    alpha = 0.5;
end

[rows, cols] = size(color);
if rows > 1 && cols > 1
    mat_color = true;
else
    mat_color = false;
end

[n_line, n_pts] = size(ph_data, 1, 2);
x = linspace(0, 100, n_pts);
hold on
for i = 1:n_line-1
    if mat_color
        c = color(i, :);
    else
        c = color;
    end
    plot(x, ph_data(i, :), 'Color', [c, alpha], 'LineWidth', 1);
end

if mat_color
        c = color(n_line, :);
    else
        c = color;
end
handle = plot(x, ph_data(n_line, :), 'Color', [c, alpha], 'LineWidth', 1);
hold off
end
