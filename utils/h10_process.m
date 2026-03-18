function rs = h10_process(h10_file, fp_T, t0, weight)
%H10_PROCESS  H10 외골격 CSV 데이터 처리 — 보행 분절, 토크/일률 계산
%
%   rs = H10_PROCESS(h10_file, fp_T, t0, weight)
%
%   H10 외골격 제어기 CSV 로그를 읽어 보행 주기별로 분절(segmentation)한 뒤,
%   관절 각도, 각속도, 토크, 일률을 계산한다.
%   토크 상수 tau_c = 0.085 * 18.75 로 전류→토크 변환을 수행한다.
%
%   입력:
%     h10_file — H10 CSV 파일 정보 [struct 또는 struct array]
%                dir() 출력 형식 (folder, name 필드 필수)
%     fp_T     — 지면반력 테이블 (보행 이벤트 검출용) [table]
%     t0       — 각 파일의 시간 오프셋 [1 x numel(h10_file), s]
%     weight   — 참여자 체중 [scalar, kg]
%
%   출력:
%     rs — 처리 결과 구조체 [struct]
%       .time        — 보행 주기 내 시간 [M x 301]
%       .record_time — 절대 기록 시간 [M x 301]
%       .stance_keep — stance 구간 논리 인덱스 [M x 301]
%       .inc_deg     — 관절 각도 (inclination) [M x 301, deg]
%       .jvel_deg    — 관절 각속도 [M x 301, deg/s]
%       .tau_ref     — 참조 토크 [M x 301, Nm]
%       .tau_act     — 실측 토크 [M x 301, Nm]
%       .pow         — 관절 일률 (체중 정규화) [M x 301, W/kg]
%       .fric_pow_c  — 쿨롱 마찰 일률 성분 [M x 301, W/kg]
%       .fric_pow_v  — 점성 마찰 일률 성분 [M x 301, W/kg]
%
%   알고리즘:
%     1) CSV 읽기 → Gait_Stage 또는 지면반력 기반 보행 이벤트 검출
%     2) 4차 Butterworth 저역통과 (6 Hz) 필터 적용
%     3) segInterp로 각 보행 주기를 301 포인트로 보간
%     4) 전류 × tau_c로 토크 변환, 토크 × 각속도로 일률 산출
%
%   참고: detect_evt, read_fp_table, read_log_file

rs = struct();

tau_c = 0.085 * 18.75;

h10_freq = 1000;
fp_freq = 500;
n_pts = 301;

[b, a] = butter(4, 6/(h10_freq/2), 'low');

t_ = [];
rec_t_ = [];
stance_keep_ = [];
inc_deg_ = [];
jvel_deg_ = [];
cur_ref_ = [];
cur_act_ = [];

for i = 1:numel(h10_file)
    T = readtable(fullfile(h10_file(i).folder, h10_file(i).name));
    T.t = T.loopCnt / h10_freq;

    if ismember("Gait_Stage", T.Properties.VariableNames)
        [lfs_srt, lfs_end, lkeep] = findStageTransition(T.Gait_Stage, 2, 3, n_pts);
        [rfs_srt, rfs_end, rkeep] = findStageTransition(T.Gait_Stage, 4, 1, n_pts);
    else
        [fp_lfs, fp_lfo, fp_rfs, fp_rfo] = evt_from_fp(fp_T, inf);
        h10_lfs = round(h10_freq / fp_freq * (fp_lfs - 1)) + 1;
        h10_rfs = round(h10_freq / fp_freq * (fp_rfs - 1)) + 1;

        lfs_srt = h10_lfs(1:end-1);
        lfs_end = h10_lfs(2:end);
        rfs_srt = h10_rfs(1:end-1);
        rfs_end = h10_rfs(2:end);

        rkeep = stance_keep(fp_rfs, fp_rfo, n_pts);
        lkeep = stance_keep(fp_lfs, fp_lfo, n_pts);
    end

    t_ = [t_; ...
        segInterp(T.t, rfs_srt, rfs_end, n_pts); ...
        segInterp(T.t, lfs_srt, lfs_end, n_pts)];
    if ismember("Record_Time", T.Properties.VariableNames)
        rec_t_ =[rec_t_; ...
        segInterp(T.Record_Time + t0(i), rfs_srt, rfs_end, n_pts); ...
        segInterp(T.Record_Time + t0(i), lfs_srt, lfs_end, n_pts)];
    end
    stance_keep_ = [stance_keep_; rkeep'; lkeep'];
    inc_deg_ = [inc_deg_; ...
        segInterp(filtfilt(b, a, T.incPosDeg_RH), rfs_srt, rfs_end, n_pts); ...
        segInterp(filtfilt(b, a, T.incPosDeg_LH), lfs_srt, lfs_end, n_pts)];
    jvel_deg_ = [jvel_deg_; ...
        segInterp(differentiate_and_filter(T.incPosDeg_RH, h10_freq, b, a), rfs_srt, rfs_end, n_pts); ...
        segInterp(differentiate_and_filter(T.incPosDeg_LH, h10_freq, b, a), lfs_srt, lfs_end, n_pts)];
    cur_ref_ = [cur_ref_; ...
        segInterp(filtfilt(b, a, T.MotorRefCurrent_RH), rfs_srt, rfs_end, n_pts); ...
        segInterp(filtfilt(b, a, T.MotorRefCurrent_LH), lfs_srt, lfs_end, n_pts)];
    cur_act_ = [cur_act_; ...
        segInterp(filtfilt(b, a, T.MotorActCurrent_RH), rfs_srt, rfs_end, n_pts); ...
        segInterp(filtfilt(b, a, T.MotorActCurrent_LH), lfs_srt, lfs_end, n_pts)];
