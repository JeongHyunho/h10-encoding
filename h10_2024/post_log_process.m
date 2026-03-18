%% Log Post Processing Pipeline
% 이 스크립트는 로그(.tdms) 파일의 후처리 파이프라인을 실행합니다.
% - encode_all.m 에서 로그 관련 절차를 발췌/재구성하여 모듈화합니다.
% - log_scripts 폴더의 함수들을 단계별로 호출합니다.

close all; clear

% 환경 설정 (실행 파일 위치로 이동)
mfile_dir = fileparts(mfilename('fullpath'));
if contains(mfile_dir, 'Editor')
    mfile_dir = fileparts(matlab.desktop.editor.getActiveFilename);
end
cd(mfile_dir)

% 프로젝트 설정 로드
run('setup.m')
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
sub_pass = 5;

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
fp_freq = 500; % encode_all.m 설정과 동일

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
