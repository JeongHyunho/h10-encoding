function colors = speed2color(speed, anchor)
%   Examples:
%       speed = [1, 2, 3]';
%       anchor = [1, 3];
%       colors = speed2color(speed, anchor);

anchor = sort(anchor);
assert(min(speed) >= min(anchor) && max(speed) <= max(anchor))

n_anchor = numel(anchor);
% c_anchor = distinguishable_colors(n_anchor);

% colors = [];
% for i = 1:3
%     c_ = interp1(anchor, c_anchor(:, i), speed);
%     colors = [colors, c_(:)];
% end
% end

colors = turbo(numel(speed));
[~, I] = sort(speed);
inverse= zeros(size(speed));
inverse(I) = 1:numel(speed);
colors = colors(inverse, :);
