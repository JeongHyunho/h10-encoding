function cache = get_log_cache(log_rs, sub_name, walk)
%GET_LOG_CACHE  로그 캐시 구조체에서 특정 참여자/walk의 데이터 조회
%
%   cache = GET_LOG_CACHE(log_rs, sub_name, walk)
%
%   encode_all.m 등에서 사전 파싱된 로그 캐시(log_rs)로부터
%   특정 참여자와 walk의 시간, 파라미터 데이터를 안전하게 추출한다.
%   해당 데이터가 없으면 기본값(available=false)을 반환한다.
%
%   입력:
%     log_rs   — 로그 캐시 구조체 [struct] (필드: sub_name.walk.*)
%                빈 배열 또는 비구조체이면 기본 cache 반환
%     sub_name — 참여자 식별 필드명 [char, 예: 'S001']
%     walk     — walk 식별 필드명 [char, 예: 'walk01']
%
%   출력:
%     cache — 조회 결과 구조체 [struct]
%       .available  — 데이터 존재 여부 [logical]
%       .log_t      — 로그 타임스탬프 [datetime array]
%       .log_p      — 보조 파라미터 [Nx2]
%       .p_median   — 파라미터 중앙값 [1x2, 기본값: NaN NaN]
%       .double_log — 분할 로그 여부 [logical]
%       .log_start  — 로그 시작 시각 [datetime]
%       .log_end    — 로그 종료 시각 [datetime]
%       .t_ranges   — 시간 범위 정보 []
%
%   참고: read_log_file

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
