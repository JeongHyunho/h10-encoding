%% EMG Post Processing Pipeline
% 이 스크립트는 EMG 데이터의 포괄적인 후처리 파이프라인을 실행합니다.
% 각 단계별로 분리된 스크립트를 순차적으로 호출합니다.

close all; clear

% 환경 설정
mfile_dir = fileparts(mfilename('fullpath'));
if contains(mfile_dir,'Editor')
    mfile_dir = fileparts(matlab.desktop.editor.getActiveFilename);
end
cd(mfile_dir)

run('setup.m')
data_dir = getenv('DATA_DIR');

% Load encoded data
load(fullfile(data_dir, 'export', 'enc_rs.mat'), 'rs')

% Load subject and condition metadata
param = readtable('h10_param.csv', detectImportOptions("h10_param.csv", "TextType", "string"));
sub_info = readtable('sub_info.csv', detectImportOptions("sub_info.csv", "TextType", "string"));
n_sub = height(sub_info);
sub_pass = 5;

idx_info = struct();
for i = 1+sub_pass:n_sub
    sub_name = sub_info.ID(i);
    idx_info.(sub_name) = rs.(sub_name).idx_info;
end

%% Step 1: Raw EMG plot for insanity check
fprintf('=== Step 1: 원시 EMG 플롯(이상 여부 점검) ===\n');
emg_raw_plot_check(idx_info, sub_info, sub_pass, n_sub);

%% Step 2: EMG Data Processing
fprintf('=== Step 2: EMG 데이터 처리 ===\n');
offset_csv = fullfile(data_dir, 'emg', 'offsets', 'multiple_dyn_offsets.csv');
if ~exist(offset_csv, 'file')
    error('dyn 오프셋 CSV 파일을 찾을 수 없습니다: %s', offset_csv);
end
dyn_offsets = readtable(offset_csv);
emg_rs = emg_data_processing(idx_info, sub_info, sub_pass, n_sub, dyn_offsets);

%% Step 3: EMG Channel Success Table
fprintf('=== Step 3: EMG 채널 성공 테이블 생성 ===\n');
if ~exist('emg_rs', 'var')
    load(fullfile(data_dir, 'emg', 'emg_summary.mat'), 'emg_rs');
end
emg_channel_success_table(emg_rs);

%% Step 4: Channel Filtering
fprintf('=== Step 4: 채널 필터링 ===\n');
if ~exist('emg_rs', 'var')
    load(fullfile(data_dir, 'emg', 'emg_summary.mat'), 'emg_rs');
end
emg_proc = emg_channel_filtering(emg_rs);

%% Step 5: EMG Normalization and Activation Calculation
fprintf('=== Step 5: EMG 정규화 및 활성도 계산 ===\n');

% Load processed EMG data
if ~exist('emg_proc', 'var')
    load(fullfile(data_dir, 'emg', 'emg_proc.mat'), 'emg_proc')
end

% EMG 측정 근육 이름, postfix 1 또는 2 는 자동 선택됨
muscle_names = {'VM', 'VL', 'RF', 'BF', 'ST', 'TA', 'GL', 'GM', 'SOL'};

% 별도 함수로 수행 (결과 저장 및 반환)
emg_norm = emg_normalization_and_activation(idx_info, muscle_names, emg_proc);

%% Step 6: EMG Plot (Disc) - After Normalization
fprintf('=== Step 6: EMG 플롯(Disc) - 정규화 후 ===\n');

% Load EMG data
if ~exist('emg_rs', 'var')
    load(fullfile(data_dir, 'emg', 'emg_summary.mat'), 'emg_rs')
end
if ~exist('emg_norm', 'var')
    load(fullfile(data_dir, 'emg', 'emg_norm.mat'), 'emg_norm')
end

emg_plot_disc(idx_info, emg_rs, emg_norm);
