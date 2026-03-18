%% post_log_process.m — 로그 파일 후처리 파이프라인
% H10 로그(.tdms) 파일의 시간 정합성·파라미터 일치 여부를 점검하고,
% 파라미터/시계열을 추출·병합하여 log_rs.mat으로 저장한다.
%
% 의존성:
%   - setup.m
%   - DATA_DIR/export/enc_rs.mat (encode_all.m 출력, idx_info 참조)
%   - h10_param.csv, sub_info.csv
%   - log_scripts/ 폴더의 함수들
%
% 출력:
%   - DATA_DIR/export/log_rs.mat
%
% 파이프라인 순서: insane_check → [이 스크립트] → encode_all

close all; clear

% 환경 설정 (실행 파일 위치로 이동)
mfile_dir = fileparts(mfilename('fullpath'));
if contains(mfile_dir, 'Editor')
    mfile_dir = fileparts(matlab.desktop.editor.getActiveFilename);
end
cd(mfile_dir)

% 프로젝트 설정 로드
run('setup.m')
run('config.m')
data_dir = getenv('DATA_DIR');
if ~isfolder(data_dir)
    error('DATA_DIR 경로가 올바르지 않습니다: %s', data_dir);
end

% log_scripts 함수 경로 추가
log_scripts_dir = fullfile(mfile_dir, 'log_scripts');
if isfolder(log_scripts_dir)
    addpath(log_scripts_dir);
end

% 인코딩 결과 로드 (rs에 idx_info 포함)
enc_file = fullfile(data_dir, 'export', 'enc_rs.mat');
if ~exist(enc_file, 'file')
    error('인코딩 결과(enc_rs.mat)를 찾을 수 없습니다: %s', enc_file);
end
if ~exist('rs', 'var')
    load(enc_file, 'rs')
end

% 메타데이터 로드
opts_param = detectImportOptions('h10_param.csv', 'TextType', 'string');
opts_param = setvartype(opts_param, opts_param.VariableNames, "string");
param = readtable('h10_param.csv', opts_param);
opts_sub = detectImportOptions('sub_info.csv', 'TextType', 'string');
sub_info = readtable('sub_info.csv', opts_sub);
n_sub = height(sub_info);

% sub_pass, S008, S009, S010 무시
sub_pass = N_PILOT_SUBJECTS;

% 보행 변수 리스트 (walk1, walk2, ...)
walks = param.Properties.VariableNames(2:end);

% rs에서 피험자별 idx_info 발췌
idx_info = struct();
for i = 1+sub_pass:n_sub
    sub_name = sub_info.ID(i);
    if isfield(rs, sub_name)
        idx_info.(sub_name) = rs.(sub_name).idx_info;
    end
end

% 공통 상수
fp_freq = FP_FREQ;

%% Step 1: 로그 파일 점검 (시간 정합성/파라미터 일치 여부)
fprintf('=== Step 1: 로그 파일 점검(시간/파라미터) ===\n');
issues = [];
issues_file = fullfile(data_dir, 'log', 'log_issues.csv');
if exist(issues_file, 'file')
    issues = readtable(issues_file, 'TextType', 'string');
else
    issues = log_file_checks(idx_info, sub_info, param, data_dir, fp_freq, sub_pass);
end

%% Step 2-3: 결과 구축 (파라미터/시계열 추출 + 연속 병합)
fprintf('=== Step 2-3: 로그 결과 구축 (issues 반영) ===\n');

log_rs = log_build_results(idx_info, sub_info, param, data_dir, sub_pass, issues);

%% Step 4: 결과 저장 (log_rs 직접 저장)
fprintf('=== Step 4: 결과 저장 (log_rs) ===\n');
export_dir = fullfile(data_dir, 'export');
if ~isfolder(export_dir)
    mkdir(export_dir);
end
save(fullfile(export_dir, 'log_rs.mat'), 'log_rs', '-v7.3');

fprintf('=== Log Post Processing 완료 ===\n');
