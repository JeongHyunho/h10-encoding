function valid_emg_labels = emg_raw_txt_plot(emg_data, filename, evt, type)
%==========================================================================
% emg_raw_txt_plot(emg_data, filename, evt, type)
%
% ⦿ 기능:
%   - emg_data 구조체에서 이미 처리된 EMG 데이터를 시각화
%   - 이벤트 데이터를 활용한 보행 단계 표시
%   - 결과를 PNG 이미지로 저장
%
% ⦿ 처리 요약(중요):
%   - 보폭 선택: 이벤트의 `rfs`에서 산출한 `ss_idx`(steady-state)로 정상 상태 보폭만 선택
%   - 이상치 탐지/제거: `find_emg_outliers()`로 평균 보폭 파형 대비 RMSE 기반 이상치 보폭을 탐지 후 해당 열을 NaN 마스킹
%       · 시각화에서 outlier 보폭은 원본 파형을 빨간 얇은 선으로 오버레이
%   - 이상 채널 판정: `is_abnormal_emg()`는 이상치 제거 전 원본 보폭 데이터(`sig_raw`)로 수행
%   - 플로팅/집계: 평균 및 표준편차, 회색 개별 보폭 플롯은 이상치 제거 후 데이터로 계산/표시
%   - 제목: 사용 보폭 수와 outlier 비율(%)만 간결히 표기
%
% ⦿ 입력:
%   - emg_data: emg_dyn_process에서 생성된 EMG 데이터 구조체 (필수)
%   - filename: 저장할 이미지 파일명 (예: 'S001_walk1_dyn01.png')
%   - evt: 이벤트 데이터 구조체 (선택적)
%   - type: 실험 조건 타입 (선택적)
%==========================================================================

% ─── 입력 인수 처리 ───
if nargin < 3
    evt = [];
end
if nargin < 4
    type = '';
end

% ─── EMG 채널 수 고정 ───
% 데이터 구조 상 EMG 채널 수는 항상 10개로 가정
n_muscles = 10;

% ─── 정상 상태 보폭 추출 ───
if ~isempty(evt) && isstruct(evt) && isfield(evt, 'rfs')
    % RFS 데이터 길이 확인
    if max(evt.rfs) < 30
        warning('[%s] RFS 데이터가 너무 짧습니다. 최소 30초 이상의 데이터가 필요합니다. (현재: %.1f초)', filename, max(evt.rfs));
        valid_emg_labels = zeros(1, n_muscles); % 모든 채널을 invalid로 설정
        return
    end
    
    % 전체 RFS 개수 계산 (정상 상태가 아닌 전체)
    n_cycles = length(evt.rfs) - 1;  % 마지막 RFS 제거 (완전한 보행 사이클만 사용)
    
    % steady-state 판별 조건
    if max(evt.rfs) < 120 || strcmp(type, 'cont') || strcmp(type, 'unknown')
        ss_idx = true(size(evt.rfs));  % 전체 사용
    else
        rfs_end = evt.rfs(end);
        ss_idx = rfs_end-120 < evt.rfs & evt.rfs < rfs_end-30;  % 후반 steady 주기
    end
    
    % steady-state RFS만 선택 (마지막 데이터 제외)
    ss_rfs = evt.rfs(ss_idx);
    ss_rfs = ss_rfs(1:end-1);  % 마지막 RFS 제거 (완전한 보행 사이클만 사용)
    
    % ss_rfs가 비어있는지 확인
    if isempty(ss_rfs)
        error('[%s] 유효한 steady-state RFS가 없습니다. 이벤트 데이터를 확인해주세요.', filename);
    end
else
    error('[%s] 이벤트 데이터가 없거나 RFS 필드가 없습니다.', filename);
end

% ─── EMG 신호 선택 ───
muscle_names = fieldnames(emg_data);  % 근육 이름 목록

% 채널 수 검증 (항상 10개여야 함)
if length(muscle_names) ~= n_muscles
    error('[%s] EMG 근육 채널 수(%d)가 기대값(%d)과 다릅니다. 입력 데이터 또는 채널 매핑을 확인하세요.', ...
        filename, length(muscle_names), n_muscles);
end

% ─── Figure 설정 ───
fh = figure('Position', [0, 0, 600, 800], 'Visible', 'off');

