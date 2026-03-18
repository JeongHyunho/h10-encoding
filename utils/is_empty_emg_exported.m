function tf = is_empty_emg_exported(file_path)
%==========================================================================
% is_empty_emg_exported(file_path)
%
% ⦿ 기능:
%   - V3D에서 export된 'emg_exported_*.txt' 파일이 유효한 데이터(행/열, 숫자)가
%     존재하는지 검사하여, 비어있거나 무효한 경우 true 반환
%
% ⦿ 입력:
%   - file_path: 검사할 파일 경로 (문자열/char)
%
% ⦿ 출력:
%   - tf: 논리값 (true: 데이터 없음/무효, false: 정상 데이터)
%==========================================================================

% 파일 존재 여부
if ~(ischar(file_path) || isstring(file_path)) || ~exist(file_path, 'file')
    tf = true; return
end

try
    rd = readcell(file_path, 'Delimiter', '\t');
catch
    tf = true; return
end

% 최소 행 수 확인 (헤더 5행 + 데이터 ≥1행)
if size(rd, 1) < 7
    tf = true; return
end

% 헤더 구조 대략 확인
% 2행: 채널 라벨, 6행부터: 데이터, 첫 컬럼은 frame 번호 (무시)
labels_row = rd(2, 2:end);
if isempty(labels_row) || all(cellfun(@(x) isempty(x) || (isstring(x) && strlength(x)==0), labels_row))
    tf = true; return
end

% 데이터 영역 추출
raw_data = rd(6:end, 2:end);
if isempty(raw_data)
    tf = true; return
end

% 문자열/결측 → NaN, 숫자는 유지하여 숫자 매트릭스로 변환
C = raw_data;
for i = 1:numel(C)
    v = C{i};
    if ismissing(v) || (isstring(v) && strlength(v) == 0)
        C{i} = NaN;
    elseif ischar(v) || isstring(v)
        numv = str2double(v);
        if isnan(numv)
            C{i} = NaN;
        else
            C{i} = numv;
        end
    elseif ~isnumeric(v)
        C{i} = NaN;
    end
end

try
    M = cell2mat(C);
catch
    tf = true; return
end

% 숫자 데이터가 전부 NaN이면 비어있는 것으로 간주
if isempty(M) || all(isnan(M(:)))
    tf = true;
else
    tf = false;
end

end
