% 여러 dyn(emg_exported_#.txt)로 분할된 보행에서 TDMS 연속 힘판(FP)과
% c3d 힘판 파형(좌/우 Fz 2채널)을 상관 정렬하여 각 dyn의 오프셋을 추정하고 CSV로 저장
% - TDMS/ c3d 모두 6 Hz, 4차, 양방향 저역통과 후 xcorr 수행
% - 랙은 TDMS 내에서 c3d가 완전히 포함되는 경우만 허용

% 환경 변수
run('setup.m')
data_dir = getenv('DATA_DIR');
v3d_dir  = getenv('V3D_PATH');
if isempty(data_dir) || isempty(v3d_dir)
    error('DATA_DIR 또는 V3D_PATH 환경변수가 설정되지 않았습니다.');
end

% 다중 dyn 케이스 수집
subs = dir(fullfile(v3d_dir, 'S*'));
targets = struct('sub', {}, 'walk', {}, 'nDyn', {});
for si = 1:numel(subs)
    if ~subs(si).isdir, continue, end
    sub_name = string(subs(si).name);
    walks = dir(fullfile(subs(si).folder, subs(si).name, 'walk*'));
    for wi = 1:numel(walks)
        if ~walks(wi).isdir, continue, end
        walk_name = string(walks(wi).name);
        v3d_walk_dir = fullfile(walks(wi).folder, walks(wi).name);
        emg_list_tmp = dir(fullfile(v3d_walk_dir, 'emg_exported_*.txt'));
        if isempty(emg_list_tmp), continue, end
        % 30초 이상 지속된 dyn만 카운트 (events_k.txt 기반)
        valid_count = 0;
        for k = 1:numel(emg_list_tmp)
            evt_file = fullfile(v3d_walk_dir, sprintf('events_%d.txt', k));
            if ~exist(evt_file, 'file'), continue, end
            dur_k = local_read_evt_duration(evt_file);
            if isfinite(dur_k) && dur_k >= 30
                valid_count = valid_count + 1;
            end
        end
        if valid_count >= 2
            % TDMS 파일 수가 dyn 수와 동일한 케이스는 제외 (여러 보행 시도 케이스)
            fp_dir_check = dir(fullfile(data_dir, 'fp', char(sub_name), [char(walk_name) '*.tdms']));
            tdms_count = numel(fp_dir_check);
            if tdms_count ~= valid_count
                targets(end+1) = struct('sub', sub_name, 'walk', walk_name, 'nDyn', valid_count);
            end
        end
    end
end
if isempty(targets)
    error('여러 dyn 파일을 가진 보행이 없습니다.');
end

fprintf('=== TDMS 기반 dyn 오프셋 정렬 결과 ===\n');
fprintf('Subject  Walk    dyn   len   dur(s)   corr    offset(s)  tdms\n');

% 결과 누적 (CSV 저장용)
sub_col = strings(0,1); walk_col = strings(0,1); dyn_col = []; len_col = []; dur_col = []; corr_col = []; offset_col = []; tdms_idx_col = [];

for ti = 1:numel(targets)
    sub_name = char(targets(ti).sub); walk_name = char(targets(ti).walk);
    % TDMS FP 파일 로드
    fp_dir = dir(fullfile(data_dir, 'fp', sub_name, [walk_name '*.tdms']));
    if isempty(fp_dir)
        fprintf('[경고] TDMS FP 없음: %s %s\n', sub_name, walk_name); continue
    end
    fp_path = fullfile(fp_dir(1).folder, fp_dir(1).name);
    % read_fp_table을 사용해 TDMS를 표준화된 힘판 테이블로 읽기
    fp_freq = 500; % encode_all과 동일 기본 주파수 가정
    calmat_left = readmatrix(fullfile(data_dir, 'fp', 'cal_mat_left.txt'));
    calmat_right = readmatrix(fullfile(data_dir, 'fp', 'cal_mat_right.txt'));
    try
        fpT = read_fp_table(fp_path, fp_freq, calmat_left, calmat_right);
    catch ME
        fprintf('[경고] read_fp_table 실패: %s → %s\n', fp_path, ME.message); continue
    end
    % TDMS 시간 벡터
    t_tdms = fpT.t(:);
    % TDMS 수직 힘 2채널(L/R) 및 저역통과 필터(4차, 30 Hz, 양방향)
    Fz_tdms = [double(fpT.LFy), double(fpT.RFy)];
    [b_lp, a_lp] = butter(4, 30/(fp_freq/2));
    Fz_tdms = filtfilt(b_lp, a_lp, Fz_tdms);

    % 특이 케이스 매핑: S025 walk23 → TDMS 2개, C3D 3개
    is_special = strcmp(sub_name, 'S025') && strcmp(walk_name, 'walk23') && numel(fp_dir) >= 2;
    if is_special
        tdms_map = [1, 2, 2];
    else
        tdms_map = [];
    end

    % 대상 walk의 dyn c3d를 읽어 TDMS Fz와 정렬 (이벤트 사용하지 않음)
    v3d_walk_dir = fullfile(v3d_dir, sub_name, walk_name);
    emg_txt_list = dir(fullfile(v3d_walk_dir, 'emg_exported_*.txt'));
    % c3d는 DATA_DIR/c3d 아래에서 찾음
    c3d_walk_dir = fullfile(data_dir, 'c3d', sub_name, walk_name);
    % C3D 파일: 'dyn' 포함, 'mvc'/'MVC' 제외
    c3d_list = dir(fullfile(c3d_walk_dir, '*dyn*.c3d'));
    if ~isempty(c3d_list)
        names_lower = lower(string({c3d_list.name}));
        c3d_list = c3d_list(~contains(names_lower, 'mvc'));
    end
    n_dyn = numel(emg_txt_list);
    % 결과 검증을 위한 오프셋/지속시간 누적 저장
    offset_list = nan(n_dyn, 1);
    dur_list = nan(n_dyn, 1);
    for k = 1:n_dyn
        % 이번 dyn에 사용된 TDMS 인덱스 (기본 1)
        tdms_idx_k = 1;
        % c3d 파일 결정 (가능하면 동일 인덱스 매칭, 아니면 근사)
        c3d_file = '';
        if ~isempty(c3d_list)
            if k <= numel(c3d_list)
                c3d_file = fullfile(c3d_list(k).folder, c3d_list(k).name);
            else
                c3d_file = fullfile(c3d_list(end).folder, c3d_list(end).name);
            end
        end
        if isempty(c3d_file) || ~exist(c3d_file,'file')
            fprintf('[경고] c3d 없음: %s %s dyn_%d\n', sub_name, walk_name, k); continue
        end
        % 특이 케이스: dyn별 TDMS 선택
        if is_special && k <= numel(tdms_map)
            idx_fp = tdms_map(k);
            if idx_fp >= 1 && idx_fp <= numel(fp_dir)
                try
                    fpT_k = read_fp_table(fullfile(fp_dir(idx_fp).folder, fp_dir(idx_fp).name), fp_freq, calmat_left, calmat_right);
                    t_tdms = fpT_k.t(:);
                    Fz_tdms = [double(fpT_k.LFy), double(fpT_k.RFy)];
                    Fz_tdms = filtfilt(b_lp, a_lp, Fz_tdms);
                    tdms_idx_k = idx_fp;
                catch ME
                    fprintf('[경고] read_fp_table 실패(특이 케이스): %s → %s\n', fp_dir(idx_fp).name, ME.message);
                end
            end
        end
        % c3d에서 Fz 좌/우 2채널 추출 후 500Hz로 리샘플
        try
            [t_c3d, fz_c3d] = local_extract_c3d_fz(c3d_file);
        catch ME
            fprintf('[경고] c3d 읽기 실패: %s → %s\n', c3d_file, ME.message); continue
        end
        if isempty(t_c3d) || isempty(fz_c3d)
            fprintf('[경고] c3d Fz 추출 실패: %s\n', c3d_file); continue
        end
        % 필터 후 보간
        fz_c3d = filtfilt(b_lp, a_lp, fz_c3d);
        tq = (0:1/fp_freq:(t_c3d(end)-t_c3d(1)))';
        fzq = interp1(t_c3d - t_c3d(1), fz_c3d, tq, 'linear', 'extrap');
        % 2채널 상관 정렬
        [best_offset, best_corr] = estimate_offset_by_xcorr_multi(Fz_tdms, fzq, fp_freq);
        % dyn duration(s): c3d 시간축 기반
        dur_k = t_c3d(end) - t_c3d(1);
        fprintf('%-7s %-7s %4d %6d %8.3f %7.3f %10.4f %5d\n', sub_name, walk_name, k, size(fzq,1), dur_k, best_corr, best_offset, tdms_idx_k);
        % 연속성 검사: dyn_{i+1}.offset > dyn_i.offset + dyn_i.dur 이어야 함
        offset_list(k) = best_offset;
        dur_list(k) = dur_k;
        if is_special
            % 특이 케이스(S025 walk23): dyn1은 TDMS1, dyn2/3은 TDMS2 기반 → dyn2↔dyn3만 검사
            if k == 3 && isfinite(offset_list(2)) && isfinite(dur_list(2)) && isfinite(best_offset)
                min_expected = offset_list(2) + dur_list(2);
                if ~(best_offset > min_expected)
                    fprintf('[검사 실패-특이] %s %s dyn_%d 오프셋 불일치(동일 TDMS 기준): offset=%.4f, 기대 최소값=%.4f (dyn2_offset=%.4f + dyn2_dur=%.4f)\n', ...
                        sub_name, walk_name, k, best_offset, min_expected, offset_list(2), dur_list(2));
                end
            end
        else
            if k > 1 && isfinite(offset_list(k-1)) && isfinite(dur_list(k-1)) && isfinite(best_offset)
                min_expected = offset_list(k-1) + dur_list(k-1);
                if ~(best_offset > min_expected)
                    fprintf('[검사 실패] %s %s dyn_%d 오프셋 불일치: offset=%.4f, 기대 최소값=%.4f (prev_offset=%.4f + prev_dur=%.4f)\n', ...
                        sub_name, walk_name, k, best_offset, min_expected, offset_list(k-1), dur_list(k-1));
                end
            end
        end
        % 결과 누적
        sub_col(end+1,1) = string(sub_name);
        walk_col(end+1,1) = string(walk_name);
        dyn_col(end+1,1) = k;
        len_col(end+1,1) = size(fzq,1);
        dur_col(end+1,1) = dur_k;
        corr_col(end+1,1) = best_corr;
        offset_col(end+1,1) = best_offset;
        tdms_idx_col(end+1,1) = tdms_idx_k;
    end
end

% CSV 저장
out_dir = fullfile(data_dir, 'emg', 'offsets');
if ~exist(out_dir, 'dir'), mkdir(out_dir), end
T = table(sub_col, walk_col, dyn_col, len_col, dur_col, corr_col, offset_col, tdms_idx_col, ...
    'VariableNames', {'subject','walk','dyn_idx','len_samples','dur_s','corr','offset_s','tdms_idx'});
csv_path = fullfile(out_dir, 'multiple_dyn_offsets.csv');
writetable(T, csv_path);
fprintf('[CSV 저장] %s (rows=%d)\n', csv_path, height(T));


% === 보조 함수들 ===
function [best_offset, best_corr] = estimate_offset_by_xcorr_multi(Fz_tdms_2ch, Fz_c3d_2ch, fs)
% 2채널(L/R) 동시 정렬: 두 채널 각각의 xcorr 점수를 더해 최적 랙 선택
    best_offset = NaN; best_corr = NaN;
    if isempty(Fz_tdms_2ch) || isempty(Fz_c3d_2ch), return, end
    % 채널 분리 (열 기준)
    xL = double(Fz_tdms_2ch(:,1)); xR = double(Fz_tdms_2ch(:,2));
    yL = double(Fz_c3d_2ch(:,1));  yR = double(Fz_c3d_2ch(:,2));
    % 평균 제거
    xL = xL / mean(xL,'omitnan'); xR = xR / mean(xR,'omitnan');
    yL = yL / mean(yL,'omitnan'); yR = yR / mean(yR,'omitnan');
    xL(~isfinite(xL))=0; xR(~isfinite(xR))=0; yL(~isfinite(yL))=0; yR(~isfinite(yR))=0;
    Nx = size(Fz_tdms_2ch,1); Ny = size(Fz_c3d_2ch,1);
    % 랙 범위를 확대: 완전 포함보다 1000샘플 여유 허용
    maxLag = max(0, Nx - Ny + 1000);
    [cL,lags] = xcorr(xL, yL, maxLag, 'none');
    [cR,~]    = xcorr(xR, yR, maxLag, 'none');
    % 유효 랙: TDMS 범위 내에서 1개 이상 겹치는 구간만 허용 (양의 랙만)
    overlap = min(Ny, max(0, Nx - lags));
    allowed = (lags >= 0) & (overlap > 0);
    % 겹침 길이로 정규화 (부분 겹침 보정)
    cL_norm = cL;
    cR_norm = cR;
    cL_norm(allowed) = cL(allowed) ./ overlap(allowed)';
    cR_norm(allowed) = cR(allowed) ./ overlap(allowed)';
    cL_norm(~allowed) = -inf;
    cR_norm(~allowed) = -inf;
    cSum = cL_norm + cR_norm;
    [best_corr, idx] = max(cSum);
    lag = lags(idx);
    best_offset = lag / fs;
end

function [t, fz_2ch] = local_extract_c3d_fz(c3d_file)
% ezc3d로 c3d를 읽고 아날로그 채널 중 FZ로 표기된 좌/우 채널을 2채널로 반환
    c3d = ezc3dRead(char(c3d_file));
    labels = string(c3d.parameters.ANALOG.LABELS.DATA);
    rate = double(c3d.parameters.ANALOG.RATE.DATA(1));
    % 안전 처리: 2D로 변형
    A2 = squeeze(c3d.data.analogs(:, :, 1));
    if ndims(A2) == 3
        A2 = reshape(A2, size(A2,1)*size(A2,2), size(A2,3));
    end
    if size(A2,2) ~= numel(labels)
        % 일부 버전에서는 프레임x채널로 반환
        A2 = squeeze(c3d.data.analogs);
    end
    if size(A2,2) ~= numel(labels)
        fz_2ch = [];
        t = [];
        return
    end
    % FZ 라벨 탐지 (좌/우 분리 시도)
    fz_idx_all = find(contains(upper(labels), 'FZ'));
    if numel(fz_idx_all) < 2
        error('local_extract_c3d_fz:expectedTwoFz', 'FZ 채널이 2개 미만입니다: %s', c3d_file);
    end
    fzR = -double(A2(:, fz_idx_all(1)));
    fzL = -double(A2(:, fz_idx_all(2)));
    fz_2ch = [fzL, fzR];
    t = (0:size(fz_2ch,1)-1)'/rate;
end

function dur = local_read_evt_duration(evt_file)
% events_#.txt에서 'Right Foot Strike' 첫/마지막 시각 차이로 지속시간(초) 근사
    dur = NaN;
    try
        rd = readcell(evt_file);
        fields = rd(2, 2:end);
        data_c = rd(6:end, 2:end);
        missed = cellfun(@ismissing, data_c);
        data_c(missed) = {nan};
        data = cell2mat(data_c);
        rfs_col = find(strcmp(fields, 'Right Foot Strike'));
        if isempty(rfs_col), return, end
        rfs = data(:, rfs_col);
        rfs = rfs(~isnan(rfs));
        if numel(rfs) >= 2
            dur = rfs(end) - rfs(1);
        elseif isscalar(rfs)
            dur = 0; % 단일 이벤트면 지속시간 추정 불가
        end
    catch
        dur = NaN;
    end
end


