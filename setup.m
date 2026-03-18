% 인코딩 메인 환경 설정
% 1. utils 폴더 검색 경로에 추가

root_repo = fileparts(mfilename('fullpath'));
curr_path = strsplit(path, ';');
utils_path = fullfile(root_repo, 'utils');

if exist(utils_path, 'dir')
    if ~any(strcmp(curr_path, utils_path))
        addpath(genpath(utils_path));
    end
else
    error('utils 폴더를 찾을 수 없습니다.');
end

% savepath;  % 세션 간 유지하려면 주석 해제
