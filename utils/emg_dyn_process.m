function rs = emg_dyn_process(emg_file, set_name, evt)
% V3D에서 export된 emg_exported_*.txt 파일을 처리하는 함수
% 입력:
%   emg_file: emg_exported_*.txt 파일 경로
%   set_name: 실험 세트 이름 ('set1' 또는 'set2')
% 출력:
%   rs: 처리된 EMG 데이터 구조체
%       - 필드: 근육명(`VM`, `VM1`, `VL`, `RF`, `RF1`, `RF2`, `BF`, `ST`, `TA`, `GL`, `GM`, `SOL`)
%       - 각 필드 데이터 구조: double 행렬 [시간 샘플 수 x 매핑된 열 수]
%           · 보통 열 수는 1 (헤더 유니크 순서 == mc_list 순서 가정)
%           · 동일 라벨의 중복 열이 존재할 경우 열 수가 1보다 클 수 있음
%       - 값: 외부(V3D)에서 필터링/정류된 값이므로 추가 필터링 없이 그대로 반환

% ─── 입력 인수 처리 ───
if nargin < 3
    evt = [];
end

rs = struct();

% EMG 데이터 읽기
if ~exist(emg_file, 'file')
    warning('EMG 파일이 존재하지 않습니다: %s', emg_file);
    return;
end

% 탭으로 구분된 텍스트 파일 읽기
rd = readcell(emg_file, 'Delimiter', '\t');

% EMG 데이터 추출 (6번째 행부터가 실제 데이터, 첫 번째 열은 프레임 번호이므로 제외)
emg_data_raw = rd(6:end, 2:end);  % 6번째 행부터, 첫 번째 열 제외
emg_data = cell2mat(emg_data_raw);

% ─── EMG 채널 매핑 ───
if strcmp(set_name, 'set1')
    mc_list = {'VM', 'VL', 'RF1', 'RF2', 'BF', 'ST', 'TA', 'GL', 'GM', 'SOL'};
elseif strcmp(set_name, 'set2')
    mc_list = {'VM1', 'VM2', 'VL', 'RF', 'BF', 'ST', 'TA', 'GL', 'GM', 'SOL'};
else
    error('Exception: unknown set_name(%s).\n', set_name)
end

% EMG 채널 수 확인 및 경고
n_channels = length(mc_list);
data_channels = unique(rd(2, 2:end));
n_data_channels = length(data_channels);

if n_data_channels < n_channels
    warning('EMG 채널 수가 부족합니다. 예상: %d, 실제: %d', n_channels, n_data_channels);
    n_channels = n_data_channels;
elseif n_data_channels > n_channels
    warning('EMG 채널 수가 예상보다 많습니다. 예상: %d, 실제: %d', n_channels, n_data_channels);
end

% ─── EMG 신호 처리 ───
% 실제 EMG 채널 이름들 추출 (2번째 행에서)
actual_channels = rd(2, 2:end);

for i = 1:n_channels
    mc_label = mc_list{i};
    
    % 해당 채널 이름과 일치하는 열들 찾기
    channel_indices = find(strcmp(actual_channels, data_channels{i}));
    
    if ~isempty(channel_indices)
        % 해당 채널의 모든 데이터를 concatenate
        sig = emg_data(:, channel_indices);
        
        % stride 정규화된 행렬(301 x N)인 경우, 보폭 기준 outlier 보정 적용
        if isnumeric(sig) && ismatrix(sig) && size(sig,1) == 301 && size(sig,2) > 1
            try
                [~, corrected] = find_emg_outliers(sig, 3);
                sig = corrected;
            catch ME
                fprintf('[EMG 이상치 보정 실패] 채널=%s, 파일=%s\n   ↳ %s\n', mc_label, emg_file, ME.message);
            end
        end
        
        % 외부 프로그램에서 이미 필터링과 정류가 완료된 데이터이므로 그대로 저장
        rs.(mc_label) = sig;
    else
        warning('채널 %s (EMG %d)을 찾을 수 없습니다.', mc_label, i);
    end
end

% ─── 보행 단계/시간 정보 계산 (evt 제공 시) ───
%  - stance_swing: [301 x n_stride] (1: stance, 0: swing)
%  - stride_time : [n_stride x 1]  (각 stride의 총 시간, 초)
rs.stance_swing = [];
rs.stride_time = [];
rs.evt_time = [];

