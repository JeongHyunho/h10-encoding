%% H10 Encoding Pipeline — Shared Configuration
% 이 파일은 파이프라인 전체에서 공유되는 상수를 정의합니다.
% 각 스크립트에서 run('config.m') 으로 호출하여 사용합니다.

% --- ICM Model ---
% Koller et al. (2019) 지수 wash-in 모델의 시상수 (초)
TAU_ICM = 41.78;

% --- Treadmill ---
% 트레드밀 전진 속도 (m/s), 모든 시도에서 동일
TREADMILL_SPEED = 1.5;

% --- Force Plate ---
% 지면반력계 샘플링 주파수 (Hz)
FP_FREQ = 500;

% --- Protocol ---
% 파일럿 참여자 수 (S005–S016, 분석에서 제외)
N_PILOT_SUBJECTS = 5;

% 이산 프로토콜 3×3 토크 격자 [flx_peak, ext_peak] (Nm/kg)
DISC_TORQUE_GRID = [ ...
    0.04, 0.04;  0.04, 0.11;  0.04, 0.18; ...
    0.11, 0.04;  0.11, 0.11;  0.11, 0.18; ...
    0.18, 0.04;  0.18, 0.11;  0.18, 0.18];

% 반응곡면 파라미터 격자 (Nm/kg, 0.001 간격)
[PG_X, PG_Y] = meshgrid(0.04:0.001:0.18, 0.04:0.001:0.18);

% 연속 프로토콜 길이 레이블
CONT_DURATIONS = ["5m", "10m", "15m"];

% --- Gait Cycle ---
% 보행 주기 보간 점 수 (0–100% in 301 steps)
N_PHASE_POINTS = 301;

% --- Torque Profile ---
% 토크 프로파일 형상 지수 (0.5 = 반정현파)
TORQUE_SHAPE_EXP = 0.5;