% ─── 각 EMG 채널마다 시각화 ───
valid_emg_labels = zeros(1, n_muscles);  % 1부터 n_muscles까지의 채널 insanity (1: 정상, 0: 이상)
for i = 1:n_muscles
    muscle_name = muscle_names{i};
    sig = emg_data.(muscle_name);

    % subplot 배치 (1열로 배치)
    ax = subplot(n_muscles, 1, i);

    % 데이터 시각화
    if isvector(sig)
        % 1차원 벡터인 경우 - 예상치 못한 데이터
        warning('[%s] 예상치 못한 1차원 데이터입니다. EMG 데이터는 2차원 행렬(시간 x 보폭)이어야 합니다.', filename);
        valid_emg_labels = zeros(1, n_muscles); % 모든 채널을 invalid로 설정
        return
    else
        % 2차원 행렬인 경우 (정규화된 시간 x 보폭 수)
        % 데이터 크기 확인
        [n_time, n_strides] = size(sig);
        
        % ss_rfs 크기와 sig의 보폭 수 비교
        if n_cycles ~= n_strides
            warning('[%s] ss_rfs 크기(%d)와 sig의 보폭 수(%d)가 일치하지 않습니다.', filename, n_cycles, n_strides);
            valid_emg_labels = zeros(1, n_muscles); % 모든 채널을 invalid로 설정
            return
        end
        
        if n_time > 0 && n_strides > 0  
            % ss_idx를 사용해서 해당하는 보폭들만 선택
            % ss_idx는 논리적 마스크이므로 find()로 인덱스 변환
            valid_strides_idx = find(ss_idx);
            valid_strides_idx = valid_strides_idx(1:end-1);  % 마지막 RFS 제거 (완전한 보행 사이클만 사용)
            sig = sig(:, valid_strides_idx);
            n_valid_strides = length(valid_strides_idx);
            
            % EMG 데이터에서 outlier 제거 (RMSE 기반, 평균 대비 편차)
            sig_raw = sig;  % outlier 시각화용 원본 보관
            if strcmp(type, 'cont')
                % 연속 조건(cont)에서는 outlier 제거 및 표시를 스킵
                outlier_strides = [];
                % sig는 원본 유지
            else
                [outlier_strides, sig] = find_emg_outliers(sig, 3);
            end
            
            % 모든 보행 phase: 0~100%
            ph = linspace(0, 100, n_time);
            
            % 모든 stride: 얇은 회색
            for stride_idx = 1:n_valid_strides
                plot(ph, sig(:, stride_idx), 'Color', [0.3, 0.3, 0.3, 0.1]), hold on
            end
            
            % outlier로 제거된 보폭들을 빨간 얇은 선으로 표시 (원본 파형 사용)
            if ~isempty(outlier_strides)
                for outlier_idx = outlier_strides
                    plot(ph, sig_raw(:, outlier_idx), 'Color', [1, 0, 0, 0.3], 'LineWidth', 1), hold on
                end
            end
            
            % 평균 파형과 표준편차
            sig_m = mean(sig, 2, 'omitnan');  % 평균 파형
            sig_s = std(sig, [], 2, 'omitnan');  % 표준편차
            
            % 표준편차 음영
            patch([ph, flip(ph)], [sig_m+sig_s; flip(sig_m-sig_s)], ...
                'b', 'FaceAlpha', 0.1, 'EdgeColor', 'none')
            
            % 평균 파형
            plot(ph, sig_m, 'b', 'LineWidth', 2)

            % Y축 범위: 평균 ± k*표준편차 기준으로 설정 (outlier의 극값 영향 제거)
            k_std = 3;  % 표준편차 계수
            y_low = min(sig_m - k_std*sig_s, [], 'omitnan');
            y_high = max(sig_m + k_std*sig_s, [], 'omitnan');
            if ~isfinite(y_low) || ~isfinite(y_high)
                % 비정상 값인 경우 전체 신호 범위로 대체
                y_low = min(sig(:), [], 'omitnan');
                y_high = max(sig(:), [], 'omitnan');
            end
            if ~isfinite(y_low) || ~isfinite(y_high)
                y_low = -1; y_high = 1; % 최후의 안전장치
            end
            if y_high <= y_low
                pad = max(1e-3, 0.1*abs(y_high));
                ylim([y_low - pad, y_high + pad])
            else
                pad = 0.05 * (y_high - y_low);
                ylim([y_low - pad, y_high + pad])
            end
            
            xlim([0, 100])
            set(gca, 'Color', 'none')
            
            % is_abnormal_emg 함수를 사용하여 insanity 판단
            % sig를 transpose하여 (보폭 수 x 시간) 형태로 변환
            sig_transposed = sig_raw';  % [n_strides x n_time] 형태로 변환
            [isAbnormal, reason] = is_abnormal_emg(sig_transposed);
            valid_emg_labels(i) = double(~isAbnormal);  % 1: 정상, 0: 이상 (isAbnormal의 반대)
            
            % 제목: 보폭 수와 outlier 비율만 간결히 표시
            outlier_pct = 100 * numel(outlier_strides) / max(1, n_valid_strides);
            title_str = sprintf('%s (%d strides, %.1f%% outliers, %s)', ...
                muscle_name, n_valid_strides, outlier_pct, reason);
        else
            % 빈 데이터인 경우
            plot(0, 0, 'r'), box off
            title_str = sprintf('%s (no data)', muscle_name);
            valid_emg_labels(i) = 0;  % 빈 데이터는 이상으로 간주
        end
    end
    
    % type 정보가 있으면 제목에 추가
    if ~isempty(type)
        title_str = sprintf('%s [%s]', title_str, type);
    end
    
    title(title_str, 'Interpreter', 'none')
    
    % 이상이 있는 채널은 제목을 빨간색으로 표시
    if valid_emg_labels(i) == 0
        title(title_str, 'Interpreter', 'none', 'Color', 'red')
    else
        title(title_str, 'Interpreter', 'none', 'Color', 'black')
    end
    
    % 마지막 subplot이 아니면 x축 라벨 숨기기
    if i < n_muscles
        set(gca, 'XTickLabel', []);
    end
end

% ─── 전체 Figure 제목 및 저장 ───
[~, name] = fileparts(filename);
sgtitle(name, 'Interpreter', 'none')  % 파일 이름을 figure 제목으로
set(fh,'InvertHardcopy',false)
exportgraphics(fh, filename, 'Resolution', 600) % 고해상도(600DPI) PNG로 저장, 투명 배경 유지
close(fh)                             % Figure 닫기
end