try
    if ~isempty(evt) && isstruct(evt) && isfield(evt, 'rfs')
        rfs = evt.rfs(:);
        if numel(rfs) >= 2
            % stride 시간 (초)
            stride_time_local = diff(rfs);
            % 각 stride 시작 시각(보행 시작 기준, 초)
            evt_time_local = rfs(1:end-1) - rfs(1);

            % RFO가 있으면 stance 비율을 실데이터 기반으로, 없으면 60% 기본값
            hasRfo = isfield(evt, 'rfo') && ~isempty(evt.rfo);
            if hasRfo
                rfo = evt.rfo(:);
            else
                rfo = [];
            end

            n_stride = numel(stride_time_local);
            stance_swing_local = zeros(301, n_stride);
            for k = 1:n_stride
                t0 = rfs(k);
                t1 = rfs(k+1);
                dt = stride_time_local(k);

                if hasRfo
                    % 현재 stride 구간 [t0, t1) 내 첫 번째 RTO 선택
                    rfo_in_stride = rfo(rfo > t0 & rfo < t1);
                    if ~isempty(rfo_in_stride)
                        t_footoff = rfo_in_stride(1);
                        stance_ratio = max(0, min(1, (t_footoff - t0) / max(dt, eps)));
                    else
                        stance_ratio = 0.6; % 구간 내 RFO가 없으면 기본 60%
                    end
                else
                    stance_ratio = 0.6; % RFO가 없으면 기본 60%
                end

                % 301 포인트 기준 마스크 생성 (행=301 포인트, 열=보폭)
                n_stance_pts = max(0, min(301, round(stance_ratio * 301)));
                if n_stance_pts > 0
                    stance_swing_local(1:n_stance_pts, k) = 1;
                end
            end

            % ─── evt ↔ EMG 보폭 수 일치성 검사 (정규화된 EMG가 들어온 경우에 한함) ───
            % 기준: EMG 필드 중 하나라도 301 x N 형태면 N을 보폭 수로 간주
            emg_stride_count = NaN;
            probe_labels = mc_list;
            for probe_i = 1:numel(probe_labels)
                lbl = probe_labels{probe_i};
                if isfield(rs, lbl) && ~isempty(rs.(lbl))
                    s = rs.(lbl);
                    if isnumeric(s) && ismatrix(s) && size(s,1) == 301
                        emg_stride_count = size(s, 2);
                        break
                    end
                end
            end

            if ~isnan(emg_stride_count) && emg_stride_count ~= n_stride
                warning('[emg_dyn_process] evt stride count(%d) and EMG stride count(%d) mismatch. stance_swing/stride_time cleared.', ...
                    n_stride, emg_stride_count);
                rs.stance_swing = [];
                rs.stride_time = [];
                rs.evt_time = [];
            else
                rs.stance_swing = stance_swing_local;
                rs.stride_time = stride_time_local(:);
                rs.evt_time = evt_time_local(:);
            end
        end
    end
catch ME
    % 이벤트 파싱 실패 시 식별 가능한 정보와 함께 알림
    [sub_name_info, walk_idx_info, dyn_idx_info] = parse_emg_file_info(emg_file);
    fprintf('[EMG 이벤트 파싱 실패] 피험자=%s, 보행=%s, 시도=%s, 파일=%s\n   ↳ %s\n', ...
        sub_name_info, walk_idx_info, dyn_idx_info, emg_file, ME.message);
    % 빈 값 유지
end

end

% ─── Local helper: Parse subject/walk/dyn from emg_file path ───
function [sub_name, walk_idx, dyn_idx] = parse_emg_file_info(emg_file)
sub_name = 'unknown'; walk_idx = 'unknown'; dyn_idx = 'unknown';
try
    tok = regexp(emg_file, 'S\d{3}', 'match');
    if ~isempty(tok), sub_name = tok{1}; end
    tok = regexp(emg_file, 'walk(\d+)', 'tokens');
    if ~isempty(tok), walk_idx = tok{1}{1}; end
    tok = regexp(emg_file, 'emg_exported_(\d+)', 'tokens');
    if ~isempty(tok), dyn_idx = tok{1}{1}; end
catch
    % ignore
end
end
