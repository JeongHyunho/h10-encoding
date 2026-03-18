function rs = emg_mvc_process(c3d, set_name)
%==========================================================================
% emg_mvc_process(c3d, set_name)
%
% ⦿ 기능:
%   - MVC 케이스의 c3d 아날로그 데이터에서 EMG 채널을 추출하여
%     Band-pass(10–400/500 Hz) → 정류(절댓값) → Low-pass(10 Hz) 필터 적용
%   - set1/set2 구성에 맞춰 센서 라벨을 근육 라벨로 매핑하여 구조체 반환
%   - 보행 정규화 없이 전체 시간 신호를 그대로 저장 (MVC 특성)
%
% ⦿ 입력:
%   - c3d: ezc3dRead로 로드한 c3d 구조체
%   - set_name: 'set1' 또는 'set2' (EMG 채널 구성에 따른 라벨 매핑)
%
% ⦿ 출력:
%   - rs: 필터링된 EMG 신호를 근육명 필드로 담은 구조체
%         예) rs.VM, rs.VM1, rs.RF, rs.RF1, ..., rs.SOL (각각 [시간 x 1] 벡터)
%
% 처리 단계 요약
%   1) 샘플링 주파수 확인 → 필터 계수 설계
%   2) EMG 라벨 존재 여부 확인 (없으면 경고 후 조기 반환)
%   3) 센서 라벨(emg_list) ↔ 근육 라벨(mc_list) 매핑(set1/set2)
%   4) 각 채널에 band-pass → rectification → low-pass 적용
%   5) 결과를 근육 라벨 필드명으로 rs에 저장
%==========================================================================

rs = struct();

% 샘플링 주파수 추출
fs = c3d.parameters.ANALOG.RATE.DATA;

% ─── 필터 설계 ───
% 샘플링 속도에 따라 bandpass 상한을 400/500 Hz로 조정
if fs <= 1000
    [b_bp, a_bp] = butter(4, [10, 400]/(fs/2), 'bandpass');  % Bandpass: 10–400 Hz
else
    [b_bp, a_bp] = butter(4, [10, 500]/(fs/2), 'bandpass');  % Bandpass: 10–500 Hz
end
[b_lp, a_lp] = butter(4, 10/(fs/2), 'low');  % Envelope: Lowpass 10 Hz

emg_list  = {'Sensor 1.IM EMG1', 'Sensor 2.IM EMG2', 'Sensor 3.IM EMG3', ...
    'Sensor 4.IM EMG4', 'Sensor 5.IM EMG5', 'Sensor 6.IM EMG6', ...
    'Sensor 7.IM EMG7', 'Sensor 8.IM EMG8', 'Sensor 9.IM EMG9', 'Sensor 10.IM EMG10'};
if strcmp(set_name, 'set1')
    mc_list = {'VM', 'VL', 'RF1', 'RF2', 'BF', 'ST', 'TA', 'GL', 'GM', 'SOL'};
elseif strcmp(set_name, 'set2')
    mc_list = {'VM1', 'VM2', 'VL', 'RF', 'BF', 'ST', 'TA', 'GL', 'GM', 'SOL'};
else
    error('Exception: unknown set_name(%s).\n', set_name)
end

emg_labels = c3d.parameters.ANALOG.LABELS.DATA;
emg_data = c3d.data.analogs;

% ─── EMG 채널 존재 여부 확인 ───
if ~any(cellfun(@(x) contains(x, 'EMG'), emg_labels))
    warning('No emg channel exists!\n')
    return
end

% 샘플링 주파수 기록 (후처리 시 시간축 표시용)
rs.fs = fs;

for i = 1:numel(emg_list)
    mc_label = mc_list{i};
    sig_idx = ismember(emg_labels, emg_list{i});
    sig = emg_data(:, sig_idx);

    % 필터링: bandpass → 절댓값 (정류) → lowpass (envelope)
    sig = filtfilt(b_bp, a_bp, sig);
    sig = abs(sig);
    sig = filtfilt(b_lp, a_lp, sig);

    % MVC 데이터는 전체 신호를 그대로 저장
    rs.(mc_label) = sig;
end

end
