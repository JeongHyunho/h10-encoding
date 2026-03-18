% 환경 설정
% 1. 메인 setup.m 실행 (utils/ path 추가)
% 2. DATA_DIR, V3D_PATH 환경 변수 설정

run(fullfile('..', 'setup.m'));

% ===== 아래 경로를 로컬 환경에 맞게 수정 =====
data_path = 'C:\path\to\H10_data';
v3d_path  = 'C:\path\to\V3D_exports';

% EMG 오프셋 파일이 데이터 폴더 내에 있는 경우
emg_path = fullfile(data_path, 'emg');
if exist(emg_path, 'dir')
    addpath(genpath(emg_path));
end

setenv('DATA_DIR', data_path);
setenv('V3D_PATH', v3d_path);
