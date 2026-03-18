function [ph, hh] = pretty_box(x, y, varargin)
%   Examples:
%       pretty_box(1, linspace(0, 10, 10), 'color', 'b', 'alpha', 0.5, 'hatch', 'on', 'whisker', 1.5, 'width', 0.5, 'outlier', 'on')

assert(isscalar(x), "첫 번째 입력 변수는 스칼라 변수여야 함")
assert(isvector(x) && length(y) > 1, "두 번째 입력 변수는 길이가 1보다 큰 벡터여야 함")

p = inputParser;
addParameter(p, 'color', [1, 1, 1], @(x) ischar(x) || (isvector(x) && numel(x) == 3));
addParameter(p, 'alpha', 0.7,  @isscalar);
addParameter(p, 'hatch', 'off',  @ischar);
addParameter(p, 'whisker', 1.5,  @isscalar);
addParameter(p, 'width', 0.3,  @isscalar);
addParameter(p, 'linewidth', 0.5,  @isscalar);
addParameter(p, 'outlier', 'on',  @ischar);
parse(p, varargin{:});
c =  p.Results.color;
ap = p.Results.alpha;
whisker = p.Results.whisker;
w = p.Results.width;
line_width = p.Results.linewidth;
hatch_on = p.Results.hatch;
outlier = p.Results.outlier;

n_pts = numel(y);
bh = boxplot(y, 'Notch', 'off', 'FactorGap', 1, 'Positions', x, 'Labels', '', 'Whisker', whisker, 'Widths', w);

% boxplot handles:
% 1. Upper Whisker
% 2. Lower Whisker
% 3. Upper Adjacent value
% 4. Lower Adjacent value
% 5. Box
% 6. Median
% 7. Outliers
set(bh(1), 'LineStyle', '-')
set(bh(2), 'LineStyle', '-')
set(bh(5), 'Color', c)
set(bh(5), 'LineStyle', 'none')
set(bh(7), 'Visible', outlier)
ph = patch(get(bh(5),'XData'), get(bh(5),'YData'), c, 'FaceAlpha', ap, 'LineWidth', line_width, 'EdgeColor', 'k');
if strcmp(hatch_on, 'on')
    oh = patch(get(bh(5),'XData'), get(bh(5),'YData'), 'w', 'FaceColor', 'none', 'EdgeColor', c);
    hh = hatchfill(oh);
    set(hh, 'Color', 'w');
    set(hh, 'LineWidth', 1.5);
    patch(get(bh(5),'XData'), get(bh(5),'YData'), 'w', 'FaceColor', 'none', 'EdgeColor', 'k', 'LineWidth', line_width);
    plot(get(bh(6), 'XData'), get(bh(6), 'YData'), 'Color', 'k', 'LineWidth', line_width);
else
    hh = [];
end
set(bh(6), 'Color', 'k', 'LineWidth', line_width)

for i = 1:7
    set(bh(i), 'Tag', sprintf('%s%d', get(bh(i), 'Tag'), i));
end
set(get(bh(1), 'Parent'), 'Tag', num2str(x))

% mean
hold on, scatter(x, mean(y), 60, 'k', 'filled', 'square')

end
