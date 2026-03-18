function cache = get_log_cache(log_rs, sub_name, walk)
%GET_LOG_CACHE Return cached log data for encode_all.m.

cache = struct( ...
    'available', false, ...
    'log_t', [], ...
    'log_p', [], ...
    'p_median', [nan nan], ...
    'double_log', false, ...
    'log_start', NaT, ...
    'log_end', NaT, ...
    't_ranges', [] ...
    );

if isempty(log_rs) || ~isstruct(log_rs)
    return
end
if ~isfield(log_rs, sub_name)
    return
end
sub_rs = log_rs.(sub_name);
if ~isstruct(sub_rs) || ~isfield(sub_rs, walk)
    return
end

walk_rs = sub_rs.(walk);
if ~isfield(walk_rs, 'log_t') || isempty(walk_rs.log_t)
    return
end

cache.available = true;
cache.log_t = walk_rs.log_t;
if isfield(walk_rs, 'log_p')
    cache.log_p = walk_rs.log_p;
end
if isfield(walk_rs, 'p_median')
    cache.p_median = walk_rs.p_median;
end
if isfield(walk_rs, 'double_log')
    cache.double_log = logical(walk_rs.double_log);
end

if ~isempty(cache.log_t)
    cache.log_start = cache.log_t(1);
    cache.log_end = cache.log_t(end);
end
if isfield(walk_rs, 't_ranges')
    cache.t_ranges = walk_rs.t_ranges;
end
end
