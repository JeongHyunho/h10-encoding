function trial = map_time_to_trials(t_k5, t_ranges)
%MAP_TIME_TO_TRIALS Map timestamps to trial indices based on ranges.

trial = ones(size(t_k5));
if isempty(t_ranges)
    return
end

for i = 1:size(t_ranges, 1)
    in_range = t_ranges(i, 1) <= t_k5 & t_k5 <= t_ranges(i, 2);
    trial(in_range) = i;
end
end