end

rs.time = t_;
rs.record_time = rec_t_;
rs.stance_keep = stance_keep_;
rs.inc_deg = inc_deg_;
rs.jvel_deg = jvel_deg_;
rs.tau_ref = tau_c * cur_ref_;
rs.tau_act = tau_c * cur_act_;
rs.pow = rs.tau_act .* rs.jvel_deg * pi / 180 / weight;
rs.fric_pow_c = abs(rs.jvel_deg) * pi / 180 / weight;
rs.fric_pow_v = (rs.jvel_deg * pi / 180) .^ 2 / weight;

end


function [idxStart, idxEnd, stanceKeep] = findStageTransition(gaitStage, fromStage, toStage, n_pts)
%FINDSTAGETRANSITION  주어진 from→to 전환이 1 – 2 – 3 – 4 – 1 한 사이클을
%                     완주했을 때만, 그 **구간의 시작·끝 인덱스**를 반환
%
%   [idxStart, idxEnd] = findStageTransition(gaitStage, 4, 1);
%
% 입력
%   gaitStage : 1×N(또는 N×1) 벡터  –  단계 값(1‥4)
%   fromStage : 이전 샘플 값        –  예) 4
%   toStage   : 현재 샘플 값        –  예) 1
%
% 출력
%   idxStart  : 각 전환 구간의 시작 인덱스(= 직전 cycle 의 toStage 지점)
%   idxEnd    : 각 전환 구간의 종료 인덱스(= 이번 cycle 의 toStage 지점)
%
%   두 출력은 길이가 동일한 열-벡터이며,
%     segment k  =  gaitStage(idxStart(k) : idxEnd(k)) 가
%     정확히 1→2→3→4→1(또는 toStage 기준으로 회전시킨 동일 패턴)를 이룹니다.
%
% 전제
%   • 단계가 1→2→3→4→1 순서로만 진행한다고 가정합니다.
%   • 인덱스를 그대로 반환하므로, 시간 계산이 필요하면 별도로 나누어 주십시오.

    arguments
        gaitStage {mustBeNumeric, mustBeVector}
        fromStage (1,1) {mustBeNumeric}
        toStage   (1,1) {mustBeNumeric}
        n_pts   (1, 1) {mustBeNumeric}
    end

    gaitStage = gaitStage(:);   % 열 벡터로 통일

    % 1) 모든 from→to 전환(후 샘플) 후보 찾기
    cand = find(gaitStage(1:end-1) == fromStage & ...
                gaitStage(2:end)   ==  toStage) + 1;   % toStage 위치
    to_cand = find(gaitStage(1:end-1) == fromStage-1 & ...
        gaitStage(2:end)   ==  fromStage) + 1;   % toe off 위치
    if numel(cand) < 2                 % 완주 판정 가능한 쌍이 없음
        idxStart = [];  idxEnd = []; stanceKeep = []; % → 빈 배열 반환
        return
    end

    % 2) 두 전환 사이가 완전 사이클인지 검사
    %    toStage 를 기준으로 회전시킨 기대 패턴: [t  t+1  t+2  t+3  t]
    expected = mod([toStage toStage+1 toStage+2 toStage+3 toStage] - 1, 4) + 1;

    startList = [];  endList = []; toList = [];

    for k = 2:numel(cand)
        seg = gaitStage(cand(k-1):cand(k));          % 두 전환 사이(포함)
        segUnique = seg([true; diff(seg) ~= 0]);     % 연속 중복 제거

        if isequal(segUnique.', expected)
            startList(end+1,1) = cand(k-1);
            endList(end+1,1)   = cand(k);

            to_in = cand(k-1) <= to_cand & to_cand <= cand(k);
            if sum(to_in) == 1
                toList(end+1,1) = to_cand(to_in);
            else
                toList(end+1,1) = nan;
            end
        end
    end

    valid = ~isnan(startList) & ~isnan(endList) & ~isnan(toList);
    startList = startList(valid);
    endList = endList(valid);
    toList = toList(valid);

    % 3) 결과
    idxStart = startList;
    idxEnd   = endList;

    % 4) stance 구간
    stanceKeep = stance_keep(startList, toList, n_pts);
