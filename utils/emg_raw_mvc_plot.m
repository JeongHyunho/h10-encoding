function valid_emg_labels = emg_raw_mvc_plot(mvc_rs, filename)
%==========================================================================
% emg_raw_mvc_plot(mvc_rs, filename)
%
% ⦿ 기능:
%   - emg_mvc_process() 결과(`mvc_rs`)를 입력으로 받아, 채널별 MVC 신호를
%     시간축으로 시각화하고 채널 유효성 검사(is_valid_mvc)를 수행
%   - 결과를 PNG 이미지로 저장하고 간단한 요약을 명령창에 출력
%
% ⦿ 입력:
%   - mvc_rs  : emg_mvc_process()가 반환한 구조체
%               · 필드 `fs`(샘플링 주파수, Hz)
%               · 근육명 필드들(예: VM/VM1/VL/RF/.../SOL) = 필터링된 EMG 파형
%   - filename: 저장할 이미지 파일명 (예: 'S001_walk1_mvc1.png')
%
% ⦿ 출력:
%   - valid_emg_labels: 1xN 논리(또는 0/1) 벡터 (채널 순서: ordered_labels)
%
% ⦿ 처리 요약:
%   1) `mvc_rs`의 근육명 필드들을 순회하며 시간 기반으로 플롯
%   2) `is_valid_mvc()`로 채널 품질을 평가하고 제목 색상(정상: 검정, 비정상: 빨강) 표시
%   3) Figure를 PNG로 저장하고, 유효 채널 개수를 요약 출력
%   ※ 본 함수는 추가 필터링을 수행하지 않고, 입력(`emg_mvc_process`)의 결과를 그대로 사용
%==========================================================================

% ─── EMG 신호 선택 ─── (emg_mvc_process 결과 사용)
fs = mvc_rs.fs;

% emg_raw_txt_plot과 동일한 순서로 고정 (set2 우선, 없으면 set1)
canonical_set2 = {'VM1','VM2','VL','RF','BF','ST','TA','GL','GM','SOL'};
canonical_set1 = {'VM','VL','RF1','RF2','BF','ST','TA','GL','GM','SOL'};
if isfield(mvc_rs, 'VM1') || isfield(mvc_rs, 'VM2')
    desired_order = canonical_set2;
else
    desired_order = canonical_set1;
end
% 존재하는 필드만 순서대로 채택 (남는 필드 처리 불필요: 프로젝트에서 10채널 고정)
ordered_labels = desired_order(cellfun(@(nm) isfield(mvc_rs, nm), desired_order));

% ─── Figure 설정 (emg_raw_txt_plot 포맷과 유사) ───
fh = figure('Position', [0, 0, 600, 800], 'Visible', 'off');

% ─── 각 EMG 채널마다 처리 및 시각화 (세로 1열) ───
n_muscles = numel(ordered_labels);
valid_emg_labels = zeros(1, n_muscles);  % 1: 정상, 0: 이상
for i = 1:n_muscles
    sig_label = ordered_labels{i};
    sig = mvc_rs.(sig_label);

    % emg_mvc_process에서 이미 필터링 완료된 신호 사용

    % subplot 배치 (n_muscles x 1)
    subplot(n_muscles, 1, i);

    % 시간 기반 플롯 (라인 두께 및 축 스타일 통일)
    t_ = (0:numel(sig)-1) / fs;
    plot(t_, sig, 'b', 'LineWidth', 2), hold on, box off
    set(gca, 'Color', 'none')

    % MVC 유효성 검사
    [is_valid, mvc_reason] = is_valid_mvc(sig);
    if ~is_valid
        title_str = sprintf('%s (%s)', sig_label, mvc_reason);
        title(title_str, 'Interpreter', 'none', 'Color', 'red')
    else
        title_str = sig_label;
        title(title_str, 'Interpreter', 'none', 'Color', 'black')
        valid_emg_labels(i) = 1;
    end

    % 마지막 subplot이 아니면 x축 라벨 숨김 (emg_raw_txt_plot과 동일 처리)
    if i < n_muscles
        set(gca, 'XTickLabel', []);
    end
end

% ─── 전체 Figure 제목 및 저장 ───
[~, name] = fileparts(filename);
sgtitle(name, 'Interpreter', 'none')  % 파일 이름을 figure 제목으로
set(fh,'InvertHardcopy',false)
saveas(fh, filename)                  % PNG로 저장
close(fh)                             % Figure 닫기

% 요약 출력 (파일명만 표시) - filename이 string/char 모두 안전하게 처리
if isstring(filename)
    filename_char = char(filename);
else
    filename_char = filename;
end
[~, saved_base, saved_ext] = fileparts(filename_char);
saved_file = [saved_base saved_ext];
fprintf('[Raw MVC plot] Saved: %s | valid_channels: %d/%d\n', ...
    saved_file, sum(valid_emg_labels), numel(ordered_labels));

end