end


function segments = segInterp(data, startIdx, endIdx, targetLen, method)
%SEGINTERP  구간 잘라 보간 (start / end 인덱스 쌍 사용)
%
%   segments = segInterp(data, startIdx, endIdx, targetLen)
%   segments = segInterp(___, method)
%
% 입력
%   data      : 1×N 또는 N×1 실수 벡터
%   startIdx  : 각 구간 시작 인덱스 벡터 (오름차순)
%   endIdx    : 각 구간 종료 인덱스 벡터 (startIdx(i) ≤ endIdx(i))
%   targetLen : 보간 후 각 구간 샘플 수 (양의 정수)
%   method    : interp1 보간 방법, 기본 'linear'
%
% 출력
%   segments  : numSeg × targetLen 행렬
%               └─ 행 = 구간 번호,  열 = 보간된 시퀀스 샘플
%
% 예)
%   seg = segInterp(sig, sIdx, eIdx, 200, 'spline');

    arguments
        data          {mustBeNumeric, mustBeVector}
        startIdx      {mustBeNumeric, mustBeVector}
        endIdx        {mustBeNumeric, mustBeVector}
        targetLen     (1,1) {mustBeInteger, mustBePositive}
        method        (1,:) char {mustBeMember(method, ...
                        {'linear','spline','pchip','nearest','makima'})} = 'linear'
    end

    % 입력 정리 및 검증 ---------------------------------------------------
    data     = data(:);                       % 열 벡터
    startIdx = round(startIdx(:));
    endIdx   = round(endIdx(:));

    if numel(startIdx) ~= numel(endIdx)
        error("startIdx와 endIdx의 길이가 일치해야 합니다.");
    end
    if any(startIdx < 1) || any(endIdx > numel(data))
        error("startIdx / endIdx가 data 범위를 벗어납니다.");
    end
    if any(endIdx < startIdx)
        error("startIdx ≤ endIdx 조건을 만족하지 않는 쌍이 있습니다.");
    end
    if ~issorted(startIdx) || ~issorted(endIdx)
        warning("startIdx와 endIdx는 오름차순이어야 합니다. 자동 정렬합니다.");
        [startIdx, sortOrd] = sort(startIdx);
        endIdx = endIdx(sortOrd);
    end

    numSeg   = numel(startIdx);
    segments = NaN(numSeg, targetLen);        % 결과 초기화

    % 구간별 보간 ---------------------------------------------------------
    for k = 1:numSeg
        segStart = startIdx(k);
        segEnd   = endIdx(k);

        rawSeg = data(segStart:segEnd);
        rawLen = numel(rawSeg);

        % 보간 좌표 (1‥rawLen → targetLen 등분)
        xi = linspace(1, rawLen, targetLen);

        segments(k, :) = interp1(1:rawLen, rawSeg, xi, method, 'extrap');
    end
end

function dx_filt = differentiate_and_filter(x, Fs, b, a)
% differentiate_and_filter - 미분 후 필터링 수행
%
% 입력:
%   x  : 입력 신호 (벡터)
%   Fs : 샘플링 주파수 (Hz)
%   b, a : 필터 계수 (butter 등으로 생성)
%
% 출력:
%   dx_filt : 미분 + 필터링된 신호 (입력과 길이 동일)

    % 길이 확인
    if length(x) < 3
        error('입력 신호의 길이는 최소 3 이상이어야 합니다.');
    end

    % --- 미분 (중앙차분법, 길이 유지) ---
    dx = zeros(size(x));
    dx(2:end-1) = (x(3:end) - x(1:end-2)) / (2 / Fs);
    dx(1) = dx(2);        % 경계 보정
    dx(end) = dx(end-1);

    % --- 필터 적용 (zero-phase filtering) ---
    dx_filt = filtfilt(b, a, dx);
end